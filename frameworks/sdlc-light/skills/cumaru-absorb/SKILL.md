---
human_revised: false
version: 1
name: cumaru-absorb
description: Use this skill whenever the user wants to close a plan and absorb its delta into the specs — validate the delta-draft, update `specs/<area>/` files, re-emit indexes, and clean up the plan directory. Trigger on phrases like "close this plan", "absorb AAA-1234", "finalize the plan", "absorver o plano", or any task that frames the work as ending a plan's lifecycle. Skill is sdlc-light-only — it knows the pillar layout (`plans/`, `specs/`) and the absorb flow (no archive pillar).
---

# `cumaru-absorb` — close a plan and absorb its delta into specs

End-to-end recipe to close a `plans/<PLAN-ID>/`. Combines `cumaru flow` (file ops) + `cumaru tag` (re-emit indexes) + Edit (frontmatter, prose). No archive pillar — absorption is direct from plans into specs.

## Pre-checks (refuse to start if any fails)

- `plans/<PLAN-ID>/index.md` exists.
- `plans/<PLAN-ID>/delta-draft.md` exists.
- Every `plans/<PLAN-ID>/t*.md` (excluding `handoff-*`) has `status: done` in the frontmatter.

If any check fails, surface to the user — don't auto-fix.

## Phase 1 — validate and absorb into specs

1. **Read and validate the delta-draft.** Open `plans/<PLAN-ID>/delta-draft.md`. Verify:
   - Every EARS / RFC 2119 criterion from the plan's `## Acceptance Criteria` is covered by an Added or Modified Requirement (or explicitly noted as not requiring a spec change).
   - The proposed changes are consistent with the plan's `scope:`.
   - No `Removed Requirements` orphan a `depends-on:` from another spec.
2. **For each spec area in the plan's `scope:` frontmatter:**
   - Edit `specs/<area>/index.md` body to reflect the new state (per the validated delta-draft).
   - Append `<PLAN-ID>` to the area's `deltas:` frontmatter list.
   - Re-emit the area's row in `specs/index.md` via `cumaru tag get specs/index.md specs` → update Description → `cumaru tag set specs/index.md specs <new body>`.
3. **Handle ghost deltas** (delta says "no spec change required"): skip step 2 for spec edits; still record in deltas if the plan had scope.

## Phase 2 — clean up the plan files

1. Delete `plans/<PLAN-ID>/delta-draft.md` (the draft is consumed — the absorption is the record).
2. **Remove or keep the plan directory:**
   - If the plan directory is no longer useful as a record → `cumaru flow plans/<PLAN-ID> remove`.
   - If it should stay as a record → update `plans/<PLAN-ID>/index.md` frontmatter: `status: done`.

## Phase 3 — re-emit plans/index.md

1. Update `plans/index.md`:
   - If the plan dir was removed → remove the row via `cumaru tag set plans/index.md plans <new body without the row>`.
   - If the plan was kept with `status: done` → update the row's Description to reflect completed state.
2. Run `cumaru doctor`:
   - Orphan check: spec rows should resolve; removed plan row should be gone.
   - File refs: spec `deltas:` entries should reference the plan (even if removed, the row in `plans/index.md` may still reference it).

## Why phased

Phase 1 is the core: the spec state is updated and the plan's contribution is permanently recorded in `deltas:`. Phase 2 cleans up intermediate artifacts. Phase 3 brings the indexes in sync. Unlike archive-based flows, there is no `archive/` pillar — the absorption commit (if git is used) and the spec's `deltas:` are the durable record.

## Patterns

| User says | You do |
|---|---|
| "Absorb AAA-1234" / "close plan X" / "finalize plan X" | Run all 3 phases on `<PLAN-ID>=AAA-1234`, with confirmation between phases |
| "Finalize but keep the plan dir" | Phase 1 → Phase 2 (keep dir, update status: done) → Phase 3 |

Use `cumaru tag get/set` (CLI, no skill) for marker-block round-trip on `plans/index.md` and `specs/index.md`; pair with `cumaru-doctor` to verify cleanness post-absorb.
