---
name: realign-doctor-spec
description: Map doctor.md's artifact table to the native Rust owners
status: open
priority: low
---

# Issue 156: Realign doctor.md with the native implementation

`doctor.md`'s artifact table names retired Bash modules
(`src/cmd_doctor.sh`, `src/cmd_doctor_checks.sh`, `src/common.sh`, pinned
at tag 0.10.0) while its body already describes the native checks. Only the
implementation/verification table retained the Bash ownership.

## Risk

- Health-check remediation routes to retired scripts instead of
  `src/commands/doctor.rs`, `src/config_tree.rs`, and `src/adapter.rs`.

## Required invariant

No current `doctor.md` row names a retired Bash module as present
behavior; every implementation reference resolves to an existing path in
the working tree.

## Work

1. Rewrite the artifact table against `src/commands/doctor.rs`,
   `src/config_tree.rs`, `src/adapter.rs`, and `src/references.rs`.
2. Keep the Bash source-snapshot mention only as an explicitly historical
   label.

## Tests

- `rg -n 'cmd_doctor.*\.sh|common\.sh' .memory/specs/doctor.md` returns no
  present-tense matches.
- Every relative link in the edited `doctor.md` resolves.

## References

- `.memory/specs/doctor.md`
- `.memory/specs/rust.md` — native doctor contract
- `.memory/issues/issue_145.md`
