---
human_revised: false
generated: true
generated-at: 2026-06-05T00:00:00Z
apps: [meta]
---

<!-- cumaru:archive -->
| Link | Description |
|------|-------------|

_No archived campaigns yet._
<!-- /cumaru:archive -->

# Archive

**Campaigns that have closed.** Once a campaign finishes (Lead runs the archive flow), the plan directory moves here, its delta is absorbed into `coverage/`, and this index gains a row.

## Rules

- **Rows are durable; directories are ephemeral.** After absorption, `archive/<KEY>/` is pruned in the same flow (see `cumaru-archive`, Phase 4). Only the row survives, carrying `Absorbed-in: <commit-sha>` pointing at the absorption commit.
- **In-flight archives** (between copy and prune) carry a full directory with `index.md`, `delta.md`, and `handoff-t<N>.md`.
- **Never loaded by default.** Drill in via `git show <Absorbed-in>` or the linked PR for verbose wording.
- **Plan IDs are immutable.** The row's `Key` matches the original plan ID exactly.

## When to consult

- Tracing why a coverage area looks the way it does — follow the area's `deltas:` list to the rows here, then `git show <Absorbed-in>`.
- Reviewing how a past campaign was sequenced (cases, handoffs) before authoring a new one.

## When NOT to consult

- Routine planning of new work — start at `intake/` + `plans/`.
- Anything still in flight — that lives in `plans/`.
