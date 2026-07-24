---
version: 1
description: Bootstrap, grow, or advance a changeset in `.cumaru/plans/` — new changeset (tracker-backed or slug-based, with blast radius / rollback / promotion path), add apply step, write handoff, draft topology delta, ready-for-archive. Drives the `cumaru-plan` skill.
allowed-tools: Bash, Read, Edit, Write
argument-hint: <plan-id-or-action>
summary: Bootstrap, grow, or advance a changeset in `.cumaru/plans/` — new changeset (tracker-backed or slug-based, with blast radius / rollback / promotion path), add apply step, write handoff, draft topology delta, ready-for-archive. Drives the `cumaru-plan` skill.
---

Argument: `$ARGUMENTS` may be a changeset ID (`AAA-1234`, `maintenance-rotate-certs`) or empty. If empty, ask the user what they want to do (new changeset, add apply step, write handoff, draft delta, archive).

1. **Load the installed `cumaru-plan` skill.** It carries the recipes — bootstrap (tracker-backed vs slug-based, both requiring blast radius / rollback / promotion path), add-step, write-handoff (Dev role records the apply diff), draft-delta (Dev role), ready-for-archive. Follow its layout and pre-checks.

2. **Pre-check.** Run `cumaru doctor --quiet` to confirm the tree is healthy enough to operate on. If errors exist that touch `plans/`, `intake/`, or `topology/`, surface them and ask whether to fix first.

3. **Dispatch by intent.** If `$ARGUMENTS` is:
   - A `<KEY>` that **does not** have `intake/<KEY>/` yet → ask: "fetch the tracker issue first via `/cumaru:intake $ARGUMENTS`?" If yes, hand off to that command, then resume here.
   - A `<KEY>` with `intake/<KEY>/` present, no `plans/<KEY>/` → run the **tracker-backed bootstrap** recipe from the skill.
   - A `maintenance-<slug>` not yet on disk → run the **slug-based bootstrap** recipe (carries everything: Overview + Acceptance Criteria + Plan / DAG + Blast radius + Rollback + Promotion path + Out of scope + Risks).
   - An existing changeset ID (`plans/<PLAN-ID>/` exists) → ask whether the user wants to **add an apply step**, **write a handoff** (Dev — records the apply diff), **draft the delta** (Dev — proposed topology changes), or **transition to archive** (hand off to `/cumaru:archive`).
   - Empty → ask.

4. **Run the recipe.** Walk the steps from the skill, confirming every judgment call (scope = topology areas the change touches; blast radius across envs; rollback procedure; promotion path dev→staging→prod; step breakdown). Use `cumaru flow` for file ops. Set the affected entity `summary:`, then run `cumaru tree plans --rows` to verify the filesystem projection.

5. **Close out.** Run `cumaru doctor`. Report what changed and what's next (e.g. "T2 step not yet applied", "ready for `/cumaru:archive` once `delta-draft.md` is filled and the change has landed in every promotion-path env").

Hard rules:

- **Blast radius / Rollback / Promotion path are not optional.** Every changeset body carries these — tracker-backed (alongside `## Plan / DAG`, `## Out of scope`, `## Risks`; Overview + AC stay in intake) or slug-based (full body).
- Dev role writes `handoff-t<N>.md` (apply diff + verify output) and `delta-draft.md`. Lead writes `index.md` and `t<N>.md` (apply step instructions). Don't blur the line.
- Set the affected entity `summary:` before verifying with `cumaru tree`.
- Never write inside `topology/` from this command — that's the archive flow's job (`/cumaru:archive`). Changeset declares the `scope:` paths; absorption happens at close.
- **Scope is decided by traversing `topology/` under the loading rule** (`.cumaru/index.md` → "Loading rule") with the intake's Overview + Acceptance Criteria as subject. The proposed `scope:` is exactly the leaf paths the traversal surfaces.
