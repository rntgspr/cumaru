---
name: post-upgrade-snapshot-pruner
description: Add a configurable maintenance script that prunes development-only files from an upgraded adopter snapshot
status: open
priority: low
---

# Issue 035: Prune the post-upgrade adopter snapshot

`cumaru upgrade` clones the complete repository into `~/.cumaru`, although an
adopter needs only the runtime distribution. The installer should silently
remove development-only surfaces after the global snapshot is installed, using
an explicit, editable allowlist.

## Risk

- The operation is destructive and targets the machine-global Cumaru snapshot.
- A wrong destination or incomplete allowlist can delete the development
  checkout or remove files required by the runtime.
- Running it on the local beta installation would invalidate the maintainer's
  current environment.

## Required invariant

The post-install pruner removes only top-level entries outside a configurable
runtime allowlist, after proving that `~/.cumaru` is a standalone Cumaru
snapshot and not the repository working tree, a symlink, the home directory,
or `/`.

## Work

1. Create a Bash script under `scripts/` and invoke it from `src/install.sh`
   after the global snapshot passes its integrity check.
2. Define the retained top-level runtime surfaces in one clearly editable
   allowlist in the script. The initial minimum is `cumaru`, `src/`, `domains/`,
   `schemas/`, and `skills/`.
3. Target `~/.cumaru` deliberately; resolve and validate it before deletion.
4. Refuse symlinks, Git working trees, the source checkout, `/`, `$HOME`, and
   paths that do not contain the expected Cumaru runtime markers.
5. Run silently as part of install/upgrade; do not require a preview, an apply
   flag, or confirmation before deleting non-allowlisted entries inside the
   validated global snapshot.
6. Document that pruning is an automatic post-install distribution step.

## Tests

- Do not execute destructive verification on the maintainer's local beta copy.
- Validate against a disposable upgraded snapshot, confirming the allowlisted
  runtime remains usable and every non-allowlisted top-level entry is removed.
- Confirm the installer invokes the pruner after integrity validation and that
  its successful output is silent.

## References

- `src/install.sh`
- `.memory/specs/install-upgrade.md`
- `.memory/disciplines/install_sh_destructive.md`
