---
human_revised: false
targets: [meta]
summary: Framework guidance for the Homebrew management domain; formulae and casks of one tap, their bump procedure, and the verification gate.
---

<!-- cumaru:components -->
| Link | Description |
|------|-------------|
_(replace with one row per formula or cask, linking its `Formula/<name>.rb` or `Casks/<token>.rb`)_
<!-- /cumaru:components -->

<!-- cumaru:root -->
_(empty — replace with tap-specific context: tap name `<user>/<tap>`, who consumes it, and local conventions)_
<!-- /cumaru:root -->

# Homebrew management domain

This file declares the domain's pillars, roles, entry, and conventions. It is
pulled into context as the root `index.md`'s `depends-on`. The kernel rules
live in `index.md` and are identical across domains.

The domain manages one Homebrew tap: a repository with `Formula/*.rb`,
`Casks/*.rb`, or both. Packages can be public or private. A private package
downloads from a source that needs authentication.

> **Axis.** `targets:` enumerates **packages**: each formula name and cask
> token in the tap, plus `platform` for tap-wide material and `meta` for
> `.cumaru/` itself. Add each package to `meta.targets.values` when its entity
> is created.

> **Facts, not copies.** The `.rb` file is the executable source of truth.
> Version strings and checksums live only there. An entity records what the
> Ruby does not say, and points at the Ruby through `reference` rows.

## Pillars (root's children)

```
.cumaru/
├── index.md      ← kernel (identical across domains)
├── config.yaml   ← canonical contract
├── domain.md     ← this file
├── formulae/     ← one entity per Formula/<name>.rb
├── casks/        ← one entity per Casks/<token>.rb
├── release/      ← procedures that change what the tap ships
├── disciplines/  ← execution gates (package-change, cumaru-first)
├── roles/        ← admin
└── templates/    ← formula.md, cask.md, any-index.md
```

- **`formulae/` — one directory per formula.** `formulae/<name>/index.md`, from
  `templates/formula.md`. The name equals the file name without `.rb`.
- **`casks/` — one directory per cask.** `casks/<token>/index.md`, from
  `templates/cask.md`. The token equals the file name without `.rb`.
- **`release/` — procedures.** `bump.md` ships with the domain. Add other
  procedures (new package, deprecation, tap migration) as flat files. Git
  history is the release log; do not record individual releases.

Both package pillars are durable. `meta.specification_dir` lists both, so
`cumaru coverage` counts their `reference` rows against `Formula/*.rb` and
`Casks/*.rb`. A package without a covering entity is a gap.

## Roles

- **Admin** ([`roles/admin.md`](roles/admin.md)) — full access. Maintains
  entities, procedures, and the `.rb` files.

## Entry

| Task | Load |
|---|---|
| Change, debug, or explain one package | `formulae/<name>/index.md` or `casks/<token>/index.md` |
| Bump a version or a checksum | the package entity, then `release/bump.md` |
| Add a package to the tap | the matching template, then `release/bump.md` steps 3 to 10 |
| Audit knowledge against the Ruby | `cumaru coverage --gaps` |

## Conventions

- **One package per commit.** A commit that touches two `.rb` files is a red
  flag.
- **Version spelling.** Write the version as the upstream tag spells it,
  including or omitting a `v` prefix. The entity records the prefix.
- **Commit message.** Record the tap's convention in the `root` tag. When none
  exists, use `chore: update <name> to <version>`.
- **Secrets.** Never store a token in `.cumaru/` or in a `.rb` file. An entity
  names the environment variable a private download needs.

## Execution disciplines

Every modular file in `disciplines/` is loaded at context start;
`applies-when:` controls when its rules apply. `disciplines/index.md` defines
how `strictness:` controls required consideration.

| Discipline | Applies when | File |
|---|---|---|
| cumaru-first | repository work can benefit from a relevant Cumaru surface | `disciplines/cumaru-first.md` |
| package-change | a change edits `Formula/*.rb` or `Casks/*.rb` | `disciplines/package-change.md` |
