---
name: realign-disciplines-spec
description: Map disciplines.md's implementation map to the native Rust owners
status: open
priority: low
---

# Issue 155: Realign disciplines.md with the native implementation

`disciplines.md` names retired Bash modules (`src/agent_adapter.sh`,
`src/common.sh`, `src/schema.sh`, `src/cmd_install.sh`,
`src/cmd_update.sh`, `src/cmd_doctor_checks.sh`, pinned at tag 0.10.0) as
owners of strictness validation, instruction wiring, and hook merging.

## Risk

- Discipline delivery debugging routes to retired scripts instead of
  `src/adapter.rs` and `src/config.rs` validation.

## Required invariant

No current `disciplines.md` row names a retired Bash module as present
behavior; every implementation reference resolves to an existing path in
the working tree.

## Work

1. Rewrite the implementation map against `src/adapter.rs`,
   `src/config.rs`, `src/commands/{install,update,doctor}.rs`, and
   `domains/__base/disciplines/`.
2. Replace Bash-only method rows (`discipline_metadata_issues`,
   `schema_validate_disciplines`) with the native strictness and adapter
   check summaries.

## Tests

- `rg -n 'agent_adapter\.sh|schema\.sh|common\.sh|cmd_update\.sh|cmd_doctor_checks|cmd_install\.sh|discipline_metadata_issues|schema_validate_disciplines'
  .memory/specs/disciplines.md` returns no present-tense matches.
- Every relative link in the edited `disciplines.md` resolves.

## References

- `.memory/specs/disciplines.md`
- `.memory/specs/rust.md`
- `.memory/issues/issue_145.md`
