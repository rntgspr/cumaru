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

The [native migration contract](rust.md#execution) records the detailed
resolution and rendering: current/legacy config is read without requiring its
schema to pass, and base/domain instructions come from one resolved HEAD commit
of main. The command does not deliver the missing migration skill.

## Public surface

```text
cumaru migrate
domains/__base/migration.md
domains/<domain>/migration.md
<!-- cumaru:migration-domain-extension -->
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
8. Printed steps use only native CLI forms. Native `update config` requires
   equal versions, so cross-version reconciliation reads the domain config and
   global schema at one resolved main commit, and candidate validation runs
   native doctor against a disposable copy of the tree. A failed source read is
   a blocker; no target version is inferred.

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

1. Accept no arguments; the hidden `--apply` flag exits 2 with an explanation,
   and any other argument is a usage error.
2. Resolve the installed domain from the `domain` (or legacy `flavor`) string
   of current `config.yaml`, then legacy `schema.yaml` only when current config
   is absent. The selected entry must be a regular non-symlink file holding one
   YAML document; `base` maps to `__base`, and the name is validated before any
   network access.
3. Resolve main HEAD and read `domains/__base/migration.md` plus an inventoried
   domain `migration.md` at that one commit. A domain absent from the main
   inventory receives the base document only.
4. Require the whole-line `<!-- cumaru:migration-domain-extension -->`
   checkpoint in the base document.

### Read-only output

1. Print the heading and execution preamble, the base body before the
   checkpoint, the optional domain body with frontmatter stripped, then the
   base body after it. The whole document is assembled before printing.
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
| Missing, symlinked, or unparsable config, unsafe domain, missing base document or checkpoint, network or UTF-8 failure | `1`, empty stdout | none |
| Usage error, including `--apply` | `2`, empty stdout | none |
| Valid instruction delivery | `0` | none |

## Implementation map

| Script or artifact | Responsibility |
|---|---|
| [`src/commands/migrate.rs`](../../src/commands/migrate.rs) | Argument refusal, current/legacy domain resolution, pinned reads, checkpoint ownership, and ordered rendering. |
| [`src/distribution.rs`](../../src/distribution.rs) | Main-HEAD resolution and commit-pinned inventory and document reads. |
| [`src/markdown.rs`](../../src/markdown.rs) | Domain-document frontmatter stripping. |
| [`domains/__base/migration.md`](../../domains/__base/migration.md) | Universal direct N-to-v9 rolling procedure and the extension checkpoint. |
| `domains/<domain>/migration.md` | Optional domain-specific migration nuance. |

## Principal methods

| Method | Contract |
|---|---|
| `migrate::execute` | Resolves the installed domain and both documents from one pinned commit, then renders without writes. |
| `migrate::installed_domain` | Reads the domain from current config or legacy schema without schema validation or mutation. |
| `migrate::domain_from_config` | Extracts `domain` or legacy `flavor` and validates it as a domain name. |
| `migrate::render` | Splits the base at the checkpoint and inserts the domain extension before refresh steps. |
| `markdown::strip_frontmatter` | Removes leading domain-document frontmatter while preserving body content. |

## Regression coverage

| Test | Covered behavior |
|---|---|
| `src/commands/migrate.rs` unit tests | Checkpoint insertion and spacing, base-only forms, missing or inline checkpoint, `domain`/`flavor` resolution, current-over-legacy selection, and failures before network access. |
| `src/markdown.rs` unit tests | Frontmatter stripping. |

The legacy delivery, repeatability, and prose-policy process scenarios in
`tests/spec/contracts/migrate_spec.sh` are not selected by `tests/run.sh`; see
the [native regression inventory](../../tests/native/README.md).

## Differences from the retired Bash CLI

- There is no `--from`, local checkout, or Git URL source; reads come from
  main HEAD pinned to one commit.
- The installed domain is resolved and validated before any source access.
- Diagnostics go to stderr with the `cumaru migrate:` prefix and empty stdout.
- Heading, preamble, checkpoint placement, and base-part spacing match the
  former output byte for byte.

## No migration skill

No `cumaru-migrate` skill ships: the configuration has stayed at version 9, so
the rolling procedure only converges pre-9 installations, and `cumaru update`
and `cumaru doctor` already route a version mismatch to `cumaru migrate`. When
the configuration version is bumped, add the new procedure step together with
an explicit plan-and-approval gate in `domains/__base/migration.md`.

## Verification

```bash
cargo test --locked
bash tests/run.sh
```

## References

- [`src/commands/migrate.rs`](../../src/commands/migrate.rs)
- [`docs/migrate.md`](../../docs/migrate.md)
- [`configuration.md`](configuration.md)
