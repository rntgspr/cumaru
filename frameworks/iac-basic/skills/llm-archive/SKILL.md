---
human_revised: false
version: 1
name: llm-archive
description: Use this skill whenever the user wants to close, finalize, or archive a changeset — move `plans/<KEY>/` into `archive/<KEY>/`, absorb the delta into the relevant `topology/` areas, and clean up the working tree. Trigger on phrases like "archive this change", "close JET-1234", "finalize the changeset", "arquivar o plano", "promote draft to delta", or any task framed as ending a changeset's lifecycle. Knows the pillar layout (`plans/`, `archive/`, `topology/`). For raw file ops, use `llm flow` directly.
---

# `llm-archive` — close a changeset and absorb its delta

End-to-end recipe to close a `plans/<KEY>/` after the change has been applied through its promotion path. Combines `llm flow` (file ops) + `llm tag` (re-emit `archive/index.md` and `topology/<area>/index.md` tables) + Edit (frontmatter, prose).

## Pre-checks (refuse to start if any fails)

- `plans/<KEY>/index.md` exists.
- `plans/<KEY>/delta-draft.md` exists.
- Every `plans/<KEY>/t*.md` (excluding `handoff-*`) has `status: done`.
- The change has been applied through its `## Promotion path` (or the remaining environments are explicitly out of this close).
- `archive/<KEY>/` does **not** exist yet.
- `git` skill installed (Phase 4 needs mutating `git add`/`commit`). If absent, refuse: "Phase 4 needs `--with git`."

Surface failures — don't auto-fix.

## Phase 1 — move into archive/ and prepare the absorption

1. `llm flow plans/<KEY>/index.md copy archive/<KEY>/index.md`
2. `llm flow plans/<KEY>/delta-draft.md move archive/<KEY>/delta.md`
3. For each `plans/<KEY>/handoff-t<N>.md`: `llm flow … copy archive/<KEY>/handoff-t<N>.md`
4. Mutate `archive/<KEY>/index.md` frontmatter: `status: done`, add `completed-at: <ISO>`, add `delta: delta.md`.
5. Refine `archive/<KEY>/delta.md`: drop `status: draft`, tighten wording, verify it covers the change's acceptance criteria.
6. For each area in the plan's `scope:`:
   - Edit `topology/<area>/index.md` body to reflect the new state of the stack (interface/dependencies/decisions/cost-security as changed).
   - Append `<KEY>` to the area's `deltas:` frontmatter list.
   - Re-emit the area's row in `topology/index.md` via `llm tag get/set topology/index.md topology`.

## Phase 2 — remove the original plan tree

Confirm `archive/<KEY>/delta.md` no longer carries `status: draft`, then:

```bash
llm flow plans/<KEY> remove
```

## Phase 3 — re-emit archive/index.md row + verify

1. Add the `<KEY>` row to `archive/index.md` via `llm tag set archive/index.md archive <new body>` (Key | Type | Apps | Summary | Absorbed-in). `Absorbed-in` stays empty here — filled in Phase 4.
2. `llm doctor`: the row pointing at `plans/<KEY>/` should be gone; the new `archive/` row should resolve to the in-flight `archive/<KEY>/`; `delta: delta.md` resolves.

## Phase 4 — commit absorption and prune the archive directory

1. Stage + commit: `git add topology/ archive/ plans/` then `git commit -m "chore(.llm): absorb <KEY> delta into <stacks>"`.
2. Capture the SHA: `git rev-parse HEAD`.
3. Re-emit the `<KEY>` row with `Absorbed-in: <sha>` via `llm tag set archive/index.md archive <new body>`.
4. Prune + commit: `llm flow archive/<KEY> remove` then `git add archive/` and `git commit -m "chore(.llm): prune archive/<KEY>/ post-absorption"`.
5. `llm doctor` — no orphans.

**Ghost deltas** ("no topology change required"): the row carries `Absorbed-in: <sha> (no topology change)`; the directory is still pruned.

## Why phased

Phase 1 is non-destructive (copies + frontmatter) — recoverable by deleting `archive/<KEY>/`. Phase 2 removes the source plan (recoverable from git). Phase 4 is the **final irreversible step**: after the prune, the `archive/index.md` row + the commit SHA are the durable record.

> **Operational follow-up.** If the change introduced a new recurring operation (a new failover, a new rotation), author its runbook now from `templates/runbook.md` under `runbooks/<slug>/` and point its `relates:` at the affected `topology/<area>` — runbooks are durable and live outside this finalize-and-delete flow.

## Companion ops (no skill needed)

### Promote an exploration to a changeset

```bash
llm flow exploring/<slug> copy plans/maintenance-<slug>   # or `remove` to discard
# Then author plans/maintenance-<slug>/index.md frontmatter (scope, status, summary, apps) and re-emit plans/index.md.
```

### Rename a plan key (rare)

```bash
llm flow plans/<old> move plans/<new>
# Update key: in plans/<new>/index.md; replace <old> with <new> in any topology area's deltas:; llm doctor.
```

## Patterns

| User says | You do |
|---|---|
| "Archive JET-1234" / "close change X" | Run all 4 phases on `<KEY>`, confirming between Phase 1→2 and again before Phase 4 (irreversible prune) |
| "Promote `exploring/move-to-opentofu` to a change" | Companion op: copy → author plan frontmatter → re-emit plans table |
| "Rename plan JET-1234 to JET-9999" | Companion op: move + update `key:` + fix `deltas:` refs |

Use `llm tag get/set` (CLI) for the `topology/index.md` + `archive/index.md` round-trips; pair with `llm-doctor` to verify post-archive.
