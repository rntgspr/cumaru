---
name: cumaru-update-specification
description: "Steady-state v9 refresh across general, scoped, artifact, configuration, and agent modes"
type: project
status: implemented
version: 9
---

# Cumaru update specification

## Purpose

`cumaru update` refreshes an installed v9 project from its selected source
domain without crossing an integer config-version boundary. It supports
general and path-scoped content refresh, dedicated skills, commands, and
configuration modes, plus adapter switching. Installation and refresh preview
by default; `--clear` is an immediate mutating exception.

## Public surface

```text
cumaru update [<path>] [--from <source>] [--apply]
cumaru update skills <agent> [--with <skill>...] [--from <source>] [--apply|--clear]
cumaru update commands [<agent>] [--from <source>] [--apply|--clear]
cumaru update config [--from <source>]
cumaru update agent [<none|claude|codex|opencode>] [--apply|--clear]
```

## Invariants

1. Installed and source domain, config, and integer version gates
   are validated before apply; lower sources are refused and higher sources
   require `cumaru migrate`.
2. Install and refresh dry-runs create no lock, staging tree, backup, or
   managed-surface mutation. `--clear` is never a dry-run.
3. General update never changes `config.yaml`; `update config` only reports
   schema/default drift for agent-led reconciliation.
4. Local tag bodies and local-only files are adopter-owned; explicitly marked
   framework Markdown, Cumaru skills, supported commands, instructions, and
   hooks are framework-owned.
5. Every `--apply` or `--clear` mutation checks for an existing Git work tree.
   When present, it requires a clean committed baseline and uses Git history as
   recovery. Without Git or outside a work tree, it warns and continues without
   creating project-local transient recovery state.
6. General update reports deprecated archive pillars and configuration plus
   installed archive skills and launchers without deleting or migrating them.
7. General update resolves only entries explicitly marked `framework: true`
   in the v9 source tree. `path` overrides select their physical destinations;
   adopter-owned paths and tag bodies remain untouched.
8. `update skills <agent> --with <skill>` validates and installs only the
   selected top-level opt-ins. It never reinstalls the domain or refreshes
   unrelated framework/adopter skills.

## Inputs and ownership

| Input or surface | Owner | Contract |
|---|---|---|
| `.cumaru/config.yaml` | adopter | Selects domain; validated in all modes and edited only by the agent. |
| `domains/<domain>/` | framework | Canonical source selected from the active checkout, local `--from`, or temporary Git source. |
| Explicitly framework-owned Markdown frontmatter and outside-tag prose | framework | Rebuilt from source. |
| `<!-- cumaru:NAME -->` bodies | adopter | Preserved by canonical name with fail-closed balanced parsing. |
| Local-only files and directories | adopter | Never changed. |
| `cumaru-*` skills, supported commands, instructions, hooks | framework | Refreshed deterministically in their adapter-native paths. |

## Execution

### Preflight

1. Require `.cumaru/index.md` and parseable `.cumaru/config.yaml`; all modes
   except config reconciliation require the installed config to be fully valid.
2. Resolve the installed domain and source, validate the complete source domain,
   and enforce domain plus integer-version agreement.
3. Mutating `--apply` and `--clear` modes probe for a Git work tree. When found,
   they require empty porcelain status, including no staged, unstaged, or
   untracked changes, an existing commit, and tracked `.cumaru/config.yaml` plus
   `.cumaru/index.md`. Otherwise they warn and proceed without Git recovery.
4. General update enumerates source content excluding `config.yaml`,
   `migration.md`, source-only skill/command directories, and backups.
5. Detect legacy `.cumaru/archive/` and installed
   `cumaru-archive` skill or launcher artifacts for explicit reconciliation.

### Dry-run

1. General/scoped mode builds canonical Markdown with local tag bodies restored;
   skills and commands report replacement/pruning; config reports removals and
   its complete candidate diff; agent installation reports its target surface.
2. These preview forms create no transaction artifacts or managed-path mutation.
   Clear forms do not enter this execution path.

### Apply

1. After the conditional Git recovery check passes or reports that no work tree
   exists, mutate only the requested managed surfaces directly; create no
   project-local lock, staging, backup, or recovery directory.
