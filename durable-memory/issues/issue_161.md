---
name: additive-meta-keys-break-released-update
description: Keep released binaries able to read the main domain config after additive meta keys ship
status: open
priority: high
---

# Issue 161: Additive `meta` keys on main break `cumaru update` in released binaries

Commit `27224c9` ships `meta.context` and `meta.doctor` in every
`domains/*/config.yaml` while the config version stays 9. Binaries up to
0.13.1 embed a schema whose `meta` object is closed
(`additionalProperties: false`). Their `cumaru update` reads the domain config
from GitHub main and validates it through `config::parse`, so the new keys are
reported as unknown properties and the command aborts. The version gate never
fires because the version is unchanged. The conclusion comes from reading the
0.13.1 source; it was not reproduced with a 0.13.1 binary.

## Risk

- Every adopter on 0.13.1 or older loses `cumaru update` against main until
  they upgrade the binary, with an error that does not mention upgrading.
- The same failure repeats on every future additive schema change.

## Required invariant

An additive, same-version change to the main domain config never makes a
released binary's `cumaru update` fail with a schema error.

## Work

1. Decide the compatibility rule: tolerate unknown properties when validating
   the remote reference, or publish domain configs per release instead of
   reading main HEAD.
2. Make the failure message name the binary upgrade when the remote config is
   newer than the embedded schema.
3. Record the rule in `specs/configuration.md` and `specs/update.md`.

## Tests

- A remote domain config with one unknown `meta` key lets `cumaru update`
  complete, or fail with an explicit upgrade message, with no project mutation.
- A remote config with a higher `version` still routes to `cumaru migrate`.

## References

- `src/commands/update.rs` remote `config::parse` of `domains/<domain>/config.yaml`
- `src/config.rs` `parse`, `validate`
- `schemas/config.schema.json` `$defs.meta`
- `tests/native/lifecycle_spec.sh`
