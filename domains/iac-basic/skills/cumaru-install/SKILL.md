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

After step 6, the CLI prints "Next steps" — run `cumaru bootstrap` next.

## Bootstrap

Run `cumaru bootstrap` and follow the printed steps in order. It prints the
universal rules and the iac-basic steps from main HEAD, pinned to one commit; the
document is never installed into `.cumaru/`.

## Uninstall

Removes the whole `.cumaru/` tree, including adopter knowledge, and every Cumaru-owned adapter artifact across all adapters after confirmation. Run it only on an explicit user request, such as resetting a bench.

```bash
cumaru uninstall                # interactive confirm; refuses non-TTY without --yes
cumaru uninstall --yes          # non-interactive (agents / CI)
```

## Patterns

| User says | You do |
|---|---|---|
| "Install the framework here" | `cumaru install --domain iac-basic` → `cumaru bootstrap` → hand off to `cumaru-topology` for the topology bootstrap |
| "Set up Cumaru for this project" | Same as above |
| "Bootstrap the topology" / "deepen networking" / "consolidate compute" | Not this skill — hand off to `cumaru-topology` (carries those recipes) |
| "Add a domain" / "install with the X domain" | `cumaru install --domain <name>` (default = base) |
