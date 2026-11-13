---
summary: Ordered bootstrap steps for the homebrew-management domain after install.
---

## homebrew-management — bootstrap steps

The install ships empty `formulae/` and `casks/` pillars. Work through the
steps in order. Where a step allows a proposal, present it and write only what
the user confirms. `disciplines/`, `templates/`, and `release/bump.md` stay as
shipped.

1. **Tap.** Ask the tap name (`<user>/<tap>`), who consumes it, and the commit
   convention. Write the answers in the `root` tag of `domain.md` with
   `cumaru tag`.
2. **Inventory.** List `Formula/*.rb` and `Casks/*.rb`. Propose one entity per
   file. Remove from `meta.coverage.source` a glob whose directory the tap does
   not have.
3. **Entities.** For each confirmed package, create
   `formulae/<name>/index.md` from `templates/formula.md` or
   `casks/<token>/index.md` from `templates/cask.md` with `cumaru fs`. Fill
   each section from the real `.rb` file and its upstream; ask about any fact
   the Ruby does not show, such as the reason for a CPU guard. Keep the
   `reference` row pointing at the `.rb` file. Never copy a version or
   checksum.
4. **Private packages.** For each package with `visibility: private`, ask the
   download strategy and the environment variable that holds the token. Never
   write the token.
5. **Targets and components.** Add each package name to
   `meta.targets.values`, and add one row per package to the `components` tag
   of `domain.md`.
6. **Coverage.** Run `cumaru coverage --gaps`. Every `.rb` file must be
   covered; report any gap that remains.
