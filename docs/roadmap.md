# Roadmap

- Add a smoke fixture under `tests/smoke/` for the seven compositions that still lack one:
  `cloudflare-worker`, `cloudflare-worker-turbo`, `cloudflare-workers-assets-turbo`, `db-migrate`,
  `publish-stack`, `terraform`, and `turbo-package`.
- Extend `scripts/verify.sh` to validate smoke fixtures against each composition's `schema.yaml`,
  not just the structural presence of the contract files.
- Give every composition a README documenting its parameters and profiles; `db-migrate` has none yet.
- Add runnable composition-level examples beyond starter intents.
- Add scheduled verification so packaging regressions surface without waiting for a pull request.
- Add download and adoption metrics once the consumer footprint grows.
