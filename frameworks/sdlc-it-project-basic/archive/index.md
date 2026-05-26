---
human_revised: false
generated: true
generated-at: 2026-05-01T00:00:00Z
apps: [meta]
---

<!-- llm:archive -->
| Key | Type | Apps | Summary |
|-----|------|------|---------|

_No archived plans yet._
<!-- /llm:archive -->

# Archive

A pillar for **plans that have shipped**. Once a plan closes (Lead runs the archive flow), the plan directory moves here, its delta is absorbed into `specs/`, and this index gains a new row.

## Rules

- **Never loaded by default.** The shallow index (this file) is the only opportunistic entry point. Drilling into `<PLAN-ID>/` requires explicit instruction or a reference from another file (a spec's `deltas:` list, a story's `## Coordination` section).
- **Curated.** Only completed plans live here. Each entry's frontmatter carries `status: done`, `completed-at:`, and `delta: delta.md`.
- **Read by reference.** A spec's frontmatter `deltas:` list points to archive entries. Open `archive/<PLAN-ID>/delta.md` when the spec body is ambiguous and you need the verbose change wording.
- **Each entry is a directory** with `index.md` (status, completed-at, delta), `delta.md` (Added / Modified / Removed Requirements), and the `handoff-t<N>.md` files carried over from the plan.
- **Plan IDs are immutable.** Whether tracker-backed (`JET-1234`, `LIN-42`, …) or slug-based (`maintenance-<slug>`), the directory name in archive matches the original plan ID exactly.

## When to consult

- Tracing why a spec area looks the way it does — follow the area's `deltas:` list to the archive entries that built it.
- Reviewing the verbose wording of a Requirement when the spec body is terse.
- Looking up how a similar past ticket was decomposed (DAG, `handoff-t<N>.md`, files touched) before authoring a new plan.

## When NOT to consult

- Routine planning of new work — start at `intake/` + `plans/`.
- Browsing for general context — the five pillars already serve current work.
- Anything still in progress — that lives in `plans/`, not here.
