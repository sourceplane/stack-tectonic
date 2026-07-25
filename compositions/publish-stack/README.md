# publish-stack

`publish-stack` is an exported Orun composition in the Stack Tectonic catalog.

## Purpose

Publish an Orun stack to an OCI registry. Runs `orun publish --dry-run` on every pull request and performs the real publish on release.

## Contract

- **Type:** `publish-stack`
- **Path:** `compositions/publish-stack`
- **Definition:** `composition.yaml`

## Profiles

| Profile   | Description                                      |
|-----------|--------------------------------------------------|
| `dry-run` | PR validation — runs `orun publish --dry-run`    |
| `verify`  | Staging validation — dry-run without publishing  |
| `release` | Production — dry-run + real publish to registry  |

## Inputs

| Input      | Required | Description                                               |
|------------|----------|-----------------------------------------------------------|
| `registry` | yes      | OCI registry base URL, e.g. `ghcr.io/org/stack-name`     |
| `version`  | yes      | Stack version to publish; passed to `orun publish --version` |
| `root`     | no       | Root directory of the stack (default `.`)                 |

## Example fixtures

- `examples/`
