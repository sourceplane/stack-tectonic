# Default GitHub Actions CI for Orun

Use this workflow as the default GitHub Actions template for repositories consuming Stack Tectonic with Orun. It compiles the plan once, uploads it as an artifact, and fans the jobs out across GitHub Actions runners using remote-state coordination.

## Required repository configuration

Set these repository-level Actions settings before enabling the workflow:

| Setting | Location | Value |
| --- | --- | --- |
| `ORUN_BACKEND_URL` | Settings -> Variables -> Actions | URL of your `orun-backend` instance |
| `CLOUDFLARE_ACCOUNT_ID` | Settings -> Secrets and variables -> Actions | Cloudflare account ID |
| `CLOUDFLARE_API_TOKEN` | Settings -> Secrets and variables -> Actions | Cloudflare API token |

`id-token: write` is required because Orun remote-state authentication uses GitHub Actions OIDC.

## Consumer repo assumption

This workflow assumes the consumer repository pins Stack Tectonic from `intent.yaml`:

```yaml
compositions:
  sources:
    - name: stack-tectonic
      kind: oci
      ref: oci://ghcr.io/sourceplane/stack-tectonic:0.13.0
```

## Default workflow template

```yaml
name: CI

on:
  pull_request:
  push:
    branches: [main]

permissions:
  contents: read
  packages: read
  id-token: write   # orun remote-state OIDC authentication

env:
  GITHUB_TOKEN: ${{ github.token }}
  ORUN_BACKEND_URL: ${{ vars.ORUN_BACKEND_URL }}

jobs:
  plan:
    name: Orun Plan
    runs-on: ubuntu-latest
    outputs:
      job-ids: ${{ steps.plan.outputs.job-ids }}
      plan-checksum: ${{ steps.plan.outputs.plan-checksum }}
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: sourceplane/orun-action/plan@v1.1.0
        id: plan
        with:
          intent: intent.yaml
          changed-only: true
          artifact-name: plan.json

  execute:
    name: ${{ matrix.job-id }}
    needs: plan
    if: needs.plan.outputs.job-ids != '[]'
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      max-parallel: 10
      matrix:
        job-id: ${{ fromJson(needs.plan.outputs.job-ids) }}
    concurrency:
      group: orun-${{ github.ref }}-${{ matrix.job-id }}
      cancel-in-progress: false
    env:
      CLOUDFLARE_ACCOUNT_ID: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
      CLOUDFLARE_API_TOKEN: ${{ secrets.CLOUDFLARE_API_TOKEN }}
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - name: Download plan artifact
        uses: actions/download-artifact@v4
        with:
          name: plan.json
      - uses: sourceplane/orun-action@v1.1.0
      - name: run job steps
        run: |
          orun run \
            --plan plan.json \
            --remote-state \
            --job "${{ matrix.job-id }}" \
            --exec-id "${{ github.run_id }}-${{ github.run_attempt }}"
```

## What this template gives you

- one plan compiled once per workflow run
- plan artifact reuse across matrix runners
- changed-only pull request and main-branch planning
- remote-state coordination across parallel GitHub Actions runners
- a pinned Orun GitHub Action version, pinned independently from the catalog release in `intent.yaml`
