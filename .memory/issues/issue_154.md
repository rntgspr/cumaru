---
name: realign-coverage-spec
description: Map coverage.md's implementation map to the native Rust owners
status: open
priority: low
---

# Issue 154: Realign coverage.md with the native implementation

`coverage.md` names retired Bash modules (`src/cmd_coverage.sh`,
`src/common.sh`, `src/cmd_tag.sh`, pinned at tag 0.10.0) and Bash-only
methods (`_coverage_spec_dir`, `fm_tag_table_rows`) as owners of bucket
classification and reference parsing, though the shared parsing now lives
in `src/references.rs`.

## Risk

- Refs-gap remediation recipes route to retired scripts; reference-row
  changes are edited in the wrong place.

## Required invariant

No current `coverage.md` row names a retired Bash module as present
behavior; every implementation reference resolves to an existing path in
the working tree.

## Work

1. Rewrite the implementation map against `src/commands/coverage.rs` and
   `src/references.rs`, plus `src/commands/tag.rs` for the row writer.
2. Point the reference row-parsing method row at `src/references.rs` as the
   shared owner for coverage and doctor.

## Tests

- `rg -n 'cmd_coverage\.sh|common\.sh|cmd_tag\.sh|_coverage_spec_dir|fm_tag_table_rows'
  .memory/specs/coverage.md` returns no present-tense matches.
- Every relative link in the edited `coverage.md` resolves.

## References

- `.memory/specs/coverage.md`
- `.memory/specs/rust.md` — native coverage contract
- `.memory/issues/issue_145.md`
