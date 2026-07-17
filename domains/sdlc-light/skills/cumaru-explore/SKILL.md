---
human_revised: false
version: 1
name: cumaru-explore
description: Use this skill whenever the user wants to capture, evolve, promote, or drop an exploration — an idea that isn't a plan yet. Trigger on phrases like "explore <topic>", "let's sketch <idea>", "ideia nova sobre X", "promove essa exploração pra um plano", "drop this exploration", "what's in exploring/?", or any task framed as pre-plan ideation. Skill is sdlc-light-only (knows the `exploring/` pillar and the `promote → plans/<PLAN-ID>/` path).
summary: Use this skill whenever the user wants to capture, evolve, promote, or drop an exploration — an idea that isn't a plan yet. Trigger on phrases like "explore <topic>", "let's sketch <idea>", "ideia nova sobre X", "promove essa exploração pra um plano", "drop this exploration", "what's in exploring/?", or any task framed as pre-plan ideation. Skill is sdlc-light-only (knows the `exploring/` pillar and the `promote → plans/<PLAN-ID>/` path).
---

# `cumaru-explore` — capture and evolve `exploring/` entries

Explorations are **transient** — they either mature into a plan or get dropped. This skill carries the bootstrap recipe plus the two terminal exits (promote / drop).

## Layout (recap from schema)

```
exploring/<slug>/
├── index.md          ← required; frontmatter [status!, summary!, apps!]
└── *.md              ← optional aux
```

`<slug>` is **pure kebab-case** — no `maintenance-` prefix, no tracker key.

## Recipe: bootstrap a new exploration

1. **Agree on a slug.** Short, kebab-case, no prefix.
2. `cumaru flow exploring/<slug> create`
3. `cumaru flow exploring/<slug>/index.md create`
4. Frontmatter: `status: idea`, `summary: <one-line>`, `apps: [...]`.
5. Fill the body: `## Idea`, `## Context`, `## Options / sketches`, `## Open questions`, `## Promotion / drop criteria`.
6. Run `cumaru tree exploring --rows` and verify the new candidate appears.
7. `cumaru doctor`.

## Recipe: promote an exploration to a plan

When the exploration has matured:

1. **Decide the destination.** If a tracker item exists → `plans/<KEY>/`. If still no tracker → `plans/maintenance-<slug>/`.
2. **Carry over the body.** Distill the exploration's ideas into the new plan's `## Overview`, `## Acceptance Criteria`, `## Plan / DAG`.
3. **Hand off to `cumaru-plan`** to author the new `plans/<PLAN-ID>/index.md` with full frontmatter.
4. **Remove or carry over the exploration:**
   - If no longer useful → `cumaru flow exploring/<slug> remove`.
   - If worth preserving → `cumaru flow exploring/<slug> copy plans/<PLAN-ID>/exploration.md` first, then remove original.
5. Run `cumaru tree exploring --rows` and `cumaru tree plans --rows` to verify the filesystem projection.
6. `cumaru doctor`.

## Recipe: drop an exploration

1. Confirm with the user.
2. `cumaru flow exploring/<slug> remove`
3. Run `cumaru tree exploring --rows` to verify the candidate is gone.
4. `cumaru doctor`.

## What this skill does NOT do

- **Plan authoring** — `cumaru-plan`.
- **Spec absorption** — explorations never touch `specs/`.

## Patterns

| User says | You do |
|---|---|
| "Let's explore <idea>" / "ideia nova" | Bootstrap recipe → propose slug → confirm → create dir + index.md → verify with `cumaru tree` |
| "What's in exploring?" | Run `cumaru tree exploring --rows`; drill if a candidate interests |
| "Promote auth-redesign to a plan" | Promote recipe → decide key → hand off to `cumaru-plan` → remove or carry over |
| "Drop the auth-redesign idea" | Confirm → remove → verify with `cumaru tree` |

Pair with `cumaru-plan` for the promote handoff and `cumaru-doctor` to verify.
