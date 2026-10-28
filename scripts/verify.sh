#!/usr/bin/env bash
# Catalog gate. Proves the tree in compositions/ is publishable *and* consumable:
# `orun publish --dry-run` only resolves the manifest and target, so on its own it
# is no evidence the package is valid. Packing the archive and resolving it back
# through a throwaway intent exercises the same code path a consumer repo runs.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

stack_version="$(awk '/^  version: /{print $2}' stack.yaml)"
test -n "$stack_version"

# Every composition directory must carry the decomposed contract: a
# composition.yaml whose metadata.name and spec.type both match the directory.
expected=0
for contract in "$repo_root"/compositions/*/composition.yaml; do
  name="$(basename "$(dirname "$contract")")"
  meta_name="$(awk '/^metadata:/{f=1;next} f&&/^  name:/{print $2;exit}' "$contract")"
  spec_type="$(awk '/^spec:/{f=1;next} f&&/^  type:/{print $2;exit}' "$contract")"
  if [ "$meta_name" != "$name" ]; then
    echo "verify: $name: metadata.name is '$meta_name', expected '$name'" >&2
    exit 1
  fi
  if [ "$spec_type" != "$name" ]; then
    echo "verify: $name: spec.type is '$spec_type', expected '$name'" >&2
    exit 1
  fi
  test -f "$(dirname "$contract")/schema.yaml" \
    || { echo "verify: $name: missing schema.yaml" >&2; exit 1; }
  test -d "$(dirname "$contract")/jobs" \
    || { echo "verify: $name: missing jobs/" >&2; exit 1; }
  expected=$((expected + 1))
done
test "$expected" -gt 0 || { echo "verify: no compositions found" >&2; exit 1; }
echo "verify: $expected composition contract(s) structurally valid"

# A job template sees exactly three namespaces: .orun, .parameters and .env
# (orun's planner builds no others). A condition on anything else is always
# false, so its step silently takes the else branch for every consumer. That is
# how turbo-package's pre-build skipped every component's tests from 0.18 to
# 0.20.0 while its lanes went green. Inside a range or with block `.` is
# rebound; use a variable there ({{ $x := ... }}) so this rule can see it.
bad_guards="$(grep -rnoE '\{\{-?[[:space:]]*(else[[:space:]]+)?(if|with)[[:space:]][^}]*' compositions \
  | grep -oE '^[^:]+:[0-9]+:|[[:space:](]\.[A-Za-z_][A-Za-z0-9_]*' \
  | awk '/^[^ (.]/{loc=$0; next} {key=$0; sub(/^[[:space:](]\./, "", key); if (key != "orun" && key != "parameters" && key != "env") print loc " ." key}')"
if [ -n "$bad_guards" ]; then
  echo "verify: these guards read a key the template context does not have (it has .orun, .parameters, .env):" >&2
  echo "$bad_guards" >&2
  exit 1
fi
echo "verify: every template guard reads .orun, .parameters or .env"

# Resolve the publish target and version without uploading.
orun publish "ghcr.io/sourceplane/stack-tectonic:${stack_version}" \
  --dry-run \
  --root . \
  --version "$stack_version"

# Pack, then resolve the packed artifact back through a consumer intent. This is
# the step that would catch a composition orun cannot load or export.
work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

# `orun pack` archives the whole root, but `orun publish` ships only the
# stack.yaml + compositions/ and examples/ layers. Stage that subset so the
# artifact we verify is the artifact consumers actually resolve.
stage_dir="$work_dir/stage"
mkdir -p "$stage_dir"
cp stack.yaml "$stage_dir/"
cp -R compositions "$stage_dir/"
[ -d examples ] && cp -R examples "$stage_dir/"

orun pack --root "$stage_dir" --output "$work_dir/stack.tgz" >/dev/null

cat > "$work_dir/intent.yaml" <<EOF
apiVersion: sourceplane.io/v1
kind: Intent
metadata:
  name: stack-tectonic-verify
compositions:
  sources:
    - name: stack-tectonic
      kind: archive
      path: $work_dir/stack.tgz
discovery:
  roots: []
environments:
  dev: {}
EOF

listed="$(cd "$work_dir" && orun compositions list --intent intent.yaml)"
echo "$listed"

for contract in "$repo_root"/compositions/*/composition.yaml; do
  name="$(basename "$(dirname "$contract")")"
  echo "$listed" | grep -q -- "$name" \
    || { echo "verify: '$name' packed but not exported by the package" >&2; exit 1; }
done

echo "verify: all $expected composition(s) export from the packed artifact"

# Render, not just resolve: plan a turbo-package component through the packed
# artifact and check its declared commands reach the steps. Structural checks
# passed every release that skipped pre-build; this one would have failed.
fixture="$work_dir/consumer"
mkdir -p "$fixture/packages/declared" "$fixture/packages/defaults"
cat > "$fixture/intent.yaml" <<EOF
apiVersion: sourceplane.io/v1
kind: Intent
metadata:
  name: stack-tectonic-render
