# cloudflare-worker-turbo

`cloudflare-worker-turbo` is an exported Orun composition in the Stack Tectonic catalog.

## Purpose

Verify a Cloudflare Worker package inside a pnpm + Turborepo monorepo and deploy
it. On top of the plain `cloudflare-worker` lifecycle this composition adds
deploy-time wiring: a committed wrangler template can be rendered from a
Secrets Manager wiring document before deploy, and managed runtime secrets can
be hydrated from an escrow after deploy.

## Contract

- **Type:** `cloudflare-worker-turbo`
- **Path:** `compositions/cloudflare-worker-turbo`
- **Composition:** `composition.yaml`
- **Schema:** `schema.yaml` — the authoritative parameter contract
- **Job:** `verify-deploy` (default) — `jobs/cloudflare-worker-turbo-verify-deploy.yaml`
- **Default profile:** `verify`
- **Required parameters:** `nodeVersion`, `pnpmVersion`, `workspaceDir`,
  `appDir`, `turboFilter`, `wranglerConfig` (default `wrangler.jsonc`)
- **Optional command parameters:** `installCommand` (default
  `pnpm install --frozen-lockfile`), `buildCommand`, `typecheckCommand`,
  `dryRunCommand`, `preDeployCommand`, `migrationCommand`, `deployCommand`,
  `smokeCommand`
- **Optional wiring parameters:** `wranglerTemplate` (empty means a legacy
  committed config and the wiring steps no-op), `wiringComponents`,
  `wiringEnvs` (default `stage,prod`), `wiringFixture` (default
  `wiring.fixture.json`), `runtimeSecrets` (default
  `us-east-1`), `orgName`, `owner`, `repo`

## Profiles

Each file in `profiles/` selects steps from the job by capability.

| Profile            | Steps |
| ------------------ | ----- |
| `pull-request`     | setup-node → setup-pnpm → install → verify-structure → build → typecheck |
| `verify` (default) | `pull-request` steps + wire-fixture (offline render) and deploy-dry-run — never needs cloud credentials |
| `deploy`           | setup → install → verify-structure → wire-fixture → build → typecheck → wire-live → pre-deploy → migrate → deploy → secrets-live → smoke; requires approval and a clean git tree |

`wire-live` is deploy-only by design so verify lanes stay
credential-free; both no-op for components without a `wranglerTemplate`, and
`secrets-live` pushes the component's orun-resolved runtime secrets (`runtimeSecrets` names, best-effort via `optionalSecretEnv`) and no-ops for components without them.

## Verification

`./scripts/verify.sh` is the catalog's only gate. It asserts that this
directory's `composition.yaml` has a `metadata.name` and `spec.type` matching
the directory, that `schema.yaml` and `jobs/` exist beside it, then packs the
catalog and confirms `cloudflare-worker-turbo` exports from the packed artifact.
