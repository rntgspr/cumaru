---
human_revised: false
version: 1
name: cumaru-archive
description: Use this skill whenever the user wants to close, finalize, or archive a changeset — move `plans/<KEY>/` into `archive/<KEY>/`, absorb the delta into the relevant `topology/` areas, and clean up the working tree. Trigger on phrases like "archive this change", "close AAA-1234", "finalize the changeset", "arquivar o plano", "promote draft to delta", or any task framed as ending a changeset's lifecycle. Knows the pillar layout (`plans/`, `archive/`, `topology/`). For raw file ops, use `cumaru flow` directly.
summary: Use this skill whenever the user wants to close, finalize, or archive a changeset — move `plans/<KEY>/` into `archive/<KEY>/`, absorb the delta into the relevant `topology/` areas, and clean up the working tree. Trigger on phrases like "archive this change", "close AAA-1234", "finalize the changeset", "arquivar o plano", "promote draft to delta", or any task framed as ending a changeset's lifecycle. Knows the pillar layout (`plans/`, `archive/`, `topology/`). For raw file ops, use `cumaru flow` directly.
---

# `cumaru-archive` — close a changeset and absorb its delta

End-to-end recipe to close a `plans/<KEY>/` after the change has been applied through its promotion path. It combines `cumaru flow`, `cumaru tree`, the topology absorption ledger, and focused health checks.

## Pre-checks (refuse to start if any fails)

- `plans/<KEY>/index.md` exists.
- `plans/<KEY>/delta-draft.md` exists.
- Every `plans/<KEY>/t*.md` (excluding `handoff-*`) has `status: done`.
- The change has been applied through its `## Promotion path` (or the remaining environments are explicitly out of this close).
- `archive/<KEY>/` does **not** exist yet.
- `git` skill installed (Phase 4 needs mutating `git add`/`commit`). If absent, refuse: "Phase 4 needs `--with git`."

Surface failures — don't auto-fix.

## Phase 1 — move into archive/ and prepare the absorption

1. `cumaru flow plans/<KEY>/index.md copy archive/<KEY>/index.md`
2. `cumaru flow plans/<KEY>/delta-draft.md move archive/<KEY>/delta.md`
3. For each `plans/<KEY>/handoff-t<N>.md`: `cumaru flow … copy archive/<KEY>/handoff-t<N>.md`
4. Mutate `archive/<KEY>/index.md` frontmatter: `status: done`, add `completed-at: <ISO>`, add `delta: delta.md`.
5. Refine `archive/<KEY>/delta.md`: drop `status: draft`, tighten wording, verify it covers the change's acceptance criteria.
6. For each area in the plan's `scope:`:
   - Edit `topology/<area>/index.md` body to reflect the new state of the stack (interface/dependencies/decisions/cost-security as changed).
   - Append `<KEY>` to the area's `deltas:` frontmatter list.
   - Update the area's `summary:` if its durable purpose changed.

## Phase 2 — remove the original plan tree

Confirm `archive/<KEY>/delta.md` no longer carries `status: draft`, then:

```bash
cumaru flow plans/<KEY> remove
```

## Phase 3 — run `cumaru tree archive --rows` + verify

1. Run `cumaru tree archive --rows` to inspect the in-flight directory.
2. Run `cumaru doctor`: summaries, semantic tags, and `delta: delta.md` must validate.

## Phase 4 — commit absorption and prune the archive directory

1. Stage + commit: `git add topology/ archive/ plans/` then `git commit -m "chore(.cumaru): absorb <KEY> delta into <stacks>"`.
2. Capture the SHA: `git rev-parse HEAD`.
3. Read the current `cumaru:absorptions` body, append `| <sha> | <KEY> | <one-line summary> |`, and write the complete table with `cumaru tag set topology/index.md absorptions`.
4. Prune + commit: `cumaru flow archive/<KEY> remove` then `git add archive/` and `git commit -m "chore(.cumaru): prune archive/<KEY>/ post-absorption"`.
5. Run `cumaru tree topology --rows`, `cumaru tree archive --rows`, and `cumaru doctor`.

**Ghost deltas** ("no topology change required"): append a ledger Description ending in `(no topology change)`; the directory is still pruned.

## Why phased

Phase 1 is non-destructive (copies + frontmatter) — recoverable by deleting `archive/<KEY>/`. Phase 2 removes the source plan (recoverable from git). Phase 4 is final: after the prune, the updated topology plus its `absorptions` ledger entry are the durable record.

> **Operational follow-up.** If the change introduced a new recurring operation (a new failover, a new rotation), author its runbook now from `templates/runbook.md` under `runbooks/<slug>/` and point its `relates:` at the affected `topology/<area>` — runbooks are durable and live outside this finalize-and-delete flow.

## Companion ops (no skill needed)

### Promote an exploration to a changeset

```bash
cumaru flow exploring/<slug> copy plans/maintenance-<slug>   # or `remove` to discard
# Then author plans/maintenance-<slug>/index.md frontmatter (scope, status, summary, apps) and run `cumaru tree plans --rows`.
```

### Rename a plan key (rare)

```bash
cumaru flow plans/<old> move plans/<new>
# Update key: in plans/<new>/index.md; replace <old> with <new> in any topology area's deltas:; cumaru doctor.
```

## Patterns

| User says | You do |
|---|---|
| "Archive AAA-1234" / "close change X" | Run all 4 phases on `<KEY>`, confirming between Phase 1→2 and again before Phase 4 (irreversible prune) |
| "Promote `exploring/move-to-opentofu` to a change" | Companion op: copy → author plan frontmatter → verify with `cumaru tree plans --rows` |
| "Rename plan AAA-1234 to AAA-9999" | Companion op: move + update `key:` + fix `deltas:` refs |

Use `cumaru tag get/set` only for the semantic `topology/index.md` `absorptions` ledger; use `cumaru tree` for navigation and pair with `cumaru-doctor` post-archive.
