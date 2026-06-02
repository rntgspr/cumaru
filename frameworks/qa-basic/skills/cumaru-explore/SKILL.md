---
human_revised: false
version: 1
name: cumaru-explore
description: Use this skill whenever the user wants to capture, evolve, promote, or drop an exploratory-testing charter — a probe that isn't a campaign yet. Trigger on phrases like "explore <area> under <condition>", "let's charter a session on checkout", "ideia de teste exploratório", "session-based testing for X", "promove essa exploração pra uma campanha", "drop this charter", "what's in exploring/?", or any task framed as exploratory testing / pre-campaign ideation. Knows the `exploring/` pillar and the `promote → plans/maintenance-<slug>/` path.
---

# `cumaru-explore` — capture and evolve `exploring/` entries

Exploratory-testing charters are **transient** — a session to probe a risky area, a "can we even automate this?" experiment, a heuristic to try. They either mature into a campaign (or surface a bug logged in the tracker → `intake/`) or get dropped. This skill carries the bootstrap recipe plus the two terminal exits (promote / drop). For raw file ops use `cumaru flow`.

## Layout (recap from schema)

```
exploring/<slug>/
├── index.md          ← required; frontmatter [status!, summary!, apps!]
└── *.md              ← optional aux
```

`<slug>` is **pure kebab-case** — no `maintenance-` prefix, no tracker key. `status:` ∈ `idea | considering | promoted | dropped` (the last two are terminal — the directory moves or is deleted).

## Recipe: bootstrap a charter

1. **Agree on a slug** — short, kebab-case (`checkout-flaky-network`, `a11y-keyboard-nav`). Confirm.
2. `cumaru flow exploring/<slug> create` → `cumaru flow exploring/<slug>/index.md create`
3. Open `templates/exploration.md`; frontmatter: `status: idea`, `summary` (8-12 words), `apps:` (levels concerned).
4. Body (free prose): `## Charter` (mission — area, time box, perspective), `## Context`, `## Heuristics / areas to probe`, `## Findings` (running notes), `## Promotion / drop criteria`.
5. Re-emit `exploring/index.md` via `cumaru tag set exploring/index.md exploring <new body>` — v4 shape: `| [<slug>](<slug>/index.md) | <one-line description of the idea, including apps if relevant> |`.
6. `cumaru doctor`.

## Recipe: run the charter (capture findings)

As the session runs, record observations under `## Findings`. Each is one of:
- **bug** — log it in the tracker, then `cumaru intake <KEY>` to mirror it (a regression test will lock it in later).
- **coverage gap** — material for a future campaign (promote, below).
- **note** — a heuristic or risk worth keeping.

The charter is a log, not a spec; keep it terse.

## Recipe: promote a charter to a campaign

1. **Decide the destination key.** Tracker item exists → `plans/<KEY>/` (run `cumaru intake <KEY>` first if needed). Else → `plans/maintenance-<slug>/`.
2. **Carry over the body** — the charter's `## Findings` (the coverage gaps) become raw material for the campaign's `## Test Strategy`, `## Scope`, `## Risks / Gaps`. Distill what survived; don't dump verbatim.
3. **Hand off to `cumaru-plan`** to author the campaign frontmatter + body.
4. **Remove or carry the charter:** `cumaru flow exploring/<slug> remove`, or `cumaru flow exploring/<slug> copy plans/<PLAN-ID>/exploration.md` first if the notes are worth keeping.
5. Re-emit `exploring/index.md` (row gone) and `plans/index.md` (row appears). `cumaru doctor`.

## Recipe: drop a charter

1. Confirm — "drop is permanent (no archive; only closed campaigns flow to archive). Sure?"
2. `cumaru flow exploring/<slug> remove` → re-emit `exploring/index.md` → `cumaru doctor`.

**Don't migrate charters to archive/.** Archive holds closed campaigns only.

## What this skill does NOT do

- **Campaign authoring** — `cumaru-plan`. **Coverage** — explorations never touch `coverage/`; only closed campaigns do, via `cumaru-archive`. **Tracker mirror** — `cumaru-intake` first if a finding becomes a tracked bug.

## Patterns

| User says | You do |
|---|---|
| "Let's charter a session on checkout under flaky network" | Bootstrap recipe → propose slug → confirm → create from template → re-emit |
| "What's in exploring?" | Read `exploring/index.md`; drill into a `<slug>/` that interests |
| "Promote checkout-flaky-network to a campaign" | Promote recipe → decide key → hand off to `cumaru-plan` → remove/carry the charter |
| "Drop the a11y charter" | Confirm → `cumaru flow exploring/a11y-keyboard-nav remove` → re-emit |

Use `cumaru tag get/set` (CLI) for `exploring/index.md`; pair with `cumaru-plan` (promote), `cumaru-intake` (log a found bug), and `cumaru-doctor`.
