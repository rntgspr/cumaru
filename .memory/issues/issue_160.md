---
name: realign-workflows-spec
description: Map workflows.md's validation rows to the native doctor graph check
status: open
priority: low
---

# Issue 160: Realign workflows.md with the native implementation

`workflows.md` names retired Bash artifacts (`schemas/schema-validate-v9.jq`,
`src/schema.sh`, pinned at tag 0.10.0) as the workflow-graph validator and a
`tests/spec/integration/workflow_graph_spec.sh` scenario that no
longer runs (the retired-jq-validator contract is outside the reviewed suite
selection). Native doctor validates graphs in
`src/commands/doctor.rs` after config preflight.

## Risk

- A contributor edits the retired jq validators to change graph rules that
  are actually enforced by the embedded Rust doctor check.

## Required invariant

No current `workflows.md` row names the retired jq validator or Bash
module as present behavior; every implementation reference resolves to an
existing path in the working tree.

## Work

1. Rewrite the validation/artifact rows against
   `src/commands/doctor.rs` and the installed skill boundary doctor
   already enforces.
2. Keep the jq validator mention only as an explicitly historical label
   pending issue 144 removal.

## Tests

- `rg -n 'schema-validate-v9\.jq|config-reconcile\.jq|schema\.sh|cmd_doctor\.sh|workflow_graph_spec'
  .memory/specs/workflows.md`
  returns no present-tense matches.
- Every relative link in the edited `workflows.md` resolves.

## References

- `.memory/specs/workflows.md`
- `.memory/specs/configuration.md` — shared validator context
- `.memory/specs/rust.md`
- `.memory/issues/issue_145.md`, `issue_144.md`
