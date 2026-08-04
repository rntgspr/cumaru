# `cumaru tag`

Read, write, and audit `<!-- cumaru:NAME --> ... <!-- /cumaru:NAME -->` tags. **Schema-validated**: `get` and `set` refuse if `<tag>` is not declared for the target file. The mechanical primitive composed by recipe skills (`cumaru-absorb`, `cumaru-explore`, `cumaru-plan`, `cumaru-specs`, `cumaru-intake`) — no skill of its own; semantics fit in this doc plus `cumaru tag --help`.

## Usage

```
cumaru tag                                  list tags declared for the root index.md
cumaru tag all [--body|--rows] list every tag in every .cumaru/*.md
cumaru tag <file>                           list the file's actual tags + schema's expected; flag diffs
cumaru tag [<file>] get <tag>               print the body of <tag>
cumaru tag [<file>] set <tag> [<content>]   replace the body; content positional or stdin
cumaru tag get [<file>] <tag>               equivalent verb-first form
cumaru tag set [<file>] <tag> [<content>]   equivalent verb-first form
```

`<file>` must end in `.md` and is relative to `.cumaru/`. An absolute path is
accepted only when it resolves inside the current `.cumaru/` tree. When omitted,
it defaults to the root `index.md` (`.cumaru/index.md`).

Tag name format: `[a-z][a-z0-9_-]*(:[a-z][a-z0-9_*-]*)*` — colon segments repeat, so deep node-tree names like `plans:plan:handoff:touched` are valid. The `cumaru:` prefix in the file is implicit — pass `specs` or `cumaru:specs`, both resolve to the same.

`<file>` audit mode (`cumaru tag <file>`) shows a diff between what the schema declares for that file and which tags actually exist — tags declared in schema but absent from the file marked `[+]`, and tags present in the file but not declared marked `[✗]`.

## Schema validation

Every `get` / `set` is validated against the schema:
- The tag must be **declared** for the file (root tags, pillar tags, or `meta.tags` with matching `host_file`).
- The set of declared tags comes from the schema walk (`root.tags`, `root.entities.<pillar>.tags`, `meta.tags`).

## Tag bodies

Every tag body is opaque adopter content. Cumaru preserves it byte-for-byte during update. `--rows` reads table-shaped rows when present; it does not impose a body format.

Tag parsing uses balanced stack semantics. Nested tags remain independently
addressable, while reading an outer tag includes the complete nested tag and
its delimiters. `cumaru doctor` warns about valid nesting because it is unusual.
Crossing tags and tags without an exact closing delimiter are invalid; reads,
writes, and update merges fail instead of interpreting the remainder of the file
as tag data.

Reads expose duplicate top-level bodies in document order. Operations that
rewrite the file, including `tag set` and update, consolidate them at the first
occurrence with one blank line. Tag names use the shared grammar enforced by
both commands.

Update preservation is name-based. Tag declarations tell the CLI where a tag is expected, but do not permit update to discard
an undeclared, moved, or opaque local body. Source-only tags retain their
canonical placeholder/scaffold body until the adopter edits them.

```markdown
| Link                          | Description                          |
|-------------------------------|--------------------------------------|
| [name](path/to/index.md)      | one-line prose about the linked file |
```

`list` views show every tag the schema declares alongside what's actually in the file.

## Tree-wide listing

`cumaru tag all` is the canonical tree-wide tag walker.

```bash
# Group every tag by host file.
cumaru tag all

# Dump every tag body.
cumaru tag all --body

# Machine-readable rows for hooks and doctor:
# file<TAB>tag<TAB>link<TAB>description<TAB>target<TAB>status
cumaru tag all --rows
```

`--rows` parses table-shaped rows and resolves links
relative to the file that hosts the tag. Root `index.md` and `domain.md` links
resolve from the project root. Status values are `ok`, `missing`, `removed`,
`external`, `anchor`, `template`, `empty`, and `invalid`. `removed` is valid only
for a `touched` target whose description identifies an intentional removal.

Exception: rows of the `reference` tag resolve from the **project root** (the parent of `.cumaru/`) and must target repository source files. A `reference` row pointing inside `.cumaru/`, at a directory, an absolute path, or a URL resolves to `invalid`. See [`cumaru coverage`](coverage.md).

## Examples

```bash
# List declared tags for the project's root index.md.
cumaru tag

# Audit a specific file's tags against the schema.
cumaru tag specs/index.md

# List every tag under .cumaru/.
cumaru tag all

# Get the components table body (hosted on domain.md).
cumaru tag get domain.md components

# Get a pillar index's table.
cumaru tag get plans/index.md plans
cumaru tag plans/index.md get plans

# Set a body via positional arg (multi-line works with $'...').
cumaru tag set intake/index.md intake "$body"
cumaru tag intake/index.md set intake "$body"

# Set a semantic tag body via stdin (preferred for long content).
cat <<'EOF' | cumaru tag specs/auth/index.md set reference
| Link | Description |
|---|---|
| [session](src/auth/session.ts) | Session lifecycle source implementation. |
EOF
```

## Exit codes

- `0` — success.
- `1` — file/tag absent, validation failure, or write failure.
- `2` — usage error or invalid tag name.

## Why a primitive (no skill)

Skills exist when there's multi-step orchestration that doesn't fit in `--help`. Tag operations are atomic: read a body, write a body, audit a file. Lifecycle skills use `cumaru tree` for structural navigation and use `cumaru tag set` only for declared semantic tags such as `reference`.

## Related

- [`cumaru fs`](fs.md) — the other CLI primitive (file ops). Recipe skills compose both.
- [`cumaru doctor`](doctor.md) — validates navigation, summaries, tag shapes, and retained file references.
- [`cumaru update`](update.md) — shares the balanced parser and preserves adopter-owned tag bodies during canonical rebuilds.
