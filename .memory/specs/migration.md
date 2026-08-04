---
name: cumaru-migration-specification
description: "Read-only rolling migration instruction delivery for direct supported N-to-v9 convergence"
type: project
status: implemented
version: 9
---

# Cumaru migration specification

## Purpose

`cumaru migrate` resolves and prints the current rolling migration instructions
for an installed project. The command is strictly read-only: an LLM executes and
adjudicates the printed detection-first steps. It converges supported prior
layouts directly from `N` to v9 rather than chaining historical adapters.

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
   is inserted at the base preservation checkpoint without restating base
   sections. Documents are never installed.
3. The installed domain is read from current `config.yaml` or, only as migration
   input, legacy `schema.yaml`.
4. Steps are detection-first and idempotent, use `Applies when / Detect / Do /
   Blockers / Verify`, and require stop-and-ask instead of guessing content.
5. Current v9 configuration normalization handles legacy-only, dual-name,
   current-only, and neither-file states deterministically. The reconciled
   candidate is validated as v9 before the final `config.version: 9` write,
   which occurs last.
6. Domain provenance is preserved before canonical refresh. Existing Git
   projects require an explicitly authorized, tracked, clean checkpoint;
   non-Git projects receive a warning and continue without a recovery point.
7. Supported migration input is an installed `.cumaru/` tree. Retired directory
   names are neither discovered nor normalized.

## Inputs and ownership

| Input or surface | Owner | Contract |
|---|---|---|
| `.cumaru/config.yaml` or legacy `.cumaru/schema.yaml` | adopter | Read only to resolve the installed domain. |
| `domains/__base/migration.md` | framework | Required current universal rolling instructions. |
| `domains/<domain>/migration.md` | framework | Optional preservation extension inserted before base conversion and refresh. |
| Printed instructions | framework | Frontmatter stripped; executed by the LLM, never by the command. |
| Durable migration decisions | adopter/LLM | Must follow blockers and preserve adjudicated content. |

## Execution

### Preflight

1. Parse only `--from` or `--from=<source>`; reject `--apply` and unknown args.
2. Resolve the installed domain from current config, then legacy config only when
   current config is absent. Resolve the source checkout and require the base
   migration document.
3. Require the base preservation checkpoint and include the selected domain
   extension there when present.

### Dry-run

1. Strip YAML frontmatter and print the base body in deterministic order, with
   the optional domain body inserted at the preservation checkpoint.
2. Perform no mutation. Because the command is strictly read-only, this is its
   only execution mode.

### Apply

There is no apply mode. The LLM separately executes the printed steps, stops at
blockers, preserves base and domain provenance, and runs doctor after v9
convergence. Before mutating updates it requires either a clean tracked Git
checkpoint or the explicit warning that non-Git execution has no recovery.

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
| [`domains/__base/migration.md`](../../domains/__base/migration.md) | Universal direct N-to-v9 rolling procedure. |
| `domains/<domain>/migration.md` | Optional domain-specific migration nuance. |
| [`src/schema.sh`](../../src/schema.sh) | Current typed config reads reused where applicable. |

## Principal methods

| Method | Contract |
|---|---|
| `cmd_migrate` | Validates args, resolves current/legacy installed domain and source documents, then prints bodies without writes. |
| `_migrate_installed_domain` | Reads the domain from current config or legacy schema without mutation. |
| `_migrate_strip_frontmatter` | Removes leading domain-document frontmatter while preserving body content. |
| `_migrate_base_part` | Prints each side of the base preservation checkpoint so the domain extension runs before refresh. |

## Regression coverage

| Test | Covered behavior |
|---|---|
| [`tests/spec/contracts/migrate_spec.sh`](../../tests/spec/contracts/migrate_spec.sh) | Read-only delivery, `.cumaru/`-only discovery, preservation-first extension order, version convergence, recovery gates, idempotence, and usage failures. |
| [`tests/spec/contracts/documented_contracts_spec.sh`](../../tests/spec/contracts/documented_contracts_spec.sh) | Public help and migration/update boundary. |
| [`tests/spec/update/dry_run_spec.sh`](../../tests/spec/update/dry_run_spec.sh) | Managed-surface non-mutation conventions around preview operations. |

## Known gap

The read-only command and rolling procedure are shipped, but a universal
`cumaru-migrate` skill is not yet distributed to adapters. [Issue 064](../issues/issue_064.md)
tracks the agent-facing inspection, approval, and post-migration checks.

## Verification

```bash
shellspec tests/spec/contracts/migrate_spec.sh
bash tests/run.sh
```

## References

- [`src/cmd_migrate.sh`](../../src/cmd_migrate.sh)
- [`docs/migrate.md`](../../docs/migrate.md)
- [`configuration.md`](configuration.md)
