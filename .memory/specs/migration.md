---
name: cumaru-migration-specification
description: "Read-only rolling migration instruction delivery for direct supported N-to-v7 convergence"
type: project
status: implemented
version: 7
---

# Cumaru migration specification

## Purpose

`cumaru migrate` resolves and prints the current rolling migration instructions
for an installed project. The command is strictly read-only: an LLM executes and
adjudicates the printed detection-first steps. It converges supported prior
layouts directly from `N` to v7 rather than chaining historical adapters.

## Public surface

```text
cumaru migrate [--from <source>]
domains/__base/migration.md
domains/<domain>/migration.md
```

## Invariants

1. The command never changes project, adapter, source, lock, backup, or staging
   state and has no `--apply` mode.
2. One base rolling document is current per release; an optional domain document
   extends it without restating base sections. Documents are never installed.
3. The installed domain is read from current `config.yaml` or, only as migration
   input, legacy `schema.yaml`.
4. Steps are detection-first and idempotent, use `Applies when / Detect / Do /
   Blockers / Verify`, and require stop-and-ask instead of guessing content.
5. Current v7 configuration normalization handles legacy-only, dual-name,
   current-only, and neither-file states deterministically; version writes occur last.

## Inputs and ownership

| Input or surface | Owner | Contract |
|---|---|---|
| `.cumaru/config.yaml` or legacy `.cumaru/schema.yaml` | adopter | Read only to resolve the installed domain. |
| `domains/__base/migration.md` | framework | Required current universal rolling instructions. |
| `domains/<domain>/migration.md` | framework | Optional domain-specific extension appended after base. |
| Printed instructions | framework | Frontmatter stripped; executed by the LLM, never by the command. |
| Durable migration decisions | adopter/LLM | Must follow blockers and preserve adjudicated content. |

## Execution

### Preflight

1. Parse only `--from` or `--from=<source>`; reject `--apply` and unknown args.
2. Resolve the installed domain from current config, then legacy config only when
   current config is absent. Resolve the source checkout and require the base
   migration document.
3. Include the selected domain extension when present.

### Dry-run

1. Strip YAML frontmatter and print the base body followed by the optional domain
   body in deterministic order.
2. Perform no mutation. Because the command is strictly read-only, this is its
   only execution mode.

### Apply

There is no apply mode. The LLM separately executes the printed steps only after
the required clean-worktree and tracked-`.cumaru/` preflight, stops at blockers,
verifies each step, and runs doctor at completion.

## Failure contract

| Condition | Status | Mutation |
|---|---:|---|
| Missing installed current/legacy config or base migration document | `1` | none |
| Usage error, including `--apply` | `2` | none |
| Valid instruction delivery | `0` | none |

## Implementation map

| Script or artifact | Responsibility |
|---|---|
| [`src/cmd_migrate.sh`](../../src/cmd_migrate.sh) | Argument parsing, domain/source resolution, frontmatter stripping, and ordered output. |
| [`domains/__base/migration.md`](../../domains/__base/migration.md) | Universal direct N-to-v7 rolling procedure. |
| `domains/<domain>/migration.md` | Optional domain-specific migration nuance. |
| [`src/schema.sh`](../../src/schema.sh) | Current typed config reads reused where applicable. |

## Principal methods

| Method | Contract |
|---|---|
| `cmd_migrate` | Validates args, resolves current/legacy installed domain and source documents, then prints bodies without writes. |
| `_migrate_installed_domain` | Reads the domain from current config or legacy schema without mutation. |
| `_migrate_strip_frontmatter` | Removes leading document frontmatter while preserving migration body order/content. |

## Regression coverage

| Test | Covered behavior |
|---|---|
| [`tests/spec/contracts/migrate_spec.sh`](../../tests/spec/contracts/migrate_spec.sh) | Read-only delivery, explicit source, current/legacy/dual filename resolution, direct N-to-v7 wording, and usage failures. |
| [`tests/spec/contracts/documented_contracts_spec.sh`](../../tests/spec/contracts/documented_contracts_spec.sh) | Public help and migration/update boundary. |
| [`tests/spec/update/dry_run_spec.sh`](../../tests/spec/update/dry_run_spec.sh) | Managed-surface non-mutation conventions around preview operations. |

## Verification

```bash
shellspec tests/spec/contracts/migrate_spec.sh
bash tests/run.sh
```

## References

- [`src/cmd_migrate.sh`](../../src/cmd_migrate.sh)
- [`docs/migrate.md`](../../docs/migrate.md)
- [`configuration.md`](configuration.md)
