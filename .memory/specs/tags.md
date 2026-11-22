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

The [native tag contract](rust.md#execution) records the detailed balanced
parsing, declaration gates, opaque get/set bodies, and staged single-file
publication. The typed tree-wide rows listing was deliberately removed by
maintainer decision; table/reference interpretation lives in
[`src/references.rs`](../../src/references.rs) for coverage and doctor, never in
`cumaru tag`.

## Public surface

```text
<!-- cumaru:NAME -->...<!-- /cumaru:NAME -->
cumaru tag
cumaru tag all [--body]
cumaru tag <file>
cumaru tag [<file>] get|set <tag> [<content>]
cumaru tag get|set [<file>] <tag> [<content>]
```

A bare `tag` audits `index.md`. A `get`/`set` without a file targets
`index.md`. Any other `tag all` argument is a usage error.

## Invariants

1. Canonical names match
   `[a-z][a-z0-9_-]*(:[a-z][a-z0-9_*-]*)*`; the file prefix is `cumaru:` only.
2. Parsing uses a stack: exact closers are required, balanced nesting is valid,
   and crossing/unclosed structures fail closed.
3. Tag bodies are adopter-owned regardless of schema host/type; update preserves
   them by canonical name, including unknown/local-only tags.
4. Duplicate top-level bodies are folded at first occurrence in document order;
   source-only tags retain canonical scaffolding.
5. `get` and `set` require the tag to be declared for the target file in the
   validated v9 configuration and never reinterpret opaque body content. The
   `reference` tag is the single exception: its get/set requires neither a
   declaration nor configuration.
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

1. Strip an optional `cumaru:` prefix and validate the name before filesystem
   access. Require a real `.cumaru/` directory.
2. Resolve the host as a regular `.md` file inside `.cumaru/`, accepting
   contained absolute and `.cumaru/`-prefixed paths and rejecting `..`,
   control characters, and every symlink component.
3. Parse the complete host with balanced stack semantics. Audits and non-
   `reference` get/set load the validated configuration and resolve the host's
   declared tags through the v9 selector tree.

### Read-only forms

1. File audit compares declared and actual tag names and fails on any missing
   or undeclared tag.
2. `all` walks every safe Markdown host without configuration and lists tag
   names per file, or prints each body between its markers with `--body`.
   Malformed hosts and traversal defects are reported after the safe output.
3. No read-only form changes Markdown or configuration.

### Apply

1. `set` accepts positional content, including an explicitly empty string, or
   piped stdin. A missing block is inserted after closed leading frontmatter.
2. Duplicate matching top-level bodies consolidate at the first occurrence;
   nested delimiters remain intact in outer bodies. The candidate must parse
   as a balanced document before publication.
3. Output is staged beside the host with exclusive creation and the host's
   permissions, synced, rechecked against the original bytes, then renamed.

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
| Invalid name, unsupported `all` mode, surplus operands, or `set` without content on a terminal | `2` | none |
| Missing/symlinked root, unsafe host, invalid config, undeclared/absent tag, malformed structure, or audit mismatch | `1` | none |
| Malformed host or traversal defect during `all` | `1` after safe output | none |
| Staging failure or detected concurrent edit during `set` | `1` | original host preserved |
| Aligned audit, valid list, get, or set | `0` | only successful `set` mutates its target |

## Transaction and recovery

`tag set` is a single-file fail-closed replacement, not a project transaction or
a filesystem-race-proof lock. It stages and validates output before renaming it
over the host. Content update requires a clean baseline when the project
already uses Git and writes merged tags directly during framework refresh.
Outside Git it warns and continues without a Git recovery point.

## Implementation map

| Artifact | Responsibility |
|---|---|
| [`src/tags.rs`](../../src/tags.rs) | Grammar, balanced parsing, extraction, duplicate consolidation, merge, and validated replacement. |
| [`src/commands/tag.rs`](../../src/commands/tag.rs) | CLI parsing, host resolution, declaration gates, audit, tree-wide listing, and staged set publication. |
| [`src/config_tree.rs`](../../src/config_tree.rs) | Per-host tag declarations resolved from the v9 selector tree. |
| [`src/references.rs`](../../src/references.rs) | Innermost-block table rows and the reference source-file rule shared by coverage and doctor. |
| [`src/commands/coverage.rs`](../../src/commands/coverage.rs) | Reference coverage bucket adjudication. |
| [`src/commands/doctor.rs`](../../src/commands/doctor.rs) | Required tags, malformed-host errors, nesting warnings, and retained-reference checks. |
| [`src/commands/update.rs`](../../src/commands/update.rs) | Canonical Markdown reconstruction using shared merge semantics. |

## Principal methods

| Method | Contract |
|---|---|
| `tags::valid_name` | Accepts the canonical colon-segment grammar. |
| `tags::parse` | Validates stack balance and returns nested blocks with depth. |
| `tags::extract` | Returns a block body, folding duplicates in document order. |
| `tags::merge` | Restores local bodies into canonical source, folds duplicates, and retains orphans/scaffolds. |
| `tags::replace` | Prepares one validated body replacement or missing-block insertion. |
| `tag::operation` | Parses both positional orders without interpreting content as options. |
| `tag::publish` | Stages beside the host and refuses detected concurrent edits before rename. |
| `config_tree::tag_contracts` | Resolves declared tag names per host. |
| `references::resolve` | Applies project-root source-file restrictions. |

## Regression coverage

| Test | Covered behavior |
|---|---|
| `src/tags.rs` unit tests | Grammar, nested extraction/replacement, duplicate folding, malformed rejection, prose preservation, and opaque bodies. |
| `src/commands/tag.rs` unit tests | Positional orders, surplus operands, and publication without clobbering concurrent changes. |
| [`tests/native/lifecycle_spec.sh`](../../tests/native/lifecycle_spec.sh) | Update preservation of opaque bodies and refusal of unbalanced tag edits. |
| [`tests/native/navigation_spec.sh`](../../tests/native/navigation_spec.sh) | Rejection of the removed typed listing mode. |
| [`tests/native/coverage_spec.sh`](../../tests/native/coverage_spec.sh) | Reference buckets and strict status. |

Remaining legacy tag scenarios are tracked in the
[native regression inventory](../../tests/native/README.md).

## Verification

```bash
cargo test --locked
bash tests/run.sh
```

## References

- [`docs/tag.md`](../../docs/tag.md)
- [`docs/coverage.md`](../../docs/coverage.md)
- [`update.md`](update.md)
