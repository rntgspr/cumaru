---
description: Capture, evolve, promote, or drop an exploration in `.llm/exploring/`. Drives the `llm-explore` skill.
allowed-tools: Bash, Read, Edit, Write
argument-hint: <slug-or-action>
---

Argument: `$ARGUMENTS` may be a kebab-case slug (`auth-redesign`), an existing exploration slug, or empty. If empty, ask the user whether they want to **bootstrap** a new exploration, **promote** an existing one to a plan, or **drop** one.

1. **Read the `llm-explore` skill** at `.llm/skills/llm-explore/SKILL.md`. It carries the bootstrap, status-transition, promote, and drop recipes.

2. **Dispatch by intent.** If `$ARGUMENTS` is:
   - A new slug (no `exploring/<slug>/` yet) → **bootstrap** recipe. Confirm the slug shape (pure kebab-case, no `maintenance-` prefix), then create the dir + index.md from `templates/exploration.md`.
   - An existing slug → ask the user: **evolve status** (idea → considering), **promote to plan** (hand off to `/llm:plan` after preparing the body), or **drop** (`llm flow exploring/<slug> remove` after confirmation).
   - Empty → ask.

3. **Run the recipe.** Walk the steps from the skill, confirming every judgment call (slug name, promotion destination, drop confirmation). Use `llm flow` for file ops and `llm tag set exploring/index.md exploring <new body>` to re-emit the index row.

4. **Close out.** Run `llm doctor` and report. For a promote, surface the new `plans/<PLAN-ID>/` and remind the user to author the plan frontmatter via `/llm:plan` if not already done.

Hard rules:

- Explorations **never** flow to `archive/`. Only completed plans do. Drop = `llm flow exploring/<slug> remove` after explicit confirmation.
- Body is **free-form prose** — no EARS, no scope, no DAG. An exploration that needs structure is ready to become a plan.
- Re-emit `exploring/index.md` row via `llm tag set` after bootstrap and after promote/drop (the row appears or disappears).
- The promote recipe hands off to `/llm:plan` to write plan frontmatter — this command only stages the body and moves the dir.
