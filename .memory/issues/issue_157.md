---
name: realign-domains-spec
description: Map domains.md's implementation map to the native Rust owners
status: open
priority: low
---

# Issue 157: Realign domains.md with the native implementation

`domains.md` names
`src/cmd_install.sh`, `src/cmd_bootstrap.sh`, `src/agent_adapter.sh`,
`src/schema.sh` rows pinned
at tag 0.10.0 and stale row content (`src/agent_adapter.sh`, `src/schema.sh`)
as owners of install, bootstrap, and validation, though the native installer
materializes remote main-HEAD content instead of copying a local domain.
`src/install.sh` itself is the live native binary installer and must not be
called retired; only its retired-snapshot row content is stale.

## Risk

- Domain packaging and install debugging route to retired scripts and a
  local-snapshot model the native CLI does not use.

## Required invariant

No current `domains.md` row names a retired Bash module or a local-copy
install model as present behavior; every implementation reference resolves
to an existing path in the working tree.

## Work

1. Rewrite the implementation map against
   `src/commands/{install,uninstall,help,bootstrap}.rs`,
   `src/distribution.rs`, `src/adapter.rs`, and `src/install.sh`.
2. Retire Bash-only method rows (`_install_list_domains`,
   `_framework_install_skills`) in favor of the native install selection
   and publication summaries.

## Tests

- `rg -n 'cmd_install\.sh|cmd_bootstrap\.sh|_framework_|_install_list|agent_adapter\.sh|schema\.sh'
  .memory/specs/domains.md` returns no present-tense matches.
- Every relative link in the edited `domains.md` resolves.

## References

- `.memory/specs/domains.md`
- `.memory/specs/rust.md` — native install contract
- `.memory/issues/issue_145.md`
