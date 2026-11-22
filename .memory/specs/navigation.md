---
name: navigation-specification
description: "Filesystem-backed v9 navigation, summaries, semantic links, and safety contract"
type: project
status: implemented
version: 9
---

# Navigation specification

## Purpose

Project the `.cumaru/` filesystem as a bounded, read-only candidate tree so an
agent can select relevant knowledge from paths and summaries before loading
Markdown bodies.

The [native navigation contract](rust.md#execution) records the detailed
execution of Rust's config-free directory selection, reusable walker, literal
H1-H6 map, and the `get` line-range reader ([`docs/get.md`](../../docs/get.md)).
This specification owns the capability-level invariants.

## Public surface

```text
cumaru tree [<directory-or-md>...] [--deep] [--rows|--markdown]
cumaru map [<directory-or-md>] [--rows|--markdown]
.cumaru/**/index.md
.cumaru/**/*.md summary:
```

## Invariants

1. The filesystem, not index marker rows, defines structural candidates.
2. Every non-hidden directory has a regular `index.md`; each Markdown summary
   is a trimmed string of 32-512 Unicode code points without C0 or DEL
   control characters.
3. Shallow traversal is the default; deep traversal audits all descendants and
   continues after individual defects.
4. Absolute paths, `..`, hidden paths, control characters, non-Markdown file
   targets, all symlinks, and canonical escapes are rejected before body or
   frontmatter reads.
5. Output is deterministic; diagnostics are deduplicated and use stderr only.
6. Navigation never loads `.cumaru/config.yaml`; it has no pillar or domain
   filter.
7. `depends-on` is the strongest candidate signal and `relates` is weaker;
   both remain relevance-prunable.
8. Summary curation is explicitly selected only for `.cumaru` `summary:`
   frontmatter maintenance. General summarization requests do not select it;
   authorized maintenance reuses scope authorization for routine corrections.

## Inputs and ownership

| Input or surface | Owner | Contract |
|---|---|---|
| `.cumaru/` paths | adopter | Structural truth, constrained by v9 safety and index rules. |
| Markdown `summary:` | framework or adopter by file ownership | Stable selection signal, not status metadata. |
| Semantic relation fields/tags | domain and adopter | Domain declares shape; adopter declares links. |
| Tree and map output | runtime | Read-only deterministic TSV or Markdown projection. |

## Execution

### Preflight

1. Clap parses options; every target is syntax-checked before filesystem
   access.
2. Require a real, non-symlink `.cumaru/` directory. No configuration file
   or external YAML or search tool is required.
3. Resolve each target to a directory or exact `.md` file, rejecting symlink
   components and canonical paths outside `.cumaru/`.

### Read-only traversal

1. `tree` accepts several targets, defaulting to the root, and normalizes a
   Markdown target to its parent directory; repeated canonical directories are
   visited once. Shallow mode requires a regular target `index.md` and lists
   direct Markdown files except `index.md` plus indexed child directories.
   Deep mode recursively validates all non-hidden descendants.
2. `map` accepts one optional target. A Markdown target remains one exact
   file; a directory, or the omitted root, is searched recursively for
   non-hidden Markdown descendants without requiring indexes or summaries.
3. `tree` reads only YAML frontmatter to obtain summaries and emits
   `path<TAB>summary` rows, with a trailing `/` on directories. `map` emits
   literal H1-H6 ATX headings with their `#` markers as
   `path:start,end<TAB>title`, where the first field is a `get` selector.
   `--markdown` selects an escaped table; `--rows` explicitly selects TSV.
4. Emit valid candidates or heading rows after path sorting; `map` retains
   numeric source-line order within each file. Aggregate traversal defects and
   return nonzero after the walk without suppressing valid output rows.
5. No lock, staging area, backup, or filesystem mutation is created.

## Failure contract

| Condition | Status | Mutation |
|---|---:|---|
| Unknown or removed option, conflicting output modes, or extra `map` target | `2` | none |
| Missing/symlinked `.cumaru/`, unsafe or missing target, or shallow target without a regular index | `1`, empty stdout | none |
| Invalid summary, unreadable heading file, or deep walk defect | `1` after complete walk; valid rows still emitted | none |

## Implementation map

| Artifact | Responsibility |
|---|---|
| [`src/commands/tree.rs`](../../src/commands/tree.rs) | Arguments, root checks, target-directory deduplication, index/summary parsing, diagnostics, and TSV/Markdown output. |
| [`src/commands/map.rs`](../../src/commands/map.rs) | Exact-file or recursive heading projection, `get` selectors, diagnostics, and TSV/Markdown output. |
| [`src/walk.rs`](../../src/walk.rs) | Contained traversal, file filters, hidden pruning, symlink rejection, deduplication, and filesystem diagnostics. |
| [`src/paths.rs`](../../src/paths.rs) | Target normalization, syntax validation, exact resolution, symlink and containment checks. |
| [`src/markdown.rs`](../../src/markdown.rs) | Frontmatter reading, summary validation, literal heading reading, and table-cell escaping. |
| [`src/tsv.rs`](../../src/tsv.rs) | Tab-separated row writing. |
| [`src/text.rs`](../../src/text.rs) | Control-character detection and diagnostic quoting. |
| [`src/commands/doctor.rs`](../../src/commands/doctor.rs) | Whole-tree summary acceptance through `markdown::validate_summary`. |
| [`src/commands/hooks.rs`](../../src/commands/hooks.rs) | Session-start payload that appends the root `cumaru tree .` projection. |
| [`domains/__base/index.md`](../../domains/__base/index.md) | Kernel loading rule that consumes tree candidates. |

## Principal methods

| Method | Contract |
|---|---|
| `tree::execute` | Validate targets and root, walk once, then emit sorted unique records and diagnostics. |
| `TreeParser::parse` | Interpret directory indexes and file candidates; enforce shallow target indexes and deep missing-index defects. |
| `TreeParser::summary` | Read and validate one frontmatter summary, recording a diagnostic when unusable. |
| `map::execute` | Resolve one scope, read headings from safe files, and emit sorted rows and diagnostics. |
| `walk::Walk::run` | Deliver safe paths to a parser callback without reading content. |
| `paths::validate_target_syntax` | Reject absolute, control-character, `..`, and hidden targets before filesystem access. |
| `paths::resolve_target` | Resolve a safe directory or exact `.md` file inside the root. |
| `markdown::validate_summary` | Enforce the trimmed 32-512 code-point, C0/DEL-free summary contract. |
| `markdown::read_headings` | Read literal H1-H6 headings and their section line ranges. |

## Regression coverage

| Test | Covered behavior |
|---|---|
| [`tests/native/navigation_spec.sh`](../../tests/native/navigation_spec.sh) | Shallow/deep tree rows, file-parent and overlapping targets, summary length limits, unsafe targets, literal map headings and section ends, `get` selections, partial results, and removed legacy options. |
| `src/walk.rs` unit tests | Markdown filtering, overlapping-target deduplication, and symlink rejection before parsing. |
| `src/commands/doctor.rs` unit tests | Installed-tree summary validation. |
| [`tests/spec/contracts/summarize_artifacts_spec.sh`](../../tests/spec/contracts/summarize_artifacts_spec.sh) | Universal summary-curation artifact contract. |

Remaining legacy tree/map scenarios and their disposition are tracked in the
[native regression inventory](../../tests/native/README.md).

## Differences from the retired Bash CLI

- `--pillars` and `--domain` were intentionally removed, not left unowned, and
  are rejected as usage errors; navigation no longer reads configuration.
- `tree` accepts several targets; output defaults to TSV with an optional
  Markdown table instead of the former Markdown default.
- `map` lists literal H1-H6 headings with markers and `get` selectors instead
  of level-two headings in `rg -n` form, and spawns no external search tool.
- Summaries reject every C0/DEL control character, not only CR, LF, and tab.

## Verification

```bash
cargo test --locked
bash tests/run.sh
```

## References

- [`../../docs/tree.md`](../../docs/tree.md)
- [`../../docs/map.md`](../../docs/map.md)
- [`rust.md`](rust.md#execution)
- [`../../docs/architecture.md`](../../docs/architecture.md)
- [`architecture.md`](architecture.md)
- [`agent-adapters.md`](agent-adapters.md)
