# Homebrew formula candidate

[`Formula/cumaru.rb`](Formula/cumaru.rb) is a reviewable candidate for the existing
[rntgspr/homebrew-tap](https://github.com/rntgspr/homebrew-tap). It has not been
published there. No repository creation or remote mutation is part of this work.
The maintainer selected MIT for Cumaru; the [project license](../../LICENSE),
Rust package, and formula declare it explicitly. Publish these changes before
publishing the package. Dependency and model licenses remain their own contracts.

## Installation after publication

```bash
brew install rntgspr/tap/cumaru
brew upgrade rntgspr/tap/cumaru
brew uninstall cumaru
type -a cumaru
```

`type -a` reveals an earlier `/usr/local/bin` installation or development symlink
that could shadow Homebrew. Resolve PATH precedence deliberately; do not force
linking over another installation. Homebrew installs the compiled executable in
its keg, with a small launcher that rejects bare `cumaru upgrade` before the
native global installer can run. `cumaru upgrade --check` remains read-only;
its native `upgrade:` suggestion refers to unmanaged installations, so follow
`brew upgrade` for this package. The underlying `libexec/cumaru` is internal to
the formula and should not be invoked directly to bypass this guard.

Formula installation downloads only one pinned, SHA-256-verified release binary.
Models remain optional explicit `cumaru model push` downloads. Installation and
removal never run the global installer or mutate adopter projects, model caches,
or `~/.config/cumaru.json`. Git and cURL are supplied by macOS; on Linux they are
declared dependencies for remote commands and coverage. Bash runs the launcher
and installed session hooks; no Rust compiler or Python is required.

## Platforms

macOS ARM64/Intel and Linux ARM64/Intel select their respective 0.10.0 assets.
Linux assets are static musl executables. Linux ARM64 requires `fphp` and
`asimdhp` CPU features; the formula rejects missing or unsupported CPU feature
reports before installation. This is a package gate for the current binary's
FP16 requirement, not runtime portability evidence for other ARM CPUs.

## Release maintenance

1. Wait for all four release binaries and `SHA256SUMS` to be published.
2. Download each asset, compare its SHA-256 with the published checksums, and
   update all four URLs/checksums and the formula version together.
3. Run `brew style`, `brew audit --strict`, installation and `brew test` in an
   isolated tap/prefix. Test macOS and Linux on both supported architectures;
   reject unsupported ARM64 CPUs rather than publishing a falsely universal asset.
4. Review the formula/license and publish to the existing tap. Homebrew/core
   submission and automatic tap updates remain separate maintainer decisions.

The candidate under this directory owns preparation until publication; after
publication the tap is the installed formula's canonical source. Do not imply
that changing this repository automatically updates the tap.

## Observed validation

Homebrew 7.0.7 on macOS ARM64 installed the published 0.10.0 executable into a
disposable `/tmp/cumaru-homebrew-validation` prefix with a separate scratch home,
cache, logs, and build directory. Actual `brew test` passed offline version/help,
context ranking without model weights, and refusal of unmanaged self-upgrade.
Homebrew selected and verified the ARM64 release checksum. The nonstandard prefix
emitted its expected Tier 3 warning; the maintainer's installed brew was untouched.
`brew style` and `brew audit --new --strict` passed. Homebrew's system simulation
selected the expected URL/checksum/version for all four targets; this checks
formula selection and does not execute the other three platform binaries.
An actual formula-install invocation with mocked Linux ARM64 CPU metadata
rejected missing `asimdhp` before attempting binary installation. A subsequent
isolated `brew uninstall` preserved byte-identical scratch model/legacy cache,
user version JSON, and project knowledge sentinels.
Full platform installation tests and tap publication remain open.

## References

- [Published release and checksums](https://github.com/rntgspr/cumaru/releases/tag/0.10.0)
- [Homebrew formula cookbook](https://docs.brew.sh/Formula-Cookbook)
- [Homebrew tap maintenance](https://docs.brew.sh/How-to-Create-and-Maintain-a-Tap)
- [Native upgrade ownership](../../docs/upgrade.md)
