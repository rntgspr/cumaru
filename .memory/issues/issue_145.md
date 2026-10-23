---
name: realign-specs-with-native-implementation
description: Replace retired Bash implementation references in current specs with the native Rust owners
status: open
priority: medium
---

# Issue 145: Realign specifications with the native implementation

The Bash modules were retired and the Rust crate is the only implementation, but
several current specifications still describe Bash as the owner of their
behavior. Their implementation tables link `src/cmd_*.sh`, `src/common.sh`,
`src/schema.sh`, and `src/agent_adapter.sh` pinned at tag 0.10.0, and
`configuration.md` still states a preflight that requires Mike Farah `yq` and
`jq`. Specifications are the durable single source of truth, so an agent that
loads one is pointed at code that no longer exists and at runtime dependencies
the native CLI does not have.

## Risk

- Agents and contributors search for or edit retired modules instead of the Rust
  owner, or reintroduce `yq`/`jq` requirements.
- Spec invariants silently diverge from native behavior because no table ties
  them to the code that enforces them.

## Required invariant

No current specification names a retired Bash module or a runtime `yq`/`jq`
requirement as present behavior; every implementation reference resolves to an
existing path in the working tree.

## Work

1. Rewrite the implementation tables in the fourteen specs that still reference
   retired Bash modules — `absorb.md`, `agent-adapters.md`, `architecture.md`,
   `configuration.md`, `coverage.md`, `disciplines.md`, `doctor.md`,
   `domains.md`, `install-upgrade.md`, `migration.md`, `navigation.md`,
   `tags.md`, `update.md`, and `workflows.md` — mapping each row to the
   `src/**/*.rs` module that now owns it; drop rows with no native owner
   and record any behavior that lost its owner as an open issue. `rust.md`
   is exempt: it intentionally retains Bash-era narration as documented port
   reference. Each spec is tracked as one child issue: 147 (`navigation`),
   148 (`update`), 149 (`tags`), 150 (`configuration`), 151 (`absorb`),
   152 (`agent-adapters`), 153 (`architecture`), 154 (`coverage`),
   155 (`disciplines`), 156 (`doctor`), 157 (`domains`),
   158 (`install-upgrade`), 159 (`migration`), and 160 (`workflows`).
2. Replace the `configuration.md` preflight that requires `yq` and `jq` with the
   native embedded-schema validation described in `rust.md`.
3. Task order through the four user-facing command specs first, one spec at a
   time against its Rust owner: `navigation.md`, `update.md`, `tags.md`,
   `configuration.md`; then the remaining ten. Each spec is verified against
   the code it now names before the next spec begins.
4. After issue 144 lands, remove `schemas/schema-validate-v9.jq`,
   `schemas/config-reconcile.jq`, their spec rows in `configuration.md` and
   `workflows.md`, and the legacy `tests/spec/integration/schema_spec.sh`
   references to them.

## Tests

- `rg -n 'src/(common|schema|agent_adapter|cmd_[a-z_]+)\.sh' .memory/specs`
  returns no matches.
- `rg -n '\byq\b|\bjq\b' .memory/specs` returns only historical or explicitly
  non-runtime mentions.
- Every relative link in the edited specs resolves to an existing file.

## References

- `.memory/specs/absorb.md`, `agent-adapters.md`, `architecture.md`,
  `configuration.md`, `coverage.md`, `disciplines.md`, `doctor.md`,
  `domains.md`, `install-upgrade.md`, `migration.md`, `navigation.md`,
  `tags.md`, `update.md`, `workflows.md`
- `.memory/specs/rust.md` module boundaries
- Issue 144 (jq removal dependency)
