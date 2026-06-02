# `cumaru coverage`

Report which repository source files are referenced by the durable
specification pillar — and which are not. Read-only: builds the source list
from `git ls-files`, reads `<!-- cumaru:reference -->` tables from spec files,
and prints the diff. Closing the gaps is the `cumaru-refs` skill's job
(`/cumaru:refs` orchestrates it).

## The model

Spec files under the durable pillar carry `reference` blocks — ordinary v4
`[Link, Description]` tables with one extra rule, hardcoded like the table
shape itself:

> **Every `reference` row targets a repository SOURCE FILE, resolved from the
> project root** (the parent of `.cumaru/`) — never a path inside `.cumaru/`, never
> a directory, never an absolute path, a URL, or an anchor.

```markdown
<!-- cumaru:reference -->
| Link                              | Description                     |
|-----------------------------------|---------------------------------|
| [util/logger](src/util/logger.ts) | Util used to log, terminal only |
<!-- /cumaru:reference -->
```

A source file referenced by at least one row is **covered** by the
specification; a source file referenced by none is **uncovered** — no spec
describes it.

## Usage

```
cumaru coverage [--refs|--gaps|--rows] [--strict]
```

| Mode / flag | Description |
|---|---|
| *(default)* | Full report: refs, covered, uncovered, stale, invalid, summary. |
| `--refs` | List every reference row, grouped by spec file (same view `cumaru tag all` gives indexes). |
| `--gaps` | Only uncovered source files, one per line — pipeable. |
| `--rows` | Machine-readable TSV: `bucket<TAB>path<TAB>spec_host<TAB>detail`. |
| `--strict` | Exit 1 when any uncovered/stale/invalid entry exists — CI gate. |

## Schema attributes (`meta` section)

| Attribute | Default | Description |
|---|---|---|
| `specification_dir` | `specs` | Which pillar holds the durable specification whose `reference` tables count. Domains ship it preset: `specs` (sdlc), `topology` (iac-basic), `coverage` (qa-basic). |
| `coverage.source` | `[]` (everything) | Array of fnmatch-style globs narrowing which tracked files count as coverable source (`*` crosses `/`, so `src/**` ≡ `src/*`). `.cumaru/` and `.agents/` are always excluded. |

Both are adopter-owned values, like `meta.apps.values`.

## Buckets

| Bucket | Meaning | Where else it surfaces |
|---|---|---|
| `covered` | Source file with ≥1 reference row. | — |
| `uncovered` | Source file with no reference row. | — |
| `stale` | Row points at a file that no longer exists. | `cumaru doctor` check 5 (missing) |
| `invalid` | Row breaks the source-file rule (`.cumaru/` path, directory, absolute path, URL, anchor). | `cumaru doctor` check 5 (invalid) |
| `foreign` | Row target exists but is outside the source scope (untracked or filtered by `coverage.source`). Informational. | — |

Rows with `template` placeholders (`<...>`) or empty bodies are skipped —
starter files don't pollute the report. Reference rows hosted outside the
specification pillar are ignored (counted in a notice line).

## Requirements

A **git work tree** — the source list is `git ls-files` (tracked files only),
so `.gitignore` is respected for free. Read-only; nothing is written.

## Examples

```bash
cumaru coverage                     # full report
cumaru coverage --refs              # what does each spec reference?
cumaru coverage --gaps | head       # the to-do list, pipeable
cumaru coverage --strict            # CI gate: exit 1 on any gap
cumaru coverage --rows | awk -F'\t' '$1 == "stale"'
```

## Related

- `cumaru-refs` skill / `/cumaru:refs` command — the reconciliation recipe: adjudicate uncovered files, write rows via `cumaru tag set`, fix stale/invalid rows.
- [`cumaru tag`](tag.md) — reads/writes the `reference` blocks (`cumaru tag <spec-file> get|set reference`).
- [`cumaru doctor`](doctor.md) — check 5 validates every reference row's target on disk.
