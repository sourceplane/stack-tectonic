# cloudflare-pages

`cloudflare-pages` is an exported Orun composition in the Stack Tectonic catalog.

## Purpose

Build static site assets and direct-upload them to Cloudflare Pages with
Wrangler (`wrangler pages deploy`). The deploy profile first reconciles the
Pages project through the Cloudflare API — creating it if it is missing and
pinning its production branch — before uploading `outputDir`.

## Contract

- **Type:** `cloudflare-pages`
- **Path:** `compositions/cloudflare-pages`
- **Composition:** `composition.yaml`
- **Schema:** `schema.yaml` — the authoritative parameter contract
- **Job:** `verify-deploy` (default) — `jobs/cloudflare-pages-verify-deploy.yaml`
- **Default profile:** `verify`
- **Required parameters:** `nodeVersion`, `appDir`, `installCommand`,
  `buildCommand`, `outputDir`, `projectName`
- **Optional parameters:** `deployBranch` (default `main`), `smokeCommand`

## Profiles

Each file in `profiles/` selects steps from the job by capability.

| Profile            | Steps |
| ------------------ | ----- |
| `pull-request`     | setup-node → install → build → verify-output |
| `verify` (default) | same steps as `pull-request` — full non-mutating verification |
| `deploy`           | `verify` steps + provision → deploy → smoke; requires approval and a clean git tree |

## Test fixtures

- `tests/smoke/component.yaml`

## Verification

`./scripts/verify.sh` is the catalog's only gate. It asserts that this
directory's `composition.yaml` has a `metadata.name` and `spec.type` matching
the directory, that `schema.yaml` and `jobs/` exist beside it, then packs the
catalog and confirms `cloudflare-pages` exports from the packed artifact.
