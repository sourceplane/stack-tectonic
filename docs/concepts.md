# Concepts

## Stack catalog

This repository is a catalog, not an application repo. It publishes versioned execution contracts that other repositories consume through OCI.

## Compositions

`compositions/` contains atomic Orun `Composition` contracts. These are the stable type-level building blocks exported by the stack package, one directory per exported type.

## Component schemas

Each composition ships a `ComponentSchema` in `schema.yaml`: a JSON Schema (draft-07) that constrains the `parameters` block of a consumer's `component.yaml`. It is what makes a typo in a parameter name a validation failure rather than a silently ignored key.

## Job templates

`jobs/<job>.yaml` holds a `JobTemplate`: the runner, timeout, the full list of `capabilities` the job can perform, and the ordered `steps` that implement them. Every step is tagged with exactly one capability.

## Execution profiles

`profiles/<profile>.yaml` holds an `ExecutionProfile`, which lists the capabilities to include for each job. A profile is a subset of a job template, so a plan-only lane and a release lane share one set of steps instead of duplicating them. Profiles may also carry `policies` such as `requireApproval` or `requireCleanGitTree`, which is where mutating lanes get their guardrails.

Consumers select a profile per environment under `subscribe.environments`; `spec.defaultProfile` in `composition.yaml` applies when none is named.

## Examples

`examples/` contains starter intents that show how a consumer repo can reference the OCI package and structure discovery roots.

## Trust model

There is one gate, `scripts/verify.sh`, run by two workflows. It validates every composition contract structurally, resolves the publish target with a dry run, then packs the layers that actually ship and resolves the packed artifact back through a throwaway consumer intent. Release automation runs the identical gate before it publishes a tag. See [verification.md](verification.md).
