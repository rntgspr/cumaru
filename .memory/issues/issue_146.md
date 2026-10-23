---
name: compact-bash-narrative-in-specs
description: After 145 lands, collapse each spec's historical Bash narration into an explicit differences section so the active contract is stated once
status: open
priority: low
---

# Issue 146: Compact historical Bash narrative in current specifications

Several command specifications currently carry two parallel contract
narratives: the active native behavior and a retained Bash-era description
("the Bash surface below is unchanged", "intentional differences from
Bash", doubled implementation and method tables). After issue 145 resolves
the implementation-map ownership, the historical content remains spread
through the body as if it were a second current contract. The
[`compact_text`](../disciplines/compact_text.md) discipline's principle —
reference the canonical source instead of duplicating its content — applies
to the byte-prose layer of the specs themselves.

## Risk

- Readers cannot tell which of two contract narratives governs the shipped
  binary, so a stale Bash sentence is quoted as current behavior.
- Every future native change must be written past the duplicated Bash
  narration, doubling maintenance cost on each spec edit.

## Required invariant

Each command specification states one active contract; historical Bash
behavior appears only in clearly labeled bounded sections (`## Differences
from the retired Bash CLI` or equivalent) that are referenced from
`rust.md` rather than restated — historical deltas are contained in one or
fewer explicit sections, and yesterday's behavior never reads as present or
future behavior.

## Work

1. For each spec touched by issue 145, collapse the remaining Bash-era
   prose into a single bounded section, keeping only deltas a port reader
   genuinely needs (what was deliberately omitted or renamed).
2. Reconcile duplicated implementation/method tables left by representative
   examples: `navigation.md`, `tags.md`, `testing.md` keep each table once
   and point the other direction through `rust.md`.
3. Update `rust.md`'s per-command "Bash differences" cross-references so
   they point at the new bounded sections instead of duplicating their
   content.

## Tests

- For `navigation.md`, `tags.md`, `update.md`: `rg -n 'Bash'` matches only
  the bounded differences sections and explicit historical labels.
- No spec outside `rust.md` and the labeled sections asserts present-tense
  Bash behavior (spot-check with `rg -ni 'the bash (implementation|command|module) remains|is unchanged'`).

## References

- `.memory/specs/rust.md` — canonical differences ledger
- `.memory/issues/issue_145.md` — prerequisite ownership realignment
- `.memory/disciplines/compact_text.md` — the applied principle
