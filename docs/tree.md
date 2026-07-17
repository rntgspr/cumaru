# `cumaru tree`

List the filesystem-backed candidates below a `.cumaru/` directory and read
their one-line selection summaries. The command is read-only and never follows
symlinks.

## Usage

```text
cumaru tree [<directory-or-md>] [--deep] [--rows]
            [--pillars <name[,name...]>] [--domain <name>]
```

Paths are relative to `.cumaru/`. Omit the target to inspect the root. A
Markdown file target is normalized to its parent, so `cumaru tree
specs/auth.md` lists the same directory as `cumaru tree specs/`.

Absolute paths, `..` segments, hidden target paths, missing targets, and
non-Markdown file targets are rejected. Hidden means any path segment whose
basename starts with `.`.

## Schema Filters

`--pillars <name[,name...]>` restricts root navigation to pillars declared in
the installed `.cumaru/schema.yaml`. With an explicit target, that target must
be inside one of the selected pillars. Unknown names, empty comma entries, and
targets outside the selection fail without emitting candidate rows.

`--domain <name>` is a guard: it requires the installed schema's `domain:` to
match the requested name. It does not load or switch to another domain source.
Both filters compose with `--deep` and `--rows`; omitting them preserves the
unfiltered behavior.

```bash
cumaru tree --pillars plans,specs --rows
cumaru tree specs --pillars specs --deep
cumaru tree --domain sdlc-full --pillars archive --rows
```

## Shallow Navigation

Shallow mode is the default. The target directory must have a regular
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
returns nonzero after the walk.

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

The default is a deterministic Markdown table:

```text
| Path | Summary |
|---|---|
| specs/auth/ | Authentication behavior and session lifecycle contracts. |
```

Pipes and backslashes are escaped in Markdown output. `--rows` emits stable
TSV with no header:

```text
specs/auth/<TAB>Authentication behavior and session lifecycle contracts.
```

Sorting uses `LC_ALL=C`. Diagnostics are written only to stderr, so `--rows`
can be piped safely. Candidate paths containing control characters are rejected.

## Summary Contract

Each candidate summary is read only from YAML frontmatter with
mikefarah/yq's `--front-matter=extract` mode. Markdown bodies are not loaded.
`summary` must be:

- A YAML string.
- Trimmed.
- Free of carriage returns, line feeds, and tabs.
- Between 32 and 256 Unicode code points, inclusive.

Missing, non-mikefarah, or incompatible `yq` is a hard runtime error.

## Symlink Safety

The `.cumaru/` root, explicit target, every target component, and every
discovered descendant must be real filesystem entries, not symlinks. Broken,
cyclic, in-tree, and escaping symlinks are all rejected before frontmatter is
read. Every candidate is canonicalized and checked for containment inside
`.cumaru/` before its summary is loaded.

## Exit Codes

- `0` - success.
- `1` - runtime, safety, or tree validation error.
- `2` - usage error.

`cumaru tree --help` works outside a project and does not require `.cumaru/` or
`yq`.
