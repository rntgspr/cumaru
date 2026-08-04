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

When `rg` is available, `map` uses it directly for fast literal `^## ` matching;
otherwise it falls back to `find` plus `awk`. Therefore headings in fenced code
blocks are also listed when `rg` is used. Hidden descendants are ignored.
Absolute paths, `..`, symlinks, hidden target components, and non-Markdown file
targets are rejected. `--pillars` and `--domain` use the same installed-config
filters as `cumaru tree`.

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
