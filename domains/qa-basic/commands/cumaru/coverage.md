---
version: 1
description: Bootstrap, deepen, or consolidate a `coverage/<area>/`. Drives the `cumaru-coverage` skill.
allowed-tools: Bash, Read, Edit, Write
argument-hint: <area-or-action>
summary: Bootstrap, deepen, or consolidate a `coverage/<area>/`. Drives the `cumaru-coverage` skill.
---

Argument: `$ARGUMENTS` may be an area name (`checkout`, `auth`), a nested path (`checkout/payment`), or empty. If empty, ask the user whether they want to **bootstrap** a new coverage area (first time a campaign touches it), **deepen** an existing one (a campaign needs more detail to plan against), or **consolidate** one (the area's `deltas:` list has grown long).

1. **Load the installed `cumaru-coverage` skill.** It carries the three recipes: bootstrap, deepen, consolidate. Follow its layout and pre-checks (Lead-only authoring; `deltas:` ↔ `consolidated-at:` state model; reference `standards/` instead of restating conventions).

2. **Dispatch by intent.** If `$ARGUMENTS` is:
   - A new area name (no `coverage/<area>/` yet) → **bootstrap** recipe. Read the feature's surface (the code that ships the behavior), any prior tests, and the relevant `standards/`; propose name, summary, `depends-on` (other coverage areas this one builds on), `apps` (the test levels in play), and a thin scenario map; confirm before creating.
   - An existing area whose body is thin → **deepen** recipe. Walk the feature by user-visible scenarios; document the coverage map (what's tested, at which level, by which suite); list known gaps and risks; split into concerns/subareas when warranted.
   - An existing area whose `deltas:` list has ≥5 entries (or the user explicitly asks "consolidate") → **consolidate** recipe. Read all referenced `archive/<PLAN-ID>/delta.md` entries; rewrite the area body as a single coherent coverage map; swap `deltas:` for `consolidated-at:`.
   - Empty → ask which area + which recipe.

3. **Run the recipe.** Walk the skill's steps, confirming every judgment call (area split, concern promotion, scenario completeness, level distribution per pyramid, consolidation cuts). Use `cumaru flow` for file ops. Set the affected entity `summary:`, then run `cumaru tree coverage --rows` to verify the filesystem projection.

4. **Close out.** Run `cumaru doctor` and report. Surface any navigation or summary defects introduced by structural changes.

Hard rules:

- **Lead-only authoring.** This command operates as the Lead. The Dev never writes inside `coverage/` directly — delta absorption happens during `/cumaru:archive`, driven by the Dev's `delta-draft.md`.
- **Bootstrap on demand.** Don't seed empty areas in advance. Wait for a campaign to declare one in `scope:`, or for the user to explicitly ask.
- **Reference `standards/`, never restate.** Coverage area bodies cite the standards that govern naming, fixtures, mocking discipline, retries — they don't re-author those rules. Duplication drifts.
- **Respect the pyramid.** Document which level covers which scenario and **why** — call out any e2e a lower level could catch.
- **Keep summaries current.** Set the affected entity `summary:` before verifying with `cumaru tree`.
