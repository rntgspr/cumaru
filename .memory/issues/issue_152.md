---
name: realign-agent-adapters-spec
description: Map agent-adapters.md's implementation map to the native Rust owners
status: open
priority: low
---

# Issue 152: Realign agent-adapters.md with the native implementation

`agent-adapters.md`'s implementation map names retired Bash modules
(`src/agent_adapter.sh`, `src/cmd_install.sh`, `src/cmd_update.sh`,
`src/cmd_uninstall.sh`, `src/cmd_doctor.sh`, pinned at tag 0.10.0) and its
method table owns merges and hooks through Bash-only names.

## Risk

- Adapter repair recipes point at retired scripts instead of
  `src/adapter.rs` and the `src/commands/{install,update,uninstall}.rs`
  coordinators.

## Required invariant

No current `agent-adapters.md` row names a retired Bash module as present
behavior; every implementation reference resolves to an existing path in
the working tree.

## Work

1. Rewrite the implementation and method tables against `src/adapter.rs`,
   `src/artifacts.rs`, and the install/update/uninstall command modules.
2. Rename Bash-only method rows (`_agent_wire_*`) to the native merge and
   cleanup responsibilities they became.

## Tests

- `rg -n 'agent_adapter\.sh|cmd_install\.sh|cmd_update\.sh|cmd_uninstall\.sh|cmd_doctor\.sh|_agent_wire_'
  .memory/specs/agent-adapters.md` returns no present-tense matches.
- Every relative link in the edited `agent-adapters.md` resolves.

## References

- `.memory/specs/agent-adapters.md`
- `.memory/specs/rust.md`
- `.memory/issues/issue_145.md`
