---
human_revised: false
version: 1
name: cumaru-absorb
description: Use this skill whenever the user wants to close a campaign — verify completion, absorb its delta directly into coverage, establish recovery, and clean up the campaign only after every gate passes. It is qa-basic-only and knows the `plans/` and `coverage/` lifecycle.
summary: Verify a campaign is complete, absorb its coverage delta, establish recovery, and remove it only after every direct close-out gate passes.
---

# `cumaru-absorb` — close a campaign and absorb its delta into coverage

Load `.cumaru/roles/lead.md`, read `plans/index.md` and `coverage/index.md`, then
run `cumaru tree --pillars plans,coverage --rows`. Use invocation arguments as the
campaign ID and preserve the phase-confirmation gates below.

End-to-end recipe to close a `plans/<PLAN-ID>/`. It combines `cumaru fs`, `cumaru tree`, coverage updates, and focused health checks.

## Pre-checks (refuse to start if any fails)

- `plans/<PLAN-ID>/index.md` exists.
- `plans/<PLAN-ID>/delta-draft.md` exists.
- Every `plans/<PLAN-ID>/t*.md` (excluding `handoff-*`) has `status: done` and
  a matching handoff with the required implementation and verification evidence.
- Verify every acceptance criterion in the campaign against the implementation,
  handoffs, and required test or runtime evidence. A `status: done` label, a
  completed attempt, a delta draft, a clean doctor result, or a commit does not
  prove implementation completion.
- If implementation is incomplete, infeasible, blocked, partially delivered,
  or lacks evidence for any criterion, report the exact blocker and leave the
  campaign, tasks, handoffs, delta draft, and auxiliary evidence intact. Do not
  enter the absorption phases. Discarding the campaign requires a separate explicit
  user decision; never infer discard from a close or absorb request.
- The `git` skill is installed. A committed recovery point is required before
  direct-absorption cleanup. If absent, refuse and keep the campaign open.
- Inventory every existing file under `plans/<PLAN-ID>/`, including ignored
  files, tasks, handoffs, auxiliary files, and evidence. Compare that inventory
  with `git ls-files --full-name -- .cumaru/plans/<PLAN-ID>/`, confirm every
  file with `git show HEAD:<path>`, and require both `git diff HEAD --
  .cumaru/plans/<PLAN-ID>/` and `git status --porcelain=v1
  --untracked-files=all --ignored=traditional -- .cumaru/plans/<PLAN-ID>/` to
  be empty before editing `coverage/`. A status check without ignored files can
  miss evidence.
- Git writes require explicit user authorization. Without the evidence baseline
  or authorization for a required commit, keep the campaign open and stop before
  durable edits or cleanup.

If any check fails, surface to the user — don't auto-fix.

## Phase 0 — discover where the delta belongs

The campaign's `scope:` was written before the work happened. It is a **hint to
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
   areas and their loaded concerns. Record a claim-to-file map; the deepest
   existing concern that already owns the subject is the exact destination.
4. **Exact fit** → that exact file is the target. **No fit** → create a new area with
   the `cumaru-coverage` skill, as usual. Never force a claim into an area that does
   not own it.
5. **Compare against `scope:`.** Where the discovered target differs, surface the
   mismatch to the user and let them choose — do not silently follow either.

Carry the resulting claim-to-file map into Phase 1. Do not collapse nested
owners back to an area's `index.md`.

## Phase 1 — validate and absorb into coverage

1. **Read and validate the delta-draft.** Open `plans/<PLAN-ID>/delta-draft.md`. Verify:
   - Every EARS / RFC 2119 criterion from the campaign's `## Acceptance Criteria` is covered by an Added or Modified Requirement (or explicitly noted as not requiring a coverage change).
   - The proposed changes are consistent with the campaign's `scope:`.
   - No removed claim or dependency orphans another coverage owner.
   - Finalize the delta in place before durable edits: remove `status: draft`,
     tighten its claims, and keep it under the campaign until guarded cleanup.
2. **For each mapped claim from Phase 0:**
   - Edit its exact `coverage/<area>/<owner>.md` file. Use the area `index.md` only
     when it is the mapped owner; never duplicate a nested concern's claim in
     its parent.
   - Keep that file's `summary:` accurate when its durable purpose changed.
   - Identify any originating `exploring/` entry actually consumed by the campaign.
     A shared source, active consumer, or unresolved provenance link blocks its
     removal.
   - Before removing consumed intake, retain the acceptance fact and stable upstream tracker reference in the owning coverage file, then remove or replace the local `relates:` edge.
3. **Handle ghost deltas** (delta says "no coverage change required") only when the
   implementation and every acceptance criterion are complete and verified,
   and the durable coverage genuinely remains unchanged. Infeasibility, partial
   delivery, or missing evidence is a blocker, never a ghost delta. A valid
   ghost follows the same validation, recovery commit, and cleanup gates.

The campaign remains intact throughout absorption and validation.

## Phase 2 — validate the durable result

1. Inspect the affected coverage and reconcile every acceptance criterion with its
   implementation evidence and durable claim or explicit no-coverage-change
   rationale. Doctor checks structure; it does not establish semantic completion.
2. Run `cumaru doctor`. Any failed check, unresolved claim, missing evidence,
   or changed cleanup target stops close-out with the complete campaign intact.
3. Present the verified durable result and exact consumed cleanup set to the user.

## Phase 3 — establish the recovery point

With Git mutation authorized, stage the exact verified durable files, the
complete `.cumaru/plans/<PLAN-ID>/` tree, and every consumed exploration
selected for cleanup, then commit with a message that names
the campaign key:

```bash
git add -- .cumaru/coverage/<verified-file> .cumaru/plans/<PLAN-ID>/
git commit -m "chore(.cumaru): absorb <PLAN-ID> delta into <areas>"
```

Before cleanup, verify the commit contains the durable result and every exact
removal target by comparing a complete filesystem inventory of
`.cumaru/plans/<PLAN-ID>/` with `git ls-files`, then confirming every file
through `git show HEAD:<path>`. Verify exact changed durable files through
`git show` and require `git diff HEAD -- <affected-paths>` to be empty. A commit that predates
the durable edits or omits an ignored or untracked file is not a recovery point.

For a verified no-coverage-change result, omit the durable-file argument. A current
clean recovery commit that already contains the complete campaign and names its key
may be reused; do not create an empty commit merely to advance the recipe.

## Phase 4 — clean transient work

Only after Phase 3 succeeds, remove the campaign and each confirmed consumed
exploration. Preserve shared or unresolved sources:

```bash
cumaru fs plans/<PLAN-ID> remove
git add -A -- .cumaru/plans/<PLAN-ID>/
git commit -m "chore(.cumaru): prune <PLAN-ID> post-absorption"
```

Run `cumaru tree plans --rows`, `cumaru tree coverage --rows`, and
`cumaru doctor`. If cleanup or its commit fails, report the failure; the Phase 3
commit is the recovery source.

## Why phased

The evidence baseline protects the implementation record before durable edits.
Phase 1 updates the living coverage while leaving the campaign intact. Phase 2 proves
acceptance and validates the durable result. Phase 3 commits that result together
with every cleanup target. Only Phase 4 removes the campaign. This domain uses
direct absorption, so no absorption staging is introduced.

## Patterns

| User says | You do |
|---|---|
| "Absorb AAA-1234" / "close campaign X" / "finalize campaign X" | Pass the completion and evidence gate, then run Phase 0 through Phase 4; preserve the campaign on any blocker |

Use `cumaru tree` for navigation and pair with `cumaru-doctor` to verify cleanness post-absorb.
