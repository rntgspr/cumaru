---
name: cumaru-update-specification
description: "Steady-state v7 refresh across general, scoped, artifact, configuration, and agent modes"
type: project
status: implemented
version: 7
---

# Cumaru update specification

## Purpose

`cumaru update` refreshes an installed v7 project from its selected source
domain without crossing an integer framework-version boundary. It supports
general and path-scoped content refresh, dedicated skills, commands, and
configuration modes, plus adapter switching. Every mode previews by default.

## Public surface

```text
cumaru update [<path>] [--from <source>] [--apply]
cumaru update skills|commands [<agent>] [--from <source>] [--apply|--clear]
cumaru update config [--from <source>]
cumaru update agent [<none|claude|codex|opencode>] [--apply|--clear]
```

## Invariants

1. Installed and source domain, config, root version, and integer version gates
   are validated before apply; lower sources are refused and higher sources
   require `cumaru migrate`.
2. Dry-run creates no lock, staging tree, backup, or managed-surface mutation.
3. General update never changes `config.yaml`; `update config` only reports
   schema/default drift for agent-led reconciliation.
4. Local tag bodies and local-only files are adopter-owned; framework Markdown,
   Cumaru skills, supported commands, instructions, and hooks are framework-owned.
5. Every apply is staged, accepted by `cumaru doctor --quiet`, serialized by a
   project lock, and restored after a handled publication failure.

## Inputs and ownership

| Input or surface | Owner | Contract |
|---|---|---|
| `.cumaru/config.yaml` | adopter | Selects domain; validated in all modes and edited only by the agent. |
| `domains/<domain>/` | framework | Canonical source selected from the active checkout, local `--from`, or temporary Git source. |
| Framework Markdown frontmatter and outside-tag prose | framework | Rebuilt from source. |
| `<!-- cumaru:NAME -->` bodies | adopter | Preserved by canonical name with fail-closed balanced parsing. |
| Local-only files and directories | adopter | Never changed. |
| `cumaru-*` skills, supported commands, instructions, hooks | framework | Refreshed deterministically in their adapter-native paths. |

## Execution

### Preflight

1. Require `.cumaru/index.md` and parseable `.cumaru/config.yaml`; all modes
   except config reconciliation require the installed config to be fully valid.
2. Resolve the installed domain and source, validate the complete source domain,
   and enforce domain plus integer-version agreement.
3. General update enumerates source content excluding `config.yaml`,
   `migration.md`, source-only skill/command directories, and backups.

### Dry-run

1. General/scoped mode builds canonical Markdown with local tag bodies restored;
   skills and commands report replacement/pruning; config reports removals and
   its complete candidate diff; agent mode reports old and target surfaces.
2. No mode creates transaction artifacts or mutates any managed path.

### Apply

1. Create project-local staging and recovery snapshots under the project lock.
2. Full update refreshes skills, commands, Markdown, then adapter integration;
   scoped update changes only the named source path. Dedicated modes change only
   their named surface. Agent mode installs the target before writing `agent`.
3. Run `cumaru doctor --quiet` against staging, then publish `.cumaru/` and the
   managed adapter surfaces. Config mode has no publish phase or live mutation.
4. Remove staging and lock after success or successful rollback.

## Failure contract

| Condition | Status | Mutation |
|---|---:|---|
| Usage error | `2` | none |
| Invalid config/domain, malformed tags, downgrade, or failed validation | `1` | none |
| Higher source on apply | `1` | none; migration required |
| Existing update lock | `1` | none |
| Staged doctor failure | `1` | none to live surfaces |
| Handled publication failure | `1` | managed surfaces restored |

## Transaction and recovery

Managed paths are `.cumaru`, `.agents`, `.claude`, `.codex`, `.opencode`,
`AGENTS.md`, `CLAUDE.md`, and `opencode.json`. Apply uses same-project staging,
`.cumaru-update.lock`, and exact recovery snapshots. Publication is a logical
multi-path transaction, not one filesystem-wide atomic rename. Test fault
checkpoints cover stage, validation, tree publication, and adapter publication.

## Implementation map

| Script or artifact | Responsibility |
|---|---|
| [`src/cmd_update.sh`](../../src/cmd_update.sh) | Parsing, planning, mode orchestration, transaction, publication, and rollback. |
| [`src/schema.sh`](../../src/schema.sh) | Config/domain validation, typed reads, and reconciliation planning. |
| [`src/common.sh`](../../src/common.sh) | Balanced tag merge used by Markdown reconstruction. |
| [`src/agent_adapter.sh`](../../src/agent_adapter.sh) | Adapter paths, instructions, hooks, and scoped cleanup. |
| [`src/cmd_doctor.sh`](../../src/cmd_doctor.sh) | Staged acceptance gate. |

## Principal methods

| Method | Contract |
|---|---|
| `cmd_update` | Parses and executes general, scoped, artifact, and config-report modes. |
| `cmd_update_agent` | Previews or transactionally materializes an explicit adapter. |
| `_update_build_expected` | Rebuilds canonical Markdown while restoring adopter tag bodies. |
| `_update_render` | Emits dry-run classifications and diffs. |
| `_update_transaction_apply` | Stages, validates, publishes, and rolls back with temporary snapshots. |
| `_update_transaction_restore` | Restores all snapshotted managed surfaces. |
| `_update_reconcile_agent_hook` | Refreshes active adapter instructions and SessionStart integration. |

## Regression coverage

| Test | Covered behavior |
|---|---|
| [`tests/spec/update/content_spec.sh`](../../tests/spec/update/content_spec.sh) | Ownership, read-only config drift reporting, and invalid-value blocking. |
| [`tests/spec/update/tags_spec.sh`](../../tests/spec/update/tags_spec.sh) | Tag preservation, malformed rejection, nesting, duplicates, and idempotence. |
| [`tests/spec/update/transaction_spec.sh`](../../tests/spec/update/transaction_spec.sh) | Staging, doctor gate, fault checkpoints, publication, and rollback. |
| [`tests/spec/update/dry_run_spec.sh`](../../tests/spec/update/dry_run_spec.sh) | Global non-mutation for every preview mode. |
| [`tests/spec/update/version_gate_spec.sh`](../../tests/spec/update/version_gate_spec.sh) | Integer gates, domain mismatch, upgrade notice, and downgrade refusal. |
| [`tests/spec/integration/agent_adapters_spec.sh`](../../tests/spec/integration/agent_adapters_spec.sh) | Adapter switching and managed artifact symmetry. |

## Verification

```bash
shellspec tests/spec/update
bash tests/run.sh
```

## References

- [`src/cmd_update.sh`](../../src/cmd_update.sh)
- [`docs/update.md`](../../docs/update.md)
- [`configuration.md`](configuration.md)
- [`tags.md`](tags.md)
