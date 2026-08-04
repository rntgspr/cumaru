---
name: navigation-specification
description: "Filesystem-backed v7 navigation, summaries, semantic links, and safety contract"
type: project
status: implemented
version: 7
---

# Navigation specification

## Purpose

Project the `.cumaru/` filesystem as a bounded, read-only candidate tree so an
agent can select relevant knowledge from paths and summaries before loading
Markdown bodies.

## Public surface

```text
cumaru tree [<directory-or-md>] [--deep] [--rows]
            [--pillars <name[,name...]>] [--domain <name>]
cumaru map [<directory-or-md>] [--rows]
           [--pillars <name[,name...]>] [--domain <name>]
.cumaru/**/index.md
.cumaru/**/*.md summary:
```

## Invariants

1. The filesystem, not index marker rows, defines structural candidates.
2. Every non-hidden directory has a regular `index.md`; each Markdown summary
   is a trimmed string of 32-512 Unicode code points without CR, LF, or tab.
3. Shallow traversal is the default; deep traversal audits all descendants and
   continues after individual defects.
4. Absolute paths, `..`, hidden paths, non-Markdown file targets, all symlinks,
   and canonical escapes are rejected before body or frontmatter reads.
5. Output is deterministic under `LC_ALL=C`; diagnostics use stderr only.
6. `--pillars` restricts candidates to config-declared pillars; `--domain` is
   an installed-domain guard, never a source switch.
7. `depends-on` is the strongest candidate signal and `relates` is weaker;
   both remain relevance-prunable.

## Inputs and ownership

| Input or surface | Owner | Contract |
|---|---|---|
| `.cumaru/` paths | adopter | Structural truth, constrained by v7 safety and index rules. |
| Markdown `summary:` | framework or adopter by file ownership | Stable selection signal, not status metadata. |
| `.cumaru/config.yaml` pillars/domain | adopter | Validated filter vocabulary and domain guard. |
| Semantic relation fields/tags | domain and adopter | Domain declares shape; adopter declares links. |
| Tree output | runtime | Read-only deterministic Markdown or TSV projection. |

## Execution

### Preflight

1. Parse options and validate target syntax before traversal.
2. Require a real `.cumaru/` root and compatible Mike Farah `yq` except for
   `--help`.
3. Validate requested pillar/domain filters from installed config.
4. Reject symlink components and canonical paths outside `.cumaru/`.

### Read-only traversal

1. `tree` normalizes a Markdown target to its parent directory. Shallow mode
   lists direct Markdown files except `index.md` and indexed child directories.
   Deep mode recursively validates all non-hidden descendants.
2. `map` preserves a Markdown target as one exact file. Directory targets are
   searched recursively for non-hidden Markdown descendants, and an omitted
   target searches the complete `.cumaru/` tree.
3. `tree` reads only YAML frontmatter to obtain summaries. `map` emits level-two
   ATX headings that begin with `## `, using `rg -n`-compatible output by
   default or TSV rows with `--rows`.
4. Emit valid candidates or heading rows after C-locale sorting; aggregate
   recursive traversal defects and return nonzero after the walk.
5. No lock, staging area, backup, or filesystem mutation is created.

## Failure contract

| Condition | Status | Mutation |
|---|---:|---|
| Unknown option or malformed invocation | `2` | none |
| Missing target/index, invalid summary, filter mismatch, or unsafe path | `1` | none |
| Missing/incompatible `yq` | `1` | none |
| Deep walk with one or more defects | `1` after complete walk | none |

## Implementation map

| Script or artifact | Responsibility |
|---|---|
| `src/cmd_tree.sh` | Parsing, safety, traversal, summaries, filtering, and output. |
| `src/cmd_map.sh` | Read-only level-two heading projection with shared path and filter validation. |
| `src/common.sh` | Shared config/frontmatter and path constants. |
| `src/cmd_doctor_checks.sh` | Whole-tree navigation and summary acceptance checks. |
| `domains/__base/index.md` | Kernel loading rule that consumes tree candidates. |
| `src/agent_adapter.sh` | Session-start root projection where supported. |

## Principal methods

| Method | Contract |
|---|---|
| `cmd_tree` | Parse, validate, traverse, and emit without mutation. |
| `cmd_map` | Recursively map headings, or map one exact Markdown target, without mutation. |
| `_tree_validate_target_syntax` | Reject unsafe or unsupported target forms. |
| `_tree_canonicalize` | Resolve and prove containment without accepting symlinks. |
| `_tree_summary` | Read and validate one summary from frontmatter. |
| `_tree_walk_shallow` | Emit direct valid candidates only. |
| `_tree_walk_deep` | Audit recursively while accumulating defects. |
| `_tree_validate_filters` | Resolve pillar restrictions and installed-domain guard. |

## Regression coverage

| Test | Covered behavior |
|---|---|
| `tests/spec/cli/tree_spec.sh` | Targets, modes, summaries, sorting, filters, streams, and symlink safety. |
| `tests/spec/cli/map_spec.sh` | Heading output, exact file targets, fenced-code exclusion, and path safety. |
| `tests/spec/cli/doctor_spec.sh` | Complete installed inventory and summary validation. |
| `tests/spec/integration/agent_adapters_spec.sh` | Bootstrap instructions and SessionStart projection. |
| `tests/spec/contracts/summarize_artifacts_spec.sh` | Universal summary-curation artifact contract. |

## Verification

```bash
shellspec tests/spec/cli/tree_spec.sh
bash tests/run.sh
```

## References

- [`../../src/cmd_tree.sh`](../../src/cmd_tree.sh)
- [`../../docs/tree.md`](../../docs/tree.md)
- [`../../docs/architecture.md`](../../docs/architecture.md)
- [`architecture.md`](architecture.md)
- [`agent-adapters.md`](agent-adapters.md)
