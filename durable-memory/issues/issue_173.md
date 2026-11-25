---
name: decide-archive-artifact-reporting
description: Decide whether native update reports installed cumaru-archive skills and launchers, or retire that Bash-era review
status: open
priority: low
---

# Issue 173: Decide whether update reports archive skill artifacts

The retired Bash update reported deprecated archive pillars and configuration
plus installed `cumaru-archive` skill or launcher artifacts for explicit
reconciliation. Native `cumaru update` prints a review line only for an existing
`.cumaru/archive/` directory (`src/commands/update.rs`); installed archive
skills and launchers are not reported. `update.md` invariant 6 now records only
the native behavior.

## Risk

- Adopters upgrading from the archive era keep stale `cumaru-archive` skills or
  launchers that no command surfaces for review.

## Required invariant

Either content update reports every installed `cumaru-archive` skill and
launcher without mutating it, or the specification states that archive artifact
review was retired and names where adopters find that guidance.

## Work

1. Decide between porting the report and retiring it.
2. Implement the report or record the retirement in `update.md` and the
   migration guidance.

## Tests

- With an installed `cumaru-archive` skill, preview and apply print one review
  line and leave the skill bytes unchanged; without one, no line is printed.

## References

- `src/commands/update.rs`
- `durable-memory/specs/update.md` invariant 6
- [`src/cmd_update.sh`](https://github.com/rntgspr/cumaru/blob/0.10.0/src/cmd_update.sh) — retired reference
