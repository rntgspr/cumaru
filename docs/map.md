# `cumaru map`

List literal H1-H6 Markdown headings under `.cumaru/` without changing the
tree. It complements `cumaru tree`: `tree` lists candidate summaries; `map`
lists the sections inside a selected scope. It is read-only, offline, and
needs no configuration, index, or summary.

## Usage

```text
cumaru map [<directory-or-md>] [--rows|--markdown]
```

One optional target defaults to the root. A directory is searched recursively;
a Markdown target is mapped exactly, unlike `cumaru tree`, which normalizes a
Markdown target to its parent directory.

The default output is TSV, `path<TAB>line<TAB>title`, keeping each heading's
`#` markers (`--rows` selects it explicitly):

```text
specs/auth.md<TAB>18<TAB>## Session lifecycle
```

`--markdown` emits an escaped Path/Line/Title table instead and conflicts with
`--rows`.

A heading is a line starting at column zero with one to six `#` characters
followed by a space, tab, or end of line. Matching is literal: headings inside
fenced code blocks and heading-shaped frontmatter lines are listed; setext and
indented headings are not. CRLF is accepted. Hidden descendants are ignored.
Results are sorted by path, then numeric line. No match is success.

Absolute paths, `..`, symlinks, hidden target components, control-character
paths, and non-Markdown file targets are rejected. Recursive traversal reports
every unsafe descendant on stderr, still emits rows from safe Markdown files,
and exits `1`.

## Examples

```bash
cumaru map
cumaru map specs/auth.md
cumaru map specs --markdown
```

## Related

- [`cumaru tree`](tree.md) — candidate and summary navigation.
- [`cumaru tag`](tag.md) — inspect or edit declared semantic blocks.
