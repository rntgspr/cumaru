---
human_revised: false
targets: [platform]
summary: One entity per formula in Formula/, with its upstream, artifacts, install contract, and reference rows to the real Ruby.
---

# Formulae

A pillar for **the knowledge behind each formula in `Formula/`**. Create an
entity when a formula enters the tap and remove it when the formula leaves.

## Rules

- **One entity per formula.** `formulae/<name>/index.md` from
  `templates/formula.md`. The directory name equals the file name without
  `.rb`.
- **Facts, not copies.** Record upstream, artifacts, dependencies, install,
  test, and bump risk. Do not copy version strings or checksums;
  `Formula/<name>.rb` is canonical.
- **Point at the real code.** Every entity keeps a `reference` row to its
  `Formula/<name>.rb`. `cumaru coverage --gaps` lists formulae without one.
- **Each entry is a directory** with `index.md` and any aux files, following
  the universal entity rules.

Use `cumaru tree formulae` to navigate current entries.

## When to use

- You change, debug, or explain one formula.
- You add a formula to the tap.
- You bump a formula. Read the entity, then follow `release/bump.md`.

## When NOT to use

- The package is a macOS application, font, or pkg → `casks/`.
- You need the generic procedure or commit convention → `release/`.
