# `cumaru get`

Print selected line ranges of Markdown files under `.cumaru/` without changing
the tree. It pairs with [`cumaru map`](map.md): `map` reports each section's
start and end lines; `get` reads only those lines. It is read-only, offline,
and atomic.

## Usage

```text
cumaru get <path[:range]>...
```

Paths are relative to `.cumaru/` and follow the `map` safety rules. The range
syntax follows `git log -L` and `sed` line addresses:

| Selector | Lines |
|---|---|
| `path` | whole file |
| `path:N` | line `N` |
| `path:N,M` | `N` through `M` |
| `path:N,` or `path:N,$` | `N` through the end of the file |
| `path:,M` | 1 through `M` |
| `path:N,+K` | `N` and the `K` lines below |
| `path:N,-K` | `N` and the `K` lines above |

Leading and trailing blank lines are trimmed from each selection (an all-blank
selection is kept). Every selector prints, in argument order, a header with
the resolved, trimmed range, then its lines verbatim; blocks are separated by
a blank line. The same file may repeat, and overlaps print as requested.

```text
==> specs/auth.md:18,42 <==
## Session lifecycle
...
```

## Failures

Every selector is validated before anything is printed; one failure prints a
single diagnostic on stderr and no output.

| Condition | Status |
|---|---:|
| Malformed range (`path:`, `path:,`, `path:,+K`, `0`), reversed range, line past EOF, or empty file | `2` |
| Unsafe path, non-Markdown target, unreadable or non-UTF-8 file | `1` |
| Output over the 32768-byte budget | `1` |

## Examples

```bash
cumaru map specs/auth.md
cumaru get specs/auth.md:18,42
cumaru get specs/update.md:12,61 specs/tags.md:76,$ disciplines/update_design.md:,17
```

## Related

- [`cumaru map`](map.md) — section start and end lines.
- [`cumaru tree`](tree.md) — candidate and summary navigation.
