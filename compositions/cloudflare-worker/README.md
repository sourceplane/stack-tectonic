# cloudflare-worker

`cloudflare-worker` is an exported Orun composition in the Stack Tectonic catalog.

## Purpose

Verify a standalone Cloudflare Worker package — install, structure check
(`package.json` plus `wranglerConfig`), build, typecheck — and deploy it with
the component's own `deployCommand`, which runs with `CLOUDFLARE_ACCOUNT_ID` and
`CLOUDFLARE_API_TOKEN` asserted present.

For a Worker inside a pnpm + Turborepo monorepo use `cloudflare-worker-turbo`.

## Contract

- **Type:** `cloudflare-worker`
- **Path:** `compositions/cloudflare-worker`
- **Composition:** `composition.yaml`
- **Schema:** `schema.yaml` — the authoritative parameter contract
- **Job:** `verify-deploy` (default) — `jobs/cloudflare-worker-verify-deploy.yaml`
- **Default profile:** `verify`
- **Required parameters:** `nodeVersion`, `installCommand`, `buildCommand`,
  `deployCommand`, `wranglerConfig` (default `wrangler.jsonc`)
- **Optional parameters:** `pnpmVersion`, `appDir` (default `.`),
  `typecheckCommand`, `dryRunCommand`, `preDeployCommand`, `migrationCommand`,
  `smokeCommand`

## Profiles

Each file in `profiles/` selects steps from the job by capability.

| Profile            | Steps |
| ------------------ | ----- |
| `pull-request`     | setup-node → install → verify-structure → build → typecheck |
| `verify` (default) | `pull-request` steps + deploy-dry-run |
| `deploy`           | `pull-request` steps + pre-deploy → migrate → deploy → smoke; requires approval and a clean git tree |

## Verification

`./scripts/verify.sh` is the catalog's only gate. It asserts that this
directory's `composition.yaml` has a `metadata.name` and `spec.type` matching
the directory, that `schema.yaml` and `jobs/` exist beside it, then packs the
catalog and confirms `cloudflare-worker` exports from the packed artifact.
