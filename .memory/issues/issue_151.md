---
name: realign-absorb-spec
description: Map absorb.md's implementation map to the native Rust owners
status: open
priority: low
---

# Issue 151: Realign absorb.md with the native implementation

`absorb.md`'s implementation map names retired Bash modules
(`src/cmd_tree.sh`, `src/cmd_fs.sh`, `src/cmd_doctor*.sh`) and Bash
method names (`_fs_resolve_inside`,
`cmd_doctor_checks`) as owners of guarded transient cleanup mechanics.

## Risk

- Absorb recipes route agents to retired scripts instead of
  `src/commands/fs.rs`, `tree.rs`, and `doctor.rs`.

## Required invariant

No current `absorb.md` row names a retired Bash module or Bash-only method
as present behavior; every implementation reference resolves to an existing
path in the working tree.

## Work

1. Rewrite the implementation map against `src/commands/fs.rs`,
   `src/commands/tree.rs`, `src/commands/doctor.rs`, `src/tags.rs`, and the
   domain `cumaru-absorb` skills it already names.
2. Replace `_fs_resolve_inside` / `cmd_doctor_checks` method rows with the
   native fs guardrail and doctor check summaries.

## Tests

- `rg -n 'cmd_fs\.sh|cmd_tree\.sh|cmd_doctor.*\.sh|cmd_doctor_checks|_fs_resolve_inside'
  .memory/specs/absorb.md` returns no present-tense matches.
- Every relative link in the edited `absorb.md` resolves.

## References

- `.memory/specs/absorb.md`
- `.memory/specs/rust.md`
- `.memory/issues/issue_145.md`
