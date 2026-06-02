---
version: 1
description: Capture, evolve, promote, or drop an infrastructure spike in `.cumaru/exploring/`. Drives the `cumaru-explore` skill.
allowed-tools: Bash, Read, Edit, Write
argument-hint: <slug-or-action>
---

Argument: `$ARGUMENTS` may be a kebab-case slug (`move-to-opentofu`), an existing spike slug, or empty. If empty, ask the user whether they want to **bootstrap** a new spike, **promote** an existing one to a changeset, or **drop** one.

1. **Read the `cumaru-explore` skill** from the installed agent skills directory (`.agents/skills/cumaru-explore/SKILL.md` for Claude or `.agents/skills/cumaru-explore/SKILL.md` for Codex). It carries the bootstrap, status-transition, promote, and drop recipes.

2. **Dispatch by intent.** If `$ARGUMENTS` is:
   - A new slug (no `exploring/<slug>/` yet) → **bootstrap** recipe. Confirm slug shape (pure kebab-case, no `maintenance-` prefix), then create the dir + index.md from `templates/exploration.md`. For infra, prompt for cost / blast radius / reversibility considerations.
   - An existing slug → ask: **evolve status** (idea → considering), **promote to changeset** (hand off to `/cumaru:plan` after preparing the body), or **drop** (`cumaru flow exploring/<slug> remove` after confirmation).
   - Empty → ask.

3. **Run the recipe.** Walk the steps from the skill, confirming every judgment call. Use `cumaru flow` for file ops and `cumaru tag set exploring/index.md exploring <new body>` to re-emit the index row.

4. **Close out.** Run `cumaru doctor` and report. For a promote, surface the new `plans/<PLAN-ID>/` and remind the user to author the changeset frontmatter (blast radius / rollback / promotion path) via `/cumaru:plan` if not already done.

Hard rules:

- Spikes **never** flow to `archive/`. Only completed changesets do. Drop = `cumaru flow exploring/<slug> remove` after explicit confirmation.
- Body is **free-form prose** — no EARS, no scope, no DAG. A spike that needs structure is ready to become a changeset.
- Re-emit `exploring/index.md` row via `cumaru tag set` after bootstrap and after promote/drop (the row appears or disappears).
- The promote recipe hands off to `/cumaru:plan` to write changeset frontmatter — this command only stages the body and moves the dir.
