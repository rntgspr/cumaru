---
name: markdown-heading-map-command
description: Add a read-only cumaru map command that projects level-two headings by file under a validated path
status: completed
priority: medium
---

# Issue 041: Add `cumaru map`

Agents can approximate a Markdown section map with:

```bash
rg '^## ' -g '*.md' .cumaru/
```

That bypasses Cumaru's path containment, symlink rejection, deterministic
rendering, domain and pillar filters, and Markdown-aware handling. A native
`cumaru map` command should expose the same fast structural view through the
framework's read-only navigation contract.

## Risk

- Raw recursive search can read unsafe paths, follow an unintended scope, or
  include headings from fenced examples and other non-document content.
- Treating `map` paths like `tree` paths would produce surprising results for a
  Markdown file: `tree` intentionally maps a file to its parent directory,
  while `map` must inspect that exact file.
- Unstable ordering or mixed diagnostics can make the result unsafe for piping
  into agent workflows.

## Required invariant

`cumaru map` is a read-only, deterministic projection of level-two ATX headings
from regular Markdown files inside `.cumaru/`. It shares `tree`'s target
validation, containment, symlink, filter, stream, and exit-status discipline,
but has a deliberately different target meaning:

| Target | `cumaru tree` | `cumaru map` |
|---|---|---|
| omitted | list root candidates | recursively map headings under `.cumaru/` |
| directory | list its candidates; shallow unless `--deep` | recursively map headings below that directory |
| Markdown file | normalize to its parent directory | inspect only that exact file |

## Work

1. Add `src/cmd_map.sh` and dispatch `cumaru map` from the main CLI.
2. Support this public surface:

   ```text
   cumaru map [<directory-or-md>] [--rows]
              [--pillars <name[,name...]>] [--domain <name>]
   ```

3. Reuse or extract `tree`'s target syntax, canonical containment, control
   character, symlink, `--pillars`, and `--domain` validation instead of
   creating a weaker parallel implementation.
4. Treat a directory as a recursive search scope and a Markdown target as one
   exact file. Reject absolute paths, `..`, hidden path components, missing
   targets, and non-Markdown file targets before reading bodies.
5. Emit level-two ATX heading lines beginning with `## ` using literal
   `rg '^## '` semantics when ripgrep is available; otherwise fall back to
   `find` plus `awk`.
6. Render deterministic `rg -n`-compatible `path:line:## heading` output.
   `--rows` emits `path<TAB>line<TAB>heading` with no header. Sort by path under
   `LC_ALL=C` and retain source line order within each file.
7. Keep diagnostics on stderr and emit valid rows before returning nonzero when
   a recursive walk encounters one or more defects.
8. Add `cumaru map --help`, top-level help, `docs/map.md`, architecture and
   navigation documentation, and the complete domain-neutral CLI map.

## Tests

- With no target, the command recursively emits every valid level-two heading
  under `.cumaru/`, grouped deterministically by path and source line.
- A directory target emits only descendants of that directory; a Markdown
  target emits only headings from that file and never headings from siblings.
- A paired regression proves the path distinction: `cumaru tree specs/auth.md`
  lists `specs/` candidates while `cumaru map specs/auth.md` reads only
  `specs/auth.md`.
- Hidden descendants and non-Markdown files are not emitted; ripgrep mode
  intentionally retains its literal matching behavior for fenced code.
- `--pillars`, `--domain`, and `--rows` compose with file and directory targets
  and preserve the same validation semantics as `tree`.
- Absolute, escaping, missing, control-character, and symlink targets fail
  without reading outside `.cumaru/` or mutating any project path.
- The default `rg -n`-compatible output and TSV output keep diagnostics on
  stderr.
- `cumaru map --help` succeeds outside an installed project.

## References

- `src/cmd_tree.sh`
- `src/cmd_help.sh`
- `cumaru`
- `docs/tree.md`
- `.memory/specs/navigation.md`
- `tests/spec/cli/tree_spec.sh`
- `tests/spec/contracts/documented_contracts_spec.sh`
