---
human_revised: false
version: 1
name: cumaru-install
description: Use this skill whenever the user wants to adopt the minimal Cumaru base package or start a custom domain through the Admin contract.
summary: Install the minimal Cumaru base package and hand custom-domain setup to Admin.
---

# `cumaru install` — adopt the minimal framework

`cumaru install` is a deterministic, mechanical copy. The base package intentionally provides no durable pillar workflow.

## Install (mechanical)

```bash
cumaru install                                        # default domain: base (minimal kernel)
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

## Post-install

Activate the Admin role to define a custom domain contract. Declare its neutral target vocabulary under `meta.targets.values`; if the custom domain models software components, place their rows in the `components` tag in `domain.md`. Define any pillars and their workflows explicitly, then run `cumaru doctor`. Do not hand off to a pillar skill that the base package does not ship.

## Uninstall

Removes the whole `.cumaru/` tree, including adopter knowledge, and every Cumaru-owned adapter artifact across all adapters after confirmation. Run it only on an explicit user request, such as resetting a bench.

```bash
cumaru uninstall                # interactive confirm; refuses non-TTY without --yes
cumaru uninstall --yes          # non-interactive (agents / CI)
```

## Patterns

| User says | You do |
|---|---|
| "Install the framework here" | `cumaru install` → activate Admin for custom-domain setup |
| "Set up Cumaru for this project" | Same as above |
| "Bootstrap a custom domain" | Activate Admin and define its pillars, target vocabulary, and roles |
| "Add a domain" / "install with the X domain" | `cumaru install --domain <name>` (default = base) |
