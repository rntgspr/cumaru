---
name: realign-navigation-spec
description: Map navigation.md's implementation and method tables to the native Rust owners
status: open
priority: medium
---

# Issue 147: Realign navigation.md with the native implementation

`navigation.md` names retired Bash modules (`src/cmd_tree.sh`,
`src/cmd_map.sh`, `src/common.sh`, pinned at tag 0.10.0) as owners of tree/map
behavior, and its preflight requires Mike Farah `yq` for every target and
ripgrep for `map`. The native CLI needs none of these runtime dependencies:
tree and map parse in-process without config (`--pillars`/`--domain` removed),
and map matches headings without spawning `rg`.

## Risk

- Agents edit retired scripts instead of `src/commands/tree.rs` /
  `src/commands/map.rs`, or reintroduce `yq`/`rg` runtime requirements.

## Required invariant

No current `navigation.md` row names a retired Bash module or a `yq`/`rg`
runtime requirement as present behavior; every implementation reference
resolves to an existing path in the working tree.

## Work

1. Rewrite the implementation and principal-method tables against
   `src/commands/tree.rs`, `src/commands/map.rs`, `src/walk.rs`,
   `src/paths.rs`, `src/markdown.rs`, `src/tsv.rs`, and `src/text.rs`.
2. Replace the yq/rg dependency preflight prose with the in-process
   validation boundaries described in `rust.md`.
3. Record pre-existing contract sentences with no native owner (such as
   `--pillars`/`--domain` filters) as intentionally removed, not owned.

## Tests

- `rg -n 'cmd_tree|cmd_map|common\.sh|cmd_doctor_checks|agent_adapter\.sh|\byq\b|ripgrep|\brg\b'
  .memory/specs/navigation.md` returns no present-tense matches (a matching
  sentence about `rg -n` output must be adjudicated as a stale Bash-era
  reference, not preserved).
- Every relative link in the edited `navigation.md` resolves.

## References

- `.memory/specs/navigation.md`
- `.memory/specs/rust.md` — native navigation contract
- `.memory/issues/issue_145.md` — aggregate issue
