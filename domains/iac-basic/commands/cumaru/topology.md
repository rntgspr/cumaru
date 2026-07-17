---
version: 1
description: Bootstrap, deepen, or consolidate a `topology/<area>/`. Drives the `cumaru-topology` skill.
allowed-tools: Bash, Read, Edit, Write
argument-hint: <area-or-action>
summary: Bootstrap, deepen, or consolidate a `topology/<area>/`. Drives the `cumaru-topology` skill.
---

Argument: `$ARGUMENTS` may be an area name (`networking`, `data`), a nested path (`networking/dev`), or empty. If empty, ask the user whether they want to **bootstrap** a new stack/area (first time a changeset touches it), **deepen** an existing one (a changeset needs more detail to plan against), or **consolidate** one (the area's `deltas:` list has grown long).

1. **Read the `cumaru-topology` skill** from the installed agent skills directory (`.agents/skills/cumaru-topology/SKILL.md` for Claude or `.agents/skills/cumaru-topology/SKILL.md` for Codex). It carries the three recipes: bootstrap, deepen, consolidate. Follow its layout and pre-checks (Lead-only authoring; `deltas:` ↔ `consolidated-at:` state model; `depends-on:` IS the apply order).

2. **Dispatch by intent.** If `$ARGUMENTS` is:
   - A new area name (no `topology/<area>/` yet) → **bootstrap** recipe. Read the HCL/manifest, the provider configs, and any existing topology to weigh placement; propose name, summary, `depends-on` (the stacks that must apply first), `apps` (the envs where it lives), interface (outputs / inputs); confirm before creating.
   - An existing area whose body is thin → **deepen** recipe. Read the executable spec (`.tf`, `.yaml`) by topic; document what the stack IS (interface, dependencies, decisions, cost & security) — never copy the code; split into concerns/subareas (per provider/account/region) when warranted.
   - An existing area whose `deltas:` list has ≥5 entries (or the user explicitly asks "consolidate") → **consolidate** recipe. Read all referenced `archive/<PLAN-ID>/delta.md` entries; rewrite the area body as a single coherent topology spec; swap `deltas:` for `consolidated-at:`.
   - Empty → ask which area + which recipe.

3. **Run the recipe.** Walk the skill's steps, confirming every judgment call (area split, concern promotion, `depends-on` apply order, consolidation cuts). Use `cumaru flow` for file ops. Set the affected entity `summary:`, then run `cumaru tree topology --rows` to verify the filesystem projection.

4. **Close out.** Run `cumaru doctor` and report. Surface any navigation or summary defects introduced by structural changes. Optionally trigger the `cumaru-arch` skill to re-render the dependency graph if the change affected `depends-on:`.

Hard rules:

- **Lead-only authoring.** This command operates as the Lead. The Dev never writes inside `topology/` directly — delta absorption happens during `/cumaru:archive`, driven by the Dev's `delta-draft.md`.
- **Bootstrap on demand.** Don't seed empty areas in advance. Wait for a changeset to declare one in `scope:`, or for the user to explicitly ask.
- **The code is the spec.** `topology/<area>/index.md` carries intent and topology — what the stack IS and how it connects. NEVER duplicate the HCL/manifest content here; that drifts and lies.
- **`depends-on:` is apply order.** Treat it as a hard load signal AND a sequencing constraint — when bootstrapping a new area, list the stacks that must already exist for this one to apply cleanly.
- **Keep summaries current.** Set the affected entity `summary:` before verifying with `cumaru tree`.
