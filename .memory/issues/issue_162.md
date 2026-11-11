---
name: doctor-drift-reference-schema-failure-is-fatal
description: Keep doctor reporting when the downloaded drift reference fails this binary's schema
status: open
priority: high
---

# Issue 162: A schema-invalid drift reference aborts the whole doctor

`drift` in `src/commands/doctor.rs` validates the downloaded reference config
with this binary's embedded schema and propagates the failure with `?`. An
additive change on main that the binary does not know turns the warn-only
drift check into a hard failure: `inspect` returns an error, no report is
printed, and the `cumaru update --apply` postcheck fails after publication.
The rejected reference is already cached as today's file, so the failure
repeats until the next day or a manual delete.

## Risk

- One additive key on main disables `cumaru doctor` for every installed
  binary of the previous release.
- `cumaru update --apply` reports an error after it already wrote changes.

## Required invariant

A drift reference that this binary cannot validate produces a non-failing
drift warning; the remaining doctor checks still run and are reported.

## Work

1. Downgrade reference parse, validation, and reconcile failures to a
   `Configuration drift` warning that names the cause.
2. Do not keep a reference that failed validation as today's cache file, or
   mark it so the next run does not treat it as usable.
3. Update `docs/doctor.md` and `specs/doctor.md`.

## Tests

- A cached reference with an unknown `meta` key yields exit 0, a drift
  warning, and the full report.
- The `update --apply` postcheck does not fail for the same reference.

## References

- `src/commands/doctor.rs` `drift`, `reference`
- `src/commands/update.rs` doctor postcheck
- `tests/native/lifecycle_spec.sh`
