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

After step 7, the script prints domain-owned next steps.

## Post-install

Activate the Admin role to define a custom domain contract. Declare its neutral target vocabulary under `meta.targets.values`; if the custom domain models software components, place their rows in the `components` tag in `domain.md`. Define any pillars and their workflows explicitly, then run `cumaru doctor`. Do not hand off to a pillar skill that the base package does not ship.

## Uninstall

Reverse of install — uninstall is mostly file ops with safety guardrails on `index.md` and pillar roots. Use when resetting a bench for testing.

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
| "Add a domain" / "install with the X domain" | `cumaru install --domain <name>` (default = sdlc-full) |
