# `cumaru tag`

Read, write, and audit `<!-- cumaru:NAME --> ... <!-- /cumaru:NAME -->` marker blocks. **Schema-validated**: `get` and `set` refuse if `<tag>` is not declared for the target file. The mechanical primitive composed by recipe skills (`cumaru-archive`, `cumaru-explore`, `cumaru-plan`, `cumaru-specs`, `cumaru-intake`) — no skill of its own; semantics fit in this doc plus `cumaru tag --help`.

## Usage

```
cumaru tag                                  list tags declared for the root index.md
cumaru tag all [--body|--rows|--tables|--prose|--mixed] list every tag in every .cumaru/*.md
cumaru tag <file>                           list the file's actual tags + schema's expected; flag diffs
cumaru tag [<file>] get <tag>               print the body of <tag>
cumaru tag [<file>] set <tag> [<content>]   replace the body; content positional or stdin
cumaru tag get [<file>] <tag>               equivalent verb-first form
cumaru tag set [<file>] <tag> [<content>]   equivalent verb-first form
```

`<file>` must end in `.md` and is relative to `.cumaru/` unless absolute. When omitted, it defaults to the root `index.md` (`.cumaru/index.md`).

Tag name format: `[a-z][a-z0-9_-]*(:[a-z][a-z0-9_*-]*)*` — colon segments repeat, so deep node-tree names like `plans:plan:handoff:files` are valid. The `cumaru:` prefix in the file is implicit — pass `specs` or `cumaru:specs`, both resolve to the same.

`<file>` audit mode (`cumaru tag <file>`) shows a diff between what the schema declares for that file and what marker blocks actually exist — tags declared in schema but absent from the file marked `[+]`, and tags present in the file but not declared marked `[✗]`.

## Schema validation

Every `get` / `set` is validated against the schema:
- The tag must be **declared** for the file (root tags, pillar tags, or `meta.tags` with matching `host_file`).
- The set of declared tags comes from the schema walk (`root.tags`, `root.entities.<pillar>.tags`, `meta.tags`).

## Body Shape (v5)

Every `<!-- cumaru:* -->` block is adopter-owned, but its body type is declared by the schema:

| Schema value | Meaning |
|---|---|
| `default` | Standard table with `Link`, `Description`. |
| `[SHA, KEY, Description]` | Custom deterministic table with those columns. |
| `prose` | Free prose, preserved and not path-resolved. |
| `mixed` / `other` | Opaque adopter-owned body; tooling preserves it but does not infer structure. |

`cumaru tag all --rows` emits only `default` table rows. `--tables` emits deterministic table rows (`default` plus custom arrays). `--prose` and `--mixed` print raw bodies for those non-table types.

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

# Deterministic table rows (default + custom column arrays):
# file<TAB>tag<TAB>columns_csv<TAB>cell1<TAB>cell2...
cumaru tag all --tables

# Schema-declared prose block bodies.
cumaru tag all --prose

# Mixed/other opaque block bodies.
cumaru tag all --mixed
```

`--rows` parses only `default` `[Link, Description]` rows and resolves links relative to the file that hosts the tag. Root `index.md` and `domain.md` links resolve from the project root. Status values are `ok`, `missing`, `external`, `anchor`, `template`, `empty`, and `invalid`.

`--tables` includes both `default` and custom-column array tags, outputting the declared column names as the first fields.

`--prose` and `--mixed` print raw bodies for schema-declared `prose` and `mixed`/`other` tag types respectively.

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
