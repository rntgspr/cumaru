---
human_revised: false
name: package-change
applies-when: a change edits Formula/*.rb or Casks/*.rb, including url, version, sha256, resource, depends_on, install, test, artifact, uninstall, or zap blocks, or adds or removes a package
strictness: 9/10
summary: "Before you commit a Formula/*.rb or Casks/*.rb change, verify every checksum against the downloaded artifact and pass audit, install, and test (or cask uninstall) through the tap clone. Follow release/bump.md and keep the package entity in sync."
---

# Verify package changes

**Gate:** do not commit a `Formula/*.rb` or `Casks/*.rb` change until each
checksum matches its downloaded artifact and the verification commands in
[`release/bump.md`](../release/bump.md) pass on `<user>/<tap>/<name>`.

## Rules

- Follow `release/bump.md`. Its verification steps cover non-bump edits too.
- Compute each `sha256` from the downloaded file. Never copy a checksum from
  release notes, a web page, or memory.
- Update every platform or architecture block together. A partial bump breaks
  some platforms.
- Verify through the tap clone, never through a file path, then restore the
  clone.
- Update the package entity when the change alters a fact it records:
  artifacts, dependencies, install layout, test, uninstall, or authentication.
  Keep its `reference` rows pointing at the real `.rb` file.
- Report each verification step you could not run, for example Linux
  artifacts on macOS or a private download without its token.

## Red flags

- A `url` or `version` changes but its `sha256` does not.
- A commit touches more than one package.
- The version in the URL differs from the version in the commit message.
- Verification ran against a file path or against the unedited tap clone.
- A token, password, or signed URL appears in a `.rb` file or in `.cumaru/`.
- A package exists without an entity, or an entity has no `reference` row.
