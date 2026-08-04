# `cumaru fs`

Safe file ops inside `.cumaru/`. **Four verbs, four guardrails, no content awareness.** The mechanical primitive composed by recipe skills (`cumaru-absorb`, `cumaru-explore`, `cumaru-plan`, `cumaru-specs`) — no skill of its own; semantics fit in this doc plus `cumaru fs --help`.

`cumaru flow` was renamed to `cumaru fs`; it now exits with a migration diagnostic and never runs a workflow.

## Usage — four verbs

```
cumaru fs <src> move    <dst>       move (or rename) a file/dir
cumaru fs <src> copy    <dst>       copy a file/dir
cumaru fs <path> create             create an empty dir; if <path> ends in .md, an empty file
cumaru fs <path> remove             delete a file/dir
```

**Paths are relative to `.cumaru/`.** No `..` segments — write the clean path from the root. Files must end in `.md`; every directory path segment must contain no dots. Trailing slash optional. Symlinked parents are resolved before every operation, and direct symlink targets are refused.

## The 4 guardrails

1. **Paths must resolve inside `.cumaru/`** — `..` segments and leading `/` are rejected outright, symlinked parents are resolved before every operation, and direct symlink targets are refused (so move/copy/remove semantics cannot vary by platform).
2. **File paths must end in `.md`; directory names contain no dots** — this applies consistently to `create`, `move`, `copy`, and `remove`, including parent directories created implicitly. Non-`.md` file extensions and dotted directory segments are refused.
3. **`remove` refuses files literally named `index.md`** — they're system-critical for the entity's existence. To remove an entity, remove its **dir** (which transitively removes its `index.md`).
4. **`remove` refuses pillar root dirs** — any direct child of `.cumaru/` (e.g. `.cumaru/plans`) can't be removed.

`move` and `copy` refuse if the destination already exists (no silent overwrites). Parent dirs are created automatically (`mkdir -p`).

## Examples

```bash
# Bootstrap a new entity.
cumaru fs exploring/auth-redesign           create     # creates the dir
cumaru fs exploring/auth-redesign/index.md  create     # creates an empty .md

# Copy supporting evidence while the original remains intact.
cumaru fs plans/AAA-1234/evidence.md copy plans/AAA-1234/evidence-reviewed.md

# Remove only after the domain skill verifies completion, validates the durable
# result, and establishes a committed recovery point containing every target.
cumaru fs plans/AAA-1234                    remove     # removes the entity dir (allowed)

# Guardrails in action.
cumaru fs plans                             remove     # ✗ refused — pillar root
cumaru fs plans/AAA-1234/index.md           remove     # ✗ refused — index.md
cumaru fs ../etc/passwd                     remove     # ✗ refused — escapes .cumaru/
cumaru fs plans/AAA-1234/notes.txt          create     # ✗ refused — non-.md extension
cumaru fs plans/AAA-1234 copy plans/AAA-1234.v2        # ✗ refused — dotted directory
```

## What it does NOT do

- **Content mutation** — frontmatter values, tag bodies, prose. Use [`cumaru tag`](tag.md) for tags, Edit for everything else.
- **Validation of what you create** — you can create `specs/foo/index.md` with empty frontmatter; `cumaru doctor` will then flag the missing fields.
- **Workflow orchestration** — `cumaru fs` does not execute named workflows. Recipe skills compose the steps (see the `cumaru-absorb` skill for the full recipe).
- **Glob expansion** — one path per call. Loop in the shell or call from a recipe for multi-file ops.

## Exit codes

- `0` — success.
- `1` — guardrail violation, source missing, destination exists, or write failure.
- `2` — usage error (unknown verb, missing args).

## Why a primitive (no skill)

Skills exist when there's multi-step orchestration that doesn't fit in `--help`. Filesystem operations are atomic. The recipes that use `cumaru fs` (absorb a plan, bootstrap a spec area, promote an exploration) live in domain-specific skills (`cumaru-absorb`, `cumaru-specs`, `cumaru-explore`) — those skills compose filesystem calls into the actual workflow.

## Related

- [`cumaru tag`](tag.md) — the other CLI primitive (tag content). Recipe skills compose both.
- [`cumaru doctor`](doctor.md) — navigation and summary validation + file refs check verify the result of flow operations.
- `cumaru-absorb`, `cumaru-explore`, `cumaru-plan`, `cumaru-specs` skills — recipes that compose `cumaru fs` into workflows.
