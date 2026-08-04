---
human_revised: false
version: 1
name: cumaru-archive
description: Use this skill whenever the user wants to close, finalize, or archive a plan in the project — move `plans/<KEY>/` into transient `archive/<KEY>/`, absorb the delta into the specs areas that own it, and clean up archive/plans. Trigger on phrases like "archive this plan", "close AAA-1234", "finalize the plan", "arquivar o plano", "promote draft to delta", or any task that frames the work as ending a plan's lifecycle. Skill is sdlc-domain-only — it knows the pillar layout (`plans/`, `archive/`, `specs/`). For raw file ops, use the `cumaru flow` command directly.
summary: Use this skill whenever the user wants to close, finalize, or archive a plan in the project — move `plans/<KEY>/` into transient `archive/<KEY>/`, absorb the delta into the specs areas that own it, and clean up archive/plans. Trigger on phrases like "archive this plan", "close AAA-1234", "finalize the plan", "arquivar o plano", "promote draft to delta", or any task that frames the work as ending a plan's lifecycle. Skill is sdlc-domain-only — it knows the pillar layout (`plans/`, `archive/`, `specs/`). For raw file ops, use the `cumaru flow` command directly.
---

# `cumaru-archive` — close a plan and absorb its delta

End-to-end recipe to close a `plans/<KEY>/`. `archive/` is transient staging; the durable result is the updated `specs/` tree and nothing else. It combines `cumaru flow`, `cumaru tree`, and focused health checks.

## Pre-checks (refuse to start if any fails)

- `plans/<KEY>/index.md` exists.
- `plans/<KEY>/delta-draft.md` exists.
- Every `plans/<KEY>/t*.md` (excluding `handoff-*`) has `status: done` in the frontmatter.
- `archive/<KEY>/` does **not** exist yet.
- `git` skill is installed. The absorption commit is the only cross-reference back from a spec to the plan that built it, so committing is required. If absent, refuse with: "Archive absorption needs `--with git` — the commit is the record. Re-install with `cumaru install --with git`."

If any check fails, surface to the user — don't auto-fix.
If `delta-draft.md` is absent, direct the user to `cumaru-plan` to create it.

Before Phase 0, summarize the plan's `summary:`, `scope:`, completed task count,
and proposed sequence. Ask for `walk` to confirm between phases or `apply` for
one explicit confirmation covering the complete sequence. Never substitute
agent confidence for user confirmation.

## Phase 0 — discover where the delta belongs

The plan's `scope:` was written before the work happened. It is a **hint to
validate**, never the authority on where a claim lands.

1. **List every area** — `cumaru tree specs --rows`. Shallow, and complete: this
   is the full set of candidate homes, which is what the ownership decision needs.
2. **Recurse only into the areas you selected** — `cumaru tree specs/<area> --deep --rows`
   for each one, to place the claim on the right concern inside it.

   Do **not** run `--deep` on the whole pillar. It is quadratic in practice: on a
   3561-file bench pillar it does not finish in two minutes and would emit ~390 KB,
   against 35 KB and one pass for the shallow list. The ownership question is
   answered at the area level; only the selected areas need their interior.
3. **Adjudicate every durable claim** in `delta-draft.md` against the enumerated
   areas, using their `summary:` to decide ownership.
4. **Exact fit** → that area is the target. **No fit** → create a new area with
   the `cumaru-specs` skill, as usual. Never force a claim into an area that does
   not own it.
5. **Compare against `scope:`.** Where the discovered target differs, surface the
   mismatch to the user and let them choose — do not silently follow either.

Carry the resulting target list into Phase 1.

## Phase 1 — move into archive/ and prepare the absorption work

1. `cumaru flow plans/<KEY>/index.md copy archive/<KEY>/index.md`
2. `cumaru flow plans/<KEY>/delta-draft.md move archive/<KEY>/delta.md`
3. For each `plans/<KEY>/handoff-t<N>.md`: `cumaru flow plans/<KEY>/handoff-t<N>.md copy archive/<KEY>/handoff-t<N>.md`
4. Mutate `archive/<KEY>/index.md` frontmatter (use Edit; `cumaru tag` if a marker block is involved):
   - `status: done`
   - add `completed-at: <ISO datetime>`
   - add `delta: delta.md`
