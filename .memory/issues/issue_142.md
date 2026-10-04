---
name: verify-homebrew-platforms
description: Observe brew install and test on every supported platform
status: open
priority: medium
---

# Issue 142: Verify Homebrew installation on every supported platform

[GitHub issue 20](https://github.com/rntgspr/cumaru/issues/20).

The published `rntgspr/tap/cumaru` formula selects four release assets, but only
the 0.10.0 candidate was installed and tested, on macOS ARM64 in an isolated
prefix. The 0.10.2 formula was published after checksum and `brew style` checks
only. macOS Intel, Linux ARM64, and Linux x86_64 installation is simulated, not
observed.

## Risk

- A platform-specific asset, dependency, or launcher defect ships to brew users
  while the formula reports success on the maintainer's machine only.
- The Linux ARM64 FP16 gate rejects or admits the wrong CPUs in practice.

## Required invariant

On every supported platform, `brew install rntgspr/tap/cumaru` installs the
matching verified executable, `brew test` passes, and unsupported Linux ARM64
CPUs are refused before installation.

## Work

1. Run `brew install`, `brew test`, and `brew audit --strict` from the published
   tap in disposable environments for macOS ARM64/Intel and Linux ARM64/Intel.
2. On Linux ARM64, observe one FP16-capable CPU succeeding and one reported
   without `fphp`/`asimdhp` being refused.
3. Record observed evidence in the Rust specification's Homebrew section and the
   packaging README.

## Tests

- Each platform reports `cumaru <formula version>`, passes `brew test`, and leaves
  `~/.cumaru`, `~/.config/cumaru.json`, and project bytes unchanged after
  `brew uninstall`.
- An unsupported Linux ARM64 CPU fails with the FP16 message and installs nothing.

## References

- [Published formula](https://github.com/rntgspr/homebrew-tap/blob/main/Formula/cumaru.rb)
- [Homebrew distribution contract](../specs/rust.md#homebrew-distribution)
- [Packaging README](../../packaging/homebrew/README.md)
- [Release 0.10.2](https://github.com/rntgspr/cumaru/releases/tag/0.10.2)
