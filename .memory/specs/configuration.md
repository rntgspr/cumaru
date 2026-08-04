---
name: cumaru-configuration-specification
description: "V7 global configuration model, validation, agent-led reconciliation, and schema naming"
type: project
status: implemented
version: 7
---

# Cumaru configuration specification

## Purpose

Cumaru v7 validates every domain source `config.yaml` and adopter
`.cumaru/config.yaml` against one global model. `cumaru update config` reports
reconciliation context; the agent edits adopter state deliberately.

## Public surface

```text
schemas/config.schema.json
domains/<domain>/config.yaml
.cumaru/config.yaml
cumaru update config [--from <source>]
```

## Invariants

1. `schemas/config.schema.json` is the only active global model; runtime never
   selects an `off-N` contract or falls back to `schema.yaml`.
2. Known objects are closed, including against `x-*`; recursive
   `root.entities` is the structural extension point.
3. Reconciliation reports model-incompatible properties and missing source
   defaults as a candidate diff; arrays and scalars remain adopter-owned values.
4. A permitted but invalid local value blocks the report instead of falling back.
5. Cumaru never rewrites `config.yaml` or creates a persistent config backup.

## Inputs and ownership

| Input or surface | Owner | Contract |
|---|---|---|
| `schemas/config.schema.json` | framework | Active project-wide Draft 2020-12 declarative contract. |
| `schemas/config.schema.off-N.json` | framework | Immutable displaced historical snapshots; never used at runtime. |
| `domains/<domain>/config.yaml` | framework | Valid initial/default values for one domain. |
| `.cumaru/config.yaml` | adopter | Effective valid configuration; present valid values win. |

## Execution

### Preflight

1. Require Mike Farah `yq` and `jq`; parse local YAML and validate the global
   model's supported structural and semantic contract.
2. Validate source config, selected domain, frontmatter/path semantics, and
   config/index integer-version agreement.
3. Config mode may begin from parseable but invalid local YAML structure so it
   can remove unknown properties; its final candidate must be fully valid.

### Report

1. Canonicalize YAML, resolve local properties against the global model, report
   each removed JSON Pointer and reason, recursively fill missing source values,
   validate the candidate, and print the complete diff.
2. Print the global schema and source-default paths needed by the agent.
3. Do not create a lock, staging tree, backup, or config mutation. `--apply` is
   a usage error.

## Failure contract

| Condition | Status | Mutation |
|---|---:|---|
| Invalid config or candidate | `1` | none |
| Missing/incompatible dependency or validator runtime failure | `4` internally, command fails | none |
| Usage error | `2` | none |

## Transaction and recovery

Configuration reconciliation is read-only. General mutating update modes require
a clean Git work tree, write managed surfaces directly, and create no
project-local transient state or private recovery snapshots.

## Reverse schema naming

Before replacing the active global model, move it to the next chronological
`config.schema.off-(N+1).json`, where `N` is the highest existing suffix. Never
renumber or modify prior snapshots. The unsuffixed `config.schema.json` is always
current; the highest suffix is its immediate predecessor.

## Implementation map

| Script or artifact | Responsibility |
|---|---|
| [`schemas/config.schema.json`](../../schemas/config.schema.json) | Active declarative global model. |
| [`schemas/schema-validate.jq`](../../schemas/schema-validate.jq) | Operational structural and semantic validator. |
| [`schemas/config-reconcile.jq`](../../schemas/config-reconcile.jq) | Model-aware pruning and recursive source-default fill. |
| [`src/schema.sh`](../../src/schema.sh) | Dependency preflight, conversion, validation, typed reads, and reconciliation dispatch. |
| [`src/cmd_update.sh`](../../src/cmd_update.sh) | Config drift reporting and clean-Git update handling. |

## Principal methods

| Method | Contract |
|---|---|
| `schema_validate_file` | Validates one config; distinguishes invalid input from runtime failure. |
| `schema_validate_installed` | Adds installed config/index version agreement. |
| `schema_validate_domain` | Adds selected/source domain agreement and domain semantics. |
| `schema_get_domain`, `schema_get_version` | Return typed configuration values. |
| `config_reconcile_plan` | Produces reconciled value plus removed-property diagnostics without mutation. |
| `_update_require_clean_git_worktree` | Verifies the clean-Git boundary before direct framework and agent artifact mutation. |

## Regression coverage

| Test | Covered behavior |
|---|---|
| [`tests/spec/integration/schema_spec.sh`](../../tests/spec/integration/schema_spec.sh) | Source configs, closed objects, typed reads, semantics, reconciliation, and status classification. |
| [`tests/spec/update/content_spec.sh`](../../tests/spec/update/content_spec.sh) | Read-only config drift reporting and invalid-value blocking. |
| [`tests/spec/update/transaction_spec.sh`](../../tests/spec/update/transaction_spec.sh) | Config non-mutation and update clean-Git boundaries. |
| [`tests/spec/update/version_gate_spec.sh`](../../tests/spec/update/version_gate_spec.sh) | Config/root and source/local integer-version gates. |
| [`tests/spec/integration/agent_adapters_spec.sh`](../../tests/spec/integration/agent_adapters_spec.sh) | Agent value preservation and switching. |

## Verification

```bash
shellspec tests/spec/integration/schema_spec.sh tests/spec/update/content_spec.sh
bash tests/run.sh
```

## References

- [`schemas/config.schema.json`](../../schemas/config.schema.json)
- [`docs/update.md`](../../docs/update.md)
- [`update.md`](update.md)
