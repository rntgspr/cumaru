# `llm archive`

Two-phase plan closure. Closes a plan, copies its artifacts to `archive/`, scaffolds an LLM-driven absorption step, and removes the plan tree on finalize.

## Usage

```
llm archive <PLAN-ID>            # Phase 1 — prepare
llm archive finalize <PLAN-ID>   # Phase 2 — finalize
```

## Phase 1 — Prepare

Run when the Dev has finished implementing the plan and written `delta-draft.md`.

**Pre-checks:**
- `plans/<PLAN-ID>/` exists.
- Every `t<N>.md` (excluding `handoff-*.md`) has `status: done`.
- `plans/<PLAN-ID>/delta-draft.md` exists.
- `archive/<PLAN-ID>/` does **not** already exist.

**What happens:**
1. Creates `archive/<PLAN-ID>/`.
2. Copies `delta-draft.md` → `archive/<PLAN-ID>/delta.md`.
3. Copies the plan's `index.md` and updates its frontmatter: `status: done`, `completed-at: <now>`, `delta: delta.md`.
4. Copies all `handoff-t<N>.md` files.
5. Writes `archive/<PLAN-ID>/temp-archive-flow.delete-me.md` — a step-by-step work file for the LLM:
   - Refine `delta.md` (drop `status: draft`, tighten wording, verify EARS coverage).
   - Absorb the delta into each `specs/<area>/` listed in the plan's `scope:` (update body + append plan ID to the spec's `deltas:` list).
   - Delete `plans/<PLAN-ID>/delta-draft.md`.
   - Delete the work file itself.

The original `plans/<PLAN-ID>/` is **kept** through Phase 1 — safe to retry if anything fails.

## Phase 2 — Finalize

Run after the LLM has completed the absorption work.

**Pre-checks:**
- `archive/<PLAN-ID>/` exists.
- `temp-archive-flow.delete-me.md` is gone.
- `archive/<PLAN-ID>/delta.md` no longer carries `status: draft`.

**What happens:**
- Removes `plans/<PLAN-ID>/` entirely.
- (If `delta-draft.md` still lingers in `plans/`, removes it.)

## Examples

```bash
llm archive JET-1234                  # Phase 1
# ...LLM follows temp-archive-flow.delete-me.md instructions...
llm archive finalize JET-1234         # Phase 2
```

## Notes

- The two phases are intentionally separate: Phase 1 is deterministic (file moves, frontmatter rewrites); Phase 2 is gated by the LLM successfully refining and absorbing the delta.
- Slug-based plans (`maintenance-<slug>/`) work the same way — pass the slug as `<PLAN-ID>`.

## Related

- [`llm regen index`](regen.md) — refresh `plans/index.md` and `archive/index.md` after archiving.
- [`llm doctor`](doctor.md) — flags lingering work files and orphan delta drafts as part of the consolidated health check.
