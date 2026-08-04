---
version: 1
description: Bootstrap, grow, or advance a test campaign in `.cumaru/plans/` — new campaign (tracker-backed or slug-based, with test strategy + scope), add case, write handoff, draft coverage delta, ready-for-archive. Drives the `cumaru-plan` skill.
allowed-tools: Bash, Read, Edit, Write
argument-hint: <plan-id-or-action>
summary: Bootstrap, grow, or advance a test campaign in `.cumaru/plans/` — new campaign (tracker-backed or slug-based, with test strategy + scope), add case, write handoff, draft coverage delta, ready-for-archive. Drives the `cumaru-plan` skill.
---

Argument: `$ARGUMENTS` may be a campaign ID (`AAA-1234`, `maintenance-deflake-checkout`) or empty. If empty, ask the user what they want to do (new campaign, add case, write handoff, draft delta, archive).

1. **Load the installed `cumaru-plan` skill.** It carries the recipes — bootstrap (tracker-backed vs slug-based, both requiring test strategy + scope), add-case, write-handoff (Dev role records the run + verify), draft-delta (Dev role), ready-for-archive. Follow its layout and pre-checks.

2. **Pre-check.** Run `cumaru doctor --quiet` to confirm the tree is healthy enough. If errors touch `plans/`, `intake/`, `coverage/`, or `standards/`, surface them and ask whether to fix first.

3. **Dispatch by intent.** If `$ARGUMENTS` is:
   - A `<KEY>` that **does not** have `intake/<KEY>/` yet → ask: "fetch the tracker issue first via `/cumaru:intake $ARGUMENTS`?" If yes, hand off, then resume.
   - A `<KEY>` with `intake/<KEY>/` present, no `plans/<KEY>/` → run the **tracker-backed bootstrap** recipe.
   - A `maintenance-<slug>` not yet on disk → run the **slug-based bootstrap** recipe (carries everything: Overview + Acceptance Criteria + Test Strategy + Cases / DAG + Scope + Risks / Gaps + Out of scope).
   - An existing campaign ID → ask whether the user wants to **add a case**, **write a handoff** (Dev — records what was authored + the runner output), **draft the delta** (Dev — proposed coverage changes), or **transition to archive** (hand off to `/cumaru:archive`).
   - Empty → ask.

4. **Run the recipe.** Walk the steps from the skill, confirming every judgment call (scope = coverage areas the campaign touches; test strategy that respects the pyramid; case breakdown; level distribution; reference relevant `standards/` instead of restating). Use `cumaru flow` for file ops. Set the affected entity `summary:`, then run `cumaru tree plans --rows` to verify the filesystem projection.

5. **Close out.** Run `cumaru doctor`. Report what changed and what's next (e.g. "T2 case authored, not yet passing", "ready for `/cumaru:archive` once every case is green and `delta-draft.md` is filled").

Hard rules:

- **Test Strategy is not optional.** Every campaign body states which levels cover what and **why** — keep the pyramid; justify any e2e a lower level could catch; reference `standards/` instead of restating.
- Dev role writes `handoff-t<N>.md` (what was authored, the run command, the verify result) and `delta-draft.md`. Lead writes `index.md` and `t<N>.md` (case instructions). Don't blur the line.
- Set the affected entity `summary:` before verifying with `cumaru tree`.
- Never write inside `coverage/` from this command — that's the archive flow's job (`/cumaru:archive`). Campaign declares the `scope:` paths; absorption happens at close.
- **Scope is decided by traversing `coverage/` under the loading rule** (`.cumaru/index.md` → "Loading rule") with the intake's Overview + Acceptance Criteria as subject. The proposed `scope:` is exactly the leaf paths the traversal surfaces.
