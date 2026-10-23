---
name: realign-migration-spec
description: Map migration.md's implementation rows to the native read-only migration service
status: open
priority: low
---

# Issue 159: Realign migration.md with the native implementation

`migration.md` names retired Bash modules (`src/cmd_migrate.sh`,
`src/schema.sh`, pinned at tag 0.10.0), a `--from` argument, and a
`_migrate_base_part`/`_migrate_installed_domain` method set as present.
The native migration resolves domain/config without schema validation, uses
`markdown::strip_frontmatter`, and rejects `--from`/`--apply` by contract.

## Risk

- Migration debug routes to retired scripts or attempts removed source
  selection flags on the native CLI.

## Required invariant

No current `migration.md` row names a retired Bash module, `--from`, or a
Bash-only method as present behavior; every implementation reference
resolves to an existing path in the working tree.

## Work

1. Rewrite the implementation map against `src/commands/migrate.rs`,
   `src/distribution.rs`, and `src/markdown.rs`.
2. Retire `--from` and `_migrate_*` rows; record the native
   `<!-- cumaru:migration-domain-extension -->` checkpoint owner in
   `src/commands/migrate.rs`.

## Tests

- `rg -n 'cmd_migrate\.sh|schema\.sh|--from|_migrate_' .memory/specs/migration.md`
  returns no present-tense matches.
- Every relative link in the edited `migration.md` resolves.

## References

- `.memory/specs/migration.md`
- `.memory/specs/rust.md` — native migration contract
- `.memory/issues/issue_145.md`
