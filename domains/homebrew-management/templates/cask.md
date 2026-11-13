---
human_revised: false
name: <cask token, equal to Casks/<token>.rb without .rb>
summary: <one-line summary, used by cumaru tree>
targets: [<cask token>]
upstream: <owner/repo or download host>
visibility: "public | private"
---

# <cask token>

<One sentence: what the application does and who installs it.>

## Source

- **Upstream:** <repository or host link>. Release kind: <GitHub release asset | vendor download | other>.
- **Tag prefix:** <`v` or none>. Write versions as the tag spells them.
- **Visibility:** <public | private>. For private: the download strategy and
  the environment variable that holds the token. Never the token itself.

## Artifacts

One row per `url` or `arch` variant in the cask.

| Architecture | Download | Notes |
|---|---|---|
| <arm / intel / universal> | <file name pattern: .dmg, .zip, .pkg> | <`sha256` per arch or `:no_check`, container layout> |

## Install surface

- **Artifacts:** <`app`, `binary`, `pkg`, `font`, `installer` stanzas and where each lands>.
- **Requirements:** <`depends_on macos:`, `depends_on formula:`, `depends_on cask:`>.
- **Signing:** <signed and notarized, or the Gatekeeper workaround users need>.
- **Updates:** <`auto_updates true` or Homebrew-driven, and the `livecheck` strategy>.

## Removal

- **Uninstall:** <`uninstall` keys: `quit:`, `launchctl:`, `pkgutil:`, `delete:`>.
- **Zap:** <`zap trash:` paths, or "none">.

## Bump risk

- <What one version change touches: number of `url`/`sha256` pairs, arch
  variants, a changed bundle name or pkg identifier.>

## Reference

The real code this entity describes, read by `cumaru coverage`. Each row
targets a repository file resolved from the project root.

<!-- cumaru:reference -->
| Link | Description |
|------|-------------|
| [Casks/<token>.rb](Casks/<token>.rb) | <the stanzas this entity explains: version/sha256 per arch, artifacts, uninstall, zap> |
<!-- /cumaru:reference -->
