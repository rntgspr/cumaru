---
name: install-sh-destructive
description: Never run src/install.sh (or cumaru upgrade) without explicit user request — it mutates the global installation
metadata:
  type: feedback
---

Do not invoke `src/install.sh` (directly, through its public URL, or indirectly via `cumaru upgrade`) without an explicit request from the user.

**Why:** The script replaces the machine-global executable at `/usr/local/bin/cumaru` (possibly through `sudo`) and rewrites `~/.config/cumaru.json`. Its legacy Bash predecessor began with `rm -rf ~/.cumaru`; on 2026-06-10 running it only to validate a kernel-drift check destroyed the `~/.cumaru → ~/workspace/cumaru` symlink. The user had said local execution of the installer was out of scope.

**How to apply:**
- Validating kernel-drift integrity does NOT require running the installer: run `scripts/sync-domain-kernel.sh --check`.
- Exercise installer behavior only through redirected scratch copies with the network stubbed.
- If the installer truly needs to run, confirm with the user first and name the global paths it will replace.
- `cumaru upgrade` executes the embedded copy of the same script; the same rule applies.
