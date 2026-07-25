# Verification model

The catalog has one gate, `scripts/verify.sh`, and two workflows that run it.

## `scripts/verify.sh`

The script runs from the repository root and executes four stages in order. Any failure stops the run.

### 1. Structural validation of every composition contract

For each `compositions/*/composition.yaml`:

- `metadata.name` must equal the directory name
- `spec.type` must equal the directory name
- `schema.yaml` must exist beside it
- `jobs/` must exist beside it

The run also fails if no composition directories are found at all, so an empty or mis-staged tree
cannot pass silently.

### 2. Publish target resolution

```bash
orun publish "ghcr.io/sourceplane/stack-tectonic:${stack_version}" \
  --dry-run --root . --version "${stack_version}"
```

`stack_version` is read from `metadata.version` in `stack.yaml`. This resolves the manifest and the
registry target without uploading anything.

### 3. Pack the shipped layers

`orun pack` archives whatever root it is given, but `orun publish` ships only `stack.yaml`,
`compositions/`, and `examples/`. The script stages exactly that subset into a temporary directory
and packs it, so the artifact under test is the artifact consumers actually resolve.

### 4. Resolve the packed artifact back through a consumer intent

The script writes a throwaway `intent.yaml` pointing at the packed tarball with an `archive`
composition source:

```yaml
compositions:
  sources:
    - name: stack-tectonic
      kind: archive
      path: <tmp>/stack.tgz
```

It then runs `orun compositions list --intent intent.yaml` and asserts that every composition
directory in the repo appears in the output.

This last stage is the point of the script. A dry-run publish only proves the manifest and target
resolve; it is no evidence the package is loadable. Packing and re-resolving exercises the same code
path a consumer repository runs, so a composition Orun cannot load or export fails here instead of
in a downstream repo after release.

## Verify workflow

`.github/workflows/verify.yml` runs on every pull request and every push to `main`. It is a single
`verify-stack` job: check out, log in to GHCR, set up Orun via `sourceplane/orun-action`, and run
`./scripts/verify.sh`.

## Release workflow

`.github/workflows/release.yml` runs on tag pushes matching `v*`:

1. Derive the version from `metadata.version` in `stack.yaml` and assert it equals the tag without
   its leading `v`. A mismatched tag fails the release before anything is published.
2. Run `./scripts/verify.sh` — the same gate the pull request ran.
3. Create the GitHub release with `gh release create --generate-notes`, skipping if it already exists.
4. Publish the OCI package with an explicit target. The target is passed explicitly because with no
   ref `orun` infers `ghcr.io/<owner>/<repo>/<package>` from the git remote, which is the wrong
   repository path.
5. Confirm the package is pullable: `orun fetch` into a temp directory, assert `stack.yaml` is
   present, and report the exported composition count.

The package push deliberately runs *after* the release is created, so the tag and release notes are
the record of record before the immutable artifact exists.
