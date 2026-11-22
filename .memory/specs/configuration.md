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

The [native configuration contract](rust.md#invariants) embeds the active JSON
Schema and parses YAML in-process; no runtime `yq`, `jq`, or schema-file lookup
exists. `config::load` applies declarative validation;
[doctor](rust.md#native-doctor) separately checks workflow graphs and installed
skill availability. Reconciliation is read-only and uses remote main-HEAD
defaults through [update config](rust.md#native-project-update).

## Public surface

```text
schemas/config.schema.json
domains/<domain>/config.yaml
.cumaru/config.yaml
cumaru update config
```

## Invariants

1. `schemas/config.schema.json` is the only active global v9 model; runtime
   never falls back to `schema.yaml` and embeds no older schema. A config that
   does not satisfy it is reshaped into v9 by the agent through `cumaru migrate`.
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
   `framework` and `optional` are independent and may combine on one entry:
   `framework` decides who owns the content, `optional` decides whether the
   file must exist. An adopter that removes a framework-owned file declares
   its literal selector with `optional: true` so doctor accepts the absence
   and update does not recreate it.
5. Recursive `**` selectors are forbidden. Undeclared entries receive only
   global rules. Overlapping wildcard rules compose; conflicting frontmatter
   fields and physical destination collisions are configuration errors.
   Rejecting conflicting reserved attributes declared by sibling wildcards has
   no native owner yet and is tracked by
   [issue 144](../issues/issue_144.md).
6. Reconciliation reports model-incompatible properties and missing source
   defaults as a candidate diff; arrays and scalars remain adopter-owned values.
7. A permitted but invalid local value blocks the report instead of falling back.
8. Cumaru never rewrites `config.yaml` or creates a persistent config backup.
9. A pillar entry's navigation `index.md` never carries a glob leaf contract.
   `rules.index_md`, `rules.pillar_index`, and an explicitly named `index.md`
   selector are its only sources, however the parent entry was selected.
   Native selector resolution exempts `index.md` from leaf wildcards. Failing
   source-domain validation when a wildcard's leaf `tags` would also match
   `index.md` has no native owner and is tracked by
   [issue 172](../issues/issue_172.md).
10. Reconciliation is asymmetric by design. Adding a key is additive and never
    reports drift. Replacing a shipped glob selector with more specific keys the
    glob itself would have matched is a structural refinement and is equally not
    drift, so the candidate does not restore the wildcard. Deleting a shipped
    key with nothing standing in for it still reports, YAML formatting alone is
    never drift, and every reported difference names the responsible property.
11. Optional `workflows.<name>.steps.<step_id>` entries name an installed skill
   and optional `needs` prerequisites. The graph must be acyclic; the agent
   runs ready steps in lexical order and only after each prerequisite
   succeeds. Configuration validity does not imply execution. Doctor checks
   installed supported-adapter skill files, not same-domain membership
   ([workflows](workflows.md)).
12. Optional `meta.context.{framework,adopter,source}` arrays are adopter-owned
   file or directory paths that select [context scopes](../../docs/context.md#scopes).
   `source` entries may also be gitignore-style globs (`**/` spans directories,
   `*` stays in one segment). Absolute paths and `..` segments are invalid; adding
   the key and its source globs was additive and did not change `version` or
   create a schema snapshot.
13. Optional `meta.doctor.after.warm` is an adopter-owned boolean (domains ship
   `false`) enabling doctor's post-check adopter cache warm
   ([doctor](doctor.md)). It is additive: no `version` change or snapshot.
14. Doctor reconciles local config against the domain `config.yaml` on GitHub
   main (cached daily, see [doctor](../../docs/doctor.md#configuration-drift-reference)).
   `meta.context.framework` and `meta.context.adopter` entries present in that
   reference but absent locally get a dedicated non-failing warning;
   `meta.context.source` is not compared.

## Inputs and ownership

| Input or surface | Owner | Contract |
|---|---|---|
| `schemas/config.schema.json` | framework | Active project-wide Draft 2020-12 declarative contract. |
| `schemas/config.schema.off-N.json` | framework | Immutable displaced historical snapshots; never used at runtime. |
| `domains/<domain>/config.yaml` | framework | Valid initial/default values for one domain. |
| `.cumaru/config.yaml` | adopter | Effective valid configuration; present valid values win. |

## Execution

### Preflight

1. `config::load` requires a regular, non-symlink `config.yaml` with exactly
   one YAML document, converts it to JSON without coercing non-string keys or
   non-finite numbers, and validates it against the embedded schema before
   returning. Schema failures aggregate JSON Pointer diagnostics.
2. Remote source configs pass through `config::parse`; update and install also
   require selected-domain and integer `config.version` agreement. v9 has no
   Markdown `framework-version` field. Selector paths, collisions, and
   frontmatter conflicts are validated by `config_tree` during resolution.
3. Config mode starts from one parseable but possibly schema-invalid local YAML
   document so it can remove unknown properties; its candidate must pass the
   embedded schema.

### Report

1. Convert local YAML to JSON, prune properties the model does not allow while
   recording each removed JSON Pointer, recursively fill missing source
   defaults while keeping refined glob selectors, validate the candidate, and
   print the complete current and candidate documents.
2. Print the embedded schema and source-default paths needed by the agent.
3. Do not create a lock, staging tree, backup, or config mutation. `--apply` is
   a usage error.

## Failure contract

| Condition | Status | Mutation |
|---|---:|---|
| Invalid config, cross-version source, or invalid candidate | `1` | none |
| Embedded-schema or conversion runtime failure | `1` | none |
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

The [Rust CLI specification](rust.md) documents the native `config::load` implementation,
embedded schema selection, diagnostics, and its current validation boundaries.

| Artifact | Responsibility |
|---|---|
| [`schemas/config.schema.json`](../../schemas/config.schema.json) | Active declarative global model, embedded at build time. |
| [`src/config.rs`](../../src/config.rs) | `CUMARU_DIR`, `CONFIG_FILE`, loading, parsing, private embedded-schema validation, YAML-to-JSON conversion, and read-only reconciliation. |
| [`src/config_tree.rs`](../../src/config_tree.rs) | V9 selector resolution, path safety, collisions, frontmatter conflicts, index exemption, and logical-to-physical lookup. |
| [`src/commands/update.rs`](../../src/commands/update.rs) | `update config` report, version gate, and conditional Git recovery. |
| [`src/commands/doctor.rs`](../../src/commands/doctor.rs) | Workflow graph validation and named drift review against main. |

Historical, not executed by any command, test runner, or CI job:
[`schemas/schema-validate-v9.jq`](../../schemas/schema-validate-v9.jq) and
[`schemas/config-reconcile.jq`](../../schemas/config-reconcile.jq) remain only as
the written reference for issue 144 and are removed by
[issue 145](../issues/issue_145.md) after it lands.

## Differences from the retired Bash CLI

- Validation runs in-process against the embedded schema; the `yq`/`jq`
  preflight and the internal status `4` for validator runtime failures are gone.
- `config::load` applies only the declarative schema. Workflow graph and skill
  availability checks moved to doctor; sibling-wildcard conflicts and the
  source wildcard index check have no native owner yet
  ([issue 144](../issues/issue_144.md), [issue 172](../issues/issue_172.md)).
- `update config` takes no source selector; defaults come from main HEAD.

## Principal methods

| Method | Contract |
|---|---|
| `config::load` | Loads and validates the installed single-document regular configuration. |
| `config::parse` | Parses one document and applies the private embedded-schema gate. |
| `config::reconcile` | Prunes model-incompatible properties, fills missing source defaults, keeps refined glob selectors, and validates the candidate without mutation. |
| `config_tree::contracts` | Resolves effective per-host frontmatter and tag contracts from the v9 tree. |
| `config_tree::directory_path` | Resolves a logical directory name through `path` overrides. |
| `doctor::validate_workflows` | Checks dependencies, cycles, and installed skill availability. |
| `doctor::review_properties` | Names each property that makes the main candidate differ from the local configuration. |
| `update::recovery` | Requires clean recovery inside Git and permits warned mutation outside Git. |

## Regression coverage

| Test | Covered behavior |
|---|---|
| `src/config.rs` unit tests | Shipped config acceptance, aggregate schema errors, nested types, unsupported versions, and reconciliation without overwriting local choices. |
| `src/config_tree.rs` unit tests | Owned update pairs, missing required files, tag selectors, invalid trees, and initial domain selection. |
| `src/commands/doctor.rs` unit tests | Workflow validation, offline default review, and the daily reference cache. |
| [`tests/native/lifecycle_spec.sh`](../../tests/native/lifecycle_spec.sh) | Config reconciliation preview without modifying adopter bytes. |

Remaining legacy schema and workflow-graph scenarios are tracked in the
[native regression inventory](../../tests/native/README.md).

## Verification

```bash
cargo test --locked
bash tests/run.sh
```

## References

- [`schemas/config.schema.json`](../../schemas/config.schema.json)
- [`docs/update.md`](../../docs/update.md)
- [`update.md`](update.md)
- [`workflows.md`](workflows.md)
