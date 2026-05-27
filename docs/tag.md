# `llm tag`

Read, write, and audit `<!-- llm:NAME --> ... <!-- /llm:NAME -->` marker blocks. **Schema-validated**: `get` and `set` refuse if `<tag>` is not declared for the target file. The mechanical primitive composed by recipe skills (`llm-archive`, `llm-explore`, `llm-plan`, `llm-specs`, `llm-intake`) — no skill of its own; semantics fit in this doc plus `llm tag --help`.

## Usage

```
llm tag                                  list tags declared for the root index.md
llm tag <file>                           list the file's actual tags + schema's expected; flag diffs
llm tag [<file>] get <tag>               print the body of <tag>
llm tag [<file>] set <tag> [<content>]   replace the body; content positional or stdin
llm tag get [<file>] <tag>               equivalent verb-first form
llm tag set [<file>] <tag> [<content>]   equivalent verb-first form
```

`<file>` must end in `.md` and is relative to `DOT_LLM_DIR` unless absolute. When omitted, it defaults to the root `index.md` (`.llm/index.md`).

Tag name format: `[a-z][a-z0-9_-]*(:[a-z][a-z0-9_*-]*)?`. The `llm:` prefix in the file is implicit — pass `specs` or `llm:specs`, both resolve to the same.

## Schema validation

Every `get` / `set` is validated against the schema:
- The tag must be **declared** for the file (root tags, pillar tags, or `meta.tags` with matching `host_file`).
- The set of declared tags comes from the schema walk (`root.tags`, `root.entities.<pillar>.tags`, `meta.tags`).
- Declarations carry a **kind** that informs the body shape:
  - `columns: [...]` → markdown table (the items are column headers; `!` marks a required column; LLM-diffable rows).
  - `description: "..."` → free prose; content stays related to the description.
  - `format: path-list` → bullet list of repo-relative `paths`.
  - `number: <int|float>` → single scalar value (the seed).

`list` views show schema's expectation alongside what's in the file.

## Examples

```bash
# List declared tags for the project's root index.md.
llm tag

# Audit a specific file's tags against the schema.
llm tag specs/index.md

# Get the components table body.
llm tag get components

# Get a pillar index's table.
llm tag get plans/index.md plans
llm tag plans/index.md get plans

# Set a body via positional arg (multi-line works with $'...').
llm tag set intake/index.md intake "$body"
llm tag intake/index.md set intake "$body"

# Set a body via stdin (preferred for long content).
cat <<'EOF' | llm tag specs/index.md set specs
| Path | Summary | Apps | Depends-on | Relates |
|------|---------|------|------------|---------|
| auth/ | OIDC + session refresh | [api, webapp] | [crypto] | [users] |
| payments/ | Stripe checkout | [api] | [auth] | [] |
EOF
```

## Exit codes

- `0` — success.
- `1` — file/tag absent, validation failure, or write failure.
- `2` — usage error or invalid tag name.

## Why a primitive (no skill)

Skills exist when there's multi-step orchestration that doesn't fit in `--help`. Tag operations are atomic: read a body, write a body, audit a file. The recipe skills (`llm-archive`, `llm-specs`, `llm-plan`, `llm-explore`, `llm-intake`) compose `llm tag set <pillar>/index.md <pillar> <new body>` calls in their bodies to re-emit pillar index rows after structural changes.

## Related

- [`llm flow`](flow.md) — the other CLI primitive (file ops). Recipe skills compose both.
- [`llm doctor`](doctor.md) — orphan check surfaces row drift that `llm tag set` fixes.
- [`llm update`](update.md) — uses `llm tag` internally for marker-preserving merges.
