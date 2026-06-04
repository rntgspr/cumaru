---
human_revised: false
version: 1
name: llm-explore
description: Use this skill whenever the user wants to capture, evolve, promote, or drop an infrastructure spike — an idea that isn't a changeset yet. Trigger on phrases like "explore <topic>", "let's sketch a multi-region setup", "ideia nova sobre X", "should we move to OpenTofu", "promove essa exploração pra um plano", "drop this spike", "what's in exploring/?", or any task framed as pre-change ideation. Knows the `exploring/` pillar and the `promote → plans/maintenance-<slug>/` path.
---

# `llm-explore` — capture and evolve `exploring/` entries

Infrastructure spikes are **transient** — a provider migration to weigh, a cost-optimization hypothesis, a multi-region sketch. They either mature into a changeset or get dropped. This skill carries the bootstrap recipe plus the two terminal exits (promote / drop). For raw file ops use `llm flow`.

## Layout (recap from schema)

```
exploring/<slug>/
├── index.md          ← required; frontmatter [status!, summary!, apps!]
└── *.md              ← optional aux
```

`<slug>` is **pure kebab-case** — no `maintenance-` prefix, no tracker key. `status:` ∈ `idea | considering | promoted | dropped` (the last two are terminal — the directory moves or is deleted).

## Recipe: bootstrap a spike

1. **Agree on a slug** — short, kebab-case (`move-to-opentofu`, `multi-region-dr`). Confirm.
2. `llm flow exploring/<slug> create` → `llm flow exploring/<slug>/index.md create`
3. Open `templates/exploration.md`; frontmatter: `status: idea`, `summary` (8-12 words), `apps:` (environments concerned).
4. Body (free prose): `## Idea`, `## Context`, `## Options / sketches`, `## Open questions`, `## Promotion / drop criteria`. For infra, weigh cost, blast radius, reversibility, and the apply-order impact on the topology.
5. Re-emit `exploring/index.md` via `llm tag set exploring/index.md exploring <new body>` (Idea | Apps | Summary).
6. `llm doctor`.

## Recipe: evolve status (idea → considering)

Edit the frontmatter `status:` only. No move; the table carries no Status column, so no re-emit needed.

## Recipe: promote a spike to a changeset

1. **Decide the destination key.** Tracker item exists → `plans/<KEY>/` (run `llm intake <KEY>` first if needed). Else → `plans/maintenance-<slug>/`.
2. **Carry over the body** — the spike's `## Options` / `## Open questions` become raw material for the changeset's `## Plan / DAG`, `## Blast radius`, `## Rollback`. Distill what survived; don't dump verbatim.
3. **Hand off to `llm-plan`** to author the changeset frontmatter + body.
4. **Remove or carry the spike:** `llm flow exploring/<slug> remove`, or `llm flow exploring/<slug> copy plans/<PLAN-ID>/exploration.md` first if the notes are worth keeping.
5. Re-emit `exploring/index.md` (row gone) and `plans/index.md` (row appears). `llm doctor`.

## Recipe: drop a spike

1. Confirm — "drop is permanent (no archive; only applied changes flow to archive). Sure?"
2. `llm flow exploring/<slug> remove` → re-emit `exploring/index.md` → `llm doctor`.

**Don't migrate spikes to archive/.** Archive holds applied changesets only.

## What this skill does NOT do

- **Changeset authoring** — `llm-plan`. **Topology** — explorations never touch `topology/`; only applied changes do, via `llm-archive`. **Tracker mirror** — `llm-intake` first if you need an issue.

## Patterns

| User says | You do |
|---|---|
| "Let's explore moving to OpenTofu" / "ideia nova" | Bootstrap recipe → propose slug → confirm → create from template → re-emit |
| "What's in exploring?" | Read `exploring/index.md`; drill into a `<slug>/` that interests |
| "Promote multi-region-dr to a change" | Promote recipe → decide key → hand off to `llm-plan` → remove/carry the spike |
| "Drop the opentofu idea" | Confirm → `llm flow exploring/move-to-opentofu remove` → re-emit |

Use `llm tag get/set` (CLI) for `exploring/index.md`; pair with `llm-plan` (promote) and `llm-doctor`.
