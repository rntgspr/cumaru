---
name: cumaru install — current state and pending considerations
description: Snapshot of `cmd_install` and what it does today
type: project
originSessionId: 507d571c-f4de-4425-8d7c-cb5b12395a28
---
**Source:** `src/cmd_install.sh`.

**Steps today:**
1. Parse `--with <skill>` (repeatable). Positional install targets are no longer accepted.
2. Default `target` is fixed to `./.cumaru`.
3. Pre-checks: the framework source exists, `target` does NOT exist, every requested `--with <name>` resolves to `skills/<name>/SKILL.md`.
4. `cp -R "$FRAMEWORK_SRC" "$target"` — wholesale copy of the starter.
5. For each `--with <name>`: `mkdir -p target/skills/<name>` + copy `skills/<name>/SKILL.md`.
6. **CLAUDE.md hook (auto-wired):** at `dirname $target` (the project root), creates or appends a block delimited by `<!-- BEGIN/END CUMARU-HOOK -->` containing a textual instruction to read `.cumaru/index.md` first plus a `@.cumaru/index.md` import (Claude Code auto-load syntax). Idempotent: skips if the marker is already present. Helper: `_install_print_hook_block`.
7. Print "Next steps" hint: edit `index.md`, edit `schema.yaml` `apps.values`, run `cumaru doctor`. Mentions the CLAUDE.md hook.

**What it does NOT do:**
- Doesn't add `.cumaru/` to the adopter's `.gitignore`.
- Doesn't symlink `cumaru` globally.
- Doesn't run `cumaru validate` automatically.
- Doesn't accept a config file.

**`cumaru upgrade` + kernel integrity check (added 2026-06-09):**
- New `upgrade` subcommand in the `cumaru` entry script: does NOTHING beyond `exec bash "$SRC/install.sh"` — re-runs the tool installer (wipe `~/.cumaru`, shallow clone, strip `.git/`, relink `~/.local/bin/cumaru`). Renato's explicit design: upgrade = re-run install, no extra behavior.
- `src/install.sh` now verifies the snapshot before linking: every `frameworks/<domain>/index.md` must be byte-identical (`cmp -s`) to `frameworks/__base/index.md`; any divergence → `✗ kernel drift`, abort with exit 1.
- The drift check deliberately does NOT live in `cumaru doctor` — doctor audits the ADOPTER's tree, which never contains `__base`. Kernel drift is a distribution problem, caught where the snapshot lands. Documented in `docs/upgrade.md` + `docs/architecture.md`.
- `CUMARU_DIR` is now fixed to `.cumaru` in `src/common.sh`; changing it there is a checkout-wide override, not a per-project setting.

**v4 note (2026-06):** the kernel drift check still runs unchanged. With v4, the universal artifacts that must match across domains include the per-domain `__base/index.md` mirror — but tag-shape consistency does not need a check: there is only one shape (`[Link, Description]`) and the parser hardcodes it.

**Smoke-tested scenarios for the hook:**
- CLAUDE.md absent → creates with `# Project instructions` header + CUMARU-HOOK block.
- CLAUDE.md exists, no hook → appends with a leading blank line, preserving prior content.
- CLAUDE.md exists with hook → skips (`· CLAUDE.md hook already present (skip)`).
