---
version: 1
description: Bootstrap, deepen, or consolidate a `specs/<area>/`. Drives the `cumaru-specs` skill.
allowed-tools: Bash, Read, Edit, Write
argument-hint: <area-or-action>
---

Argument: `$ARGUMENTS` may be an area name (`auth`, `payments`), a nested path (`auth/login`), or empty. If empty, ask the user whether they want to **bootstrap** new areas (typical at install time, or first time a plan touches an undocumented area), **deepen** an existing area (a plan needs more spec to map against), or **consolidate** one (the area's `deltas:` list has grown long).

1. **Read the `cumaru-specs` skill** from the installed agent skills directory (`.agents/skills/cumaru-specs/SKILL.md` for Claude or `.agents/skills/cumaru-specs/SKILL.md` for Codex). It carries the three recipes: bootstrap, deepen, consolidate. Follow its layout and pre-checks (Lead-only authoring; `deltas:` ↔ `consolidated-at:` state model).

2. **Dispatch by intent.** If `$ARGUMENTS` is:
   - A new area name (no `specs/<area>/` yet) → **bootstrap** recipe. Read CLAUDE.md, README, and the area's code surface; propose name, summary, `depends-on`, `apps`; confirm before creating.
   - An existing area whose body is thin → **deepen** recipe. Read the code by topic; write EARS-style requirements; split into concerns/subareas when warranted.
   - An existing area whose `deltas:` list has ≥5 entries (or the user explicitly asks "consolidate") → **consolidate** recipe. Read all referenced `archive/<PLAN-ID>/delta.md` entries; rewrite the area body as a single coherent spec; swap `deltas:` for `consolidated-at:`.
   - Empty → ask which area + which recipe.

3. **Run the recipe.** Walk the skill's steps, confirming every judgment call (area split, concern promotion, EARS coverage, consolidation cuts). Use `cumaru flow` for file ops and `cumaru tag set specs/index.md specs <new body>` to re-emit the index row.

4. **Close out.** Run `cumaru doctor` and report. Surface any new orphan rows/files introduced by structural changes (a deepen that promotes a concern to a subarea changes the row shape).

Hard rules:

- **Lead-only authoring.** This command operates as the Lead. The Dev never writes inside `specs/` directly — delta absorption happens during `/cumaru:archive`, driven by the Dev's `delta-draft.md`.
- **Bootstrap on demand.** Don't seed empty areas in advance. Wait for a plan to declare one in `scope:`, or for the user to explicitly ask.
- **Don't invent EARS.** An empty `## Requirements (EARS)` section is better than fabricated ones. Ground every bullet in code you can point to.
- **Re-emit `specs/index.md` row** via `cumaru tag set` after any structural change (new area, new concern, promoted subarea, consolidation).
