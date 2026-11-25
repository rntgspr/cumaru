---
name: validate-source-disciplines-before-update
description: Reject invalid source discipline strictness before update publication instead of only in the doctor postcheck
status: open
priority: low
---

# Issue 174: Validate source discipline metadata before update writes

The retired Bash `schema_validate_disciplines` (tag 0.10.0, `src/schema.sh`)
rejected invalid source-domain discipline strictness before install or update
wrote anything. Native install keeps that gate
(`install::validate_disciplines`), but native `cumaru update` plans and
publishes refreshed `.cumaru/disciplines/*.md` without validating their
strictness first; only the post-publication doctor inspection reports the
defect, leaving the published change for Git recovery.

## Risk

- A main-HEAD discipline with missing or out-of-range `strictness` is written
  into an adopter tree before any check fails, so the adopter must restore it
  from Git or, outside Git, by hand.

## Required invariant

Update refuses, before any write, a plan whose refreshed discipline files other
than the index carry missing or invalid `strictness`, with status 1 and every
adopter byte unchanged.

## Work

1. Reuse `markdown::validate_strictness` on every planned discipline candidate
   during update planning.
2. Update `disciplines.md` preflight item 1 to name the native owner.

## Tests

- A stubbed source discipline with `strictness: 11/10` makes
  `update --apply` exit 1 before publication and leaves the project unchanged.
- A valid source discipline refreshes and passes the doctor postcheck.

## References

- `src/commands/update.rs`
- `src/commands/install.rs` — `validate_disciplines`
- `durable-memory/specs/disciplines.md` preflight item 1
