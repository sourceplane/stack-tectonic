# Terraform Composition

Repo-local Orun composition for Terraform infrastructure components.

## Contract

| Field | Value |
| --- | --- |
| Type | `terraform` |
| Composition | `composition.yaml` |
| Schema | `schema.yaml` |
| Job | `terraform` (default) — `jobs/terraform-validate.yaml` |
| Default Profile | `apply` |
| Profiles | `plan-only`, `apply`, `local` |

## Parameters (from schema)

`schema.yaml` is the authoritative contract for this table.

| Parameter | Required | Description |
| --- | --- | --- |
| `stackName` | yes | Logical name of the Terraform stack |
| `terraformDir` | yes | Relative path to the Terraform root module |
| `terraformVersion` | yes | Pinned Terraform CLI version |
| `secretOutputs` | no | Comma-separated `KEY=output` pairs queued on the runner sink after apply and published over the lease-bound channel (SEC-JOB) |
| `orgName` | no | Organization name |
| `owner` | no | GitHub org owner |
| `repo` | no | GitHub repo name |
| `namespace` | no | Logical namespace |
| `namespacePrefix` | no | Environment-scoped prefix |
| `lane` | no | Deployment lane |

## Profiles

Each file in `profiles/` selects steps from the `terraform` job by capability.

### `plan-only`

Non-mutating validation: setup, env export, context, fmt, init, validate, plan
(state served by the platform's terraform HTTP backend via runner-exported
TF_HTTP_* — no cloud credentials step, no workspaces). Used on pull requests
to preview changes.

### `apply` (default)

Full lifecycle: the `plan-only` steps plus `terraform apply`. Used on
main-branch pushes when profile rules select it.

### `local`

The `plan-only` steps without the `terraform.aws-credentials` step, so a
developer can run the plan lane on a workstation using ambient AWS credentials
instead of assuming the GitHub-OIDC role. Stops at `plan` — it never applies.

## Job Steps

1. **setup-terraform** — Install pinned Terraform version
2. **aws-credentials** — Assume the environment's GitHub-OIDC plan role (skipped by `local`)
3. **terraform-env** — Export `TF_VAR_*` from component parameters and environment
4. **terraform-context** — Print version and component metadata
5. **terraform-fmt-check** — Enforce canonical formatting
6. **terraform-init** — Initialize with S3 backend config
7. **terraform-workspace** — Select or create environment workspace
8. **terraform-validate** — Validate configuration
9. **terraform-plan** — Generate execution plan
10. **terraform-apply** — Apply changes (only in the `apply` profile)

## S3 Backend Convention

```
bucket: {orgName}-{environment}
key:    {repo}/{componentName}/terraform.tfstate
region: {awsRegion}
```

Note: S3 backend consumption requires IAM roles from `aws-admin` (Task 0004/0005).
Until then, `terraform init` will fail on live runs but `orun validate` and
`orun plan` will succeed.

## Local Verification

```bash
orun compositions --intent intent.yaml --long
orun validate --intent intent.yaml
```

The catalog gate itself is `./scripts/verify.sh`, run from the repository root.
