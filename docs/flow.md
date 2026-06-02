# `cumaru flow`

Safe file ops inside `.cumaru/`. **Four verbs, four guardrails, no content awareness.** The mechanical primitive composed by recipe skills (`cumaru-archive`, `cumaru-explore`, `cumaru-plan`, `cumaru-specs`) — no skill of its own; semantics fit in this doc plus `cumaru flow --help`.

## Usage — four verbs

```
cumaru flow <src> move    <dst>       move (or rename) a file/dir
cumaru flow <src> copy    <dst>       copy a file/dir
cumaru flow <path> create             create an empty dir; if <path> ends in .md, an empty file
cumaru flow <path> remove             delete a file/dir
```

**Paths are relative to `.cumaru/`.** No `..` segments — write the clean path from the root. Files must end in `.md`; every directory path segment must contain no dots. Trailing slash optional.

## The 4 guardrails

1. **Paths must resolve inside `.cumaru/`** — `..` segments and leading `/` are rejected outright, symlinked parents are resolved before every operation, and direct symlink targets are refused.
2. **File paths must end in `.md`; directory names contain no dots** — this applies consistently to `create`, `move`, `copy`, and `remove`, including parent directories created implicitly. Non-`.md` file extensions and dotted directory segments are refused.
3. **`remove` refuses files literally named `index.md`** — they're system-critical for the entity's existence. To remove an entity, remove its **dir** (which transitively removes its `index.md`).
4. **`remove` refuses pillar root dirs** — any direct child of `.cumaru/` (e.g. `.cumaru/plans`) can't be removed.

`move` and `copy` refuse if the destination already exists (no silent overwrites). Parent dirs are created automatically (`mkdir -p`).

## Examples

```bash
# Bootstrap a new entity.
cumaru flow exploring/auth-redesign           create     # creates the dir
cumaru flow exploring/auth-redesign/index.md  create     # creates an empty .md

# Archive flow phase 1 — non-destructive moves and copies.
cumaru flow plans/AAA-1234/delta-draft.md     move       archive/AAA-1234/delta.md
cumaru flow plans/AAA-1234/handoff-t1.md      copy       archive/AAA-1234/handoff-t1.md
cumaru flow plans/AAA-1234/index.md           copy       archive/AAA-1234/index.md

# Archive flow phase 2 — irreversible removal of the original plan tree.
cumaru flow plans/AAA-1234                    remove     # removes the entity dir (allowed)

# Guardrails in action.
cumaru flow plans                             remove     # ✗ refused — pillar root
cumaru flow plans/AAA-1234/index.md           remove     # ✗ refused — index.md
cumaru flow ../etc/passwd                     remove     # ✗ refused — escapes .cumaru/
cumaru flow plans/AAA-1234/notes.txt          create     # ✗ refused — non-.md extension
cumaru flow plans/AAA-1234 copy archive/AAA-1234.v2      # ✗ refused — dotted directory
```

## What it does NOT do

- **Content mutation** — frontmatter values, tag bodies, prose. Use [`cumaru tag`](tag.md) for marker blocks, Edit for everything else.
- **Validation of what you create** — you can create `specs/foo/index.md` with empty frontmatter; `cumaru doctor` will then flag the missing fields.
- **Workflow orchestration** — flow doesn't know about "archiving a plan" as a concept. Recipe skills compose the steps (see the `cumaru-archive` skill for the full recipe).
- **Glob expansion** — one path per call. Loop in the shell or call from a recipe for multi-file ops.

## Exit codes

- `0` — success.
- `1` — guardrail violation, source missing, destination exists, or write failure.
- `2` — usage error (unknown verb, missing args).

## Why a primitive (no skill)

Skills exist when there's multi-step orchestration that doesn't fit in `--help`. Flow operations are atomic. The recipes that USE flow (archive a plan, bootstrap a spec area, promote an exploration) live in domain-specific skills (`cumaru-archive`, `cumaru-specs`, `cumaru-explore`) — those skills compose flow calls into the actual workflow.

## Related

- [`cumaru tag`](tag.md) — the other CLI primitive (marker-block content). Recipe skills compose both.
- [`cumaru doctor`](doctor.md) — orphan check + file refs check verify the result of flow operations.
- `cumaru-archive`, `cumaru-explore`, `cumaru-plan`, `cumaru-specs` skills — recipes that compose `cumaru flow` into workflows.