compositions:
  sources:
    - name: stack-tectonic
      kind: archive
      path: $work_dir/stack.tgz
discovery:
  roots:
    - packages/
environments:
  dev: {}
EOF
for pkg in declared defaults; do
  {
    echo "apiVersion: sourceplane.io/v1"
    echo "kind: Component"
    echo "metadata:"
    echo "  name: $pkg"
    echo "spec:"
    echo "  type: turbo-package"
    echo "  subscribe:"
    echo "    environments:"
    echo "      - name: dev"
    echo "        profile: verify"
    echo "  parameters:"
    echo "    nodeVersion: \"20\""
    echo "    pnpmVersion: \"10.12.1\""
    if [ "$pkg" = declared ]; then
      echo "    preBuildCommand: echo render-check-pre-build"
      echo "    buildCommand: echo render-check-build"
      echo "    typecheckCommand: echo render-check-typecheck"
    fi
  } > "$fixture/packages/$pkg/component.yaml"
done
(cd "$fixture" && orun plan --no-catalog-refresh --format json --output plan.json >/dev/null)

step_run() { # <job-id prefix> <step id>
  jq -r --arg j "$1" --arg s "$2" \
    '.jobs[] | select(.id | startswith($j + ".")) | .steps[] | select(.id == $s) | .run' \
    "$fixture/plan.json"
}
expect() { # <job> <step> <text the rendered run must contain>
  run="$(step_run "$1" "$2")"
  case "$run" in
    *"$3"*) ;;
    *) echo "verify: turbo-package rendered $1/$2 as '$run', expected it to contain '$3'" >&2; exit 1 ;;
  esac
}
expect declared pre-build         "echo render-check-pre-build"
expect declared build-package     "echo render-check-build"
expect declared typecheck-package "echo render-check-typecheck"
expect defaults pre-build         'echo "Skipping pre-build."'
expect defaults build-package     "pnpm exec turbo run build --filter=./"
expect defaults typecheck-package "pnpm exec turbo run typecheck --filter=./"
echo "verify: turbo-package renders declared commands and falls back to its defaults"

# cloudflare-worker-turbo's deploy step passes --x-provision=false only when a
# component sets skipResourceProvisioning: absent or false keeps wrangler's
# default, so no consumer changes behaviour until it opts in. The deploy
# profile binds secrets, so this fixture declares a placeholder workspace.
workers="$work_dir/workers"
mkdir -p "$workers/apps/opted-in" "$workers/apps/default"
cat > "$workers/intent.yaml" <<EOT
apiVersion: sourceplane.io/v1
kind: Intent
metadata:
  name: stack-tectonic-render-workers
execution:
  state:
    workspace: ws_rendercheck
    project: render-check
compositions:
  sources:
    - name: stack-tectonic
      kind: archive
      path: $work_dir/stack.tgz
discovery:
  roots:
    - apps/
environments:
  stage: {}
EOT
for worker in opted-in default; do
  {
    echo "apiVersion: sourceplane.io/v1"
    echo "kind: Component"
    echo "metadata:"
    echo "  name: $worker"
    echo "spec:"
    echo "  type: cloudflare-worker-turbo"
    echo "  subscribe:"
    echo "    environments:"
    echo "      - name: stage"
    echo "        profile: deploy"
    echo "  parameters:"
    echo "    nodeVersion: \"20\""
    echo "    pnpmVersion: \"10.12.1\""
    echo "    workspaceDir: ../.."
    echo "    appDir: ."
    echo "    turboFilter: $worker"
    echo "    wranglerConfig: wrangler.jsonc"
    [ "$worker" = opted-in ] && echo "    skipResourceProvisioning: true"
  } > "$workers/apps/$worker/component.yaml"
done
(cd "$workers" && orun plan --no-catalog-refresh --format json --output plan.json >/dev/null)
deploy_run() { # <component>
  jq -r --arg j "$1" \
    '.jobs[] | select(.id | startswith($j + ".")) | .steps[] | select(.id == "deploy") | .run' \
    "$workers/plan.json"
}
opted_in="$(deploy_run opted-in)"
default_run="$(deploy_run default)"
case "$opted_in" in
  *'provision_flag="--x-provision=false"'*) ;;
  *) echo "verify: cloudflare-worker-turbo deploy ignores skipResourceProvisioning: true" >&2; exit 1 ;;
esac
case "$default_run" in
  *"--x-provision=false"*) echo "verify: cloudflare-worker-turbo deploy skips provisioning without being asked to" >&2; exit 1 ;;
esac
for run in "$opted_in" "$default_run"; do
  case "$run" in
    *'wrangler deploy --config wrangler.jsonc --env stage $provision_flag'*) ;;
    *) echo "verify: cloudflare-worker-turbo deploy command changed shape: $run" >&2; exit 1 ;;
  esac
done
echo "verify: cloudflare-worker-turbo passes --x-provision=false only when a component opts in"
