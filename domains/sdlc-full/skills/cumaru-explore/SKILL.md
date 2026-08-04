---
human_revised: false
version: 1
name: cumaru-explore
description: Use this skill whenever the user wants to capture, evolve, promote, or drop an exploration — an idea that isn't a plan yet. Trigger on phrases like "explore <topic>", "let's sketch <idea>", "ideia nova sobre X", "promove essa exploração pra um plano", "drop this exploration", "what's in exploring/?", or any task framed as pre-plan ideation. Skill is sdlc-only (knows the `exploring/` pillar, the `promote → plans/maintenance-<slug>/` path).
summary: Use this skill whenever the user wants to capture, evolve, promote, or drop an exploration — an idea that isn't a plan yet. Trigger on phrases like "explore <topic>", "let's sketch <idea>", "ideia nova sobre X", "promove essa exploração pra um plano", "drop this exploration", "what's in exploring/?", or any task framed as pre-plan ideation. Skill is sdlc-only (knows the `exploring/` pillar, the `promote → plans/maintenance-<slug>/` path).
---

# `cumaru-explore` — capture and evolve `exploring/` entries

Explorations are **transient** — they either mature into a plan or get dropped. This skill carries the bootstrap recipe (kebab-case slug, frontmatter from `exploration.md` template) plus the two terminal exits (promote / drop). For raw file ops use `cumaru fs` directly.

## Layout (recap from schema)

```
exploring/<slug>/
├── index.md          ← required; frontmatter [status!, summary!, targets!]
└── *.md              ← optional aux (referenced via `aux:` if needed)
```

- `<slug>` is **pure kebab-case** — no `maintenance-` prefix, no tracker key.
- `status:` is one of `idea | considering | promoted | dropped` — but `promoted` and `dropped` are **terminal** (the directory is moved or deleted at that point; that status value mostly serves as a tombstone if you do leave it on disk briefly during a transition).

## Recipe: bootstrap a new exploration

When the user says "explore X" / "let's sketch <idea>" / "ideia nova":

1. **Agree on a slug.** Propose one — short, kebab-case, no prefix (e.g., `auth-redesign`, `unify-error-handling`). Confirm with the user.
2. `cumaru fs exploring/<slug> create`
3. `cumaru fs exploring/<slug>/index.md create`
4. Open `templates/exploration.md` (under `.cumaru/templates/`) and copy its shape into the new file. Frontmatter:
   - `status: idea` (start state) — flip to `considering` later if the user is actively weighing options.
   - `summary: <one-line>` — what the idea is in 8-12 words. It appears in `cumaru tree exploring` output.
   - `targets: [...]` — affected components (keys from `meta.targets.values`).
5. Fill the body following the template: `## Idea`, `## Context`, `## Options / sketches`, `## Open questions`, `## Promotion / drop criteria`. Author's voice; free prose.
6. Run `cumaru tree exploring --rows` and verify the new candidate appears.
7. `cumaru doctor` — navigation and summary checks clean.

## Recipe: evolve status (idea → considering)

Just edit the frontmatter (`status: idea` → `status: considering`). No move or structural update is required because navigation is projected from the filesystem.

## Recipe: promote an exploration to a plan

When the exploration has matured ("vamos virar isso plano agora"):

1. **Decide the destination key.**
   - If a tracker item now exists for it → use `cumaru-intake` to create `intake/<KEY>.md`, then promote to `plans/<KEY>/`.
   - If still no tracker item → `plans/maintenance-<slug>/` (slug-based plan).
2. **Carry over the body.** The exploration's `## Idea` / `## Options` / `## Open questions` become raw material for the new plan's `## Plan / DAG` and `## Out of scope`. Don't dump verbatim — distill what survived the maturation.
3. **Hand off to `cumaru-plan`** (the bootstrap-plan skill) to author the new `plans/<PLAN-ID>/index.md` with full frontmatter (`scope`, `status: in-progress`, `summary`, `targets`). The plan skill drives the structure; this skill just makes the source content available.
4. **Remove or absorption the exploration:**
   - If the exploration's notes are no longer useful → `cumaru fs exploring/<slug> remove`.
   - If they're worth preserving alongside the plan → `cumaru fs exploring/<slug>/index.md copy plans/<PLAN-ID>/exploration.md` first, then remove the original dir.
5. Run `cumaru tree exploring --rows` and `cumaru tree plans --rows` to verify the filesystem projection.
6. Run `cumaru doctor`.

## Recipe: drop an exploration

When the idea won't happen:

1. Confirm with the user — "drop is permanent (no absorption; only plans flow to absorption). Sure?"
2. `cumaru fs exploring/<slug> remove`
3. Run `cumaru tree exploring --rows` to verify the candidate is gone.
4. `cumaru doctor` — navigation and summary checks clean.

**Don't retain explorations during close-out.** Only a confirmed consumed
exploration is removed after its plan is absorbed.

## What this skill does NOT do

- **Plan authoring** — that's `cumaru-plan`. This skill hands off the body content; the plan skill structures it.
- **Spec absorption** — explorations never touch `specs/`. Only plans do, via direct absorption (`cumaru-absorb`).
- **Tracker mirror** — if you need to pull a tracker item, use `cumaru-intake` first; this skill only writes the kebab-case slug path.

## Patterns

| User says | You do |
|---|---|
| "Let's explore <idea>" / "ideia nova" | Bootstrap recipe → propose slug → confirm → create dir + index.md from template → verify with `cumaru tree` |
| "What's in exploring?" | Run `cumaru tree exploring --rows`; drill if a candidate interests |
| "Promote auth-redesign to a plan" | Promote recipe → decide key → hand off to `cumaru-plan` → remove or carry over the exploration body |
| "Drop the auth-redesign idea" | Confirm with user → `cumaru fs exploring/auth-redesign remove` → verify with `cumaru tree` |
| "Change status to considering" | Edit frontmatter `status:` only |

Pair with `cumaru-plan` for the promote handoff and `cumaru-doctor` to verify post-operation state.
