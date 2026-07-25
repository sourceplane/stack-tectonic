# Production deploys

This document explains how to configure reliable production deployments using stack-tectonic compositions on the production branch.

## The `--changed` trap

When using `orun run --changed` on production branch pushes (e.g. after a squash merge to `main`), the change detection compares the merge commit against its parent. Because a squash merge produces a single commit whose parent is the previous `main` HEAD, and the new commit already includes all changes, `--changed` may resolve to zero changed components:

```text
0 components x 3 envs -> 0 jobs
```

This produces a **green CI run with zero deployments** — a false positive that masks the absence of any live deployment.

## Recommended patterns

### Pattern 1: Run all production jobs on main (recommended for small repos)

Remove `--changed` from the production branch push step:

```yaml
- name: Execute
  env:
    CLOUDFLARE_ACCOUNT_ID: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
    CLOUDFLARE_API_TOKEN: ${{ secrets.CLOUDFLARE_API_TOKEN }}
  run: orun run
```

This ensures every deployable component runs its production job on every push to main. For repos with fewer than 10 components, this adds minimal overhead.

### Pattern 2: Changed-only with correct base ref

If the repo has many components and full runs are expensive, pass explicit base/head refs:

```yaml
- name: Execute
  env:
    CLOUDFLARE_ACCOUNT_ID: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
    CLOUDFLARE_API_TOKEN: ${{ secrets.CLOUDFLARE_API_TOKEN }}
  run: orun run --changed --base "${{ github.event.before }}" --head "${{ github.sha }}"
```

Using `github.event.before` as the base ensures the diff covers the actual changes introduced by the merge.

### Pattern 3: Separate deploy workflow on main

Keep `--changed` for PR validation but add a dedicated production deploy step:

```yaml
jobs:
  deploy:
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: sourceplane/orun-action@v1.1.0
      - name: Deploy all production components
        env:
          CLOUDFLARE_ACCOUNT_ID: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
          CLOUDFLARE_API_TOKEN: ${{ secrets.CLOUDFLARE_API_TOKEN }}
        run: orun run --env production
```

## Composition behavior

Deployment is not gated inside the job steps. It is decided entirely by which **execution profile**
an environment subscribes to: a deploy only happens when the selected profile includes the
composition's `deploy` capability.

For `cloudflare-pages`, `cloudflare-pages-turbo`, `cloudflare-worker`, `cloudflare-worker-turbo`,
and `cloudflare-workers-assets-turbo`:

| Profile | What runs | Mutating? |
| --- | --- | --- |
| `pull-request` | setup, install, structure/build verification | no |
| `verify` | `pull-request` plus `deploy-dry-run` where the composition has one | no |
| `deploy` | the full pipeline through `provision`/`deploy` and `smoke` | yes |

`cloudflare-pages` and `cloudflare-pages-turbo` have no `deploy-dry-run` capability, so their
`verify` lane stops at build-output verification. The `cloudflare-worker*` compositions do have one.

The Terraform-reconciled variants (`cloudflare-pages-terraform`, `cloudflare-pages-turbo-terraform`)
use the same shape with `terraform-plan` in `verify` and `terraform-apply` in `release`.

Guardrails come from profile policies rather than in-step branch checks. Every mutating profile in
the catalog sets:

```yaml
policies:
  requireApproval: true
  requireCleanGitTree: true
```

Credentials are still enforced at the step: `deploy` steps assert `CLOUDFLARE_ACCOUNT_ID` and
`CLOUDFLARE_API_TOKEN` are set and hard-fail when they are missing, rather than silently skipping.

The `deployBranch` parameter is not a gate — it is the branch name passed to
`wrangler pages deploy --branch` and to the Pages project's `production_branch` setting.

## Wiring a component

Bind the mutating profile only to the environment that should actually deploy:

```yaml
spec:
  type: cloudflare-pages-turbo
  subscribe:
    environments:
      - name: preview
        profile: pull-request
      - name: staging
        profile: verify
      - name: production
        profile: deploy
```

If an environment names no profile, the composition's `spec.defaultProfile` applies — which is
`verify` for every Cloudflare composition in this catalog, i.e. non-mutating. An environment that
should deploy must say so explicitly.

## Verifying a deploy actually happened

Check the executed step list for the run, not just its colour. If the run for the production
environment shows only the setup, install, build, and verification steps, the environment resolved a
non-mutating profile and nothing was deployed.

A green run reporting `0 components x 3 envs -> 0 jobs` means **no deployment occurred**. This is
never evidence of a successful deploy.

## Consumer repo checklist

Before relying on production deploys:

1. Set `CLOUDFLARE_ACCOUNT_ID` and `CLOUDFLARE_API_TOKEN` as GitHub repository secrets
2. Ensure your workflow passes these as environment variables to the `orun run` step
3. Subscribe the production environment to the composition's `deploy` (or `release`) profile
4. Choose one of the patterns above for your production branch push behavior
5. Replace `PLACEHOLDER` database IDs in `wrangler.jsonc` with real resource IDs
6. If using D1, configure `migrationCommand` in your `component.yaml` parameters
7. Optionally add `smokeCommand` to verify the live endpoint after deploy
