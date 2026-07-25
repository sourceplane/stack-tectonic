# cloudflare-pages-terraform

`cloudflare-pages-terraform` is an exported Orun composition in the Stack Tectonic catalog.

## Purpose

Verify a static site build locally, then reconcile a Git-backed Cloudflare Pages
project with Terraform. There is no Wrangler upload here — the Pages project is
declared in the Terraform module under `terraformDir` and Cloudflare builds from
the connected repository using `cloudflareBuildCommand` and `rootDir`.

## Contract

- **Type:** `cloudflare-pages-terraform`
- **Path:** `compositions/cloudflare-pages-terraform`
- **Composition:** `composition.yaml`
- **Schema:** `schema.yaml` — the authoritative parameter contract
- **Job:** `verify-reconcile` (default) — `jobs/cloudflare-pages-terraform-verify-reconcile.yaml`
- **Default profile:** `verify`
- **Required parameters:** `nodeVersion`, `appDir`, `installCommand`,
  `buildCommand`, `outputDir`, `terraformDir`, `terraformVersion`,
  `projectName`, `repoOwner`, `repoName`, `cloudflareBuildCommand`, `rootDir`
- **Optional parameters:** `deployBranch` (default `main`)

## Profiles

Each file in `profiles/` selects steps from the job by capability.

| Profile            | Steps |
| ------------------ | ----- |
| `pull-request`     | setup-node → install → build → verify-output → setup-terraform → terraform-fmt |
| `verify` (default) | `pull-request` steps + terraform-init → terraform-validate → terraform-plan |
| `release`          | `pull-request` steps + terraform-init → terraform-validate → terraform-apply; requires approval and a clean git tree |

## Test fixtures

- `tests/smoke/component.yaml`

## Verification

`./scripts/verify.sh` is the catalog's only gate. It asserts that this
directory's `composition.yaml` has a `metadata.name` and `spec.type` matching
the directory, that `schema.yaml` and `jobs/` exist beside it, then packs the
catalog and confirms `cloudflare-pages-terraform` exports from the packed
artifact.
