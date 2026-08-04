# `cumaru map`

List level-two Markdown headings under `.cumaru/` without changing the tree.
It complements `cumaru tree`: `tree` lists candidate summaries; `map` lists
the sections inside a selected scope.

## Usage

```text
cumaru map [<directory-or-md>] [--rows]
           [--pillars <name[,name...]>] [--domain <name>]
```

The default output matches `rg -n '^## '` style:

```text
specs/auth.md:18:## Session lifecycle
```

`--rows` emits `path<TAB>line<TAB>heading`. A directory is searched
recursively; a Markdown target is mapped exactly, unlike `cumaru tree`, which
normalizes a Markdown target to its parent directory.

`map` requires `rg` and uses it directly for literal `^## ` matching. Headings
in fenced code blocks and heading-shaped frontmatter are therefore listed.
Hidden descendants are ignored. Results are sorted by C-locale path while
headings within each file retain numeric source-line order.

Absolute paths, `..`, symlinks, hidden target components, control-character
paths, and non-Markdown file targets are rejected. Recursive traversal reports
every unsafe descendant, still emits rows from safe Markdown files, and exits
nonzero. Unsafe symlink targets are never read. `--pillars` and `--domain` use
the same installed-config filters as `cumaru tree`.

## Examples

```bash
cumaru map
cumaru map specs/auth.md
cumaru map specs --rows
cumaru map --pillars specs --domain sdlc-full
```

## Related

- [`cumaru tree`](tree.md) — candidate and summary navigation.
- [`cumaru tag`](tag.md) — inspect or edit declared semantic blocks.
