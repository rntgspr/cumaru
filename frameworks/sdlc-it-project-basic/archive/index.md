---
human_revised: false
generated: true
generated-at: 2026-05-01T00:00:00Z
apps: [meta]
---

<!-- llm:archive -->
| Key | Type | Apps | Summary | Absorbed-in |
|-----|------|------|---------|-------------|

_No archived plans yet._
<!-- /llm:archive -->

# Archive

A pillar for **plans that have shipped**. Once a plan closes (Lead runs the archive flow), the plan directory moves here, its delta is absorbed into `specs/`, and this index gains a new row.

## Rules

- **Rows are durable; directories are ephemeral.** After plan close and spec absorption, `archive/<KEY>/` is pruned in the same archive flow (see `llm-archive` skill, Phase 4). Only the row in this index survives, carrying `Absorbed-in: <commit-sha>` pointing at the commit that applied the absorption.
- **In-flight archives** (between Phase 1 copy and Phase 4 prune) carry a full directory with `index.md`, `delta.md`, and `handoff-t<N>.md`.
- **Never loaded by default.** The shallow index (this file) is the only opportunistic entry point. For verbose change wording, drill in via `git show <Absorbed-in>` or open the linked PR.
- **Curated.** Only completed plans live here. Each row's `Absorbed-in:` is the cited commit; `Summary` is one line.
- **Plan IDs are immutable.** Whether tracker-backed (`JET-1234`, `LIN-42`, …) or slug-based (`maintenance-<slug>`), the row's `Key` matches the original plan ID exactly.

## When to consult

- Tracing why a spec area looks the way it does — follow the area's `deltas:` list (plan IDs) to find the corresponding rows here, then `git show <Absorbed-in>` for the verbose change wording.
- Reviewing a Requirement's wording when the spec body is terse — same drill-in path via the commit SHA.
- Looking up how a similar past ticket was decomposed (DAG, handoffs) before authoring a new plan — `git show --stat <Absorbed-in>` then drill into specific files at that commit.

## When NOT to consult

- Routine planning of new work — start at `intake/` + `plans/`.
- Browsing for general context — the five pillars already serve current work.
- Anything still in progress — that lives in `plans/`, not here.
