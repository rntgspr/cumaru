---
name: cumaru-tags-specification
description: "Semantic tag grammar, balanced parsing, commands, and source-reference rules"
type: project
status: implemented
version: 9
---

# Cumaru tags specification

## Purpose

Semantic tags delimit adopter-owned bodies inside framework Markdown. The
shared balanced parser powers `cumaru tag` and update preservation; configuration
declares where tags are valid.

## Public surface

```text
<!-- cumaru:NAME -->...<!-- /cumaru:NAME -->
cumaru tag
cumaru tag all [--body|--rows]
cumaru tag <file>
cumaru tag [<file>] get|set <tag> [<content>]
cumaru tag get|set [<file>] <tag> [<content>]
```

## Invariants

1. Canonical names match
   `[a-z][a-z0-9_-]*(:[a-z][a-z0-9_*-]*)*`; the file prefix is `cumaru:` only.
2. Parsing uses a stack: exact closers are required, balanced nesting is valid,
   and crossing/unclosed structures fail closed.
3. Tag bodies are adopter-owned regardless of schema host/type; update preserves
   them by canonical name, including unknown/local-only tags.
4. Duplicate top-level bodies are folded at first occurrence in document order;
   source-only tags retain canonical scaffolding.
5. `get` and `set` require the tag to be declared for the target file and never
   reinterpret opaque body content.
6. Doctor promotes balanced-parser failures into a host-attributed error and
   status `1`; malformed hosts cannot pass as an empty successful tag inventory.
   Balanced unknown tags remain opaque and valid nesting remains warning-only.

## Inputs and ownership

| Input or surface | Owner | Contract |
|---|---|---|
| Tag delimiters and source placement | framework | Canonical Markdown scaffold and declared host. |
| Tag body | adopter | Preserved byte content subject to deterministic duplicate folding. |
| `config.yaml` tag declaration | framework/adopter config | Declares required marker names for resolved files; does not prescribe body format or authorize deletion. |
| `reference` rows | adopter | Must obey the repository-source-file rule. |

## Execution

### Preflight

1. Normalize optional `cumaru:` prefix, validate the name and `.md` target, and
   require containment inside `.cumaru/`.
2. Parse the complete host with balanced stack semantics. For `get`/`set`, walk
   validated config declarations and require the tag/host pairing.

### Dry-run

1. Listing and audit forms are read-only. `all` groups bodies or emits typed
   rows; file audit compares actual and expected tags.
2. No listing operation changes Markdown or configuration.

### Apply

1. `set` accepts positional content or stdin, writes through a temporary file,
   validates the normalized result, and replaces the target only on success.
2. Duplicate matching top-level bodies consolidate at the first occurrence with
   one blank line; nested delimiters remain intact in outer bodies.

## Reference special rule

Every `reference` row resolves from the repository root, not its Markdown host.
The target must be a project-root-relative repository source file. Paths inside
`.cumaru/`, directories, absolute paths, URLs, anchors, and escaping paths are
`invalid`. Existing targets outside tracked or configured coverage scope are
`foreign`; missing valid-shaped targets are `stale`. Empty/template rows are
ignored. Doctor validates retained references and `cumaru coverage` classifies
covered, uncovered, stale, invalid, and foreign entries.

## Failure contract

| Condition | Status | Mutation |
|---|---:|---|
| Invalid name or usage | `2` | none |
| Undeclared tag/host, missing file/tag, malformed structure, or write failure | `1` | none |
| Valid list/get/set | `0` | only successful `set` mutates its target |

## Transaction and recovery

`tag set` is a single-file fail-closed replacement, not a project transaction.
It builds and validates temporary output before replacing the host. General
update requires a clean baseline when the project already uses Git and writes
merged tags directly during framework refresh. Outside Git it warns and
continues without a Git recovery point.

## Implementation map

| Script or artifact | Responsibility |
|---|---|
| [`src/common.sh`](../../src/common.sh) | Grammar, balanced parsing, extraction, merge, replacement, and target resolution. |
| [`src/cmd_tag.sh`](../../src/cmd_tag.sh) | CLI parsing, declaration validation, audit, typed listing, and set orchestration. |
| [`src/cmd_coverage.sh`](../../src/cmd_coverage.sh) | Reference coverage bucket adjudication. |
| [`src/cmd_doctor_checks.sh`](../../src/cmd_doctor_checks.sh) | Tag contracts, nesting warning, and retained-reference checks. |
| [`src/cmd_update.sh`](../../src/cmd_update.sh) | Canonical Markdown reconstruction using shared merge semantics. |

## Principal methods

| Method | Contract |
|---|---|
| `_fm_block_parse` | Validates stack balance and supports list/extract/top-level/nesting operations. |
| `fm_block_merge` | Restores local bodies into canonical source, folds duplicates, and retains orphans/scaffolds. |
| `fm_block_replace` | Validates and atomically prepares one normalized body replacement. |
| `fm_tag_table_rows` | Emits resolved default-table rows using cached tag specifications. |
| `_fm_resolve_reference_target` | Applies project-root source-file restrictions. |
| `cmd_tag` | Dispatches list, audit, get, set, and tree-wide typed views. |

## Regression coverage

| Test | Covered behavior |
|---|---|
| [`tests/spec/update/tags_spec.sh`](../../tests/spec/update/tags_spec.sh) | Grammar, duplicates, nesting, malformed structures, preservation, and idempotence. |
| [`tests/spec/update/transaction_spec.sh`](../../tests/spec/update/transaction_spec.sh) | Public update rejection and non-mutation for malformed source/local tags. |
| [`tests/spec/cli/coverage_spec.sh`](../../tests/spec/cli/coverage_spec.sh) | Reference buckets, source rule, modes, scope, and runtime guards. |
| [`tests/spec/cli/doctor_spec.sh`](../../tests/spec/cli/doctor_spec.sh) | Malformed-tag error attribution and non-mutation, balanced duplicates, opaque unknown tags, nesting, references, and cached row processing. |

## Verification

```bash
shellspec tests/spec/update/tags_spec.sh tests/spec/cli/coverage_spec.sh
bash tests/run.sh
```

## References

- [`src/common.sh`](../../src/common.sh)
- [`docs/tag.md`](../../docs/tag.md)
- [`docs/coverage.md`](../../docs/coverage.md)
- [`update.md`](update.md)
