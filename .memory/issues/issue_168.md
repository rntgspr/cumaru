---
name: context-uncovered-files-dropped-silently
description: Make files outside the meta.context lists visible instead of silently unranked
status: open
priority: medium
---

# Issue 168: Files outside the `meta.context` lists vanish from ranking

Once `meta.context` exists, a `.cumaru/` Markdown file covered by neither the
`framework` nor the `adopter` list has no scope and is not indexed. That is
the intended rule, but it is silent. After `cumaru update config` fills the
shipped defaults, `commands/`, `skills/`, `migration.md`, `bootstrap.md`, and
any adopter-created directory stop appearing in results with no diagnostic.
The base domain ships `adopter: []`, so no adopter-authored content is ranked
there, where the previous release ranked every visible Markdown file.

## Risk

- An adopter believes a search covered the whole tree when part of it is
  excluded.
- The base domain's default makes context search close to empty.

## Required invariant

An adopter can tell from the command output or documentation which visible
`.cumaru/` files are excluded from ranking by the current lists.

## Work

1. Report the count of uncovered Markdown files on stderr, with the paths
   under a verbose or warm run.
2. Review the shipped defaults per domain, the base domain's empty `adopter`
   list first.
3. Document the exclusion rule in `docs/context.md`.

## Tests

- A tree with one uncovered `reviews/a.md` reports one excluded file and
  ranks the covered ones.
- A tree without `meta.context` reports no exclusions.

## References

- `src/commands/context.rs` `covers`, `inventory`
- `domains/*/config.yaml` `meta.context`
- `docs/context.md` Scopes