5. Refine `archive/<KEY>/delta.md`: drop `status: draft`, tighten wording, verify requirements coverage.
6. Set a valid stable `summary:` on `archive/<KEY>/index.md` while it exists.
7. For each target area from Phase 0:
    - Edit `specs/<area>/index.md` body to reflect the new state.
    - Update the area's `summary:` if its durable purpose changed.

## Phase 2 — remove the original plan tree

Confirm `archive/<KEY>/delta.md` no longer carries `status: draft`. Then:

```bash
cumaru flow plans/<KEY> remove
```

(The `cumaru flow` guardrail allows this — `plans/<KEY>/` is an entity dir, not the pillar root itself.)

## Phase 3 — commit the absorption and clean archive/

After Phase 2, the source plan is gone and `archive/<KEY>/` is the in-flight close-out workspace. The durable end state is `specs/`; archive must be empty for this plan.

1. Run `cumaru doctor` before commit — verify summaries, semantic tags, and file references.
2. Stage and commit the spec absorption. The message **must name every KEY absorbed**: it is the grep key that replaces the old ledger, and commit messages survive rebase and squash where SHAs do not.
   ```bash
   git add specs/ archive/ plans/
   git commit -m "chore(.cumaru): absorb <KEY> delta into <areas>"
   ```
3. No structural index row is maintained; `cumaru tree archive --rows` reflects the current directory.
4. Prune the archive directory and commit the cleanup:
   ```bash
   cumaru flow archive/<KEY> remove
   git add archive/
   git commit -m "chore(.cumaru): prune archive/<KEY>/ post-absorption"
   ```
5. Run `cumaru doctor` — `archive/<KEY>/` must not exist.

**Ghost deltas** (delta declared "no spec change required"): remove the transient archive directory; the plan leaves **only its commit**. Work that alters no system contract has no place in the living spec — that is correct, not a gap.

## Why phased

Phase 1 is *non-destructive* (copies + frontmatter updates) so a mistake is recoverable by deleting `archive/<KEY>/`. Phase 2 removes the source plan tree — recoverable from git, but disruptive. Phase 3 is final: `specs/` becomes the durable truth and the commit is how you find which plan built it; archive leaves no residue for `<KEY>`.

## Companion ops (no skill needed — these are 1-2 line operations)

### Promote an exploration to a plan

When an exploration matures into committed work:

```bash
cumaru flow exploring/<slug>          copy   plans/maintenance-<slug>
# OR (if you want to discard the exploration after promotion)
cumaru flow exploring/<slug>          remove
# Then edit plans/maintenance-<slug>/index.md to add plan frontmatter (scope, status, summary, …)
# and run `cumaru tree plans --rows`.
```

### Promote a local issue to a plan

Use `cumaru-issue` to validate and distill `issues/<slug>/index.md` into
`plans/maintenance-<slug>/`, then remove the issue directory. Local issues do
not enter `archive/` directly.

### Rename a plan key (rare)

```bash
cumaru flow plans/<old>  move  plans/<new>
# Then in plans/<new>/index.md, update `key:` in frontmatter (Edit).
# Then cumaru doctor — navigation and summary checks clean.
```

## Patterns

| User says | You do |
|---|---|
| "Archive AAA-1234" / "close plan X" / "finalize plan X" | Run Phase 0 then all 3 phases on `<KEY>=AAA-1234`, confirming the Phase 0 targets, between Phase 1 and Phase 2, and again before Phase 3's commit/cleanup |
| "Promote `exploring/auth-redesign` to a plan" | Companion op: copy → write plan frontmatter → verify with `cumaru tree plans --rows` |
| "Rename plan AAA-1234 to AAA-9999" | Companion op: move + update `key:` |

Use `cumaru tree` for navigation and pair with `cumaru-doctor` to verify cleanness post-archive. This recipe writes no marker tags.
