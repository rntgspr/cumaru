---
name: context-missing-listed-path-fails-ranking
description: Stop a missing meta.context path from failing ordinary context queries
status: open
priority: high
---

# Issue 164: A missing listed `meta.context` path fails ordinary ranking

A `meta.context` entry that does not exist is a diagnostic that makes
`execute` return a partial failure. That applies to every invocation, not only
to the doctor-triggered warm. Shipped defaults list directories an adopter may
legitimately lack: `sdlc-light` lists `exploring`, which is absent in a fresh
clone when it is empty and untracked. Every `cumaru context "query"` then
prints its rows and exits 1, `cumaru update` reports the cache as not warmed,
and doctor with `meta.doctor.after.warm: true` fails a passing report.

## Risk

- Agents treat a successful ranking as failed because of the exit status.
- A shipped default makes doctor fail on a healthy tree once warm is enabled.

## Required invariant

A listed path that is absent only fails the command when the maintainer
decided it must; an ordinary ranking query with usable rows exits 0.

## Work

1. Decide the classification: warning for query and update warm, failure only
   for the doctor-triggered warm, or honor `optional` from the `root` tree.
2. Apply it in `inventory`/`execute` without duplicating the walk.
3. Update `docs/context.md` and `specs/context.md`.

## Tests

- With `adopter: [specs, exploring]` and no `exploring/`, a query prints rows
  and exits with the decided status.
- Doctor with warm enabled and the same tree exits with the decided status.

## References

- `src/commands/context.rs` `inventory`, `execute`, `warm`
- `src/commands/doctor.rs` `after_warm`
- `domains/sdlc-light/config.yaml` `meta.context`
