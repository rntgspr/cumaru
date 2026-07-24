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

1. `cumaru install [agent <name>] [--domain <name>] [--with <skill>...]` always targets `./.cumaru`; the default domain is `sdlc-full` and `base` resolves to `domains/__base/`.
2. The selected domain is copied from `domains/`, then its source-only `skills/` and `commands/` directories are pruned from `.cumaru/`.
3. Missing or null `agent` state selects the generic `.agents/` adapter. Explicit values are `claude`, `codex`, and `opencode`; the CLI keyword `none` serializes to null.
4. Domain skills, supported commands, and durable instructions are installed in the native paths declared by `docs/agent-adapters.md`. Opt-in top-level skills follow the selected adapter's skill path.
5. Fresh installs always create framework v6 trees. Existing v5 adopter trees are not upgraded by reinstalling the CLI; they must run `cumaru migrate v6 --apply`.
6. The installer writes `agent` last, does not add `.cumaru/` to `.gitignore`, and does not run doctor automatically.

## Upgrade and integrity

- `cumaru upgrade` executes `src/install.sh`: it replaces `~/.cumaru` with a fresh shallow checkout and relinks `~/.local/bin/cumaru`. It is destructive to a development symlink and must never be run without explicit user authorization.
- Distribution integrity compares every domain kernel `domains/<domain>/index.md` and universal artifact against `domains/__base`; drift aborts before linking.
- Kernel integrity is deliberately outside doctor. Doctor validates an installed adopter tree and accepts only framework v6; pre-v6 trees are directed to migration.
- `CUMARU_DIR` remains fixed to `.cumaru` in `src/common.sh`.
