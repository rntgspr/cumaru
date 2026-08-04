---
name: distribution-version-and-staleness
description: Give the global snapshot a composite distribution version and let adopters learn explicitly when it is behind GitHub
status: open
priority: medium
---

# Issue 127: Distribution version and staleness notice

The global snapshot at `~/.cumaru` has no identity. `src/install.sh` extracts a
`git archive` of `main` without `.git/`, the repository has no tags or
releases, and `config.version` is the integer framework contract (`9`, pinned
by `schemas/config.schema.json` as `"const": 9`). An adopter therefore cannot
tell which build is installed, nor whether GitHub already has a newer one.

We want a composite release number such as `9.1` and a check that tells the
user the installed snapshot is behind or old.

## Risk

- Reusing `config.version` for `9.1` would break the integer version gate:
  ordinary update refuses to cross an integer boundary and `cumaru migrate`
  owns those crossings (see `../disciplines/update_design.md`, item 4). A
  fractional value also violates the current schema `const`.
- A staleness check that silently calls GitHub breaks offline and CI use and
  makes read-only commands depend on the network.
- A version written by hand into a file drifts from the commit it describes.
- Release artifacts (tarballs) are not required for exclusion to take effect:
  `.gitattributes` `export-ignore` already applies through `git archive` in the
  installer. Releases must be justified by versioning, not by packaging.

## Required invariant

The installed snapshot reports a distribution version derived from Git, whose
major component equals the integer `config.version` contract it ships, and any
comparison with GitHub happens only on an explicit user action that states
when the network is used and reports "cannot check" distinctly from "up to
date".

## Proposed direction

- Keep two versions: the integer contract (`config.version: 9`) and a semver
  distribution tag (`v9.1.0`) whose major must equal the contract.
- Derive the snapshot version at install time instead of committing it: a
  `VERSION` file marked `export-subst` in `.gitattributes` lets `git archive`
  expand `$Format:%(describe)$` (Git 2.32+) or `$Format:%H$` into the snapshot.
- Expose it through `cumaru version` (offline) and an explicit
  `cumaru upgrade --check` that queries the latest GitHub release and prints
  installed, latest, and the upgrade command, without replacing anything.

## Resolved decisions

1. Tags only: plain `X.Y.Z` (no `v` prefix; first `9.0.0`), cut by the
   maintainer; no GitHub Releases. Tag major equals `config.version`.
2. The installer installs the highest `X.Y.Z` tag from GitHub's archive
   tarball (`archive/refs/tags/<tag>.tar.gz`), falling back to `main` only
   while no tag exists. No clone; Git is needed only for `ls-remote`.
3. `cumaru doctor` stays offline and never reports staleness.
4. No `export-subst`: `main` is amended and force-pushed, so tag ancestry is
   unstable. The installer writes the resolved tag (or `main`) into
   `~/.cumaru/VERSION`; a checkout without it is a development build.

## Work

1. Done: contract recorded in `../specs/install-upgrade.md` (invariants 3, 6,
   8-11, failure rows, implementation map).
2. Done: tarball installer writing `VERSION`, and `cumaru version`.
3. Done: `cumaru upgrade --check`, `docs/upgrade.md`, help, README and kernel
   CLI maps.
4. Pending (maintainer): create tag `9.0.0`. Until then the installer
   installs `main` and `--check` reports `cannot check: no X.Y.Z release tag`.

Once step 4 is done this issue is fully absorbed and can be removed.

## Tests

- The installer copy installs the highest `X.Y.Z` tag and writes `VERSION`,
  falls back to `main` without tags, and leaves an existing snapshot untouched
  when the download fails.
- `cumaru version` prints the installed tag and contract `9` offline; a Git
  checkout reports a development build.
- `cumaru upgrade --check` reports "behind" (newer tag, or `main` once a tag
  exists), "up to date", and "cannot check" with status `1`; HOME unchanged.

## References

- `src/install.sh`
- `src/cmd_version.sh`
- `tests/spec/cli/version_spec.sh`
- `cumaru` (`upgrade` dispatch)
- `.gitattributes`
- `schemas/config.schema.json`
- `../specs/install-upgrade.md`
- `../specs/configuration.md`
- [git `ls-remote`](https://git-scm.com/docs/git-ls-remote)
- [GitHub: downloading source code archives](https://docs.github.com/en/repositories/working-with-files/using-files/downloading-source-code-archives)
