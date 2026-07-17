---
human_revised: false
version: 1
name: cumaru-refs
description: Use this skill whenever the user wants to work spec↔code coverage in a Cumaru project — find source files no spec references, wire code files into spec `reference` tables, or audit existing references. Trigger on phrases like "run coverage", "spec coverage", "which files lack specs", "o que não está coberto", "add reference rows", "map code to specs", "traceability", "rastreabilidade", or after `cumaru coverage` reports gaps. The CLI report is `cumaru coverage`; this skill carries the reconciliation recipe.
summary: Use this skill whenever the user wants to work spec↔code coverage in a Cumaru project — find source files no spec references, wire code files into spec `reference` tables, or audit existing references. Trigger on phrases like "run coverage", "spec coverage", "which files lack specs", "o que não está coberto", "add reference rows", "map code to specs", "traceability", "rastreabilidade", or after `cumaru coverage` reports gaps. The CLI report is `cumaru coverage`; this skill carries the reconciliation recipe.
---

# `cumaru-refs` — spec↔code reference coverage

Maintains the `<!-- cumaru:reference -->` tables that map spec files to the
repository source files they cover, and closes the gaps `cumaru coverage`
reports. Universal: works on any domain — the durable pillar comes from
`meta.specification_dir` in `schema.yaml` (`specs`, `topology`, `coverage`,
…; default `specs`).

## The reference rule (canon)

Every row of a `reference` block targets a **repository source file**:

```markdown
<!-- cumaru:reference -->
| Link                              | Description                              |
|-----------------------------------|------------------------------------------|
| [util/logger](src/util/logger.ts) | Util used to log, terminal only          |
<!-- /cumaru:reference -->
```

- The Link path is resolved from the **project root** (the parent of `.cumaru/`)
  — never a path inside `.cumaru/`, never a directory, never a URL or anchor.
- A source file referenced by at least one row is **covered** by the
  specification; a source file referenced by none is **uncovered**.
- The Description is one line of prose about what the file does — written
  after reading the file, never invented.

## Invocation

```bash
cumaru coverage             # full report: refs, covered, uncovered, stale, invalid
cumaru coverage --refs      # every reference row, grouped by spec file
cumaru coverage --gaps      # only uncovered source files (pipeable)
cumaru coverage --rows      # TSV for tooling: bucket, path, spec_host, detail
cumaru coverage --strict    # exit 1 on any gap — CI gate
```

Source files come from `git ls-files`, narrowed by the `meta.coverage.source`
glob array in `schema.yaml` (`*` crosses `/`; empty = every tracked file;
`.cumaru/` and `.agents/` always excluded).

## Reconciliation recipe

Bash is **mechanical** (`cumaru coverage` discovers and reports); **the LLM
(you) adjudicates** each finding:

| Finding | How to reconcile |
|---|---|
| `uncovered` — source file with no row | (a) an existing spec file already describes this area → **read the source file**, then add a row to that spec's `reference` block; OR (b) no spec covers the area → propose a new spec entity (use the domain's spec skill, e.g. `cumaru-specs`/`cumaru-topology`/`cumaru-coverage`), then reference the file there; OR (c) the file isn't coverable source (asset, config, generated) → propose narrowing `meta.coverage.source` in `schema.yaml` instead of forcing a row. |
| `stale` — row points at a missing file | (a) file was renamed/moved → fix the row's path (check `git log --diff-filter=R` or search by basename); OR (b) file was deleted → drop the row, and consider whether the spec prose needs the same trim. |
| `invalid` — row breaks the source-file rule | Rewrite the target as a project-root-relative path to a real file. A directory target must be expanded into per-file rows (or dropped). `.cumaru/` paths belong in other tags, never in `reference`. |
| `foreign` — target exists but outside source scope | Either the file should count as source → widen `meta.coverage.source`; or the row is intentional documentation of an untracked artifact → leave it (foreign is informational). |

Writing rows — always through the CLI so the block stays canonical:

```bash
cumaru tag <spec-file> get reference        # current body
cat <<'EOF' | cumaru tag <spec-file> set reference
| Link | Description |
|------|-------------|
| [util/logger](src/util/logger.ts) | Util used to log, terminal only |
EOF
```

`cumaru tag set` replaces the whole body: fetch the current body first, append
the new rows, and write the union back.

## Workflow

1. Run `cumaru coverage` and read the summary.
2. Group the uncovered files by the spec entity that should own them; present
   the proposal (which rows land in which spec file) before writing.
3. For each spec file, read the affected source files, write the rows via
   `cumaru tag set`, one spec file at a time.
4. Handle `stale` and `invalid` rows per the table above.
5. Re-run `cumaru coverage` (and `cumaru doctor` — its file-reference check also
   validates reference rows) to confirm the gaps closed.

## What this skill does NOT do

- **Write spec prose.** Bootstrapping or deepening a spec entity belongs to
  the domain's spec skill; this skill only maintains the reference tables.
- **Decide coverage policy.** Whether a file deserves a spec is the adopter's
  call — surface the gap, propose, confirm.
- **Touch git.** `git ls-files` and history lookups are read-only.
