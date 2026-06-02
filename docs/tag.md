# `cumaru tag`

Read, write, and audit `<!-- cumaru:NAME --> ... <!-- /cumaru:NAME -->` marker blocks. **Schema-validated**: `get` and `set` refuse if `<tag>` is not declared for the target file. The mechanical primitive composed by recipe skills (`cumaru-archive`, `cumaru-explore`, `cumaru-plan`, `cumaru-specs`, `cumaru-intake`) — no skill of its own; semantics fit in this doc plus `cumaru tag --help`.

## Usage

```
cumaru tag                                  list tags declared for the root index.md
cumaru tag all [--body|--rows]              list every tag in every .cumaru/*.md
cumaru tag <file>                           list the file's actual tags + schema's expected; flag diffs
cumaru tag [<file>] get <tag>               print the body of <tag>
cumaru tag [<file>] set <tag> [<content>]   replace the body; content positional or stdin
cumaru tag get [<file>] <tag>               equivalent verb-first form
cumaru tag set [<file>] <tag> [<content>]   equivalent verb-first form
```

`<file>` must end in `.md` and is relative to `.cumaru/` unless absolute. When omitted, it defaults to the root `index.md` (`.cumaru/index.md`).

Tag name format: `[a-z][a-z0-9_-]*(:[a-z][a-z0-9_*-]*)*` — colon segments repeat, so deep node-tree names like `plans:plan:handoff:files` are valid. The `cumaru:` prefix in the file is implicit — pass `specs` or `cumaru:specs`, both resolve to the same.

## Schema validation

Every `get` / `set` is validated against the schema:
- The tag must be **declared** for the file (root tags, pillar tags, or `meta.tags` with matching `host_file`).
- The set of declared tags comes from the schema walk (`root.tags`, `root.entities.<pillar>.tags`, `meta.tags`).

## Body shape — universal (v4)

Every `<!-- cumaru:* -->` block has the **same shape**: a markdown table with two columns — `Link` and `Description`. The shape is hardcoded in the parser, doctor, update, and this CLI; schemas don't declare per-tag columns. Add rows, never columns.

```markdown
| Link                          | Description                          |
|-------------------------------|--------------------------------------|
| [name](path/to/index.md)      | one-line prose about the linked file |
```

`list` views show every tag the schema declares alongside what's actually in the file.

## Tree-wide listing

`cumaru tag all` is the canonical tree-wide walker for marker blocks.

```bash
# Group every tag by host file.
cumaru tag all

# Dump every marker body.
cumaru tag all --body

# Machine-readable rows for hooks and doctor:
# file<TAB>tag<TAB>link<TAB>description<TAB>target<TAB>status
cumaru tag all --rows
```

`--rows` parses only v4 `[Link, Description]` rows and resolves links relative to the file that hosts the tag. Status values are `ok`, `missing`, `external`, `anchor`, `template`, `empty`, and `invalid`.

Exception: rows of the `reference` tag resolve from the **project root** (the parent of `.cumaru/`) and must target repository source files — the coverage rule, hardcoded like the table shape. A `reference` row pointing inside `.cumaru/`, at a directory, an absolute path, or a URL resolves to `invalid`. See [`cumaru coverage`](coverage.md).

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

# Set a body via stdin (preferred for long content).
cat <<'EOF' | cumaru tag specs/index.md set specs
| Link                          | Description                                                                |
|-------------------------------|----------------------------------------------------------------------------|
| [auth](auth/index.md)         | OIDC + session refresh — [api, webapp]; depends on `crypto`; relates `users` |
| [payments](payments/index.md) | Stripe checkout — [api]; depends on `auth`                                  |
EOF
```

## Exit codes

- `0` — success.
- `1` — file/tag absent, validation failure, or write failure.
- `2` — usage error or invalid tag name.

## Why a primitive (no skill)

Skills exist when there's multi-step orchestration that doesn't fit in `--help`. Tag operations are atomic: read a body, write a body, audit a file. The recipe skills (`cumaru-archive`, `cumaru-specs`, `cumaru-plan`, `cumaru-explore`, `cumaru-intake`) compose `cumaru tag set <pillar>/index.md <pillar> <new body>` calls in their bodies to re-emit pillar index rows after structural changes.

## Related

- [`cumaru flow`](flow.md) — the other CLI primitive (file ops). Recipe skills compose both.
- [`cumaru doctor`](doctor.md) — orphan check surfaces row drift that `cumaru tag set` fixes.
- [`cumaru update`](update.md) — uses `cumaru tag` internally for marker-preserving merges.