2. Full update refreshes Markdown; scoped update changes only the named source
   path. Dedicated modes change only their named surface. Agent mode installs
   the target adapter artifacts.
3. Run `cumaru doctor --quiet` after mutation. Config mode has no live mutation.
4. `--clear` immediately removes the requested skills, commands, or complete
   adapter footprint after preflight. An explicit agent scopes removal to that
   adapter; an omitted agent clears the selected surface across all adapters.

## Failure contract

| Condition | Status | Mutation |
|---|---:|---|
| Usage error | `2` | none |
| Invalid config/domain, malformed tags, downgrade, or failed validation | `1` | none |
| Higher source on apply | `1` | none; migration required |
| No Git executable or non-Git project | warning | proceeds without Git recovery |
| Dirty Git work tree or missing committed Cumaru baseline | `1` | none; no transient state |
| Post-mutation doctor failure | `1` | mutation remains for Git review/restoration |
| Write failure | `1` | partial mutation possible; inspect and restore from Git history |

## Transaction and recovery

Managed paths are `.cumaru`, `.agents`, `.claude`, `.codex`, `.opencode`,
`AGENTS.md`, `CLAUDE.md`, and `opencode.json`. Apply and clear write the
requested managed surfaces directly after the Git recovery check. They are not
filesystem-wide atomic operations, and Cumaru creates no project-local lock,
staging, private backup, or recovery directory. Existing Git projects use their
clean committed state as the recovery point; non-Git projects proceed with an
explicit warning and no framework-created recovery point.

## Implementation map

| Script or artifact | Responsibility |
|---|---|
| [`src/cmd_update.sh`](../../src/cmd_update.sh) | Parsing, planning, conditional Git recovery check, direct mutation, and post-check. |
| [`src/schema.sh`](../../src/schema.sh) | Config/domain validation, typed reads, and reconciliation planning. |
| [`src/common.sh`](../../src/common.sh) | Balanced tag merge used by Markdown reconstruction. |
| [`src/agent_adapter.sh`](../../src/agent_adapter.sh) | Adapter paths, instructions, hooks, and scoped cleanup. |
| [`src/cmd_doctor.sh`](../../src/cmd_doctor.sh) | Post-write structural health check. |

## Principal methods

| Method | Contract |
|---|---|
| `cmd_update` | Parses and executes general, scoped, artifact, and config-report modes. |
| `cmd_update_agent` | Previews or materializes an explicit adapter; `--clear` immediately removes one or all adapter footprints after the conditional Git recovery check. |
| `_update_build_expected` | Rebuilds canonical Markdown while restoring adopter tag bodies. |
| `_update_render` | Emits dry-run classifications and diffs. |
| `_update_check_git_recovery` | Enforces clean committed recovery inside Git; warns and succeeds outside Git. |
| `_update_report_deprecated_archive` | Reports retired archive state without mutation. |
| `_update_reconcile_agent_hook` | Refreshes explicit adapter instructions and SessionStart integration. |

## Regression coverage

| Test | Covered behavior |
|---|---|
| [`tests/spec/update/content_spec.sh`](../../tests/spec/update/content_spec.sh) | Ownership, read-only config drift reporting, and invalid-value blocking. |
| [`tests/spec/update/tags_spec.sh`](../../tests/spec/update/tags_spec.sh) | Tag preservation, malformed rejection, nesting, duplicates, and idempotence. |
| [`tests/spec/update/transaction_spec.sh`](../../tests/spec/update/transaction_spec.sh) | Conditional Git recovery, non-Git mutation, dirty-worktree rejection, and absence of transient debris. |
| [`tests/spec/update/dry_run_spec.sh`](../../tests/spec/update/dry_run_spec.sh) | Global non-mutation for every preview mode. |
| [`tests/spec/update/version_gate_spec.sh`](../../tests/spec/update/version_gate_spec.sh) | Integer gates, domain mismatch, upgrade notice, and downgrade refusal. |
| [`tests/spec/integration/agent_adapters_spec.sh`](../../tests/spec/integration/agent_adapters_spec.sh) | Adapter installation plus immediate scoped/all-surface clear behavior. |

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
