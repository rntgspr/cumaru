---
name: cumaru-configuration-specification
description: "V9 global configuration model, validation, agent-led reconciliation, and schema naming"
type: project
status: implemented
version: 9
---

# Cumaru v9 configuration specification

## Purpose

Cumaru v9 validates every domain source `config.yaml` and adopter
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

1. `schemas/config.schema.json` is the only active global v9 model; runtime
   never falls back to `schema.yaml`. The archived v8 model is selected only
   for installed `version: 8` trees during the migration window.
2. The direct `root` tree is the structural extension point. Its reserved
   attributes are `path`, `optional`, `framework`, `frontmatter`, and
   `tags`; every other key is a literal or glob path selector.
3. A key containing a dot denotes a file. Every other key denotes a directory;
   directory metadata applies to its `index.md`. Literal selectors are
   required unless `optional: true`; globs match zero or more entries, and a
   literal sibling wins over a wildcard regardless of YAML order.
4. `frontmatter` maps field names to objects: presence requires the field and
   `optional: true` makes it optional. `tags` is an array of marker names.
   A `path` value replaces the parent-relative selector location. Only
   `framework: true` is framework-owned; ownership never inherits.
5. Recursive `**` selectors are forbidden. Undeclared entries receive only
   global rules. Overlapping wildcard rules compose; a contradictory reserved
   attribute declaration is a configuration error.
6. Reconciliation reports model-incompatible properties and missing source
   defaults as a candidate diff; arrays and scalars remain adopter-owned values.
7. A permitted but invalid local value blocks the report instead of falling back.
8. Cumaru never rewrites `config.yaml` or creates a persistent config backup.
9. Optional `workflows.<name>.steps.<step_id>` entries name a same-domain
   installed skill and optional `needs` prerequisites. The graph must be
   acyclic; the agent runs ready steps in lexical order and only after each
   prerequisite succeeds. Configuration validity does not imply execution.

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
   the integer `config.version`; v9 has no Markdown `framework-version` field.
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
a clean committed baseline when already inside Git, otherwise warn and proceed.
They write managed surfaces directly and create no project-local transient state
or private recovery snapshots.

## Reverse schema naming

Before replacing the active global model, move it to the next chronological
`config.schema.off-(N+1).json`, where `N` is the highest existing suffix. Never
renumber or modify prior snapshots. The unsuffixed `config.schema.json` is always
current; the highest suffix is its immediate predecessor.

## Implementation map

| Script or artifact | Responsibility |
|---|---|
| [`schemas/config.schema.json`](../../schemas/config.schema.json) | Active declarative global model. |
| [`schemas/schema-validate-v9.jq`](../../schemas/schema-validate-v9.jq) | Operational v9 structural and semantic validator. |
| [`schemas/config-reconcile.jq`](../../schemas/config-reconcile.jq) | Model-aware pruning and recursive source-default fill. |
| [`src/schema.sh`](../../src/schema.sh) | Dependency preflight, conversion, validation, typed reads, and reconciliation dispatch. |
| [`src/cmd_update.sh`](../../src/cmd_update.sh) | Config drift reporting and conditional Git recovery handling. |

## Principal methods

| Method | Contract |
|---|---|
| `schema_validate_file` | Validates one config; distinguishes invalid input from runtime failure. |
| `schema_validate_installed` | Validates the installed versioned configuration. |
| `schema_validate_domain` | Adds selected/source domain agreement and domain semantics. |
| `schema_get_domain`, `schema_get_version` | Return typed configuration values. |
| `config_reconcile_plan` | Produces reconciled value plus removed-property diagnostics without mutation. |
| `_update_check_git_recovery` | Requires clean recovery inside Git and permits warned mutation outside Git. |

## Regression coverage

| Test | Covered behavior |
|---|---|
| [`tests/spec/integration/schema_spec.sh`](../../tests/spec/integration/schema_spec.sh) | Source configs, closed objects, typed reads, semantics, reconciliation, and status classification. |
| [`tests/spec/update/content_spec.sh`](../../tests/spec/update/content_spec.sh) | Read-only config drift reporting and invalid-value blocking. |
| [`tests/spec/update/transaction_spec.sh`](../../tests/spec/update/transaction_spec.sh) | Config non-mutation and conditional Git recovery boundaries. |
| [`tests/spec/update/version_gate_spec.sh`](../../tests/spec/update/version_gate_spec.sh) | Source/local integer-version gates without root frontmatter version. |
| [`tests/spec/integration/agent_adapters_spec.sh`](../../tests/spec/integration/agent_adapters_spec.sh) | Adapter switching without persisted selection. |
| [`tests/spec/integration/workflow_graph_spec.sh`](../../tests/spec/integration/workflow_graph_spec.sh) | Optional workflow graph shape, skill availability, and stable order. |

The v8 model is archived at
[`schemas/config.schema.off-9.json`](../../schemas/config.schema.off-9.json).
The v8 validator remains selected for installed `version: 8` trees until
their domain configurations migrate; the active unsuffixed schema is v9.

## Verification

```bash
shellspec tests/spec/integration/schema_spec.sh tests/spec/update/content_spec.sh
bash tests/run.sh
```

## References

- [`schemas/config.schema.json`](../../schemas/config.schema.json)
- [`docs/update.md`](../../docs/update.md)
- [`update.md`](update.md)
- [`workflows.md`](workflows.md)
