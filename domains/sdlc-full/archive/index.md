---
human_revised: false
apps: [meta]
summary: Framework guidance for Archive and its required workflow.
---


# Archive

A transient staging pillar for **plans that have shipped and are being absorbed**. Once a plan closes, the plan directory moves here, its delta is absorbed into `specs/`, and the directory is removed after absorption.

## Rules

- **Archive is transient.** Rows and directories exist only while absorption is in flight. After specs are updated, the durable record moves to `specs/index.md` `cumaru:absorptions`.
- **In-flight archives** carry a full directory with `index.md`, `delta.md`, and `handoff-t<N>.md`.
- **Never loaded by default.** The shallow index (this file) is only an operational queue for close-out work.
- **Curated.** Only completed plans awaiting absorption live here.
- **Plan IDs are immutable.** Whether tracker-backed (`AAA-1234`, `LIN-42`, …) or slug-based (`maintenance-<slug>`), the row's `Key` matches the original plan ID exactly.

## When to consult

- Continuing an in-flight absorption that was paused after a plan moved out of `plans/`.
- Auditing archive cleanup before running `cumaru doctor`.

## When NOT to consult

- Routine planning of new work — start at `intake/` + `plans/`.
- Looking for durable history — use `specs/index.md` `cumaru:absorptions`.
- Anything still being implemented — that lives in `plans/`, not here.
