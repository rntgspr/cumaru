---
name: coverage-specification
description: "Current contract for read-only source-to-specification reference coverage."
type: project
status: implemented
version: 9
---

# Coverage specification

## Purpose

`cumaru coverage` compares Git-tracked source files with `reference` rows hosted
under the configured durable specification pillar. It reports gaps and malformed
or out-of-scope references without modifying either source or specifications.

The [native coverage contract](rust.md#native-coverage) records the detailed
guard order, shared reference parser, configured physical directory resolution,
malformed-host diagnostics, and offline verification.

## Public surface

```text
cumaru coverage [--refs|--gaps|--rows] [--strict]
.cumaru/config.yaml: meta.specification_dir
.cumaru/config.yaml: meta.coverage.source
<!-- cumaru:reference -->
```

## Invariants

1. Source inventory comes from `git ls-files`; the command requires a Git work
   tree and is read-only.
2. Reference targets are project-root-relative repository source files, never
   `.cumaru/` paths, directories, absolute paths, URLs, or anchors.
3. Only reference rows hosted below `meta.specification_dir` count; template
   and empty rows are skipped before host filtering. The value is one pillar
   name or a non-empty list of unique names; a list counts rows hosted below
   any of them, and every listed pillar must resolve to an existing configured
   directory. Accepting a list was additive: no `version` change or snapshot.
4. `--strict` fails only when uncovered, stale, or invalid entries exist;
   foreign entries are informational.

## Buckets

| Bucket | Contract |
|---|---|
| `covered` | Tracked in-scope source file targeted by at least one valid row. |
| `uncovered` | Tracked in-scope source file targeted by no valid row. |
| `stale` | Row target is syntactically admissible but missing on disk. |
| `invalid` | Row violates the source-file rule. |
| `foreign` | Existing row target is untracked or filtered out of source scope. |

## Modes

| Mode | Output |
|---|---|
| default report | References, bucket counts/details, outside-host notice, and summary. |
| `--refs` | Reference rows grouped by specification host. |
| `--gaps` | Uncovered paths only, one per line. |
| `--rows` | TSV `bucket\tpath\tspec_host\tdetail`. |
| `--strict` | Modifier for any mode; status 1 on uncovered/stale/invalid. |

## Inputs and ownership

| Input or surface | Owner | Contract |
|---|---|---|
| Git index | repository | Defines tracked candidates through `git ls-files`. |
| `meta.specification_dir` | adopter | Selects the durable pillar; defaults to `specs`. V9 resolves each logical name through `path` overrides; an undeclared or wildcard name fails. |
| `meta.coverage.source` | adopter | Optional array of globs; `*` crosses `/`, leading dots match, and no backslash escapes or extglob are supported. |
| `reference` tag bodies | adopter | Valid `[Link, Description]` rows maintained through Cumaru tag/refs workflows. |

## Execution

### Preflight

1. Require `.cumaru/`, `config.yaml`, a config that passes the embedded
   schema, the selected specification directory, and a Git work tree, in that
   order. Each failure prints one diagnostic on stderr with empty stdout.
2. Read source globs, enumerate tracked files through read-only `git ls-files`,
   and enumerate reference rows from safe Markdown hosts through the shared
   walker, balanced tag parser, and reference row parser.

### Read-only reports

All modes are reports and perform no writes, locks, staging, backups, Git index
changes, or tag mutations.

### Apply

There is no apply mode. The separate `cumaru-refs` skill adjudicates and edits
reference rows.

## Exclusion behavior

The current source inventory always excludes tracked paths under `.cumaru/`,
`.agents/`, `.claude/`, and `.opencode/`, plus root `AGENTS.md`, `CLAUDE.md`,
`opencode.json`, and `opencode.jsonc`. Remaining paths are optionally narrowed
by `meta.coverage.source`; empty globs mean every remaining tracked file.

## Known gap

`.codex/` is not present in the implementation's unconditional exclusion list.
The intended treatment is ambiguous; this specification records the gap and
does not claim exclusion or prescribe a change.

## Failure contract

| Condition | Status | Mutation |
|---|---:|---|
| Unknown/multiple output modes | `2` | none |
| Missing tree, config, or specification pillar, invalid config or glob, or non-Git project | `1`, empty stdout | none |
| Malformed host or traversal defect | `1` after the report; defects on stderr | none |
| `--strict` with uncovered/stale/invalid | `1` | none |
| Successful report, including foreign-only gaps | `0` | none |

## Implementation map

| Script or artifact | Responsibility |
|---|---|
| [`../../src/commands/coverage.rs`](../../src/commands/coverage.rs) | Guards, source inventory, exclusions/globs, bucket adjudication, rendering, and strict status. |
| [`../../src/references.rs`](../../src/references.rs) | Reference-row parsing and target resolution shared with doctor. |
| [`../../src/commands/tag.rs`](../../src/commands/tag.rs) | Reference tag read/write primitive used by the refs workflow. |
| [`../../domains/__base/skills/cumaru-refs/SKILL.md`](../../domains/__base/skills/cumaru-refs/SKILL.md) | Gap-remediation workflow. |

## Principal methods

| Method | Contract |
|---|---|
| `coverage::specification_dirs` | Resolve the configured durable specification directories. |
| `coverage::source_globs` | Compile optional `meta.coverage.source` patterns. |
| `coverage::tracked_files`, `coverage::source_files` | Emit tracked candidates after exclusions and glob filtering. |
| `coverage::reference_rows` | Collect rows from innermost `reference` blocks in safe hosts. |
| `coverage::classify`, `coverage::render` | Assign buckets and render each mode. |
| `references::table_row`, `references::resolve` | Parse normalized rows and apply the source-file rule. |

## Regression coverage

| Test | Covered behavior |
|---|---|
| `src/commands/coverage.rs` unit tests | Row parsing, innermost-block attribution, target statuses, exclusions with `.codex/`, globs, specification directories, and bucket rendering. |
| [`../../tests/native/coverage_spec.sh`](../../tests/native/coverage_spec.sh) | Every bucket, strict status, mode conflict, and byte preservation. |
| `src/commands/doctor.rs` unit tests | Retained reference validation through the shared parser. |

Remaining legacy coverage scenarios are tracked in the
[native regression inventory](../../tests/native/README.md).

## Differences from the retired Bash CLI

- Invalid configs fail through the embedded-schema gate, and an undeclared or
  wildcard `meta.specification_dir` fails instead of silently falling back to
  `specs`.
- Malformed tag hosts and walker defects (symlinks; hidden entries are pruned)
  are reported after the projection with status 1, where the awk reader parsed
  leniently and `find` included hidden or linked files.
- Table separators may use alignment colons; rows after a nested
  non-reference block remain in the reference body.
- Ordering is byte order rather than locale `sort`; globs do not support
  backslash escapes or extglob.
- Direct symlink and special-file targets are invalid, and syntactic
  `.cumaru/` paths are invalid even when missing.
- Report text matches the former output without ANSI colors, and `.codex/`
  stays coverable as before ([Known gap](#known-gap)).

## Verification

```bash
cargo test --locked
bash tests/run.sh
```

## References

- [`../../docs/coverage.md`](../../docs/coverage.md)
- [`../../docs/tag.md`](../../docs/tag.md)
- [`tags.md`](tags.md)
