---
version: 1
description: Bootstrap, grow, or advance a plan in `.cumaru/plans/` — new plan (tracker-backed or slug-based), add task, write handoff, draft delta, ready-for-archive. Drives the `cumaru-plan` skill.
allowed-tools: Bash, Read, Edit, Write
argument-hint: <plan-id-or-action>
---

Argument: `$ARGUMENTS` may be a plan ID (`AAA-1234`, `maintenance-cleanup-helpers`) or empty. If empty, ask the user what they want to do (new plan, add task to existing plan, write handoff, draft delta, archive).

1. **Read the `cumaru-plan` skill** from the installed agent skills directory (`.agents/skills/cumaru-plan/SKILL.md` for Claude or `.agents/skills/cumaru-plan/SKILL.md` for Codex). It carries the recipes — bootstrap (tracker-backed vs slug-based), add-task, write-handoff (Dev role), draft-delta (Dev role), ready-for-archive. Follow its layout and pre-checks.

2. **Pre-check.** Run `cumaru doctor --quiet` to confirm the tree is healthy enough to operate on. If errors exist that touch `plans/` or `intake/`, surface them and ask whether to fix first.

3. **Dispatch by intent.** If `$ARGUMENTS` is:
   - A `<KEY>` that **does not** have `intake/<KEY>/` yet → ask: "fetch the tracker issue first via `/cumaru:intake $ARGUMENTS`?" If yes, hand off to that command, then resume here.
   - A `<KEY>` with `intake/<KEY>/` present, no `plans/<KEY>/` → run the **tracker-backed bootstrap** recipe from the skill.
   - A `maintenance-<slug>` not yet on disk → run the **slug-based bootstrap** recipe.
   - An existing plan ID (`plans/<PLAN-ID>/` exists) → ask whether the user wants to **add a task**, **write a handoff** (Dev), **draft the delta** (Dev), or **transition to archive** (hand off to `/cumaru:archive`).
   - Empty → ask.

4. **Run the recipe.** Walk the steps from the skill, confirming every judgment call (scope paths, task breakdown, handoff content). Use `cumaru flow` for file ops, `cumaru tag set plans/index.md plans <new body>` to re-emit the index row.

5. **Close out.** Run `cumaru doctor`. Report what changed and what's next (e.g. "T2 still pending", "ready for `/cumaru:archive` once `delta-draft.md` is filled").

Hard rules:

- Tracker-backed plans **do not** carry `## Overview` or `## Acceptance Criteria` in the plan body — those live in `intake/<KEY>/`. Slug-based plans do carry them.
- Dev role writes `handoff-t<N>.md` and `delta-draft.md`. Lead writes `index.md` and `t<N>.md`. Don't blur the line — if the user requests a Dev-role action, the recipe applies the Dev's bounded write rules.
- Re-emit `plans/index.md` row via `cumaru tag set` after **every** structural change (new plan, new task, task status flip, plan close).
- Never write inside `specs/` from this command — that's the archive flow's job (`/cumaru:archive`).
