---
name: cumaru-update-v5-gitboiler-smoke
description: "Lessons from v5 update smoke on gitboiler — legacy flavor fallback, source-schema tag typing, reference rows, schema apply"
metadata:
  type: project
---

Smoke target: `/Users/gaspar/workspace/gitboiler`, installed with old `sdlc-light` v4 tree.

**Bug found and fixed: legacy `flavor:`.** `gitboiler/.cumaru/schema.yaml` had `flavor: sdlc-light`, not `domain:`. `cumaru update` only read `domain:` and fell back to `base`, producing a dangerous dry-run that wanted to replace `domain.md` with Base content. Fix: `cmd_update.sh` now reads `domain:` first, then legacy `flavor:` as a read-only fallback.

**Bug found and fixed: tag typing during migration dry-run.** In v4 -> v5 dry-run, `update` originally classified `root` using the local v4 schema, so `root` prose showed as `[Δ]` malformed table. Fix: `_update_render` now receives the source framework root and classifies tag types using the source v5 schema when rendering the dry-run.

**Bench migration steps executed.**
- `cumaru update --from /Users/gaspar/workspace/cumaru` dry-run: selected `sdlc-light` after the fallback fix.
- `cumaru update --from /Users/gaspar/workspace/cumaru --apply`: merged framework files and replaced framework-owned skills/hooks/commands.
- `cumaru update schema --from /Users/gaspar/workspace/cumaru --apply`: intentionally destructive schema replacement requested by Renato for the bench.
- Manually bumped `gitboiler/.cumaru/index.md` `framework-version: 5` after schema replacement, because doctor correctly reported schema version 5 vs index version 4.

**Reference rows issue found in bench.** `gitboiler` had `reference` links like `../../src/lib/logger.js`. The v5/source-file rule is project-root relative (`src/lib/logger.js`). Re-emitted the `reference` blocks in `specs/logging/index.md` and `specs/logging/logger.md` with project-root-relative paths. Final `cumaru doctor --quiet` was green: `0 error(s), 0 warning(s), 7 ok`.

**Operational note.** This test did not run `install.sh` or `cumaru upgrade`. It did modify `gitboiler`'s untracked `.cumaru/` and `.agents/` bench fixture, plus existing project worktree files were already dirty/untracked before the test.
