---
human_revised: false
version: 1
name: cumaru-archive
description: Use this skill whenever the user wants to close, finalize, or archive a plan in the project — move `plans/<KEY>/` into `archive/<KEY>/`, absorb the delta into the relevant spec areas, and clean up the working tree. Trigger on phrases like "archive this plan", "close AAA-1234", "finalize the plan", "arquivar o plano", "promote draft to delta", or any task that frames the work as ending a plan's lifecycle. Skill is sdlc-domain-only — it knows the pillar layout (`plans/`, `archive/`, `specs/`). For raw file ops, use the `cumaru flow` command directly.
---

# `cumaru-archive` — close a plan and absorb its delta

End-to-end recipe to close a `plans/<KEY>/`. Combines `cumaru flow` (file ops) + `cumaru tag` (re-emit the `archive/index.md` and `specs/<area>/index.md` tables) + Edit (frontmatter, prose).

## Pre-checks (refuse to start if any fails)

- `plans/<KEY>/index.md` exists.
- `plans/<KEY>/delta-draft.md` exists.
- Every `plans/<KEY>/t*.md` (excluding `handoff-*`) has `status: done` in the frontmatter.
- `archive/<KEY>/` does **not** exist yet.
- `git` skill is installed (Phase 4 needs mutating `git add` / `git commit`). If absent, refuse with: "Phase 4 needs `--with git`. Re-install with `cumaru install --with git` or finish Phase 1–3 manually and skip Phase 4."

If any check fails, surface to the user — don't auto-fix.

## Phase 1 — move into archive/ and prepare the absorption work

1. `cumaru flow plans/<KEY>/index.md copy archive/<KEY>/index.md`
2. `cumaru flow plans/<KEY>/delta-draft.md move archive/<KEY>/delta.md`
3. For each `plans/<KEY>/handoff-t<N>.md`: `cumaru flow plans/<KEY>/handoff-t<N>.md copy archive/<KEY>/handoff-t<N>.md`
4. Mutate `archive/<KEY>/index.md` frontmatter (use Edit; `cumaru tag` if a marker block is involved):
   - `status: done`
   - add `completed-at: <ISO datetime>`
   - add `delta: delta.md`
5. Refine `archive/<KEY>/delta.md`: drop `status: draft`, tighten wording, verify EARS coverage.
6. For each spec area in the plan's `scope:` frontmatter:
   - Edit `specs/<area>/index.md` body to reflect the new state.
   - Append `<KEY>` to the area's `deltas:` frontmatter list.
   - Re-emit the area's row in `specs/index.md` via `cumaru tag get specs/index.md specs` → update Description (v4 shape: `| [<area>](<area>/index.md) | <one-line> |`) → `cumaru tag set specs/index.md specs <new body>`.

## Phase 2 — remove the original plan tree

Confirm `archive/<KEY>/delta.md` no longer carries `status: draft`. Then:

```bash
cumaru flow plans/<KEY> remove
```

(The `cumaru flow` guardrail allows this — `plans/<KEY>/` is an entity dir, not the pillar root itself.)

## Phase 3 — re-emit archive/index.md row + verify

1. Add the row to `archive/<KEY>` in `archive/index.md` via `cumaru tag set archive/index.md archive <new body>` — v4 shape: `| [<KEY>](<KEY>/index.md) | <one-line summary of what shipped, plus apps if relevant> |`. The absorbed commit SHA is appended to the Description in Phase 4 (e.g. "— absorbed in 3f1c2ab").
2. Run `cumaru doctor`:
   - Orphan check: row pointing at `plans/<KEY>/` should be gone; new row in `archive/` should resolve to the in-flight `archive/<KEY>/` directory.
   - File refs: `delta: delta.md` should resolve.

## Phase 4 — Commit absorption and prune archive directory

After Phase 3, the spec(s) carry the absorbed delta and `archive/index.md`
has the new row. Commit and prune the directory; the row + commit SHA
become the durable record.

1. Stage and commit the absorption:
   ```bash
   git add specs/ archive/ plans/
   git commit -m "chore(.cumaru): absorb <KEY> delta into <areas>"
   ```
