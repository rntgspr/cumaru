---
name: doctor-newer-reference-version-aborts-report
description: Decide how doctor reports a main config version newer than the binary supports
status: open
priority: high
---

# Issue 163: A newer reference version aborts the doctor report

When the drift reference on main carries a `version` greater than the one this
binary supports, `drift` returns an error telling the adopter to run
`cumaru migrate`. That was the requested behavior, but it aborts the entire
doctor: no health report is printed although the local v9 tree is valid for
this binary, and the installed binary cannot migrate to a version it does not
know. The `cumaru update --apply` postcheck fails the same way.

## Risk

- The day main moves to the next config version, every installed binary of
  the previous version loses `cumaru doctor` entirely.
- The message points to `cumaru migrate`, which the old binary cannot perform
  toward the new version; the real action is upgrading the binary first.

## Required invariant

A reference version newer than the binary supports is reported with the
correct next action, and never hides the health of the installed tree.

## Work

1. Decide with the maintainer: keep the hard stop, or print the report and
   end with a failing or warning drift line.
2. Make the message name the binary upgrade before `cumaru migrate`.
3. Update `docs/doctor.md` and `specs/doctor.md` with the decision.

## Tests

- A reference with `version: 10` produces the decided status and message, and
  the remaining checks are reported if the decision is not a hard stop.
- A reference with `version: 9` is unaffected.

## References

- `src/commands/doctor.rs` `drift`, `SUPPORTED_VERSION`
- `src/commands/update.rs` doctor postcheck
- `.memory/specs/migration.md`
