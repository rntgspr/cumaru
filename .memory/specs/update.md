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
5. Every mutating apply requires a clean Git work tree before writing managed
   files, creates no project-local transient state, and uses Git history as the
   recovery boundary.

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
3. Mutating apply modes require a Git work tree with empty porcelain status,
   including no staged, unstaged, or untracked changes, an existing commit, and
   tracked `.cumaru/config.yaml` plus `.cumaru/index.md` before writing files.
4. General update enumerates source content excluding `config.yaml`,
   `migration.md`, source-only skill/command directories, and backups.

### Dry-run

1. General/scoped mode builds canonical Markdown with local tag bodies restored;
   skills and commands report replacement/pruning; config reports removals and
   its complete candidate diff; agent mode reports old and target surfaces.
2. No mode creates transaction artifacts or mutates any managed path.

### Apply

1. After the clean-Git preflight passes, mutate only the requested managed
   surfaces directly; create no project-local lock, staging, backup, or recovery
   directory.
2. Full update refreshes Markdown; scoped update changes only the named source
   path. Dedicated modes change only their named surface. Agent mode installs
   the target adapter artifacts.
3. Run `cumaru doctor --quiet` after mutation. Config mode has no live mutation.

## Failure contract

| Condition | Status | Mutation |
|---|---:|---|
| Usage error | `2` | none |
| Invalid config/domain, malformed tags, downgrade, or failed validation | `1` | none |
| Higher source on apply | `1` | none; migration required |
| Non-Git or dirty Git work tree | `1` | none; no transient state |
| Post-mutation doctor failure | `1` | mutation remains for Git review/restoration |
| Write failure | `1` | partial mutation possible; inspect and restore from Git history |

## Transaction and recovery

Managed paths are `.cumaru`, `.agents`, `.claude`, `.codex`, `.opencode`,
`AGENTS.md`, `CLAUDE.md`, and `opencode.json`. Apply writes the requested
managed surfaces directly after the clean-Git preflight. It is not one
filesystem-wide atomic operation, and Cumaru creates no project-local lock,
staging, private backup, or recovery directory. The required clean Git work tree
provides the user-controlled recovery point.

## Implementation map

| Script or artifact | Responsibility |
|---|---|
| [`src/cmd_update.sh`](../../src/cmd_update.sh) | Parsing, planning, clean-Git preflight, direct mutation, and post-check. |
| [`src/schema.sh`](../../src/schema.sh) | Config/domain validation, typed reads, and reconciliation planning. |
| [`src/common.sh`](../../src/common.sh) | Balanced tag merge used by Markdown reconstruction. |
| [`src/agent_adapter.sh`](../../src/agent_adapter.sh) | Adapter paths, instructions, hooks, and scoped cleanup. |
| [`src/cmd_doctor.sh`](../../src/cmd_doctor.sh) | Staged acceptance gate. |

## Principal methods

| Method | Contract |
|---|---|
| `cmd_update` | Parses and executes general, scoped, artifact, and config-report modes. |
| `cmd_update_agent` | Previews or directly materializes an explicit adapter after clean-Git validation. |
| `_update_build_expected` | Rebuilds canonical Markdown while restoring adopter tag bodies. |
| `_update_render` | Emits dry-run classifications and diffs. |
| `_update_require_clean_git_worktree` | Refuses mutating update modes outside a Git work tree or with pending porcelain status. |
| `_update_require_clean_git_worktree` | Runs the clean-Git preflight before direct mutation. |
| `_update_reconcile_agent_hook` | Refreshes active adapter instructions and SessionStart integration. |

## Regression coverage

| Test | Covered behavior |
|---|---|
| [`tests/spec/update/content_spec.sh`](../../tests/spec/update/content_spec.sh) | Ownership, read-only config drift reporting, and invalid-value blocking. |
| [`tests/spec/update/tags_spec.sh`](../../tests/spec/update/tags_spec.sh) | Tag preservation, malformed rejection, nesting, duplicates, and idempotence. |
| [`tests/spec/update/transaction_spec.sh`](../../tests/spec/update/transaction_spec.sh) | Clean-Git preflight, direct mutation behavior, doctor gate, and absence of transient debris. |
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
