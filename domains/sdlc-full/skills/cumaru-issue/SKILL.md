---
human_revised: false
version: 1
name: cumaru-issue
description: Use this skill whenever the user wants to capture, refine, promote, or drop a locally authored SDLC issue from the current chat or repository context. Trigger on phrases like "create an issue for this", "track this bug locally", "capture this follow-up", "open an internal issue", "plan this issue", "drop this issue", or "what's in issues/?". This skill is sdlc-full-only and writes `issues/<slug>/` without contacting a tracker.
summary: Capture, refine, promote, or drop a local SDLC issue created from chat and repository context.
---

# `cumaru-issue` - capture and evolve `issues/` entries

An issue is a locally authored, transient work item. It captures a concrete bug, feature, improvement, task, or chore before execution planning. It is not a tracker mirror and it is not a plan.

## Layout

```
issues/<slug>/
└── index.md          <- [type!, priority!, status!, summary!, apps!]
```

- `<slug>` is plain kebab-case, with no tracker key or `maintenance-` prefix.
- `type:` is one of `bug | feature | improvement | task | chore`.
- `priority:` is one of `critical | high | medium | low`.
- `status:` is `open | ready | planned | dropped`. `planned` and `dropped` are terminal: the directory is normally removed during that transition.

## Recipe: bootstrap a local issue

When the user identifies concrete work but does not want to create a tracker item or execution plan yet:

1. Agree on a short kebab-case slug and confirm it does not collide with an existing `issues/<slug>/`.
2. `cumaru flow issues/<slug> create`
3. `cumaru flow issues/<slug>/index.md create`
4. Open `templates/issue.md` and author the issue from the chat and repository evidence:
   - Set `type`, `priority`, `status: open`, `apps`, and a stable `summary:`.
   - Write a specific `## Description`, relevant `## Context`, and concrete `## Impact`.
   - State observable `## Acceptance Criteria (EARS / RFC 2119)`; do not invent criteria not supported by the request or evidence.
   - Record material constraints and unresolved questions in `## Notes`.
5. Run `cumaru tree issues --rows` and verify the entry appears.
6. Run `cumaru doctor`.

## Recipe: refine an issue

Edit the issue as new evidence arrives. Move `status: open` to `ready` only when its outcome and acceptance criteria are clear enough to plan. Do not add task breakdown, `scope:`, or a DAG here; those belong in `plans/`.

## Recipe: promote an issue to a plan

When the user is ready to execute a local issue:

1. Read `issues/<slug>/index.md`. Confirm the acceptance criteria and affected applications still describe the intended outcome.
2. Hand off to `cumaru-plan` to create `plans/maintenance-<slug>/`. It is slug-based because no tracker item exists.
3. Distill the issue's Description, Context, Impact, and Acceptance Criteria into the slug-based plan. Add `scope:`, the DAG, risks, and tasks there; do not copy the issue body blindly.
4. Remove the issue only after the plan is valid: `cumaru flow issues/<slug> remove`.
5. Run `cumaru tree issues --rows`, `cumaru tree plans --rows`, and `cumaru doctor`.

## Recipe: drop an issue

1. Confirm with the user that the issue is resolved elsewhere, rejected, or no longer relevant.
2. `cumaru flow issues/<slug> remove`
3. Run `cumaru tree issues --rows` and `cumaru doctor`.

Issues never flow directly to `archive/`; only completed plans do.

## Boundaries

- **Tracker-backed work** belongs in `intake/` and is authored through `cumaru-intake`.
- **Open-ended ideas** belong in `exploring/` and use `cumaru-explore`.
- **Execution planning** belongs in `plans/` and uses `cumaru-plan`.
- This skill writes no tracker data and does not create plans without the user's decision to promote.
