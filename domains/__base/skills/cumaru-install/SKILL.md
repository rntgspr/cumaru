---
human_revised: false
version: 1
name: cumaru-install
description: Use this skill whenever the user wants to adopt the Cumaru framework in a project — install the .cumaru/ tree, choose a domain, wire the .agents/ instruction file, and (post-install) bootstrap the spec areas for an existing codebase. Trigger on phrases like "install the framework", "set up .cumaru/ here", "adopt Cumaru", "instala o framework", "bootstrap specs from the codebase", "scaffold the spec areas", "compactar / consolidate area X", "deepen the auth spec", or any request to seed/grow the `specs/` pillar. The install itself is deterministic (copy framework files + skills + slash commands); the spec bootstrap that follows is LLM-driven via this skill.
summary: Use this skill whenever the user wants to adopt the Cumaru framework in a project — install the .cumaru/ tree, choose a domain, wire the .agents/ instruction file, and (post-install) bootstrap the spec areas for an existing codebase. Trigger on phrases like "install the framework", "set up .cumaru/ here", "adopt Cumaru", "instala o framework", "bootstrap specs from the codebase", "scaffold the spec areas", "compactar / consolidate area X", "deepen the auth spec", or any request to seed/grow the `specs/` pillar. The install itself is deterministic (copy framework files + skills + slash commands); the spec bootstrap that follows is LLM-driven via this skill.
---

# `cumaru install` — adopt the framework + bootstrap specs

`cumaru install` is a **deterministic, mechanical copy** — it doesn't make judgment calls. The judgment work (which components the project ships, which spec areas exist) is **your job** as the LLM, guided by this skill, **after** the copy completes.

## Install (mechanical)

```bash
cumaru install                                        # default domain
cumaru install --domain base                          # minimal kernel only (no pilares)
cumaru install --domain sdlc-full
cumaru install --with git                             # default domain + opt-in skill(s)
```

What the script does, in order:
1. Resolves the chosen domain → `domains/<name>/` (or `domains/__base/` for `base`).
2. Prompts before replacing an existing `.cumaru/`; rejects non-interactive overwrite.
3. Copies the domain wholesale into `.cumaru/`.
4. **Auto-installs every `cumaru-*` skill** from the domain into `.agents/skills/` — these are the operating skills the LLM needs for any work in this tree.
5. Applies `--with <skill>` opt-ins from the top-level `skills/` directory.
6. Wires `.agents/AGENTS.md` with a `<!-- BEGIN/END CUMARU-HOOK -->` block that `@`-imports `.cumaru/index.md` so every agent session in the project auto-loads the framework entry point. Idempotent (skip-if-marker-present).
7. Installs slash commands into `.agents/commands/`.

After step 7, the script prints "Next steps" — that's your cue to start the spec bootstrap below.

## Post-install (LLM work — start here)

The framework is in place; the codebase is not yet mapped to it. **Your job** is to seed `specs/` so future plans have somewhere to absorb deltas. Do these in order, **with user confirmation on each judgment call**.

### Step 1 — Components

`.cumaru/domain.md` has a `<!-- cumaru:components -->` table with placeholder rows (`webapp`, `api`). Replace them with the project's actual components.

1. Read the project's `README`, `package.json`/`pyproject.toml`/`go.mod`/etc., and the top-level dir layout to identify components (a "component" is typically a deployable surface or a coherent codebase chunk).
2. Propose the list to the user. Don't auto-decide.
3. Use `cumaru tag set domain.md components` to write the table (v4 — every body is `[Link, Description]`):
   ```
   | Link              | Description                                            |
   |-------------------|--------------------------------------------------------|
   | [webapp](../web/) | Next.js + TypeScript front-end at `web/`               |
   | [api](../api/)    | FastAPI + Python 3.12 service at `api/`                |
   ```
4. Update `.cumaru/schema.yaml > meta.apps.values` to list those same keys (in addition to the reserved `platform` and `meta`).
5. Run `cumaru doctor` — `[✓] Schema conformance` should hold.

### Step 2 — Hand off to `cumaru-specs` for the spec bootstrap

With components declared, the next post-install step is seeding `specs/` so future plans have somewhere to absorb deltas. **That work lives in the domain-specific `cumaru-specs` skill** (it carries the bootstrap / deepen / consolidate recipes). When the user is ready, invoke it — `cumaru-specs` walks them through:

- **Bootstrap** — identify functional areas (`auth`, `payments`, …) and create skeleton `specs/<area>/index.md` per area, with user confirmation on every split.
- **Deepen** — fill an area's requirements grounded in code; split into concerns / subareas as warranted.
- **Consolidate** — compact accumulated deltas into a single coherent spec when `deltas:` grows long.

This skill stops at Step 1 because the spec work is recurring (deepen + consolidate happen across the project's lifetime, not just at install). Keeping it in `cumaru-specs` lets non-sdlc domains install without that overhead.

## Uninstall

Reverse of install — uninstall is mostly file ops with safety guardrails on `index.md` and pillar roots. Use when resetting a bench for testing.

```bash
cumaru uninstall                # interactive confirm; refuses non-TTY without --yes
cumaru uninstall --yes          # non-interactive (agents / CI)
```

## Patterns

| User says | You do |
|---|---|
| "Install the framework here" | `cumaru install` → walk through Step 1 (components) → hand off to `cumaru-specs` for the spec bootstrap |
| "Set up Cumaru for this project" | Same as above |
| "Bootstrap the specs" / "deepen X" / "consolidate Y" | Not this skill — hand off to `cumaru-specs` (carries those recipes) |
| "Add a domain" / "install with the X domain" | `cumaru install --domain <name>` (default = sdlc-full) |
