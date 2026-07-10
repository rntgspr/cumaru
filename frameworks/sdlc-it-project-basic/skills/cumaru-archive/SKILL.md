---
human_revised: false
version: 1
name: cumaru-archive
description: Use this skill whenever the user wants to close, finalize, or archive a plan in the project — move `plans/<KEY>/` into transient `archive/<KEY>/`, absorb the delta into specs, record the absorption in `specs/index.md`, and clean up archive/plans. Trigger on phrases like "archive this plan", "close AAA-1234", "finalize the plan", "arquivar o plano", "promote draft to delta", or any task that frames the work as ending a plan's lifecycle. Skill is sdlc-domain-only — it knows the pillar layout (`plans/`, `archive/`, `specs/`). For raw file ops, use the `cumaru flow` command directly.
---

# `cumaru-archive` — close a plan and absorb its delta

End-to-end recipe to close a `plans/<KEY>/`. `archive/` is transient staging: the durable result is the updated `specs/` tree plus the `specs/index.md` `cumaru:absorptions` row (`SHA | KEY | Description`). Combines `cumaru flow` (file ops) + `cumaru tag` (re-emit index tables) + Edit (frontmatter, prose).

## Pre-checks (refuse to start if any fails)

- `plans/<KEY>/index.md` exists.
- `plans/<KEY>/delta-draft.md` exists.
- Every `plans/<KEY>/t*.md` (excluding `handoff-*`) has `status: done` in the frontmatter.
- `archive/<KEY>/` does **not** exist yet.
- `git` skill is installed (final absorption needs `git add` / `git commit` to produce the SHA recorded in `specs/index.md`). If absent, refuse with: "Archive absorption needs `--with git` to record the absorption SHA. Re-install with `cumaru install --with git` or finish the absorption manually and leave a placeholder SHA only with user approval."

If any check fails, surface to the user — don't auto-fix.

## Phase 1 — move into archive/ and prepare the absorption work

1. `cumaru flow plans/<KEY>/index.md copy archive/<KEY>/index.md`
2. `cumaru flow plans/<KEY>/delta-draft.md move archive/<KEY>/delta.md`
3. For each `plans/<KEY>/handoff-t<N>.md`: `cumaru flow plans/<KEY>/handoff-t<N>.md copy archive/<KEY>/handoff-t<N>.md`
4. Mutate `archive/<KEY>/index.md` frontmatter (use Edit; `cumaru tag` if a marker block is involved):
   - `status: done`
   - add `completed-at: <ISO datetime>`
   - add `delta: delta.md`
5. Refine `archive/<KEY>/delta.md`: drop `status: draft`, tighten wording, verify requirements coverage.
6. Add an in-flight row in `archive/index.md` via `cumaru tag set archive/index.md archive <new body>` — v5 default shape: `| [<KEY>](<KEY>/index.md) | <one-line summary of what is being absorbed> |`.
7. For each spec area in the plan's `scope:` frontmatter:
    - Edit `specs/<area>/index.md` body to reflect the new state.
    - Append `<KEY>` to the area's `deltas:` frontmatter list.
    - Re-emit the area's row in `specs/index.md` via `cumaru tag get specs/index.md specs` → update Description (default shape: `| [<area>](<area>/index.md) | <one-line> |`) → `cumaru tag set specs/index.md specs <new body>`.

## Phase 2 — remove the original plan tree

Confirm `archive/<KEY>/delta.md` no longer carries `status: draft`. Then:

```bash
cumaru flow plans/<KEY> remove
```

(The `cumaru flow` guardrail allows this — `plans/<KEY>/` is an entity dir, not the pillar root itself.)

## Phase 3 — commit absorption, record it in specs/, and clean archive/

After Phase 2, the source plan is gone and `archive/<KEY>/` is the in-flight close-out workspace. The durable end state is specs + the absorptions ledger; archive must be empty for this plan.

1. Run `cumaru doctor` before commit:
   - Orphan check: row pointing at `plans/<KEY>/` should be gone; the in-flight row in `archive/` should resolve to `archive/<KEY>/`.
   - File refs: `delta: delta.md` should resolve while the archive directory exists.
2. Stage and commit the spec absorption:
   ```bash
   git add specs/ archive/ plans/
   git commit -m "chore(.cumaru): absorb <KEY> delta into <areas>"
   ```
3. Capture the commit SHA: `git rev-parse HEAD`.
4. Re-emit the `cumaru:absorptions` table in `specs/index.md` via `cumaru tag get specs/index.md absorptions` → append `| <sha> | <KEY> | <one-line summary of what became durable> |` → `cumaru tag set specs/index.md absorptions <new body>`.
5. Remove the `<KEY>` row from `archive/index.md` via `cumaru tag set archive/index.md archive <new body>`.
6. Prune the archive directory and commit the ledger/cleanup:
   ```bash
   cumaru flow archive/<KEY> remove
   git add specs/index.md archive/
   git commit -m "chore(.cumaru): record <KEY> absorption"
   ```
7. Run `cumaru doctor` — should report no orphans. `archive/index.md` must not contain `<KEY>`, and `archive/<KEY>/` must not exist.

**Ghost deltas** (delta declared "no spec change required"): still record a `specs/index.md` `absorptions` row with the SHA and Description ending in `(no spec change)`, then remove the archive row and directory.

## Why phased

Phase 1 is *non-destructive* (copies + frontmatter updates) so a mistake is recoverable by deleting `archive/<KEY>/` and restoring the plan row. Phase 2 removes the source plan tree — recoverable from git, but disruptive. Phase 3 is final: specs become the durable truth and `specs/index.md` records the SHA/KEY/Description absorption ledger; archive leaves no residue for `<KEY>`.

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

### Migrate already-absorbed archives to specs absorptions

One-shot recipe to bring a project with pre-existing archive rows into the
transient archive lifecycle. Run after `cumaru update --apply` brings the
updated skill into the consumer repo.

For each row in `archive/index.md`:

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
3. **Record the absorption** in `specs/index.md` `cumaru:absorptions` as `| <sha> | <KEY> | <one-line summary> |` via `cumaru tag set`.
4. **Remove archive residue**: remove the `<KEY>` row from `archive/index.md`; if `archive/<KEY>/` exists, `cumaru flow archive/<KEY> remove`.
5. Commit per batch or per `<KEY>` (user preference, default: batch of
   10 per commit, message
   `chore(.cumaru): prune <N> already-absorbed archives`).

## Patterns

| User says | You do |
|---|---|
| "Archive AAA-1234" / "close plan X" / "finalize plan X" | Run all 3 phases above on `<KEY>=AAA-1234`, with confirmation between Phase 1 and Phase 2, and again before Phase 3's commit/cleanup |
| "Promote `exploring/auth-redesign` to a plan" | Companion op: copy → write plan frontmatter → re-emit plans table |
| "Rename plan AAA-1234 to AAA-9999" | Companion op: move + update `key:` + fix `deltas:` refs |

Use `cumaru tag get/set` (CLI, no skill) for marker-block round-trip on `specs/index.md` and `archive/index.md`; pair with `cumaru-doctor` to verify cleanness post-archive.
