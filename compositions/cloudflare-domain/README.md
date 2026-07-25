# cloudflare-domain composition

Manages Cloudflare DNS zones and custom domain attachments for Pages and Worker
projects via Terraform.

## Component Type

`cloudflare-domain`

## Parameters

`schema.yaml` is the authoritative contract for this table.

| Parameter | Required | Description |
|-----------|----------|-------------|
| `stackName` | yes | Terraform stack identifier |
| `terraformDir` | yes | Path to Terraform root relative to component |
| `terraformVersion` | yes | Terraform CLI version |
| `baseDomain` | yes | The root domain managed by this component (e.g. `example.com`) |
| `zoneMode` | yes | `existing` adopts a zone already present in Cloudflare (no zone creation); `managed` creates and manages the zone lifecycle via Terraform |
| `pagesProjectPrefix` | yes | Pages project name prefix. The full project name is derived as `{pagesProjectPrefix}-{environment}` at plan time |
| `awsAccountId` | no | AWS account ID hosting the GitHub-OIDC role this component assumes |
| `awsRegion` | no | AWS region for state backend |
| `orgName` | no | Organization name for state bucket |
| `owner` | no | GitHub repository owner |
| `repo` | no | GitHub repository name |
| `namespace` | no | Logical namespace |
| `namespacePrefix` | no | Environment-scoped prefix |

## Zone Modes

### `existing` (adopt)

Use when the domain is already added to a Cloudflare account. The Terraform
module uses `data.cloudflare_zone` to look up the zone by name. No zone
creation or deletion occurs.

### `managed` (create)

Use when the domain has not been added to Cloudflare. The Terraform module
creates a `cloudflare_zone` resource and manages its full lifecycle. Delegation
(NS records at the registrar) must be completed manually after the first apply.

## Profiles

Defined in `composition.yaml` against the single job `cloudflare-domain`
(`jobs/cloudflare-domain-validate.yaml`). `apply` is the `defaultProfile`.

- **plan-only**: setup → aws-credentials → env → context → fmt → init →
  workspace → validate → plan. Used for PR validation.
- **apply**: the same steps plus `terraform apply`. Used on main-branch pushes.

## Outputs

Non-secret outputs reported by the Terraform module:

- `zone_id` — Cloudflare zone identifier
- `zone_name` — Domain name of the zone
- `zone_status` — Zone activation status
- `pages_custom_domains` — Map of attached Pages custom domain hostnames and statuses
