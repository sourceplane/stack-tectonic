# db-migrate

`db-migrate` is an exported Orun composition in the Stack Tectonic catalog.

## Purpose

Run database migrations from a pnpm + Turborepo monorepo: install the
workspace, build the `@saas/db` package, assume the environment's GitHub-OIDC
plan role, then invoke the migration runner (`dist/runner/cli.js`) in either
`plan` or `apply` mode. The Orun environment name is passed through as
`MIGRATION_ENV` and as `--env`, so plan and apply always target the environment
the run belongs to.

## Contract

- **Type:** `db-migrate`
- **Path:** `compositions/db-migrate`
- **Composition:** `composition.yaml`
- **Schema:** `schema.yaml` — the authoritative parameter contract
- **Job:** `migrate` (default) — `jobs/db-migrate-run.yaml`
- **Default profile:** `apply`
- **Required parameters:** `nodeVersion`, `pnpmVersion`, `secretName`
- **Optional parameters:** `owner`, `repo`

either profile in CI needs them set.

## Profiles

Each file in `profiles/` selects steps from the job by capability.

| Profile           | Steps |
| ----------------- | ----- |
| `plan`            | setup-node → setup-pnpm → install → build → plan. Reports pending migrations without mutating the database; used on pull requests. |
| `apply` (default) | the same setup steps followed by `apply` instead of `plan`. Applies pending migrations to the live database post-merge. |

`setup-pnpm` is declared before `setup-node` in the job so `setup-node` can warm
and persist the pnpm store cache, keyed on the workspace lockfile.

## Verification

`./scripts/verify.sh` is the catalog's only gate. It asserts that this
directory's `composition.yaml` has a `metadata.name` and `spec.type` matching
the directory, that `schema.yaml` and `jobs/` exist beside it, then packs the
catalog and confirms `db-migrate` exports from the packed artifact.
