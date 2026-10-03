---
human_revised: false
version: 1
name: cumaru-install
description: Use this skill whenever the user wants to adopt the Cumaru framework in a project — install the .cumaru/ tree, choose a domain, select an agent adapter, and (post-install) bootstrap the topology areas for an existing codebase. Trigger on phrases like "install the framework", "set up .cumaru/ here", "adopt Cumaru", "instala o framework", "bootstrap topology from the codebase", "scaffold the topology stacks", "compactar / consolidate area X", "deepen the networking topology", or any request to seed/grow the `topology/` pillar. The install itself is deterministic (materializes framework files, skills, and adapter wiring); the topology bootstrap that follows is LLM-driven via this skill.
summary: Use this skill whenever the user wants to adopt the Cumaru framework in a project — install the .cumaru/ tree, choose a domain, select an agent adapter, and (post-install) bootstrap the topology areas for an existing codebase. Trigger on phrases like "install the framework", "set up .cumaru/ here", "adopt Cumaru", "instala o framework", "bootstrap topology from the codebase", "scaffold the topology stacks", "compactar / consolidate area X", "deepen the networking topology", or any request to seed/grow the `topology/` pillar. The install itself is deterministic (materializes framework files, skills, and adapter wiring); the topology bootstrap that follows is LLM-driven via this skill.
---

# `cumaru install` — adopt the framework + bootstrap topology

`cumaru install` is a **deterministic, mechanical copy** — it doesn't make judgment calls. The judgment work (which environments and topology areas the project uses) is **your job** as the LLM, guided by this skill, **after** the copy completes.

## Install (mechanical)

```bash
cumaru install --domain iac-basic                         # this domain's workflow
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

After step 6, the CLI prints "Next steps" — that's your cue to start the topology bootstrap below.

## Post-install (LLM work — start here)

The framework is in place; the codebase is not yet mapped to it. **Your job** is to seed `topology/` so future changesets have somewhere to absorb deltas. Do these in order, **with user confirmation on each judgment call**.

### Step 1 — Environments

1. Read the infrastructure layout and deployment configuration to identify the project's environments.
2. Propose the environment list to the user. Don't auto-decide or reinterpret environments as software components.
3. Update `.cumaru/config.yaml > meta.targets.values` with those environment keys, keeping the reserved `all` and `meta` values.
4. Do not configure a tracker registry on `intake/index.md`; `cumaru-intake`
   records observed scalar provenance on each item without adding an integration.
5. Run `cumaru doctor`; resolve structural errors, then review warnings and the authored content semantically.

### Step 2 — Hand off to `cumaru-topology` for the topology bootstrap

With environments declared, the next post-install step is seeding `topology/` so future changesets have somewhere to absorb deltas. **That work lives in the domain-specific `cumaru-topology` skill** (it carries the bootstrap / deepen / consolidate recipes). When the user is ready, invoke it — `cumaru-topology` walks them through:

- **Bootstrap** — identify infrastructure stacks (`networking`, `compute`, `database`, …) and create skeleton `topology/<area>/index.md` per stack, with user confirmation on every split.
- **Deepen** — fill a stack's interface/dependencies/decisions grounded in code; split into concerns / subareas per provider/account/region.
- **Consolidate** — rewrite a topology whose body has drifted into a changelog back into a flat statement of current state. On request only.

This skill stops at Step 1 because the topology work is recurring (deepen + consolidate happen across the project's lifetime, not just at install). Keeping it in `cumaru-topology` lets non-iac domains install without that overhead.

## Uninstall

Removes the whole `.cumaru/` tree, including adopter knowledge, and every Cumaru-owned adapter artifact across all adapters after confirmation. Run it only on an explicit user request, such as resetting a bench.

```bash
cumaru uninstall                # interactive confirm; refuses non-TTY without --yes
cumaru uninstall --yes          # non-interactive (agents / CI)
```

## Patterns

| User says | You do |
|---|---|---|
| "Install the framework here" | `cumaru install --domain iac-basic` → declare environments → hand off to `cumaru-topology` for the topology bootstrap |
| "Set up Cumaru for this project" | Same as above |
| "Bootstrap the topology" / "deepen networking" / "consolidate compute" | Not this skill — hand off to `cumaru-topology` (carries those recipes) |
| "Add a domain" / "install with the X domain" | `cumaru install --domain <name>` (default = base) |
