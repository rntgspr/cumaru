---
name: realign-update-spec
description: Map update.md's implementation and method tables to the native Rust owners
status: open
priority: medium
---

# Issue 148: Realign update.md with the native implementation

`update.md` names retired Bash modules (`src/cmd_update.sh`, `src/schema.sh`,
`src/common.sh`, `src/agent_adapter.sh`, `src/cmd_doctor.sh`, pinned at tag
0.10.0) as owners, and describes a `--from <source>` surface that the native
CLI removed (main-HEAD pinned reads only). The Bash-specific execution tables
read as current behavior.

## Risk

- Agents edit retired update scripts, attempt removed `--from` usage, or
  trust the Bash failure contract for version gates instead of the native
  one in `rust.md`.

## Required invariant

No current `update.md` row names a retired Bash module or the removed
`--from`/local-snapshot source as present behavior; every implementation
reference resolves to an existing path in the working tree.

## Work

1. Rewrite the implementation and method tables against
   `src/commands/update.rs`, `src/artifacts.rs`, `src/adapter.rs`,
   `src/config_tree.rs`, and `src/tags.rs`.
2. Retire the `--from <source>` grammar and the Bash install/update dry-run
   classifications from the public surface and preflight sections.
3. Record behaviors that lost their native owner as separate findings.

## Tests

- `rg -n 'cmd_update\.sh|schema\.sh|common\.sh|agent_adapter\.sh|cmd_doctor\.sh|--from' .memory/specs/update.md`
  returns no present-tense matches (historical labels may remain).
- Every relative link in the edited `update.md` resolves.

## References

- `.memory/specs/update.md`
- `.memory/specs/rust.md` — native project update contract
- `.memory/issues/issue_145.md` — aggregate issue
