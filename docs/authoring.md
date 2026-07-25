# Authoring guide

A composition is not one file. It is a directory of four kinds of document, each with its own
`kind:` and its own `metadata.name`, wired together by reference:

```text
compositions/<name>/
├── composition.yaml   # kind: Composition
├── schema.yaml        # kind: ComponentSchema
├── jobs/<job>.yaml    # kind: JobTemplate
├── profiles/<p>.yaml  # kind: ExecutionProfile
└── README.md
```

The worked example below is `compositions/turbo-package`, the smallest composition in the catalog.

## 1. `composition.yaml`

The entry point. It names the type, points at the schema, lists the job templates and execution
profiles, and picks the defaults.

```yaml
apiVersion: sourceplane.io/v1alpha1
kind: Composition
metadata:
  name: turbo-package
spec:
  type: turbo-package
  description: Turborepo package verification jobs

  schemaRef:
    name: turbo-package-component

  defaultJob: verify
  defaultProfile: verify

  jobs:
    - name: verify
      templateRef:
        name: turbo-package-verify

  profiles:
    - name: quick-check
      profileRef:
        name: turbo-package-quick-check
    - name: verify
      profileRef:
        name: turbo-package-verify
```

`metadata.name` and `spec.type` must both equal the directory name — `scripts/verify.sh` fails the
build otherwise.

Note the two namespaces. `jobs[].name` and `profiles[].name` are the short names a component uses
(`profile: quick-check`). `templateRef.name` and `profileRef.name` are the `metadata.name` of the
documents under `jobs/` and `profiles/`, which are prefixed with the composition name to stay unique
across the catalog.

## 2. `schema.yaml`

A `ComponentSchema` holding a JSON Schema (draft-07) for the component document. Constrain `type`
with a `const` so a mistyped component fails validation, and set
`parameters.additionalProperties: false` so unknown parameters are caught rather than silently
ignored.

```yaml
apiVersion: sourceplane.io/v1alpha1
kind: ComponentSchema
metadata:
  name: turbo-package-component
spec:
  type: turbo-package
  schema:
    $schema: http://json-schema.org/draft-07/schema#
    title: Turbo Package Component
    type: object
    required: [name, type, parameters]
    properties:
      name:
        type: string
      type:
        type: string
        const: turbo-package
      parameters:
        type: object
        required: [nodeVersion, pnpmVersion]
        properties:
          nodeVersion: { type: string }
          pnpmVersion: { type: string }
          preBuildCommand: { type: string }
          buildCommand: { type: string }
          typecheckCommand: { type: string }
        additionalProperties: false
    additionalProperties: true
```

`metadata.name` here is what `composition.yaml`'s `schemaRef.name` points at.

## 3. `jobs/<job>.yaml`

A `JobTemplate` declares the full set of `capabilities` the job can perform, then defines the
`steps` that implement them. Every step carries a `capability` tag. Steps either `run` a shell
command or `use` a GitHub Action with `with:` inputs, and component parameters are interpolated as
`{{ .parameters.<name> }}`.

```yaml
apiVersion: sourceplane.io/v1alpha1
kind: JobTemplate
metadata:
  name: turbo-package-verify
spec:
  description: Install the workspace and validate a shared package
  runsOn: ubuntu-22.04
  timeout: 25m
  retries: 0

  labels:
    scope: verify

  capabilities:
    - turbo-package.setup-node
    - turbo-package.setup-pnpm
    - turbo-package.install
    - turbo-package.pre-build
    - turbo-package.verify-structure
    - turbo-package.build
    - turbo-package.typecheck

  steps:
    - id: setup-pnpm
      name: setup-pnpm
      capability: turbo-package.setup-pnpm
      use: pnpm/action-setup@v4
      with:
        version: "{{.parameters.pnpmVersion}}"

    # ... install, pre-build, verify-structure ...

    - id: build-package
      name: build-package
      capability: turbo-package.build
      run: "{{if .buildCommand}}{{.parameters.buildCommand}}{{else}}pnpm exec turbo run build --filter=./{{end}}"
      onFailure: stop
```

Conventions worth keeping:

- Namespace capabilities as `<composition>.<verb>` so they stay unique across the catalog.
- One capability per step, and keep steps atomic — a capability that bundles "build and deploy"
  cannot be split across profiles later.
- Set `onFailure: stop` on steps that must not be skipped past.
- Order matters: steps run in file order, and profiles filter that order rather than reordering it.

## 4. `profiles/<profile>.yaml`

An `ExecutionProfile` selects which capabilities of which job actually run. This is how one job
template serves several lanes.

```yaml
apiVersion: sourceplane.io/v1alpha1
kind: ExecutionProfile
metadata:
  name: turbo-package-quick-check
spec:
  description: Quick check with setup and structure verification only

  jobs:
    verify:
      includeCapabilities:
        - turbo-package.setup-node
        - turbo-package.setup-pnpm
        - turbo-package.install
        - turbo-package.verify-structure
```

The key under `jobs:` is the short job name from `composition.yaml` (`verify`), not the template
name. The sibling `turbo-package-verify` profile includes the same list plus `pre-build`, `build`,
and `typecheck` — that difference is the entire distinction between the two lanes.

Profiles may also carry `policies`. `compositions/cloudflare-pages/profiles/cloudflare-pages-deploy.yaml`
sets `requireApproval: true` and `requireCleanGitTree: true`; `publish-stack`'s `release` profile
sets `requireCleanGitTree: true`. Attach those to the mutating profiles, not the verification ones.

### Choosing a profile from a component

Consumers bind a profile per environment, which is why the same composition can be non-mutating on a
pull request and mutating on production:

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

If a component names no profile, `spec.defaultProfile` from `composition.yaml` applies.

## Add a composition

1. Create `compositions/<name>/` and write the four documents above. Keep `metadata.name` and
   `spec.type` in `composition.yaml` equal to the directory name.
2. Give the composition at least one non-mutating profile and, if it mutates anything, one mutating
   profile guarded by policies.
3. Add a realistic fixture under `compositions/<name>/tests/smoke/component.yaml`, preferably
   excerpted or adapted from a consumer-style repo.
4. Write `compositions/<name>/README.md` documenting the parameters and the profiles.
5. Run `./scripts/verify.sh`.

## Keep the catalog clean

- Prefer atomic compositions over variant explosions; prefer a new profile over a new composition
  when the only difference is which steps run.
- Keep capabilities fine-grained enough that a future profile can pick a subset of them.
- Keep fixtures close enough to real repositories that they can guide consumers and feed CI.
- Keep the OCI consumption story pinned to released versions, not floating refs.
