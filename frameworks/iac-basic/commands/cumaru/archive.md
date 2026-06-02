---
version: 1
description: Close a changeset — move `plans/<KEY>/` into `archive/<KEY>/`, absorb its delta into the relevant `topology/` areas, and clean up. Drives the `cumaru-archive` skill.
allowed-tools: Bash, Read, Edit, Write
argument-hint: <PLAN-ID>
---

Argument: `$ARGUMENTS` is the plan ID (`AAA-1234` or `maintenance-<slug>`). If empty, ask the user which changeset to close — and confirm the change has been **applied through its promotion path** (or the remaining environments are explicitly out of this close).

1. **Read the `cumaru-archive` skill** from the installed agent skills directory (`.agents/skills/cumaru-archive/SKILL.md` for Claude or `.agents/skills/cumaru-archive/SKILL.md` for Codex). It carries the 3-phase recipe (move + absorb / remove plan tree / re-emit indexes + verify), the pre-checks (including the apply/promotion verification), and the rationale for phasing (Phase 1 is non-destructive; Phase 2 is irreversible).

2. **Pre-check.** Run the skill's pre-checks on `plans/$ARGUMENTS/`:
   - `plans/$ARGUMENTS/index.md` exists.
   - `plans/$ARGUMENTS/delta-draft.md` exists.
   - Every `plans/$ARGUMENTS/t*.md` (excluding `handoff-*`) has `status: done`.
   - The change has been applied through its `## Promotion path`.
   - `archive/$ARGUMENTS/` does **not** exist yet.

   Surface any failure verbatim and stop — don't auto-fix. If `delta-draft.md` is missing, suggest `/cumaru:plan $ARGUMENTS` to write it first.

3. **Confirm with the user.** Print a one-paragraph summary: the changeset's `summary:`, `scope:` (which topology areas it touches), tasks (`N/N done`), the environments it landed in, and the proposed sequence (Phase 1 → Phase 2 → Phase 3). Ask `walk` (confirm between phases) or `apply` (run all three with one confirmation upfront).

4. **Run Phase 1** (non-destructive — copies + frontmatter updates):
   - `cumaru flow plans/$ARGUMENTS/index.md copy archive/$ARGUMENTS/index.md`
   - `cumaru flow plans/$ARGUMENTS/delta-draft.md move archive/$ARGUMENTS/delta.md`
   - For each `handoff-t<N>.md`: copy into `archive/$ARGUMENTS/`.
   - Mutate `archive/$ARGUMENTS/index.md` frontmatter: `status: done`, add `completed-at: <ISO datetime>`, add `delta: delta.md`.
   - Refine `archive/$ARGUMENTS/delta.md`: drop `status: draft`, tighten wording, verify it covers the change's acceptance criteria.
   - For each topology area in the plan's `scope:`: edit `topology/<area>/index.md` body to reflect the new state of the stack (interface / depends-on / decisions / cost-security as changed); append `$ARGUMENTS` to `deltas:` frontmatter; re-emit `topology/index.md` row via `cumaru tag set`.

   Stop here if `walk` and reconfirm before Phase 2.

5. **Run Phase 2** (irreversible) — confirm `archive/$ARGUMENTS/delta.md` no longer carries `status: draft`, then `cumaru flow plans/$ARGUMENTS remove`.

6. **Run Phase 3** — re-emit `archive/index.md` row via `cumaru tag set archive/index.md archive <new body>`. Run `cumaru doctor` and report: orphan check should be clean (the row at `plans/$ARGUMENTS/` is gone; new row at `archive/$ARGUMENTS/` resolves); file refs check should find `delta: delta.md`.

Hard rules:

- **Never skip Phase 1's topology absorption.** Every area in `scope:` gets its `deltas:` updated and its body refined — otherwise the archive is a tombstone disconnected from the living topology.
- **Phase 2 is irreversible.** Only run it after the user (or your confidence) is solid on Phase 1's content.
- **Re-emit every affected index** (`archive/index.md`, `topology/index.md`, plan's row disappearance) via `cumaru tag set` before declaring done.
- **Don't touch the original `plans/$ARGUMENTS/` until Phase 2.** Phase 1 only COPIES; if anything goes wrong you delete `archive/$ARGUMENTS/` and start over.
- **Verify the change actually applied.** A changeset never archives mid-promotion — apply through all declared environments first, or amend the plan's `## Promotion path` to scope the close honestly.
