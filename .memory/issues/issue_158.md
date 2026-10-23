---
name: realign-install-upgrade-spec
description: Map install-upgrade.md's distribution contract to the native binary installer
status: open
priority: low
---

# Issue 158: Realign install-upgrade.md with the native implementation

`install-upgrade.md` documents the destructive Bash snapshot installer
(`~/.cumaru` tarball replacement, kernel drift checks at upgrade time,
legacy `~/.local/bin/cumaru` link) as part of the current contract,
alongside `src/cmd_install.sh` and `src/cmd_version.sh` rows pinned at tag
0.10.0. The native distribution is binary-only: `/usr/local/bin/cumaru`,
`src/install.sh`, and no `~/.cumaru` snapshot.

## Risk

- A maintainer or agent re-runs the destructive `cumaru upgrade` model
  believing it is the live installer behavior.

## Required invariant

No current `install-upgrade.md` row presents the global snapshot installer
or retired `src/cmd_*.sh` modules as present behavior; every implementation
reference resolves to an existing path in the working tree.

## Work

1. Move the global-snapshot contract into an explicitly historical section
   and state the native binary installation contract from `rust.md`
   (`src/install.sh`, `src/commands/upgrade.rs`, `src/release.rs`,
   `src/distribution.rs`).
2. Re-check the `install-upgrade` failure contract table against the
   native `upgrade --check` and installer statuses.

## Tests

- `rg -n '~/\.cumaru|cmd_install\.sh|cmd_version\.sh|unpacks'
  .memory/specs/install-upgrade.md` returns only historical-labeled matches.
- Every relative link in the edited `install-upgrade.md` resolves.

## References

- `.memory/specs/install-upgrade.md`
- `.memory/specs/rust.md`
- `.memory/issues/issue_145.md`
