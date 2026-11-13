---
human_revised: false
targets: [platform]
summary: Procedures that change what the tap ships; the shipped bump procedure plus adopter procedures such as adding or deprecating a package.
---

# Release

A pillar for **the procedures that change what the tap ships**. Entries are
workflow documents, not per-version logs; Git history is the release log.

## Rules

- **Procedures only.** Record steps and conventions. Do not record individual
  releases.
- **Package facts live in `formulae/` and `casks/`.** Link to them instead of
  repeating them.
- **`bump.md` is framework-owned.** Record tap-specific deviations in a
  separate procedure file or in the `root` tag of `domain.md`.

Use `cumaru tree release` to navigate current entries.

## When to use

- You bump a package version or update a checksum.
- You add, rename, deprecate, or remove a package.
- You review a package commit.

## When NOT to use

- You need the install contract of one package → `formulae/<name>/` or
  `casks/<token>/`.
