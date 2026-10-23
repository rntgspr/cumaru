---
name: realign-architecture-spec
description: Map architecture.md's implementation map to the native Rust owners
status: open
priority: low
---

# Issue 153: Realign architecture.md with the native implementation

`architecture.md`'s implementation map names retired Bash modules
(`src/schema.sh`, `src/common.sh`, `src/cmd_update.sh`,
`src/agent_adapter.sh`, `src/cmd_doctor*.sh`), lists
Bash/cURL/rg/jq/yq preflight requirements, and states the Bash failure
contract as current. Its purpose paragraph already credits rust.md, but the
tables below still own the Bash reality.

## Risk

- The architecture overview misleads new contributors about dependencies
  and code layout of the only implementation.

## Required invariant

No current `architecture.md` row names a retired Bash module or a
`jq`/`yq`/`rg` runtime requirement as present behavior; every implementation
reference resolves to an existing path in the working tree.

## Work

1. Rewrite the implementation map against `src/main.rs`, `src/config.rs`,
   `src/config_tree.rs`, `src/artifacts.rs`, `src/adapter.rs`,
   `src/walk.rs`, and `src/commands/*`.
2. Replace the Bash dependency preflight with the native cURL-only source
   access boundary and Git read-only use.
3. Retire the Bash failure-contract narration into historical labels.

## Tests

- `rg -n '\byq\b|\bjq\b|ripgrep|schema\.sh|common\.sh|cmd_update\.sh|agent_adapter\.sh|cmd_doctor'
  .memory/specs/architecture.md` returns no present-tense matches.
- Every relative link in the edited `architecture.md` resolves.

## References

- `.memory/specs/architecture.md`
- `.memory/specs/rust.md`
- `.memory/issues/issue_145.md`
