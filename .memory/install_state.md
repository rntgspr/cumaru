---
name: cumaru install — current v6 state
description: Current installer contract, dependencies, domain installation, agent artifacts, and upgrade behavior
type: project
originSessionId: 507d571c-f4de-4425-8d7c-cb5b12395a28
---
**Sources:** `src/cmd_install.sh`, `src/install.sh`, `docs/install.md`, and `docs/upgrade.md`.

## Runtime prerequisites

- Bash, cURL, Git, `jq`, and Mike Farah `yq` v4 must be available on `PATH`.
- The Python package also named `yq` is incompatible with Cumaru's frontmatter and YAML expressions.
- Recommended macOS command: `brew install git jq yq`.
- `jq` owns JSON tracker payloads; `yq` owns schema/frontmatter operations; Git owns installation, upgrade, and coverage inventory; cURL owns the remote installer and tracker adapters.

## Project installation

1. `cumaru install [--domain <name>] [--with <skill>...]` always targets `./.cumaru`; the default domain is `sdlc-full` and `base` resolves to `domains/__base/`.
2. The selected domain is copied from `domains/`, then its `skills/` and `commands/` source directories are pruned from `.cumaru/` because installed agent artifacts belong under `.agents/`.
3. Domain-shipped `cumaru-*` skills and slash commands are installed under `.agents/`. Opt-in top-level skills are added only through repeatable `--with` flags.
4. The installer creates or updates the canonical `CUMARU-HOOK` instruction block in `.agents/AGENTS.md`. Cumaru does not install or manage prompt hooks.
5. Fresh installs always create framework v6 trees. Existing v5 adopter trees are not upgraded by reinstalling the CLI; they must run `cumaru migrate v6 --apply`.
6. The installer does not add `.cumaru/` to `.gitignore`, accept a config file, or run doctor automatically.

## Upgrade and integrity

- `cumaru upgrade` executes `src/install.sh`: it replaces `~/.cumaru` with a fresh shallow checkout and relinks `~/.local/bin/cumaru`. It is destructive to a development symlink and must never be run without explicit user authorization.
- Distribution integrity compares every domain kernel `domains/<domain>/index.md` and universal artifact against `domains/__base`; drift aborts before linking.
- Kernel integrity is deliberately outside doctor. Doctor validates an installed adopter tree and accepts only framework v6; pre-v6 trees are directed to migration.
- `CUMARU_DIR` remains fixed to `.cumaru` in `src/common.sh`.
