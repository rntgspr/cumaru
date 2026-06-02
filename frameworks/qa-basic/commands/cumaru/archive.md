---
version: 1
description: Close a test campaign — move `plans/<KEY>/` into `archive/<KEY>/`, absorb its delta into the relevant `coverage/` areas, and clean up. Drives the `cumaru-archive` skill.
allowed-tools: Bash, Read, Edit, Write
argument-hint: <PLAN-ID>
---

Argument: `$ARGUMENTS` is the campaign ID (`AAA-1234` or `maintenance-<slug>`). If empty, ask the user which campaign to close — and confirm every case is authored, automated, and passing.

1. **Read the `cumaru-archive` skill** from the installed agent skills directory (`.agents/skills/cumaru-archive/SKILL.md` for Claude or `.agents/skills/cumaru-archive/SKILL.md` for Codex). It carries the 3-phase recipe (move + absorb / remove plan tree / re-emit indexes + verify), the pre-checks, and the rationale for phasing (Phase 1 is non-destructive; Phase 2 is irreversible).

2. **Pre-check.** Run the skill's pre-checks on `plans/$ARGUMENTS/`:
   - `plans/$ARGUMENTS/index.md` exists.
   - `plans/$ARGUMENTS/delta-draft.md` exists.
   - Every `plans/$ARGUMENTS/t*.md` (excluding `handoff-*`) has `status: done`.
   - Every authored case is passing in CI (non-flaky).
   - `archive/$ARGUMENTS/` does **not** exist yet.

   Surface any failure verbatim and stop — don't auto-fix. If `delta-draft.md` is missing, suggest `/cumaru:plan $ARGUMENTS` to write it first.

3. **Confirm with the user.** Print a one-paragraph summary: the campaign's `summary:`, `scope:` (which coverage areas it touches), cases (`N/N done`), the test levels involved, and the proposed sequence (Phase 1 → Phase 2 → Phase 3). Ask `walk` (confirm between phases) or `apply` (run all three with one confirmation upfront).

4. **Run Phase 1** (non-destructive — copies + frontmatter updates):
   - `cumaru flow plans/$ARGUMENTS/index.md copy archive/$ARGUMENTS/index.md`
   - `cumaru flow plans/$ARGUMENTS/delta-draft.md move archive/$ARGUMENTS/delta.md`
   - For each `handoff-t<N>.md`: copy into `archive/$ARGUMENTS/`.
   - Mutate `archive/$ARGUMENTS/index.md` frontmatter: `status: done`, add `completed-at: <ISO datetime>`, add `delta: delta.md`.
   - Refine `archive/$ARGUMENTS/delta.md`: drop `status: draft`, tighten wording, verify it captures `### Added / Modified / Removed Scenarios` and `### Levels / Gaps changed` for every affected area.
   - For each coverage area in the plan's `scope:`: edit `coverage/<area>/index.md` body to reflect the new state (scenarios covered, level distribution, residual gaps); append `$ARGUMENTS` to `deltas:` frontmatter; re-emit `coverage/index.md` row via `cumaru tag set`.

   Stop here if `walk` and reconfirm before Phase 2.

5. **Run Phase 2** (irreversible) — confirm `archive/$ARGUMENTS/delta.md` no longer carries `status: draft`, then `cumaru flow plans/$ARGUMENTS remove`.

6. **Run Phase 3** — re-emit `archive/index.md` row via `cumaru tag set archive/index.md archive <new body>`. Run `cumaru doctor` and report: orphan check should be clean; file refs check should find `delta: delta.md`.

Hard rules:

- **Never skip Phase 1's coverage absorption.** Every area in `scope:` gets its `deltas:` updated and its body refined — otherwise the archive is a tombstone disconnected from the living coverage map.
- **Phase 2 is irreversible.** Only run it after the user (or your confidence) is solid on Phase 1's content.
- **Re-emit every affected index** (`archive/index.md`, `coverage/index.md`, plan's row disappearance) via `cumaru tag set` before declaring done.
- **Don't touch the original `plans/$ARGUMENTS/` until Phase 2.** Phase 1 only COPIES; if anything goes wrong you delete `archive/$ARGUMENTS/` and start over.
- **Reference `standards/` instead of restating conventions.** Coverage area bodies cite the standards that govern them; they don't re-author the rules.
