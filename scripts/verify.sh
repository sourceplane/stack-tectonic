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
