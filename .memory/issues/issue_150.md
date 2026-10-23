---
name: realign-configuration-spec
description: Replace configuration.md's yq/jq validator contract with the native embedded-schema boundary
status: open
priority: medium
---

# Issue 150: Realign configuration.md with the native implementation

`configuration.md` keeps the Bash validator contract: a preflight requiring
Mike Farah `yq` and `jq`, retired jq validators
(`schemas/schema-validate-v9.jq`, `schemas/config-reconcile.jq`) listed as
operational, retired `src/schema.sh` and `src/cmd_update.sh` rows pinned at
tag 0.10.0, and the validator filename in `workflows.md` too. The native CLI
embeds `config.schema.json` and validates in-process.

## Risk

- Adopters install `yq`/`jq` believing config validation requires them, or
  edit the retired jq validators instead of the embedded schema path.

## Required invariant

No current `configuration.md` or `workflows.md` row names `yq`, `jq`, or the
retired jq validators as present runtime behavior; every implementation
reference resolves to an existing path in the working tree.

## Work

1. Replace the preflight and implementation tables with
   `src/config.rs`, `src/config_tree.rs`, and the embedded
   `schemas/config.schema.json` boundary described in `rust.md`.
2. Move the jq validator rows into explicit historical labels until issue
   144's removal clears their last consumer.
3. Cross-check `workflows.md`'s validation row against the native doctor
   graph check in `src/commands/doctor.rs`.

## Tests

- `rg -n '\byq\b|\bjq\b|schema-validate-v9\.jq|config-reconcile\.jq|schema\.sh|cmd_update\.sh'
  .memory/specs/configuration.md .memory/specs/workflows.md` returns only
  explicitly historical mentions.
- Every relative link in the edited specs resolves.

## References

- `.memory/specs/configuration.md`
- `.memory/specs/workflows.md`
- `.memory/specs/rust.md` — native configuration contract
- `.memory/issues/issue_145.md`, `issue_144.md`
