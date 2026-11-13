---
human_revised: false
targets: [platform]
summary: One entity per cask in Casks/, with its upstream, artifacts, install surface, removal, and reference rows to the real Ruby.
---

# Casks

A pillar for **the knowledge behind each cask in `Casks/`**. Create an entity
when a cask enters the tap and remove it when the cask leaves.

## Rules

- **One entity per cask.** `casks/<token>/index.md` from `templates/cask.md`.
  The directory name equals the file name without `.rb`.
- **Facts, not copies.** Record upstream, artifacts, requirements, signing,
  updates, uninstall, and zap. Do not copy version strings or checksums;
  `Casks/<token>.rb` is canonical.
- **Point at the real code.** Every entity keeps a `reference` row to its
  `Casks/<token>.rb`. `cumaru coverage --gaps` lists casks without one.
- **Each entry is a directory** with `index.md` and any aux files, following
  the universal entity rules.

Use `cumaru tree casks` to navigate current entries.

## When to use

- You change, debug, or explain one cask.
- You add a cask to the tap.
- You bump a cask. Read the entity, then follow `release/bump.md`.

## When NOT to use

- The package is a command-line tool or library → `formulae/`.
- You need the generic procedure or commit convention → `release/`.
