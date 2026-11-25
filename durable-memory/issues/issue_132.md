---
name: remaining-domain-bootstraps
description: Move every remaining domain's bootstrap steps into a source-only bootstrap.md
status: open
priority: medium
---

# Issue 132: Ship bootstrap.md for the remaining domains

Only `focus` ships `bootstrap.md`. For `design-as-code`, `iac-basic`,
`qa-basic`, `sdlc-full`, `sdlc-light`, and `vault-memory`, `cumaru bootstrap`
prints the `__base` rules plus a "ships no bootstrap.md" note, while their steps
remain inside each `cumaru-install` skill.

## Risk

- Two bootstrap contracts coexist, and install-skill steps drift from pillars.

## Required invariant

Every domain ships a `bootstrap.md` naming each of its pillar directories and
templates, and its `cumaru-install` skill points to `cumaru bootstrap` instead
of restating steps.

## Work

1. Move each domain's bootstrap section from its `cumaru-install` skill into
   `domains/<domain>/bootstrap.md`.
2. Generalize the focus coverage check in `bootstrap_spec.sh` to every domain.

## Tests

- `cumaru bootstrap` in each installed domain prints a domain body, not the
  missing-file note.
- A domain `bootstrap.md` missing a pillar directory fails the coverage check.

## References

- `domains/*/skills/cumaru-install/SKILL.md`
- `domains/focus/bootstrap.md`
- `tests/spec/contracts/bootstrap_spec.sh`
