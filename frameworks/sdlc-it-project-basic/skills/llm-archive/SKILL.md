---
human_revised: false
name: llm-archive
description: Use this skill whenever the user wants to close, finalize, or archive a plan in the project — move `plans/<KEY>/` into `archive/<KEY>/`, absorb the delta into the relevant spec areas, and clean up the working tree. Trigger on phrases like "archive this plan", "close JET-1234", "finalize the plan", "arquivar o plano", "promote draft to delta", or any task that frames the work as ending a plan's lifecycle. Skill is sdlc-flavor-only — it knows the pillar layout (`plans/`, `archive/`, `specs/`). For raw file ops, use the `llm flow` command directly.
---

# `llm-archive` — close a plan and absorb its delta

Receita end-to-end para encerrar um `plans/<KEY>/`. Combina `llm flow` (file ops) + `llm tag` (re-emit das tabelas em `archive/index.md`, `specs/<area>/index.md`) + Edit (frontmatter, prosa).

## Pre-checks (refuse to start if any fails)

- `plans/<KEY>/index.md` exists.
- `plans/<KEY>/delta-draft.md` exists.
- Every `plans/<KEY>/t*.md` (excluindo `handoff-*`) tem `status: done` no frontmatter.
- `archive/<KEY>/` does **not** exist yet.

If any check fails, surface to the user — don't auto-fix.

## Phase 1 — move into archive/ and prepare the absorption work

1. `llm flow plans/<KEY>/index.md copy archive/<KEY>/index.md`
2. `llm flow plans/<KEY>/delta-draft.md move archive/<KEY>/delta.md`
3. For each `plans/<KEY>/handoff-t<N>.md`: `llm flow plans/<KEY>/handoff-t<N>.md copy archive/<KEY>/handoff-t<N>.md`
4. Mutate `archive/<KEY>/index.md` frontmatter (use Edit; `llm tag` if a marker block is involved):
   - `status: done`
   - add `completed-at: <ISO datetime>`
   - add `delta: delta.md`
5. Refine `archive/<KEY>/delta.md`: drop `status: draft`, tighten wording, verify EARS coverage.
6. For each spec area in the plan's `scope:` frontmatter:
   - Edit `specs/<area>/index.md` body to reflect the new state.
   - Append `<KEY>` to the area's `deltas:` frontmatter list.
   - Re-emit the area's row in `specs/index.md` via `llm tag get specs/index.md specs` → update → `llm tag set specs/index.md specs <new body>`.

## Phase 2 — remove the original plan tree

Confirm `archive/<KEY>/delta.md` no longer carries `status: draft`. Then:

```bash
llm flow plans/<KEY> remove
```

(The `llm flow` guardrail allows this — `plans/<KEY>/` is an entity dir, not the pillar root itself.)

## Phase 3 — re-emit archive/index.md row + verify

1. Add the row to `archive/<KEY>` in `archive/index.md` via `llm tag set archive/index.md archive <new body>` (Key | Title | Completed | Delta | Scope).
2. Run `llm doctor`:
   - Orphan check: row pointing at `plans/<KEY>/` should be gone; new row in `archive/` should resolve.
   - File refs: `delta: delta.md` should resolve.

## Why phased

Phase 1 is *non-destructive* (copies + frontmatter updates) so a mistake is recoverable just by deleting `archive/<KEY>/`. Phase 2 is the irreversible step — only run after the LLM (you) has confirmed Phase 1's content is right and the user is OK with it.

## Companion ops (no skill needed — these are 1-2 line operations)

### Promote an exploration to a plan

When an exploration matures into committed work:

```bash
llm flow exploring/<slug>          copy   plans/maintenance-<slug>
# OR (if you want to discard the exploration after promotion)
llm flow exploring/<slug>          remove
# Then edit plans/maintenance-<slug>/index.md to add plan frontmatter (scope, status, summary, …)
# and re-emit plans/index.md row via llm tag.
```

### Rename a plan key (rare)

```bash
llm flow plans/<old>  move  plans/<new>
# Then in plans/<new>/index.md, update `key:` in frontmatter (Edit).
# Then in any spec area's deltas: list, replace <old> with <new> (Edit + llm tag for the spec table).
# Then llm doctor — orphan check should be clean.
```

## Patterns

| User says | You do |
|---|---|
| "Archive JET-1234" / "close plan X" / "finalize plan X" | Run all 3 phases above on `<KEY>=JET-1234`, with confirmation between Phase 1 and Phase 2 |
| "Promote `exploring/auth-redesign` to a plan" | Companion op: copy → write plan frontmatter → re-emit plans table |
| "Rename plan JET-1234 to JET-9999" | Companion op: move + update `key:` + fix `deltas:` refs |

Use `llm tag get/set` (CLI, no skill) for marker-block round-trip on `specs/index.md` and `archive/index.md`; pair with `llm-doctor` to verify cleanness post-archive.
