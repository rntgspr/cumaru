---
version: 1
description: Close a changeset — move `plans/<KEY>/` into `archive/<KEY>/`, absorb its delta into the relevant `topology/` areas, and clean up. Drives the `cumaru-archive` skill.
allowed-tools: Bash, Read, Edit, Write
argument-hint: <PLAN-ID>
summary: Close a changeset — move `plans/<KEY>/` into `archive/<KEY>/`, absorb its delta into the relevant `topology/` areas, and clean up. Drives the `cumaru-archive` skill.
---

Argument: `$ARGUMENTS` is the plan ID (`AAA-1234` or `maintenance-<slug>`). If empty, ask the user which changeset to close — and confirm the change has been **applied through its promotion path** (or the remaining environments are explicitly out of this close).

1. **Load the installed `cumaru-archive` skill.** It carries the four-phase recipe: prepare absorption, remove the plan tree, verify the projection, then commit the absorption and prune archive staging.

2. **Pre-check.** Run the skill's pre-checks on `plans/$ARGUMENTS/`:
   - `plans/$ARGUMENTS/index.md` exists.
   - `plans/$ARGUMENTS/delta-draft.md` exists.
   - Every `plans/$ARGUMENTS/t*.md` (excluding `handoff-*`) has `status: done`.
   - The change has been applied through its `## Promotion path`.
   - `archive/$ARGUMENTS/` does **not** exist yet.

   Surface any failure verbatim and stop — don't auto-fix. If `delta-draft.md` is missing, suggest `/cumaru:plan $ARGUMENTS` to write it first.

3. **Confirm with the user.** Print a one-paragraph summary: the changeset's `summary:`, `scope:` (which topology areas it touches), tasks (`N/N done`), the environments it landed in, and the proposed sequence (Phase 0 → Phase 1 → Phase 2 → Phase 3). Ask `walk` (confirm between phases) or `apply` (run all three with one confirmation upfront).

4. **Run Phase 0 — discover where the delta belongs.** Run `cumaru tree topology --rows` for the complete area list, then `cumaru tree topology/<area> --deep --rows` only for the areas you select — never `--deep` on the whole pillar, which does not scale. Adjudicate every durable claim in `delta.md` against those areas by their `summary:`. Exact fit → that area is the target; no fit → create a new one via `cumaru-topology`. `scope:` is a hint to validate, not the authority — surface any mismatch to the user and let them choose before continuing.

5. **Run Phase 1** (non-destructive — copies + frontmatter updates):
   - `cumaru flow plans/$ARGUMENTS/index.md copy archive/$ARGUMENTS/index.md`
   - `cumaru flow plans/$ARGUMENTS/delta-draft.md move archive/$ARGUMENTS/delta.md`
   - For each `handoff-t<N>.md`: copy into `archive/$ARGUMENTS/`.
   - Mutate `archive/$ARGUMENTS/index.md` frontmatter: `status: done`, add `completed-at: <ISO datetime>`, add `delta: delta.md`.
   - Refine `archive/$ARGUMENTS/delta.md`: drop `status: draft`, tighten wording, verify it covers the change's acceptance criteria.
   - For each target area discovered above: edit `topology/<area>/index.md` to reflect the new state and keep `summary:` accurate.

   Stop here if `walk` and reconfirm before Phase 2.

6. **Run Phase 2** (irreversible) — confirm `archive/$ARGUMENTS/delta.md` no longer carries `status: draft`, then `cumaru flow plans/$ARGUMENTS remove`.

7. **Run Phases 3 and 4** — verify with `cumaru tree archive --rows`; commit the topology absorption with a message naming every KEY absorbed (it is the grep key that replaces the old ledger); prune `archive/$ARGUMENTS/`; commit cleanup; then run `cumaru tree topology --rows` and `cumaru doctor`.

Hard rules:

- **Never skip Phase 0 or Phase 1's absorption.** Every discovered target area gets its body refined — otherwise the archive is a tombstone disconnected from the living topology.
- **Phase 2 is irreversible.** Only run it after the user (or your confidence) is solid on Phase 1's content.
- **No structural rows and no ledger.** Navigation comes from `cumaru tree`; the durable record is the pillar itself.
- **Don't touch the original `plans/$ARGUMENTS/` until Phase 2.** Phase 1 only COPIES; if anything goes wrong you delete `archive/$ARGUMENTS/` and start over.
- **Verify the change actually applied.** A changeset never archives mid-promotion — apply through all declared environments first, or amend the plan's `## Promotion path` to scope the close honestly.
