---
human_revised: false
version: 1
name: cumaru-archive
description: Use this skill whenever the user wants to close, finalize, or archive a test campaign — move `plans/<KEY>/` into `archive/<KEY>/`, absorb the delta into the relevant `coverage/` areas, and clean up the working tree. Trigger on phrases like "archive this campaign", "close AAA-1234", "finalize the campaign", "arquivar a campanha", "promote draft to delta", or any task framed as ending a campaign's lifecycle. Knows the pillar layout (`plans/`, `archive/`, `coverage/`). For raw file ops, use `cumaru flow` directly.
---

# `cumaru-archive` — close a campaign and absorb its delta

End-to-end recipe to close a `plans/<KEY>/` after its cases are authored, automated, and passing. Combines `cumaru flow` (file ops) + `cumaru tag` (re-emit `archive/index.md` and `coverage/<area>/index.md` tables) + Edit (frontmatter, prose).

## Pre-checks (refuse to start if any fails)

- `plans/<KEY>/index.md` exists.
- `plans/<KEY>/delta-draft.md` exists.
- Every `plans/<KEY>/t*.md` (excluding `handoff-*`) has `status: done`.
- The cases are passing and non-flaky (or the remaining work is explicitly out of this close).
- `archive/<KEY>/` does **not** exist yet.
- `git` skill installed (Phase 4 needs mutating `git add`/`commit`). If absent, refuse: "Phase 4 needs `--with git`."

Surface failures — don't auto-fix.

## Phase 1 — move into archive/ and prepare the absorption

1. `cumaru flow plans/<KEY>/index.md copy archive/<KEY>/index.md`
2. `cumaru flow plans/<KEY>/delta-draft.md move archive/<KEY>/delta.md`
3. For each `plans/<KEY>/handoff-t<N>.md`: `cumaru flow … copy archive/<KEY>/handoff-t<N>.md`
4. Mutate `archive/<KEY>/index.md` frontmatter: `status: done`, add `completed-at: <ISO>`, add `delta: delta.md`.
5. Refine `archive/<KEY>/delta.md`: drop `status: draft`, tighten wording, verify it covers the campaign's acceptance criteria.
6. For each area in the plan's `scope:`:
   - Edit `coverage/<area>/index.md` body to reflect the new coverage state — update `## Scenarios (GWT)`, `## Levels`, and `## Gaps` as changed.
   - Append `<KEY>` to the area's `deltas:` frontmatter list.
   - Re-emit the area's row in `coverage/index.md` via `cumaru tag get/set coverage/index.md coverage`.

## Phase 2 — remove the original plan tree

Confirm `archive/<KEY>/delta.md` no longer carries `status: draft`, then:

```bash
cumaru flow plans/<KEY> remove
```

## Phase 3 — re-emit archive/index.md row + verify

1. Add the `<KEY>` row to `archive/index.md` via `cumaru tag set archive/index.md archive <new body>` — v4 shape: `| [<KEY>](<KEY>/index.md) | <one-line summary, plus apps if relevant> |`. The absorbed commit SHA is appended to the Description in Phase 4 (e.g. "— absorbed in 3f1c2ab").
2. `cumaru doctor`: the row pointing at `plans/<KEY>/` should be gone; the new `archive/` row should resolve to the in-flight `archive/<KEY>/`; `delta: delta.md` resolves.

## Phase 4 — commit absorption and prune the archive directory

1. Stage + commit: `git add coverage/ archive/ plans/` then `git commit -m "chore(.cumaru): absorb <KEY> delta into <areas>"`.
2. Capture the SHA: `git rev-parse HEAD`.
3. Re-emit the `<KEY>` row with the absorbed commit SHA appended to the Description (e.g. `… — absorbed in 3f1c2ab`) via `cumaru tag set archive/index.md archive <new body>`.
4. Prune + commit: `cumaru flow archive/<KEY> remove` then `git add archive/` and `git commit -m "chore(.cumaru): prune archive/<KEY>/ post-absorption"`.
5. `cumaru doctor` — no orphans.

**Ghost deltas** ("no coverage change required"): the row carries `Absorbed-in: <sha> (no coverage change)`; the directory is still pruned.

## Why phased

Phase 1 is non-destructive (copies + frontmatter) — recoverable by deleting `archive/<KEY>/`. Phase 2 removes the source plan (recoverable from git). Phase 4 is the **final irreversible step**: after the prune, the `archive/index.md` row + the commit SHA are the durable record.

> **Conventions follow-up.** If the campaign introduced a new cross-cutting testing convention (a new mocking rule, a fixture pattern, a coverage gate), author its standard now from `templates/standard.md` under `standards/<slug>/` and point its `relates:` at the affected `coverage/<area>` — standards are durable and live outside this finalize-and-delete flow.

## Companion ops (no skill needed)

### Promote an exploration to a campaign

```bash
cumaru flow exploring/<slug> copy plans/maintenance-<slug>   # or `remove` to discard
# Then author plans/maintenance-<slug>/index.md frontmatter (scope, status, summary, apps) and re-emit plans/index.md.
```

### Rename a plan key (rare)

```bash
cumaru flow plans/<old> move plans/<new>
# Update key: in plans/<new>/index.md; replace <old> with <new> in any coverage area's deltas:; cumaru doctor.
```

## Patterns

| User says | You do |
|---|---|
| "Archive AAA-1234" / "close campaign X" | Run all 4 phases on `<KEY>`, confirming between Phase 1→2 and again before Phase 4 (irreversible prune) |
| "Promote `exploring/checkout-flaky-network` to a campaign" | Companion op: copy → author plan frontmatter → re-emit plans table |
| "Rename plan AAA-1234 to AAA-9999" | Companion op: move + update `key:` + fix `deltas:` refs |

Use `cumaru tag get/set` (CLI) for the `coverage/index.md` + `archive/index.md` round-trips; pair with `cumaru-doctor` to verify post-archive.
