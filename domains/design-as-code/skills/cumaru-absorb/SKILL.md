---
human_revised: false
version: 1
name: cumaru-absorb
description: Use this skill whenever the user wants to close a plan and absorb its delta into specs, then clean up the plan directory. It is sdlc-light-only and knows the `plans/` and `specs/` lifecycle.
summary: Use this skill whenever the user wants to close a plan and absorb its delta into specs, then clean up the plan directory. It is sdlc-light-only and knows the `plans/` and `specs/` lifecycle.
---

# `cumaru-absorb` — close a plan and absorb its delta into specs

Load `.cumaru/roles/lead.md`, read `plans/index.md` and `specs/index.md`, then
run `cumaru tree --pillars plans,specs --rows`. Use invocation arguments as the
plan ID and preserve the phase-confirmation gates below.

End-to-end recipe to close a `plans/<PLAN-ID>/`. It combines `cumaru flow`, `cumaru tree`, spec updates, and focused health checks.

## Pre-checks (refuse to start if any fails)

- `plans/<PLAN-ID>/index.md` exists.
- `plans/<PLAN-ID>/delta-draft.md` exists.
- Every `plans/<PLAN-ID>/t*.md` (excluding `handoff-*`) has `status: done` in the frontmatter.

If any check fails, surface to the user — don't auto-fix.

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

## Phase 1 — validate and absorb into specs

1. **Read and validate the delta-draft.** Open `plans/<PLAN-ID>/delta-draft.md`. Verify:
   - Every EARS / RFC 2119 criterion from the plan's `## Acceptance Criteria` is covered by an Added or Modified Requirement (or explicitly noted as not requiring a spec change).
   - The proposed changes are consistent with the plan's `scope:`.
   - No `Removed Requirements` orphan a `depends-on:` from another spec.
2. **For each target area from Phase 0:**
   - Edit `specs/<area>/index.md` body to reflect the new state (per the validated delta-draft).
   - Keep the area's `summary:` accurate when the durable purpose changed.
3. **Handle ghost deltas** (delta says "no spec change required"): skip step 2 entirely. The plan leaves no `.cumaru/` trace — only its commit, if the `git` skill is installed. Work that alters no system contract has no place in the living spec; that is correct, not a gap.

## Phase 2 — clean up the plan files

1. Delete `plans/<PLAN-ID>/delta-draft.md` (the draft is consumed — the absorption is the record).
2. **Remove or keep the plan directory:**
   - If the plan directory is no longer useful as a record → `cumaru flow plans/<PLAN-ID> remove`.
   - If it should stay as a record → update `plans/<PLAN-ID>/index.md` frontmatter: `status: done`.

## Phase 3 — verify navigation

1. Run `cumaru tree plans --rows` to inspect the current filesystem projection.
2. Run `cumaru doctor` and resolve only semantic-tag or summary failures.

## Why phased

Phase 1 is the core: the spec state is updated to reflect the new truth. Phase 2 cleans up intermediate artifacts. Phase 3 verifies the filesystem projection. Unlike archive-based flows there is no `archive/` pillar — the updated `specs/` files **are** the durable record. With the `git` skill installed, a commit message naming the plan key is how you find them later; without it this domain keeps no history layer, which is consistent with the pillar stating what is true now.

## Patterns

| User says | You do |
|---|---|
| "Absorb AAA-1234" / "close plan X" / "finalize plan X" | Run Phase 0 then all 3 phases on `<PLAN-ID>=AAA-1234`, confirming the Phase 0 targets and between phases |
| "Finalize but keep the plan dir" | Phase 0 → Phase 1 → Phase 2 (keep dir, update status: done) → Phase 3 |

Use `cumaru tree` for navigation and pair with `cumaru-doctor` to verify cleanness post-absorb.
