---
name: coverage-specification
description: "Current v7 contract for read-only source-to-specification reference coverage."
type: project
status: implemented
version: 7
---

# Coverage specification

## Purpose

`cumaru coverage` compares Git-tracked source files with `reference` rows hosted
under the configured durable specification pillar. It reports gaps and malformed
or out-of-scope references without modifying either source or specifications.

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
   and empty rows are skipped before host filtering.
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
| `meta.specification_dir` | adopter | Selects the durable pillar; defaults to `specs` when empty. |
| `meta.coverage.source` | adopter | Optional array of Bash fnmatch-style globs; `*` crosses `/`. |
| `reference` tag bodies | adopter | Valid `[Link, Description]` rows maintained through Cumaru tag/refs workflows. |

## Execution

### Preflight

1. Require `.cumaru/`, `config.yaml`, the selected specification directory,
   and a Git work tree.
2. Read source globs, enumerate tracked files, and enumerate parsed reference
   rows through the shared tag machinery.

### Dry-run

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
| Missing tree, config, specification pillar, or Git work tree | `1` | none |
| `--strict` with uncovered/stale/invalid | `1` | none |
| Successful report, including foreign-only gaps | `0` | none |

## Implementation map

| Script or artifact | Responsibility |
|---|---|
| [`../../src/cmd_coverage.sh`](../../src/cmd_coverage.sh) | Source inventory, filtering, bucket adjudication, rendering, and strict status. |
| [`../../src/common.sh`](../../src/common.sh) | Shared reference-row parsing and target resolution. |
| [`../../src/cmd_tag.sh`](../../src/cmd_tag.sh) | Reference tag read/write primitive. |
| [`../../domains/__base/skills/cumaru-refs/SKILL.md`](../../domains/__base/skills/cumaru-refs/SKILL.md) | Gap-remediation workflow. |

## Principal methods

| Method | Contract |
|---|---|
| `_coverage_spec_dir` | Read the configured durable specification directory. |
| `_coverage_source_globs` | Emit block or inline source globs one per line. |
| `_coverage_source_files` | Emit sorted unique tracked candidates after exclusions and glob filtering. |
| `cmd_coverage` | Validate mode, classify rows, render output, and enforce strict status. |
| `fm_tag_table_rows` | Emit normalized reference rows and resolution statuses. |

## Regression coverage

| Test | Covered behavior |
|---|---|
| [`../../tests/spec/cli/coverage_spec.sh`](../../tests/spec/cli/coverage_spec.sh) | Report, refs, gaps, rows, strict, all buckets, globs, exclusions, row rotation, and runtime guards. |
| [`../../tests/spec/cli/doctor_spec.sh`](../../tests/spec/cli/doctor_spec.sh) | Retained reference validation and shared row processing. |

## Verification

```bash
shellspec tests/spec/cli/coverage_spec.sh
bash tests/run.sh
```

## References

- [`../../docs/coverage.md`](../../docs/coverage.md)
- [`../../docs/tag.md`](../../docs/tag.md)
- [`tags.md`](tags.md)
