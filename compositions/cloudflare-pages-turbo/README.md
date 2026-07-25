# cloudflare-pages-turbo

`cloudflare-pages-turbo` is an exported Orun composition in the Stack Tectonic catalog.

## Purpose

Build a static app inside a pnpm + Turborepo monorepo and direct-upload it to
Cloudflare Pages. The deploy profile reconciles the Pages project through the
Cloudflare API before uploading `outputDir`.

## Contract

- **Type:** `cloudflare-pages-turbo`
- **Path:** `compositions/cloudflare-pages-turbo`
- **Composition:** `composition.yaml`
- **Schema:** `schema.yaml` — the authoritative parameter contract
- **Job:** `verify-deploy` (default) — `jobs/cloudflare-pages-turbo-verify-deploy.yaml`
- **Default profile:** `verify`
- **Required parameters:** `nodeVersion`, `pnpmVersion`, `workspaceDir`,
  `appDir`, `turboFilter`, `outputDir`, `projectName`
- **Optional parameters:** `installCommand` (default
  `pnpm install --frozen-lockfile`), `buildCommand`, `deployBranch` (default
  `main`), `smokeCommand`, `environmentAwareProjectName`, `environmentBuildVar`
- **Per-env naming:** `environmentAwareProjectName: true` appends the Orun
  environment name as a suffix to `projectName` (e.g. `my-app` becomes
  `my-app-stage` in the stage environment).
- **Build-time env:** `environmentBuildVar` names a Vite-compatible variable
  (e.g. `VITE_DEPLOY_ENV`) exported with the Orun environment name during build.

## Profiles

Each file in `profiles/` selects steps from the job by capability.

| Profile            | Steps |
| ------------------ | ----- |
| `pull-request`     | setup-node → setup-pnpm → install → verify-structure → build → verify-output |
| `verify` (default) | same steps as `pull-request` — full non-mutating verification |
| `deploy`           | `verify` steps + provision → deploy → smoke; requires approval and a clean git tree |

## Test fixtures

- `tests/smoke/component.yaml`

## Verification

`./scripts/verify.sh` is the catalog's only gate. It asserts that this
directory's `composition.yaml` has a `metadata.name` and `spec.type` matching
the directory, that `schema.yaml` and `jobs/` exist beside it, then packs the
catalog and confirms `cloudflare-pages-turbo` exports from the packed artifact.
