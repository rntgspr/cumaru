---
version: 1
description: Close a plan — move `plans/<KEY>/` into `archive/<KEY>/`, absorb its delta into `specs/`, and clean up. Drives the `cumaru-archive` skill.
allowed-tools: Bash, Read, Edit, Write
argument-hint: <PLAN-ID>
summary: Close a plan — move `plans/<KEY>/` into `archive/<KEY>/`, absorb its delta into `specs/`, and clean up. Drives the `cumaru-archive` skill.
---

Argument: `$ARGUMENTS` is the plan ID (`AAA-1234` or `maintenance-<slug>`). If empty, ask the user which plan to close — and confirm the plan is genuinely ready (all tasks done, handoffs present, delta-draft written).

1. **Read the `cumaru-archive` skill** from the installed agent skills directory (`.agents/skills/cumaru-archive/SKILL.md` for Claude or `.agents/skills/cumaru-archive/SKILL.md` for Codex). It carries the 3-phase recipe (move + absorb / remove plan tree / record absorption + clean archive), the pre-checks, and the rationale for phasing (Phase 1 is non-destructive; Phase 2 is irreversible).

2. **Pre-check.** Run the skill's pre-checks on `plans/$ARGUMENTS/`:
   - `plans/$ARGUMENTS/index.md` exists.
   - `plans/$ARGUMENTS/delta-draft.md` exists.
   - Every `plans/$ARGUMENTS/t*.md` (excluding `handoff-*`) has `status: done`.
   - `archive/$ARGUMENTS/` does **not** exist yet.

   Surface any failure verbatim and stop — don't auto-fix. If `delta-draft.md` is missing, suggest `/cumaru:plan $ARGUMENTS` to write it first.

3. **Confirm with the user.** Print a one-paragraph summary: the plan's `summary:`, `scope:` (which spec areas it touches), tasks (`N/N done`), and the proposed sequence (Phase 1 → Phase 2 → Phase 3). Ask `walk` (confirm between phases) or `apply` (run all three with one confirmation upfront).

4. **Run Phase 1** (non-destructive — copies + frontmatter updates):
   - `cumaru flow plans/$ARGUMENTS/index.md copy archive/$ARGUMENTS/index.md`
   - `cumaru flow plans/$ARGUMENTS/delta-draft.md move archive/$ARGUMENTS/delta.md`
   - For each `handoff-t<N>.md`: copy into `archive/$ARGUMENTS/`.
   - Mutate `archive/$ARGUMENTS/index.md` frontmatter: `status: done`, add `completed-at: <ISO datetime>`, add `delta: delta.md`.
   - Refine `archive/$ARGUMENTS/delta.md`: drop `status: draft`, tighten wording, verify requirements coverage.
   - For each spec area in the plan's `scope:`: edit `specs/<area>/index.md` to reflect the new state, append `$ARGUMENTS` to `deltas:`, and keep `summary:` accurate.

   Stop here if `walk` and reconfirm before Phase 2.

5. **Run Phase 2** (irreversible) — confirm `archive/$ARGUMENTS/delta.md` no longer carries `status: draft`, then `cumaru flow plans/$ARGUMENTS remove`.

6. **Run Phase 3** — commit the spec absorption, capture the SHA, append `SHA | KEY | Description` to `specs/index.md` `cumaru:absorptions`, remove `archive/$ARGUMENTS/`, commit cleanup, then run `cumaru doctor`.

Hard rules:

- **Never skip Phase 1's spec absorption.** The plan's `scope:` paths each get their `deltas:` updated and their body refined — otherwise the archive is a tombstone disconnected from the living spec.
- **Phase 2 is irreversible.** Only run it after the user (or your confidence) is solid on Phase 1's content.
- **No structural rows.** Navigation comes from `cumaru tree`; only the specs absorption ledger is persisted.
- **Don't touch the original `plans/$ARGUMENTS/` until Phase 2.** Phase 1 only COPIES; if anything goes wrong you delete `archive/$ARGUMENTS/` and start over.
