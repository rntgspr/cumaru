---
human_revised: false
version: 1
name: cumaru-install
description: Use this skill whenever the user wants to adopt the Cumaru framework in a project — install the .cumaru/ tree, choose a domain, select an agent adapter, and (post-install) bootstrap the spec areas for an existing codebase. Trigger on phrases like "install the framework", "set up .cumaru/ here", "adopt Cumaru", "instala o framework", "bootstrap specs from the codebase", "scaffold the spec areas", "compactar / consolidate area X", "deepen the auth spec", or any request to seed/grow the `specs/` pillar. The install itself is deterministic (materializes framework files, skills, and adapter wiring); the spec bootstrap that follows is LLM-driven via this skill.
summary: Use this skill whenever the user wants to adopt the Cumaru framework in a project — install the .cumaru/ tree, choose a domain, select an agent adapter, and (post-install) bootstrap the spec areas for an existing codebase. Trigger on phrases like "install the framework", "set up .cumaru/ here", "adopt Cumaru", "instala o framework", "bootstrap specs from the codebase", "scaffold the spec areas", "compactar / consolidate area X", "deepen the auth spec", or any request to seed/grow the `specs/` pillar. The install itself is deterministic (materializes framework files, skills, and adapter wiring); the spec bootstrap that follows is LLM-driven via this skill.
---

# `cumaru install` — adopt the framework + bootstrap specs

`cumaru install` is a **deterministic, mechanical copy** — it doesn't make judgment calls. The judgment work (which components the project ships, which spec areas exist) is **your job** as the LLM, guided by this skill, **after** the copy completes.

## Install (mechanical)

```bash
cumaru install --domain sdlc-light                         # this domain's workflow
cumaru install --domain <name>                        # explicit domain from `cumaru help domains`
cumaru install agent claude --domain <name>           # explicit adapter: none|claude|codex|opencode
cumaru update skills claude --with git --apply        # opt-in skill, after adoption only
```

What the CLI does, in order:
1. Validates the domain and adapter arguments and refuses an existing `.cumaru/` before any network access; refresh and opt-in skills belong to `cumaru update`.
2. Resolves HEAD of `main` and pins every read to that commit (`base` aliases `__base`); there is no local or `--from` source.
3. Materializes only the structure and files selected by the domain's `config.yaml` into `.cumaru/`.
4. **Installs every `cumaru-*` skill** from the domain into the selected adapter's native skill directory, keeping existing skill folders.
5. Wires durable instructions, plus session hooks where the adapter supports them (Claude, Codex), preserving adopter content; only Generic (`none`) and OpenCode also receive command launchers. The adapter is not persisted in config.
6. Prints next steps. It does not run `cumaru doctor` or `cumaru bootstrap`.

After step 6, the CLI prints "Next steps" — that's your cue to start the spec bootstrap below.

## Post-install (LLM work — start here)

The framework is in place; the codebase is not yet mapped to it. **Your job** is to seed `specs/` so future plans have somewhere to absorb deltas. Do these in order, **with user confirmation on each judgment call**.

### Step 1 — Components

`.cumaru/domain.md` has a `<!-- cumaru:components -->` table with placeholder rows (`webapp`, `api`). Replace them with the project's actual components.

1. Read the project's `README`, `package.json`/`pyproject.toml`/`go.mod`/etc., and the top-level dir layout to identify components (a "component" is typically a deployable surface or a coherent codebase chunk).
2. Propose the list to the user. Don't auto-decide.
3. Use `cumaru tag set domain.md components` to write the table:
   ```
   | Link              | Description                                            |
   |-------------------|--------------------------------------------------------|
   | [webapp](../web/) | Next.js + TypeScript front-end at `web/`               |
   | [api](../api/)    | FastAPI + Python 3.12 service at `api/`                |
   ```
4. Update `.cumaru/config.yaml > meta.targets.values` to list those same keys (in addition to the reserved `platform` and `meta`).
5. Run `cumaru doctor`; resolve structural errors, then review warnings and the authored content semantically.

### Step 2 — Hand off to `cumaru-specs` for the spec bootstrap

With components declared, the next post-install step is seeding `specs/` so future plans have somewhere to absorb deltas. **That work lives in the domain-specific `cumaru-specs` skill** (it carries the bootstrap / deepen / consolidate recipes). When the user is ready, invoke it — `cumaru-specs` walks them through:

- **Bootstrap** — identify functional areas (`auth`, `payments`, …) and create skeleton `specs/<area>/index.md` per area, with user confirmation on every split.
- **Deepen** — fill an area's requirements grounded in code; split into concerns / subareas as warranted.
- **Consolidate** — rewrite a spec whose body has drifted into a changelog back into a flat statement of current state. On request only.

This skill stops at Step 1 because the spec work is recurring (deepen + consolidate happen across the project's lifetime, not just at install). Keeping it in `cumaru-specs` lets non-sdlc domains install without that overhead.

## Uninstall

Removes the whole `.cumaru/` tree, including adopter knowledge, and every Cumaru-owned adapter artifact across all adapters after confirmation. Run it only on an explicit user request, such as resetting a bench.

```bash
cumaru uninstall                # interactive confirm; refuses non-TTY without --yes
cumaru uninstall --yes          # non-interactive (agents / CI)
```

## Patterns

| User says | You do |
|---|---|
| "Install the framework here" | `cumaru install --domain sdlc-light` → walk through Step 1 (components) → hand off to `cumaru-specs` for the spec bootstrap |
| "Set up Cumaru for this project" | Same as above |
| "Bootstrap the specs" / "deepen X" / "consolidate Y" | Not this skill — hand off to `cumaru-specs` (carries those recipes) |
| "Add a domain" / "install with the X domain" | `cumaru install --domain <name>` (default = base) |
