---
name: architecture-specification
description: "Current v7 kernel, configuration, ownership, adapter, and lifecycle architecture"
type: project
status: implemented
version: 7
---

# Architecture specification

## Purpose

Define Cumaru's v7 system boundaries: a domain-neutral kernel, self-contained
domains, filesystem-backed knowledge navigation, one global configuration
model, semantic tag islands, and agent-native delivery.

## Public surface

```text
cumaru install|uninstall|update|migrate|upgrade
cumaru tree|tag|flow|coverage|doctor|help
.cumaru/{index.md,domain.md,config.yaml}
schemas/config.schema.json
domains/{__base,sdlc-full,sdlc-light,iac-basic,qa-basic,vault-memory}/
```

## Invariants

1. `domains/__base/index.md` is the domain-neutral kernel and is byte-identical
   in every shipped domain.
2. `schemas/config.schema.json` is the only active configuration model;
   domain and adopter `config.yaml` files validate against it.
3. The filesystem is structural truth. Marker blocks hold semantic adopter
   data, never child inventories.
4. Framework Markdown frontmatter and outside-tag prose are canonical; local
   tag bodies and local-only files are adopter-owned.
5. Every installed Markdown file has a trimmed 32-512-code-point `summary:`;
   every non-hidden directory has `index.md`.
6. Exactly one adapter is selected by `agent`; only Cumaru-owned native
   artifacts may be installed, refreshed, or removed.
7. Transient lifecycle content is removed after absorption. The durable pillar
   is the sole current record; Git history is the historical cross-reference.
8. Execution disciplines load eagerly; relevance controls application, not
   delivery.
9. Every discipline except its index declares `strictness: 0/10` through
   `10/10`; missing metadata is invalid and has effective strictness `0/10`.

## Inputs and ownership

| Input or surface | Owner | Contract |
|---|---|---|
| `schemas/config.schema.json` | framework | Closed global v7 model used by runtime validation. |
| `domains/<domain>/` | framework | Self-contained canonical source and initial config values. |
| `.cumaru/config.yaml` | adopter | Every valid present value is preserved; config reconciliation adds defaults and removes incompatible keys. |
| Framework Markdown outside tags | framework | Replaced from the matching source at equal version. |
| `<!-- cumaru:NAME -->` bodies | adopter | Preserved by canonical name, independent of schema type or host. |
| Local-only files and directories | adopter | Never changed by update. |
| Adapter instructions, hooks, `cumaru-*` skills and commands | framework | Deterministically reconciled for the selected adapter. |

## Execution

### Preflight

1. Require compatible Bash, Git, cURL, `jq`, and Mike Farah `yq` where the
   invoked command needs them.
2. Validate config shape, semantics, selected domain, and config/index integer
   version agreement before steady-state mutation.
3. Reject cross-version update; migration is the only N-to-v7 route.

### Dry-run

1. Update modes calculate canonical content, ownership-preserving tag merges,
   adapter changes, or config reconciliation without mutation.
2. Migration only prints the current rolling instructions.
3. Read-only navigation, coverage, help, and health inspection do not create
   locks, staging trees, or backups.

### Apply

1. Install copies one validated domain and wires one selected adapter.
2. Update stages the selected managed surfaces, validates them with doctor,
   then publishes under a project lock.
3. `update config` reports `.cumaru/config.yaml` schema/default drift for the
   agent to reconcile deliberately; it never publishes a replacement.

## Failure contract

| Condition | Status | Mutation |
|---|---:|---|
| Usage error | `2` | none |
| Invalid config, tree, source, or safety boundary | `1` | none |
| Schema validator/runtime dependency failure | `4` internally | none |
| Update validation failure before mutation | `1` | none |
| Update write or post-check failure | `1` | partial mutation possible; restore from Git history |

## Transaction and recovery

Update apply requires a clean Git work tree before mutation, then writes managed
surfaces directly and runs doctor after mutation. It creates no project-local
lock, staging, private backup, or recovery directory; Git history is the
recovery boundary after mutation starts.
Migration is read-only at the CLI layer; its LLM-executed edits require tracked
Git history before mutation.

## Implementation map

| Script or artifact | Responsibility |
|---|---|
| `cumaru` | Module loading and command dispatch. |
| `src/schema.sh` | Typed reads, global-model validation, and config reconciliation. |
| `src/common.sh` | Shared frontmatter, balanced tags, inventory, and kernel helpers. |
| `src/cmd_update.sh` | Ownership-aware planning, clean-Git preflight, and direct mutation. |
| `src/agent_adapter.sh` | Native adapter paths, instructions, hooks, and cleanup. |
| `src/cmd_doctor*.sh` | Installed-tree acceptance gate. |
| `domains/__base/` | Canonical kernel and universal artifacts. |

## Principal methods

| Method | Contract |
|---|---|
| `schema_validate_file` | Validate one config; distinguish invalid input from runtime failure. |
| `schema_validate_installed` | Add installed config/index agreement checks. |
| `fm_block_merge` | Fail-closed canonical Markdown merge preserving local tag bodies. |
| `_update_require_clean_git_worktree` | Enforce the clean-Git boundary before direct managed-surface mutation. |
| `_agent_wire_instructions` | Install selected adapter instructions without deleting adopter content. |
| `cmd_doctor_checks` | Execute the seven v7 installed-tree checks. |

## Regression coverage

| Test | Covered behavior |
|---|---|
| `tests/spec/integration/schema_spec.sh` | Global model, semantics, typed reads, reconciliation. |
| `tests/spec/update/*.sh` | Ownership, version gates, dry-run, clean-Git preflight, direct mutation, tags. |
| `tests/spec/integration/agent_adapters_spec.sh` | Adapter install, switch, repair, and removal. |
| `tests/spec/cli/doctor_spec.sh` | Seven-check v7 acceptance and cached inspection. |
| `tests/spec/contracts/documented_contracts_spec.sh` | Public and universal artifact contracts. |

## Verification

```bash
bash tests/run.sh
shellspec --random examples
```

## References

- [`../../docs/architecture.md`](../../docs/architecture.md)
- [`../../docs/update.md`](../../docs/update.md)
- [`../../schemas/config.schema.json`](../../schemas/config.schema.json)
- [`update.md`](update.md)
- [`navigation.md`](navigation.md)
