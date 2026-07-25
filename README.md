# Stack Tectonic

Versioned OCI catalog of reusable Orun compositions, starter examples, and release metadata.

This repository is the source of truth for the stack published to:

`oci://ghcr.io/sourceplane/stack-tectonic:<version>`

## Use the OCI package in `intent.yaml`

Pin the catalog as a composition source in the consumer repository:

```yaml
compositions:
  sources:
    - name: stack-tectonic
      kind: oci
      ref: oci://ghcr.io/sourceplane/stack-tectonic:0.13.0
```

Pin the catalog in `intent.yaml`, then run it with Orun. The full consumer setup is in [docs/using-this-stack-from-oci.md](docs/using-this-stack-from-oci.md), and the default GitHub Actions workflow template is documented in [docs/remote-state-matrix-ci.md](docs/remote-state-matrix-ci.md).

## Catalog layout

```text
stack-tectonic/
├── stack.yaml
├── README.md
├── docs/
├── compositions/
├── examples/
├── scripts/
└── .github/workflows/
```

`orun publish` ships the layers a consumer actually resolves: `stack.yaml`, `compositions/`, and `examples/`.

## Composition layout

Every composition lives under `compositions/<name>/` and is decomposed into four kinds of file:

```text
compositions/<name>/
├── composition.yaml   # kind: Composition — schemaRef, defaultJob, defaultProfile, jobs[], profiles[]
├── schema.yaml        # kind: ComponentSchema — JSON Schema (draft-07) for component parameters
├── jobs/<job>.yaml    # kind: JobTemplate — declares capabilities[] and the steps[] that implement them
└── profiles/<p>.yaml  # kind: ExecutionProfile — selects a subset of a job's capabilities
```

Each step in a job template is tagged with a `capability`, and a profile lists the capabilities it
includes. That is how a plan-only lane and a release lane share one job template instead of
duplicating steps. Components pick a profile per environment:

```yaml
spec:
  type: cloudflare-pages
  subscribe:
    environments:
      - name: staging
        profile: verify
      - name: production
        profile: deploy
```

## Compositions

| Composition | Category | Profiles (default first) | Purpose |
| --- | --- | --- | --- |
| `cloudflare-domain` | dns | `apply`, `plan-only` | Cloudflare zones plus Pages/Worker custom domain attachments, managed with Terraform |
| `cloudflare-pages` | hosting | `verify`, `pull-request`, `deploy` | Cloudflare Pages build, verify, and direct-upload deploy pipeline |
| `cloudflare-pages-turbo` | hosting | `verify`, `pull-request`, `deploy` | Cloudflare Pages deployment built from a pnpm and Turbo monorepo |
| `cloudflare-pages-terraform` | platform | `verify`, `pull-request`, `release` | Cloudflare Pages deployment managed with Terraform |
| `cloudflare-pages-turbo-terraform` | platform | `verify`, `pull-request`, `release` | Turbo monorepo Pages build reconciled with Terraform |
| `cloudflare-worker` | edge | `verify`, `pull-request`, `deploy` | Cloudflare Worker build, verify, and deploy pipeline |
| `cloudflare-worker-turbo` | edge | `verify`, `pull-request`, `deploy` | Cloudflare Worker delivery from a Turborepo build |
| `cloudflare-workers-assets-turbo` | edge | `verify`, `pull-request`, `deploy` | Worker + Static Assets single-bundle delivery for apps that emit a Worker entrypoint plus an `ASSETS` directory |
| `terraform` | infrastructure | `apply`, `plan-only`, `local` | Terraform validation and planning for multi-tenant SaaS infrastructure components |
| `db-migrate` | data | `apply`, `plan` | Database migration runner — plan on pull requests, apply on merge |
| `publish-stack` | release | `dry-run`, `verify`, `release` | Publish an Orun stack to an OCI registry with dry-run validation |
| `turbo-package` | developer-experience | `verify`, `quick-check` | Shared package verification in a pnpm and Turbo workspace |

Most compositions carry their own `README.md` with parameter and profile detail beside the contract.

## Trust signals

- `scripts/verify.sh` is the single catalog gate. It structurally validates every
  `compositions/*/composition.yaml` (`metadata.name` and `spec.type` must equal the directory name,
  and `schema.yaml` plus `jobs/` must exist), resolves the publish target with
  `orun publish --dry-run`, then stages and packs the shipped layers and resolves the packed
  artifact back through a throwaway consumer intent using `kind: archive`, asserting every
  composition exports.
- Packing and re-resolving is the part that carries weight: `orun publish --dry-run` only resolves
  the manifest and target, so on its own it is no evidence the package is loadable by a consumer.
- `.github/workflows/verify.yml` runs that script on every pull request and every push to `main`.
- `.github/workflows/release.yml` runs the same script before publishing a tag.
- Where a composition ships a smoke fixture under `compositions/<name>/tests/`, it is excerpted or
  adapted from a real consumer repository so the contract is documented with a real repo shape
  instead of a synthetic placeholder. Five of the twelve have one today; see
  [docs/roadmap.md](docs/roadmap.md).

## Docs

- [Getting started](docs/getting-started.md)
- [Core concepts](docs/concepts.md)
- [Authoring guide](docs/authoring.md)
- [Verification model](docs/verification.md)
- [Production deploys](docs/production-deploys.md)
- [Remote-state matrix CI](docs/remote-state-matrix-ci.md)
- [Roadmap](docs/roadmap.md)
- [Using this stack from OCI](docs/using-this-stack-from-oci.md)

## Release flow

1. Update `metadata.version` in `stack.yaml`.
2. Run `./scripts/verify.sh`.
3. Merge to `main`.
4. Push a matching tag like `v0.13.0`.

The release workflow asserts the tag matches `stack.yaml`, reruns `./scripts/verify.sh`, creates the
GitHub release, then publishes the OCI package and confirms it is pullable with `orun fetch`. The
package is pushed after the release is created so the tag and release notes are the record of record
before the immutable artifact exists.
