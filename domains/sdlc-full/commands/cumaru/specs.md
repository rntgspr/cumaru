---
version: 1
description: Bootstrap, deepen, or consolidate a `specs/<area>/`. Drives the `cumaru-specs` skill.
allowed-tools: Bash, Read, Edit, Write
argument-hint: <area-or-action>
summary: Bootstrap, deepen, or consolidate a `specs/<area>/`. Drives the `cumaru-specs` skill.
---

Argument: `$ARGUMENTS` may be an area name (`auth`, `payments`), a nested path (`auth/login`), or empty. If empty, ask the user whether they want to **bootstrap** new areas (typical at install time, or first time a plan touches an undocumented area), **deepen** an existing area (a plan needs more spec to map against), or **consolidate** one (the area's `deltas:` list has grown long).

1. **Read the `cumaru-specs` skill** from the installed agent skills directory (`.agents/skills/cumaru-specs/SKILL.md` for Claude or `.agents/skills/cumaru-specs/SKILL.md` for Codex). It carries the three recipes: bootstrap, deepen, consolidate. Follow its layout and pre-checks (Lead-only authoring; `deltas:` ↔ `consolidated-at:` state model).

2. **Dispatch by intent.** If `$ARGUMENTS` is:
   - A new area name (no `specs/<area>/` yet) → **bootstrap** recipe. Read `.agents/AGENTS.md`, README, and the area's code surface; propose name, summary, `depends-on`, `apps`; confirm before creating.
   - An existing area whose body is thin → **deepen** recipe. Read the code by topic; write EARS/RFC 2119 requirements; split into concerns/subareas when warranted.
   - An existing area whose `deltas:` list has ≥5 entries (or the user explicitly asks "consolidate") → **consolidate** recipe. Use `specs/index.md` `cumaru:absorptions` to locate the relevant commits when detail is needed; rewrite the area body as a single coherent spec; swap `deltas:` for `consolidated-at:`.
   - Empty → ask which area + which recipe.

3. **Run the recipe.** Walk the skill's steps, confirming every judgment call (area split, concern promotion, requirements coverage, consolidation cuts). Use `cumaru flow` for file ops. Set the affected entity `summary:`, then run `cumaru tree specs --rows` to verify the filesystem projection.

4. **Close out.** Run `cumaru doctor` and report. Surface any navigation or summary defects introduced by structural changes.

Hard rules:

- **Lead-only authoring.** This command operates as the Lead. The Dev never writes inside `specs/` directly — delta absorption happens during `/cumaru:archive`, driven by the Dev's `delta-draft.md`.
- **Bootstrap on demand.** Don't seed empty areas in advance. Wait for a plan to declare one in `scope:`, or for the user to explicitly ask.
- **Don't invent requirements.** An empty `## Requirements (EARS / RFC 2119)` section is better than fabricated ones. Ground every bullet in code you can point to.
- **Keep summaries current.** Set the affected entity `summary:` before verifying with `cumaru tree`.
