# Getting started

`stack-tectonic` is a versioned Orun stack catalog. Consumer repositories pin it as an OCI composition source, then declare local `component.yaml` manifests that use the exported composition types.

## 1. Pin the Orun runtime in CI

Use `sourceplane/orun-action` in GitHub Actions and pin the action version you want the consuming repository to run.

## 2. Pin the catalog

Declare this stack in `intent.yaml`:

```yaml
compositions:
  sources:
    - name: stack-tectonic
      kind: oci
      ref: oci://ghcr.io/sourceplane/stack-tectonic:0.13.0
```

## 3. Discover local components

Point `discovery.roots` at the application, infra, and deploy directories that own `component.yaml` files.

## 4. Pick a profile per environment

Each component subscribes to environments and names the execution profile that runs there:

```yaml
spec:
  type: cloudflare-pages
  subscribe:
    environments:
      - name: development
        profile: pull-request
      - name: production
        profile: deploy
```

A profile selects a subset of the composition's job steps, so the non-mutating and mutating lanes come from the same contract. Omit `profile` and the composition's default applies.

## 5. Plan and apply

Run `orun validate`, `orun plan`, or `orun run` against that intent. The stack stays versioned independently from the consuming repository.

For the full repo-consumer workflow, see [using-this-stack-from-oci.md](using-this-stack-from-oci.md). For the default GitHub Actions template, see [remote-state-matrix-ci.md](remote-state-matrix-ci.md).
