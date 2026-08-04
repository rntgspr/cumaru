---
human_revised: false
version: 1
name: cumaru-archive
description: Use this skill whenever the user wants to close, finalize, or archive a test campaign — move `plans/<KEY>/` into `archive/<KEY>/`, absorb the delta into the relevant `coverage/` areas, and clean up the working tree. Trigger on phrases like "archive this campaign", "close AAA-1234", "finalize the campaign", "arquivar a campanha", "promote draft to delta", or any task framed as ending a campaign's lifecycle. Knows the pillar layout (`plans/`, `archive/`, `coverage/`). For raw file ops, use `cumaru flow` directly.
summary: Use this skill whenever the user wants to close, finalize, or archive a test campaign — move `plans/<KEY>/` into `archive/<KEY>/`, absorb the delta into the relevant `coverage/` areas, and clean up the working tree. Trigger on phrases like "archive this campaign", "close AAA-1234", "finalize the campaign", "arquivar a campanha", "promote draft to delta", or any task framed as ending a campaign's lifecycle. Knows the pillar layout (`plans/`, `archive/`, `coverage/`). For raw file ops, use `cumaru flow` directly.
---

# `cumaru-archive` — close a campaign and absorb its delta

End-to-end recipe to close a `plans/<KEY>/` after its cases are authored, automated, and passing. It combines `cumaru flow`, `cumaru tree`, and focused health checks. The durable result is the updated `coverage/` tree — nothing is carried forward out of `archive/`.

## Pre-checks (refuse to start if any fails)

- `plans/<KEY>/index.md` exists.
- `plans/<KEY>/delta-draft.md` exists.
- Every `plans/<KEY>/t*.md` (excluding `handoff-*`) has `status: done`.
- The cases are passing and non-flaky (or the remaining work is explicitly out of this close).
- `archive/<KEY>/` does **not** exist yet.
- `git` skill installed (Phase 4 needs mutating `git add`/`commit`). If absent, refuse: "Phase 4 needs `--with git`."

Surface failures — don't auto-fix.

## Phase 0 — discover where the delta belongs

The plan's `scope:` was written before the work happened. It is a **hint to
validate**, never the authority on where a claim lands.

1. **List every area** — `cumaru tree coverage --rows`. Shallow, and complete: this
   is the full set of candidate homes, which is what the ownership decision needs.
2. **Recurse only into the areas you selected** — `cumaru tree coverage/<area> --deep --rows`
   for each one, to place the claim on the right concern inside it.

   Do **not** run `--deep` on the whole pillar. It is quadratic in practice: on a
   3561-file bench pillar it does not finish in two minutes and would emit ~390 KB,
   against 35 KB and one pass for the shallow list. The ownership question is
   answered at the area level; only the selected areas need their interior.
3. **Adjudicate every durable claim** in `delta-draft.md` against the enumerated
   areas, using their `summary:` to decide ownership.
4. **Exact fit** → that area is the target. **No fit** → create a new area with
   the `cumaru-coverage` skill, as usual. Never force a claim into an area that
   does not own it.
5. **Compare against `scope:`.** Where the discovered target differs, surface the
   mismatch to the user and let them choose — do not silently follow either.

Carry the resulting target list into the absorption step below.

## Phase 1 — move into archive/ and prepare the absorption

1. `cumaru flow plans/<KEY>/index.md copy archive/<KEY>/index.md`
2. `cumaru flow plans/<KEY>/delta-draft.md move archive/<KEY>/delta.md`
3. For each `plans/<KEY>/handoff-t<N>.md`: `cumaru flow … copy archive/<KEY>/handoff-t<N>.md`
4. Mutate `archive/<KEY>/index.md` frontmatter: `status: done`, add `completed-at: <ISO>`, add `delta: delta.md`.
5. Refine `archive/<KEY>/delta.md`: drop `status: draft`, tighten wording, verify it covers the campaign's acceptance criteria.
6. For each target area from Phase 0:
   - Edit `coverage/<area>/index.md` body to reflect the new coverage state — update `## Scenarios (GWT)`, `## Levels`, and `## Gaps` as changed.
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

1. Stage + commit: `git add coverage/ archive/ plans/` then `git commit -m "chore(.cumaru): absorb <KEY> delta into <areas>"`. The message **must name every KEY absorbed** — it is the grep key that finds this work later, and messages survive rebase and squash where SHAs do not.
2. Prune + commit: `cumaru flow archive/<KEY> remove` then `git add archive/` and `git commit -m "chore(.cumaru): prune archive/<KEY>/ post-absorption"`.
3. Run `cumaru tree coverage --rows`, `cumaru tree archive --rows`, and `cumaru doctor`.

**Ghost deltas** ("no coverage change required"): the archive directory is still pruned and the campaign leaves **only its commit**. Work that alters no durable contract has no place in the living coverage map — that is correct, not a gap.

## Why phased

Phase 1 is non-destructive (copies + frontmatter) — recoverable by deleting `archive/<KEY>/`. Phase 2 removes the source plan (recoverable from git). Phase 4 is final: after the prune, the updated `coverage/` is the durable record and the commit is how you find it.

> **Conventions follow-up.** If the campaign introduced a new cross-cutting testing convention (a new mocking rule, a fixture pattern, a coverage gate), author its standard now from `templates/standard.md` under `standards/<slug>/` and point its `relates:` at the affected `coverage/<area>` — standards are durable and live outside this finalize-and-delete flow.

## Companion ops (no skill needed)

### Promote an exploration to a campaign

```bash
cumaru flow exploring/<slug> copy plans/maintenance-<slug>   # or `remove` to discard
# Then author plans/maintenance-<slug>/index.md frontmatter (scope, status, summary, apps) and run `cumaru tree plans --rows`.
```

### Rename a plan key (rare)

```bash
cumaru flow plans/<old> move plans/<new>
# Update key: in plans/<new>/index.md; then cumaru doctor.
```

## Patterns

| User says | You do |
|---|---|
| "Archive AAA-1234" / "close campaign X" | Run Phase 0 then all 4 phases on `<KEY>`, confirming the Phase 0 targets, between Phase 1→2, and again before Phase 4 (irreversible prune) |
| "Promote `exploring/checkout-flaky-network` to a campaign" | Companion op: copy → author plan frontmatter → verify with `cumaru tree plans --rows` |
| "Rename plan AAA-1234 to AAA-9999" | Companion op: move + update `key:` |

Use `cumaru tree` for navigation and pair with `cumaru-doctor` post-archive. This recipe writes no marker tags.