2. Capture the commit SHA: `git rev-parse HEAD`.
3. Re-emit the `<KEY>` row in `archive/index.md` with the absorbed commit SHA appended to the Description
   (e.g. `… — absorbed in 3f1c2ab`) via `cumaru tag set archive/index.md archive <new body>`.
4. Prune the directory and commit:
   ```bash
   cumaru flow archive/<KEY> remove
   git add archive/
   git commit -m "chore(.cumaru): prune archive/<KEY>/ post-absorption"
   ```
5. Run `cumaru doctor` — should report no orphans.

**Ghost deltas** (delta declared "no spec change required"): the Description
ends with `… — absorbed in <sha> (no spec change)` and the directory is
still pruned.

## Why phased

Phase 1 is *non-destructive* (copies + frontmatter updates) so a mistake is recoverable just by deleting `archive/<KEY>/`. Phase 2 removes the source plan tree — recoverable from git, but disruptive. Phase 4 is the **final irreversible step**: the absorption commit + directory prune means `archive/<KEY>/` no longer exists on disk; from that point on, the row in `archive/index.md` + the commit SHA are the durable record.

## Companion ops (no skill needed — these are 1-2 line operations)

### Promote an exploration to a plan

When an exploration matures into committed work:

```bash
cumaru flow exploring/<slug>          copy   plans/maintenance-<slug>
# OR (if you want to discard the exploration after promotion)
cumaru flow exploring/<slug>          remove
# Then edit plans/maintenance-<slug>/index.md to add plan frontmatter (scope, status, summary, …)
# and re-emit plans/index.md row via cumaru tag.
```

### Rename a plan key (rare)

```bash
cumaru flow plans/<old>  move  plans/<new>
# Then in plans/<new>/index.md, update `key:` in frontmatter (Edit).
# Then in any spec area's deltas: list, replace <old> with <new> (Edit + cumaru tag for the spec table).
# Then cumaru doctor — orphan check should be clean.
```

### Prune already-absorbed archives (retroactive migration)

One-shot recipe to bring a project with pre-existing archives into the
ephemeral lifecycle. Run after `cumaru update --apply` brings the updated
skill into the consumer repo.

For each row in `archive/index.md` table without `Absorbed-in:`:

1. **Verify spec absorption.** Scan `specs/` for `<KEY>` in any area's
   `deltas:` frontmatter:
   ```bash
   grep -rn "<KEY>" specs/ | grep "deltas:" -A0
   ```
   - Found → record the spec path; proceed.
   - Not found AND plan's `scope:` was non-empty → surface to user and
     stop (ghost delta? unabsorbed? manual review).
   - Not found AND plan's `scope:` was empty (or `delta.md` says "no spec
     change required") → ghost delta path; skip the spec scan.
2. **Locate the absorbing commit.**
   - For absorbed plans:
     ```bash
     git log --diff-filter=AM -p -S "<KEY>" -- specs/ | head -40
     ```
     Take the first commit that added `<KEY>` to a `deltas:` list. That's
     `<absorbed-in>`.
   - For ghost deltas:
     ```bash
     git log -p -- archive/index.md | grep -B3 "<KEY>"
     ```
     Take the commit that added the row.
3. **Update the row** with `Absorbed-in: <sha>` (or
   `<sha> (no spec change)` for ghosts) via `cumaru tag set`.
4. **Prune the directory**: `cumaru flow archive/<KEY> remove`.
5. Commit per batch or per `<KEY>` (user preference, default: batch of
   10 per commit, message
   `chore(.cumaru): prune <N> already-absorbed archives`).

## Patterns

| User says | You do |
|---|---|
| "Archive AAA-1234" / "close plan X" / "finalize plan X" | Run all 4 phases above on `<KEY>=AAA-1234`, with confirmation between Phase 1 and Phase 2, and again before Phase 4 (irreversible prune) |
| "Promote `exploring/auth-redesign` to a plan" | Companion op: copy → write plan frontmatter → re-emit plans table |
| "Rename plan AAA-1234 to AAA-9999" | Companion op: move + update `key:` + fix `deltas:` refs |

Use `cumaru tag get/set` (CLI, no skill) for marker-block round-trip on `specs/index.md` and `archive/index.md`; pair with `cumaru-doctor` to verify cleanness post-archive.
