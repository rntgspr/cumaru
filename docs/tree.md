# `cumaru tree`

List the filesystem-backed candidates below one or more `.cumaru/` directories
and read their one-line selection summaries. The command is read-only, offline,
needs no configuration, and never follows symlinks.

## Usage

```text
cumaru tree [<directory-or-md>...] [--deep] [--rows|--markdown]
```

Paths are relative to `.cumaru/`. Omit every target to inspect the root. Pass
several targets as separate arguments, such as `cumaru tree plans specs`;
commas are literal path characters, not separators. A Markdown file target is
normalized to its parent, so `cumaru tree specs/auth.md` lists the same
directory as `cumaru tree specs/`. Overlapping targets are visited once.

Absolute paths, `..` segments, hidden target paths, missing targets, and
non-Markdown file targets are rejected. Hidden means any path segment whose
basename starts with `.`. Navigation is independent of domain and config
declarations; there are no pillar or domain filters.

## Shallow Navigation

Shallow mode is the default. Each target directory must have a regular
`index.md`. The command lists:

- Direct non-hidden Markdown files other than `index.md`.
- Direct non-hidden directories that have a regular `<child>/index.md`.

A child directory without an index is not a shallow candidate. Use `--deep`
to audit missing indexes. Directory paths end in `/`; file paths retain `.md`.
Every path is relative to `.cumaru/`.

## Deep Inspection

`--deep` recursively inspects every non-hidden Markdown descendant. It keeps
walking through directories with missing indexes and files with invalid
summaries, emits every valid candidate, reports every defect on stderr, and
returns `1` after the walk.

Every non-hidden directory, including the target, is checked for `index.md`.
An `index.md` represents its directory and is never emitted as a separate
file. The target directory itself is not emitted.

## Cross-reference discovery

Use tree traversal when a task may affect behavior outside its declared scope.
Empty `depends-on:` and `relates:` values are absence of declared edges, not
evidence that a concern is isolated.

```bash
cumaru tree specs/
cumaru tree specs/auth/
cumaru tree specs/auth/ --deep
cumaru tree plans specs --rows
```

Start shallow, select candidates whose summaries match the task, and recurse
only into those directories. Use `--deep` when a selected branch suggests
nested concerns or when auditing coverage, not as the default loading mode.
After selecting a concern file, inspect its semantic `reference` table to find
affected source files and consumers. Report related specs outside the active
scope and uncovered gaps before implementation.

Stop when the latest summaries, names, and domain-declared semantic links add
no relevant candidate. The bounded walk discovers relationships without
bulk-loading Markdown bodies.

## Output

The default is stable TSV with no header (`--rows` selects it explicitly):

```text
specs/auth/<TAB>Authentication behavior and session lifecycle contracts.
```

`--markdown` emits an escaped table instead and conflicts with `--rows`:

```text
| Path | Summary |
|---|---|
| specs/auth/ | Authentication behavior and session lifecycle contracts. |
```

Rows from all targets are combined, sorted by byte order, and deduplicated.
Diagnostics go only to stderr, so TSV can be piped safely.

## Summary Contract

Each candidate summary is read only from YAML frontmatter; reading stops at the
closing fence and Markdown bodies are not loaded. `summary` must be a trimmed
string of 32 to 512 Unicode code points without C0 control or DEL characters.

## Symlink Safety

The `.cumaru/` root, explicit targets, and every discovered descendant must be
real filesystem entries. Symlinks and canonical escapes are rejected before
frontmatter is read.

## Exit Codes

- `0` - success.
- `1` - runtime, safety, or tree validation error; with `--deep`, valid rows
  may still be emitted first.
- `2` - usage error.

`cumaru tree --help` works outside a project.
