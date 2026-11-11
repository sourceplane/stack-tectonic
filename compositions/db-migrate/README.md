# db-migrate

`db-migrate` is an exported Orun composition in the Stack Tectonic catalog.

## Purpose

Run database migrations from a pnpm + Turborepo monorepo: install the
workspace, build the db package (`@saas/db` unless `buildFilter` names another),
then invoke its migration runner (`dist/runner/cli.js`) in either `plan` or
`apply` mode. The Orun environment name is passed through as `MIGRATION_ENV`
and as `--env`, so plan and apply always target the environment the run belongs
to.

## Contract

- **Type:** `db-migrate`
- **Path:** `compositions/db-migrate`
- **Composition:** `composition.yaml`
- **Schema:** `schema.yaml` — the authoritative parameter contract
- **Job:** `migrate` (default) — `jobs/db-migrate-run.yaml`
- **Default profile:** `apply`
- **Required parameters:** `nodeVersion`, `pnpmVersion`
- **Optional parameters:** `buildFilter`, `owner`, `repo`

## Parameters

| Parameter     | Default    | Meaning |
| ------------- | ---------- | ------- |
| `nodeVersion` | (required) | Node.js version for `actions/setup-node`. |
| `pnpmVersion` | (required) | pnpm version for `pnpm/action-setup`. |
| `buildFilter` | `@saas/db` | Turbo filter for the package whose `dist/runner/cli.js` runs the migrations. The build step runs `pnpm exec turbo run build --filter=<buildFilter>`. |
| `owner`       | (none)     | Repository owner, accepted for callers that still pass it. |
| `repo`        | (none)     | Repository name, accepted for callers that still pass it. |

The plan and apply steps run from the component's directory and call
`node ../../dist/runner/cli.js`. Point the component's `path` at the migrations
directory two levels below the db package (for example
`packages/db/src/migrations`), and set `buildFilter` to that package's name.

`buildFilter` fails quietly when it is wrong. The build step builds whatever
package the filter names and goes green; the plan or apply step then fails with
`MODULE_NOT_FOUND` for a `dist` that was never built. If a run's build step
reports `Packages in scope: @saas/db` and you set another filter, the parameter
is not reaching the template.

```yaml
spec:
  type: db-migrate
  path: packages/db/src/migrations
  parameters:
    nodeVersion: "20"
    pnpmVersion: "10.12.1"
    buildFilter: "@example/db"
```

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
catalog and confirms `db-migrate` exports from the packed artifact. It then
plans two components through the packed artifact, one setting `buildFilter`
and one leaving it out, and checks the rendered build step of each: the first
must build the declared package, and the second must render exactly the 0.21.0
command, `pnpm exec turbo run build --filter=@saas/db`.

`tests/smoke/component.yaml` is a fixture adapted from a real consumer: a db
package that is not `@saas/db`, with its migrations two levels below it.
