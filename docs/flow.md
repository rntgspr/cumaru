# `llm flow`

Safe file ops inside `.llm/`. **Four verbs, four guardrails, no content awareness.** The mechanical primitive composed by recipe skills (`llm-archive`, `llm-explore`, `llm-plan`, `llm-specs`) — no skill of its own; semantics fit in this doc plus `llm flow --help`.

## Usage — four verbs

```
llm flow <src> move    <dst>       move (or rename) a file/dir
llm flow <src> copy    <dst>       copy a file/dir
llm flow <path> create             create an empty dir; if <path> ends in .md, an empty file
llm flow <path> remove             delete a file/dir
```

**Paths are relative to `.llm/`** (the active `DOT_LLM_DIR`). No `..` segments — write the clean path from the root. Files must end in `.md`; dirs have no extension. Trailing slash optional.

## The 4 guardrails

1. **Paths must resolve inside `.llm/`** — `..` segments and leading `/` are rejected outright.
2. **File paths must end in `.md`** — non-`.md` extensions (`.txt`, `.yaml`, …) refused. Directory names have no extension at all (`.foo` is rejected — looks like a file).
3. **`remove` refuses files literally named `index.md`** — they're system-critical for the entity's existence. To remove an entity, remove its **dir** (which transitively removes its `index.md`).
4. **`remove` refuses pillar root dirs** — any direct child of `.llm/` (e.g. `.llm/plans`) can't be removed.

`move` and `copy` refuse if the destination already exists (no silent overwrites). Parent dirs are created automatically (`mkdir -p`).

## Examples

```bash
# Bootstrap a new entity.
llm flow exploring/auth-redesign           create     # creates the dir
llm flow exploring/auth-redesign/index.md  create     # creates an empty .md

# Archive flow phase 1 — non-destructive moves and copies.
llm flow plans/JET-1234/delta-draft.md     move       archive/JET-1234/delta.md
llm flow plans/JET-1234/handoff-t1.md      copy       archive/JET-1234/handoff-t1.md
llm flow plans/JET-1234/index.md           copy       archive/JET-1234/index.md

# Archive flow phase 2 — irreversible removal of the original plan tree.
llm flow plans/JET-1234                    remove     # removes the entity dir (allowed)

# Guardrails in action.
llm flow plans                             remove     # ✗ refused — pillar root
llm flow plans/JET-1234/index.md           remove     # ✗ refused — index.md
llm flow ../etc/passwd                     remove     # ✗ refused — escapes .llm/
llm flow plans/JET-1234/notes.txt          create     # ✗ refused — non-.md extension
```

## What it does NOT do

- **Content mutation** — frontmatter values, tag bodies, prose. Use [`llm tag`](tag.md) for marker blocks, Edit for everything else.
- **Validation of what you create** — you can create `specs/foo/index.md` with empty frontmatter; `llm doctor` will then flag the missing fields.
- **Workflow orchestration** — flow doesn't know about "archiving a plan" as a concept. Recipe skills compose the steps (see the `llm-archive` skill for the full recipe).
- **Glob expansion** — one path per call. Loop in the shell or call from a recipe for multi-file ops.

## Exit codes

- `0` — success.
- `1` — guardrail violation, source missing, destination exists, or write failure.
- `2` — usage error (unknown verb, missing args).

## Why a primitive (no skill)

Skills exist when there's multi-step orchestration that doesn't fit in `--help`. Flow operations are atomic. The recipes that USE flow (archive a plan, bootstrap a spec area, promote an exploration) live in flavor-specific skills (`llm-archive`, `llm-specs`, `llm-explore`) — those skills compose flow calls into the actual workflow.

## Related

- [`llm tag`](tag.md) — the other CLI primitive (marker-block content). Recipe skills compose both.
- [`llm doctor`](doctor.md) — orphan check + file refs check verify the result of flow operations.
- `llm-archive`, `llm-explore`, `llm-plan`, `llm-specs` skills — recipes that compose `llm flow` into workflows.
