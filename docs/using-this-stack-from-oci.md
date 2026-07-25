# Using this stack from OCI

This repository is meant to be consumed from other repositories as a versioned OCI-hosted Orun stack. The goal is simple:

- keep `component.yaml` ownership local to the consumer repo
- keep execution contracts centralized and versioned in this catalog
- let `intent.yaml` pin which catalog release the repo uses

## What this stack publishes

The published OCI artifact ships three layers: `stack.yaml`, the composition contracts under
`compositions/`, and the starter intents under `examples/`.

The exported composition types are:

- `cloudflare-domain`
- `cloudflare-pages`
- `cloudflare-pages-turbo`
- `cloudflare-pages-terraform`
- `cloudflare-pages-turbo-terraform`
- `cloudflare-worker`
- `cloudflare-worker-turbo`
- `cloudflare-workers-assets-turbo`
- `db-migrate`
- `publish-stack`
- `terraform`
- `turbo-package`

Each type is a directory under `compositions/<name>/` holding `composition.yaml`, `schema.yaml`,
`jobs/`, and `profiles/`. See [authoring.md](authoring.md) for what each document does.

## The split to keep in mind

There are two separate things to pin in a consumer repo:

1. Your CI workflow pins the Orun runtime version (for example `sourceplane/orun-action@v1.1.0`).
2. `intent.yaml` pins the composition catalog release.

That separation matters because upgrading the CLI and upgrading the stack contracts are different lifecycle decisions.

## Minimal `intent.yaml`

Use an OCI composition source in the consumer repository:

```yaml
apiVersion: sourceplane.io/v1
kind: Intent
metadata:
  name: my-platform

compositions:
  sources:
    - name: stack-tectonic
      kind: oci
      ref: oci://ghcr.io/sourceplane/stack-tectonic:0.13.0

discovery:
  roots:
    - apps
    - infra
    - deploy

environments:
  development: {}
  production: {}
```

The important line is the OCI source:

```yaml
ref: oci://ghcr.io/sourceplane/stack-tectonic:0.13.0
```

Pin a released version instead of `latest` so plans stay reproducible.

## Default GitHub Actions workflow

Use the copyable workflow in [remote-state-matrix-ci.md](remote-state-matrix-ci.md) as the default GitHub Actions template for consumer repositories using Orun with this stack.

## Local component ownership

The consuming repository should keep `component.yaml` files next to the code or infrastructure they own.

Example, adapted from `compositions/cloudflare-pages/tests/smoke/component.yaml`:

```yaml
apiVersion: sourceplane.io/v1
kind: Component

metadata:
  name: marketing-site

spec:
  type: cloudflare-pages
  lifecycle: production
  owner: platform
  domain: platform-docs
  path: website

  subscribe:
    environments:
      - name: development
        profile: pull-request
      - name: production
        profile: deploy

  parameters:
    nodeVersion: "20"
    appDir: .
    installCommand: pnpm install --frozen-lockfile
    buildCommand: pnpm run build
    outputDir: dist
    projectName: marketing-site
    deployBranch: main
```

The component stays repo-local. Only the execution contract for `cloudflare-pages` comes from the OCI package.

## Choosing a profile per environment

Each entry under `subscribe.environments` names the execution profile that environment runs. A
profile includes a subset of the job's capabilities, so the same component can build and verify on a
pull request and additionally provision, deploy, and smoke-test on production. Omit `profile` and
the composition's `spec.defaultProfile` applies.

Consult the composition's README for its profile list, or run `orun compositions list --long`
against your intent.

## Recommended adoption path

1. Start with atomic compositions like `terraform`, `cloudflare-pages`, or `turbo-package`.
2. Adopt monorepo-aware types like `cloudflare-pages-turbo`, `cloudflare-worker-turbo`, or
   `cloudflare-workers-assets-turbo` when the repo needs them.
3. Layer in the Terraform-reconciled variants (`cloudflare-pages-terraform`,
   `cloudflare-pages-turbo-terraform`, `cloudflare-domain`) once projects and DNS need to be managed
   as infrastructure rather than created by hand.
4. Use the starter intents under `examples/` as a shape reference for multi-composition repos.

## Upgrade flow

1. Update the OCI ref in `intent.yaml`.
2. Lock or re-resolve composition sources if the consumer workflow uses source locking.
3. Run `orun validate` and `orun plan`.
4. Promote the catalog upgrade through environments like any other platform change.

## GitHub Actions workflow template

For the default consumer workflow that compiles a single plan and runs it through a remote-state matrix in GitHub Actions, see [remote-state-matrix-ci.md](remote-state-matrix-ci.md).

## Why this repo uses a catalog structure

The layout separates:

- `compositions/` for atomic contracts, each decomposed into schema, job templates, and profiles
- `examples/` for starter consumer intents
- `docs/` for consumer and contributor guidance
- `scripts/` and `.github/workflows/` for the release gate

That makes the stack easier to search, test, version, and consume one type at a time.
