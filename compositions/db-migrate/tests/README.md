# Tests for db-migrate

These files provide contract or smoke fixtures that CI can inspect for `db-migrate` without requiring a full consumer repository checkout.

- `tests/smoke` — a product whose db package is not `@saas/db`, adapted from a real consumer. `scripts/verify.sh` plans it through the packed artifact and checks that the build step builds the package `buildFilter` names.
