---
name: homebrew-distribution
description: Ship and maintain Homebrew installation for the native Cumaru CLI
status: open
priority: medium
---

# Issue 141: Distribute Cumaru through Homebrew

[GitHub issue 19](https://github.com/rntgspr/cumaru/issues/19).

Release 0.10.0 supplies four compiled executables and `SHA256SUMS`, but Cumaru
has no maintained Homebrew package or documented brew installation path.

## Risk

- Manual installation and package-manager upgrades can select different binaries
  or overwrite each other's paths without clear ownership.

## Required invariant

A documented brew command installs the correct verified native executable into
Homebrew's prefix without running the global installer, downloading models, or
modifying adopter projects. Brew owns upgrades/removal for its installation.

## Work

1. Inspect existing tap availability and select the repository/maintainer ownership.
   Start with an owned tap; submission to homebrew/core is a separate decision.
2. Package published executables with pinned release URLs and SHA-256. Prefer
   compiled installation consistent with README; explicitly declare supported
   OS/architecture combinations and Linux ARM64's FP16 requirement. Decide whether
   raw assets suffice or release archives are needed before changing distribution.
3. Install `cumaru` into the managed prefix. Declare actual runtime dependencies
   and license; keep model packages optional and outside the formula.
4. Define release-to-formula maintenance and verification. Never update the formula
   before the complete release asset/checksum set is available.
5. Document install, upgrade, and uninstall plus coexistence with `/usr/local/bin`,
   development symlinks, and `cumaru upgrade`. Do not let CLI self-upgrade silently
   replace a brew-managed executable; choose the supported ownership behavior.

## Tests

- Formula style/audit and `brew test` pass; installed version/help and a disposable
  offline context query succeed without downloading model weights.
- Verify supported architecture selection, hashes, upgrade/removal ownership,
  and declared unsupported-platform/CPU behavior in appropriate environments.
- Existing `.cumaru/` projects and `~/.cumaru/` model/legacy data remain intact;
  testing does not modify the maintainer's global installation without authorization.

## Implementation evidence

- Candidate formula and packaging/ownership documentation are in
  [`packaging/homebrew`](../../packaging/homebrew/README.md). The existing
  [rntgspr/homebrew-tap](https://github.com/rntgspr/homebrew-tap) has been inspected
  read-only; the candidate is not published there.
- Published 0.10.0 URLs and all four checksums match `SHA256SUMS`. Homebrew 7.0.7
  system simulation selects the correct asset for each OS/architecture.
- An isolated macOS ARM64 brew installation in `/tmp` and actual `brew test`
  passed version/help, offline context without weights, and refusal of unmanaged
  self-upgrade. `brew style` and `brew audit --new --strict` passed.
- A managed launcher blocks bare `cumaru upgrade`; the underlying native binary
  lives in `libexec`. Linux ARM64 installation checks `fphp`/`asimdhp` before
  installing the current FP16-dependent asset. A mocked Linux ARM64 invocation
  rejected missing FP16 support before publication. Isolated `brew uninstall`
  preserved scratch model/legacy cache, user JSON, and project bytes. Actual
  other-platform installation and CPU behavior remain unverified.
- The maintainer selected MIT on 2026-10-03. Root LICENSE, Rust package metadata,
  and the candidate formula now declare MIT explicitly. Those local changes still
  need publication; dependency/model licenses remain separate. Tap publication
  and automatic formula updates require separate maintainer authorization.
  The issue remains open.

## References

- [Release 0.10.0](https://github.com/rntgspr/cumaru/releases/tag/0.10.0)
- [Release workflow](../../.github/workflows/release.yml)
- [Native installer](../../rust/install.sh)
- [Upgrade contract](../../docs/upgrade.md)
- [Homebrew tap guide](https://docs.brew.sh/How-to-Create-and-Maintain-a-Tap)
- [Homebrew formula cookbook](https://docs.brew.sh/Formula-Cookbook)
