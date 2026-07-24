---
version: 1
description: Capture, evolve, promote, or drop a test-strategy spike in `.cumaru/exploring/`. Drives the `cumaru-explore` skill.
allowed-tools: Bash, Read, Edit, Write
argument-hint: <slug-or-action>
summary: Capture, evolve, promote, or drop a test-strategy spike in `.cumaru/exploring/`. Drives the `cumaru-explore` skill.
---

Argument: `$ARGUMENTS` may be a kebab-case slug (`deflake-checkout`), an existing spike slug, or empty. If empty, ask the user whether they want to **bootstrap** a new spike, **promote** an existing one to a campaign, or **drop** one.

1. **Load the installed `cumaru-explore` skill.** It carries the bootstrap, status-transition, promote, and drop recipes.

2. **Dispatch by intent.** If `$ARGUMENTS` is:
   - A new slug (no `exploring/<slug>/` yet) → **bootstrap** recipe. Confirm slug shape (pure kebab-case, no `maintenance-` prefix), then create the dir + index.md from `templates/exploration.md`. For test strategy, prompt for the hypothesis (what's broken / what's missing), the level(s) under consideration, and the experiment that would resolve it.
   - An existing slug → ask: **evolve status** (idea → considering), **promote to campaign** (hand off to `/cumaru:plan` after preparing the body), or **drop** (`cumaru flow exploring/<slug> remove` after confirmation).
   - Empty → ask.

3. **Run the recipe.** Walk the steps from the skill, confirming every judgment call. Use `cumaru flow` for file ops. Set the affected entity `summary:`, then run `cumaru tree exploring --rows` to verify the filesystem projection.

4. **Close out.** Run `cumaru doctor` and report. For a promote, surface the new `plans/<PLAN-ID>/` and remind the user to author the campaign frontmatter (test strategy + scope) via `/cumaru:plan` if not already done.

Hard rules:

- Spikes **never** flow to `archive/`. Only completed campaigns do. Drop = `cumaru flow exploring/<slug> remove` after explicit confirmation.
- Body is **free-form prose** — no acceptance criteria, no scope, no DAG. A spike that needs structure is ready to become a campaign.
- Set the affected entity `summary:` before verifying with `cumaru tree`.
- The promote recipe hands off to `/cumaru:plan` to write campaign frontmatter — this command only stages the body and moves the dir.
