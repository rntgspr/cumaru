---
name: realign-tags-spec
description: Map tags.md's implementation and method tables to the native Rust owners
status: open
priority: medium
---

# Issue 149: Realign tags.md with the native implementation

`tags.md` names retired Bash modules (`src/common.sh`, `src/cmd_tag.sh`,
`src/cmd_coverage.sh`, `src/cmd_doctor_checks.sh`, pinned at tag 0.10.0) as
owners of the balanced-parser, audit, and set-publication contracts, plus a
typed `all --rows` mode the native CLI deliberately removed.

## Risk

- Agents edit retired tag scripts or call the removed typed listing mode
  and treat its failure as a defect.

## Required invariant

No current `tags.md` row names a retired Bash module or `tag all --rows` as
present behavior; every implementation reference resolves to an existing
path in the working tree.

## Work

1. Rewrite the implementation and method tables against `src/tags.rs`,
   `src/commands/tag.rs`, `src/config_tree.rs`, and `src/references.rs`.
2. Retire the `all --rows` row from the public surface; keep the
   deliberate omission as a documented native difference.
3. Record any preserved-body contract sentence without a native owner.

## Tests

- `rg -n 'cmd_tag\.sh|common\.sh|cmd_coverage\.sh|cmd_doctor_checks\.sh|cmd_update\.sh|all --rows' .memory/specs/tags.md` returns
  no present-tense matches after the edit; any match must be either removed
  or relabeled as the deliberate native difference it documents.
- Every relative link in the edited `tags.md` resolves.

## References

- `.memory/specs/tags.md`
- `.memory/specs/rust.md` — native tag contract
- `.memory/issues/issue_145.md` — aggregate issue
