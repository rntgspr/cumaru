---
human_revised: false
targets: [platform]
summary: Step-by-step package version bump for formulae and casks; fetch artifacts, update url and sha256, verify through the tap clone, restore it, and commit one package.
---

# Bump a package version

The steps cover formulae and casks. Cask commands appear in parentheses.

## Why the tap clone

Homebrew refuses `brew audit` with a file path, and refuses `brew install` and
`brew test` with a file path unless `HOMEBREW_DEVELOPER` is set. The name
`<user>/<tap>/<name>` resolves to the tap clone at
`$(brew --repository <user>/<tap>)`, not to this working copy. Copy the edited
file into the clone to verify it, then restore the clone.

## Steps

1. Read the package entity (`formulae/<name>/index.md` or
   `casks/<token>/index.md`) for the tag prefix, artifacts, and visibility.
2. Confirm that the upstream release exists, for example
   `gh release view <tag> --repo <owner>/<repo>`. For a private package, export
   the token variable the entity names first.
3. Download each artifact and compute its checksum: `shasum -a 256 <file>`.
4. Update every `url`, `version`, and `sha256` in the `.rb` file, for every
   platform or architecture block. Refresh each `resource` the release needs.
5. Stage the edit in the tap clone: `cp Formula/<name>.rb
   "$(brew --repository <user>/<tap>)/Formula/"` (`Casks/<token>.rb` into
   `Casks/`). First check `git -C "$(brew --repository <user>/<tap>)" status`;
   do not overwrite unrelated changes in the clone.
6. Audit: `brew audit --strict <user>/<tap>/<name>`
   (`brew audit --cask --strict <user>/<tap>/<token>`).
7. Install: `brew reinstall --build-from-source <user>/<tap>/<name>`
   (`brew reinstall --cask <user>/<tap>/<token>`).
8. Test: `brew test <user>/<tap>/<name>`
   (launch the application or binary once, then
   `brew uninstall --cask --zap <user>/<tap>/<token>` and reinstall).
9. Restore the tap clone: `git -C "$(brew --repository <user>/<tap>)"
   checkout -- <path>`, then `git pull`.
10. Commit only that `.rb` file, plus its entity when a recorded fact changed.

## Commit convention

- Use the tap convention from the `root` tag of `domain.md`. When none exists,
  use `chore: update <name> to <version>`.
- Write `<version>` as the upstream tag spells it.
- One package per commit.

## Adding a package

Create the entity from `templates/formula.md` or `templates/cask.md`, add the
name to `meta.targets.values`, add a row to the `components` tag of
`domain.md`, then run steps 3 to 10 for the new `.rb` file.
