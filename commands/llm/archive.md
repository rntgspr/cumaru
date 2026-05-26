---
description: Close a plan — move `plans/<KEY>/` into `archive/<KEY>/`, absorb its delta into `specs/`, and clean up. Drives the `llm-archive` skill.
allowed-tools: Bash, Read, Edit, Write
argument-hint: <PLAN-ID>
---

Argument: `$ARGUMENTS` is the plan ID (`JET-1234` or `maintenance-<slug>`). If empty, ask the user which plan to close — and confirm the plan is genuinely ready (all tasks done, handoffs present, delta-draft written).

1. **Read the `llm-archive` skill** at `.llm/skills/llm-archive/SKILL.md`. It carries the 3-phase recipe (move + absorb / remove plan tree / re-emit indexes + verify), the pre-checks, and the rationale for phasing (Phase 1 is non-destructive; Phase 2 is irreversible).

2. **Pre-check.** Run the skill's pre-checks on `plans/$ARGUMENTS/`:
   - `plans/$ARGUMENTS/index.md` exists.
   - `plans/$ARGUMENTS/delta-draft.md` exists.
   - Every `plans/$ARGUMENTS/t*.md` (excluding `handoff-*`) has `status: done`.
   - `archive/$ARGUMENTS/` does **not** exist yet.

   Surface any failure verbatim and stop — don't auto-fix. If `delta-draft.md` is missing, suggest `/llm:plan $ARGUMENTS` to write it first.

3. **Confirm with the user.** Print a one-paragraph summary: the plan's `summary:`, `scope:` (which spec areas it touches), tasks (`N/N done`), and the proposed sequence (Phase 1 → Phase 2 → Phase 3). Ask `walk` (confirm between phases) or `apply` (run all three with one confirmation upfront).

4. **Run Phase 1** (non-destructive — copies + frontmatter updates):
   - `llm flow plans/$ARGUMENTS/index.md copy archive/$ARGUMENTS/index.md`
   - `llm flow plans/$ARGUMENTS/delta-draft.md move archive/$ARGUMENTS/delta.md`
   - For each `handoff-t<N>.md`: copy into `archive/$ARGUMENTS/`.
   - Mutate `archive/$ARGUMENTS/index.md` frontmatter: `status: done`, add `completed-at: <ISO datetime>`, add `delta: delta.md`.
   - Refine `archive/$ARGUMENTS/delta.md`: drop `status: draft`, tighten wording, verify EARS coverage.
   - For each spec area in the plan's `scope:`: edit `specs/<area>/index.md` body to reflect the new state; append `$ARGUMENTS` to `deltas:` frontmatter; re-emit `specs/index.md` row via `llm tag set`.

   Stop here if `walk` and reconfirm before Phase 2.

5. **Run Phase 2** (irreversible) — confirm `archive/$ARGUMENTS/delta.md` no longer carries `status: draft`, then `llm flow plans/$ARGUMENTS remove`.

6. **Run Phase 3** — re-emit `archive/index.md` row via `llm tag set archive/index.md archive <new body>`. Run `llm doctor` and report: orphan check should be clean (the row at `plans/$ARGUMENTS/` is gone; new row at `archive/$ARGUMENTS/` resolves); file refs check should find `delta: delta.md`.

Hard rules:

- **Never skip Phase 1's spec absorption.** The plan's `scope:` paths each get their `deltas:` updated and their body refined — otherwise the archive is a tombstone disconnected from the living spec.
- **Phase 2 is irreversible.** Only run it after the user (or your confidence) is solid on Phase 1's content.
- **Re-emit every affected index** (`archive/index.md`, `specs/index.md`, and `plans/index.md` row disappearance) via `llm tag set` before declaring done.
- **Don't touch the original `plans/$ARGUMENTS/` until Phase 2.** Phase 1 only COPIES; if anything goes wrong you delete `archive/$ARGUMENTS/` and start over.
