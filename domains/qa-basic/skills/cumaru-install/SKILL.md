---
human_revised: false
version: 1
name: cumaru-install
description: Use this skill whenever the user wants to adopt the Cumaru framework in a project — install the .cumaru/ tree, choose a domain, select an agent adapter, and (post-install) bootstrap the coverage areas for an existing codebase. Trigger on phrases like "install the framework", "set up .cumaru/ here", "adopt Cumaru", "instala o framework", "bootstrap coverage from the codebase", "scaffold the coverage areas", "compactar / consolidate area X", "deepen the auth coverage", or any request to seed/grow the `coverage/` pillar. The install itself is deterministic (copy framework files + skills + slash commands); the coverage bootstrap that follows is LLM-driven via this skill.
summary: Use this skill whenever the user wants to adopt the Cumaru framework in a project — install the .cumaru/ tree, choose a domain, select an agent adapter, and (post-install) bootstrap the coverage areas for an existing codebase. Trigger on phrases like "install the framework", "set up .cumaru/ here", "adopt Cumaru", "instala o framework", "bootstrap coverage from the codebase", "scaffold the coverage areas", "compactar / consolidate area X", "deepen the auth coverage", or any request to seed/grow the `coverage/` pillar. The install itself is deterministic (copy framework files + skills + slash commands); the coverage bootstrap that follows is LLM-driven via this skill.
---

# `cumaru install` — adopt the framework + bootstrap coverage

`cumaru install` is a **deterministic, mechanical copy** — it doesn't make judgment calls. The judgment work (which test levels and coverage areas the project uses) is **your job** as the LLM, guided by this skill, **after** the copy completes.

## Install (mechanical)

```bash
cumaru install                                        # default domain
cumaru install --domain base                          # minimal kernel only (no pilares)
cumaru install --domain sdlc-full
cumaru install --with git                             # default domain + opt-in skill(s)
```

What the script does, in order:
1. Resolves the chosen domain → `domains/<name>/` (or `domains/__base/` for `base`).
2. Refuses an existing `.cumaru/` and routes refresh or opt-in additions to `cumaru update`.
3. Copies the domain wholesale into `.cumaru/`.
4. **Auto-installs every `cumaru-*` skill** from the domain into the selected adapter's native skill directory.
5. Applies `--with <skill>` opt-ins from the top-level `skills/` directory.
6. Wires durable instructions through the selected agent adapter.
7. Installs supported slash commands for the selected adapter without persisting that adapter in config.

After step 7, the script prints "Next steps" — that's your cue to start the coverage bootstrap below.

## Post-install (LLM work — start here)

The framework is in place; the codebase is not yet mapped to it. **Your job** is to seed `coverage/` so future campaigns have somewhere to absorb deltas. Do these in order, **with user confirmation on each judgment call**.

### Step 1 — Test levels

1. Read the test layout and runner configuration to identify the project's test levels.
2. Propose the level list to the user. Don't auto-decide or reinterpret levels as software components.
3. Update `.cumaru/config.yaml > meta.targets.values` with those test-level keys, keeping the reserved `all` and `meta` values.
4. Do not configure a tracker registry on `intake/index.md`; `cumaru-intake`
   records observed scalar provenance on each item without adding an integration.
5. Run `cumaru doctor`; resolve structural errors, then review warnings and the authored content semantically.

### Step 2 — Hand off to `cumaru-coverage` for the coverage bootstrap

With test levels declared, the next post-install step is seeding `coverage/` so future campaigns have somewhere to absorb deltas. **That work lives in the domain-specific `cumaru-coverage` skill** (it carries the bootstrap / deepen / consolidate recipes). When the user is ready, invoke it — `cumaru-coverage` walks them through:

- **Bootstrap** — identify coverage areas (`auth`, `payments`, …) and create skeleton `coverage/<area>/index.md` per area, with user confirmation on every split.
- **Deepen** — fill an area's scenarios (GWT) grounded in tests; split into cases / subareas per flow/feature.
- **Consolidate** — rewrite a coverage map whose body has drifted into a changelog back into a flat statement of current state. On request only.

This skill stops at Step 1 because the coverage work is recurring (deepen + consolidate happen across the project's lifetime, not just at install). Keeping it in `cumaru-coverage` lets non-qa domains install without that overhead.

## Uninstall

Reverse of install — uninstall is mostly file ops with safety guardrails on `index.md` and pillar roots. Use when resetting a bench for testing.

```bash
cumaru uninstall                # interactive confirm; refuses non-TTY without --yes
cumaru uninstall --yes          # non-interactive (agents / CI)
```

## Patterns

| User says | You do |
|---|---|---|
| "Install the framework here" | `cumaru install` → declare test levels → hand off to `cumaru-coverage` for the coverage bootstrap |
| "Set up Cumaru for this project" | Same as above |
| "Bootstrap the coverage" / "deepen auth" / "consolidate checkout" | Not this skill — hand off to `cumaru-coverage` (carries those recipes) |
| "Add a domain" / "install with the X domain" | `cumaru install --domain <name>` (default = sdlc-full) |
