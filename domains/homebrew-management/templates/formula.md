---
human_revised: false
name: <formula name, equal to Formula/<name>.rb without .rb>
summary: <one-line summary, used by cumaru tree>
targets: [<formula name>]
upstream: <owner/repo or download host>
visibility: "public | private"
---

# <formula name>

<One sentence: what the software does and who installs it.>

## Source

- **Upstream:** <repository or host link>. Release kind: <GitHub release asset | source tarball | other>.
- **Tag prefix:** <`v` or none>. Write versions as the tag spells them.
- **Visibility:** <public | private>. For private: the download strategy and
  the environment variable that holds the token (for example
  `HOMEBREW_GITHUB_API_TOKEN`). Never the token itself.

## Artifacts

One row per `url` block in the formula. Name the platform and architecture
block that selects it.

| Platform | Artifact | Notes |
|---|---|---|
| <macOS ARM64 / macOS Intel / Linux ARM64 / Linux Intel / all> | <file name pattern> | <`using: :nounzip`, archive layout, CPU guard> |

## Build and dependencies

- **Kind:** <prebuilt binary | build from source | language virtualenv>.
- **Dependencies:** <`depends_on` and `uses_from_macos` entries, and why each exists>.
- **Resources:** <`resource` blocks and why each exists, or "none">.
- **Bottles:** <bottle block present or not, and who builds them>.

## Install and test

- **Install:** <what `def install` puts in `bin`, `libexec`, `share`, and any wrapper script>.
- **Caveats:** <post-install message, service block, or "none">.
- **Test:** <what `test do` asserts>.

## Bump risk

- <What one version change touches: number of `url`/`sha256` pairs, resources
  to refresh, platform guards to recheck.>

## Reference

The real code this entity describes, read by `cumaru coverage`. Each row
targets a repository file resolved from the project root.

<!-- cumaru:reference -->
| Link | Description |
|------|-------------|
| [Formula/<name>.rb](Formula/<name>.rb) | <the blocks this entity explains: url/sha256 per platform, depends_on, install, test> |
<!-- /cumaru:reference -->
