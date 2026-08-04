---
release: 2026-09-11
targets:
---

## design-as-code — align the lifecycle

**Applies when** — an earlier design-domain tree contains copied SDLC Light
navigation, an archive starter, or completed plans retained as history.

**Detect** — compare installed domain guidance and config with the source
`domains/design-as-code/`. Inspect filesystem candidates for legacy exploring
and archive content, and identify completed plans without assuming absorption.

**Do** — during base step 3, before any canonical refresh:

1. Reconcile the six pillars: intake, research, concepts, plans, specs, and
   assets. Use the current config schema and domain defaults; do not discard
   adopter entities or content mechanically.
2. Classify legacy ideation by its actual content: research evidence belongs in
   research and design directions in concepts. Preserve links and resolve
   ambiguous ownership with the user before relocating content.
3. Preserve all local-only lifecycle content at its adjudicated destination.
   Removing a starter from the source does not delete an adopter's copy, but
   canonical guidance must not be refreshed until this classification is complete.
4. For completed work, use `cumaru-absorb` to verify durable claims, asset
   records, shared consumers, and the tracked Git recovery point before cleanup.
   If a legacy archived plan must be restored to plans for that recipe, confirm
   its mapping and preserve the evidence; stop on a destination collision.
5. Remove obsolete empty legacy pillar directories only after their contents
   have been accounted for and the user confirms removal. Pillar-root removal
   is deliberately refused by `cumaru fs`; do not bypass that guard silently.

**Blockers** — missing tracked recovery, ambiguous ownership, conflicting
claims, missing evidence, shared active consumers in the removal set, or failed
verification. Never infer that a completed status proves successful absorption.

**Verify** — the declared pillars have valid indexes; guidance uses the current
lifecycle; accepted experience claims live in specs and reusable asset records
remain in assets. Run `cumaru tree --rows`; defer `cumaru doctor` to base step
13, after version convergence and canonical refresh. No consumed completed work
remains as a parallel history record; shared active evidence is preserved.

## design-as-code — pre-refresh tracker provenance

Preserve brief provenance first; only then retire the tracker registry.

**Applies when** — `intake/index.md` has a tracker array or the intake entity in
`config.yaml` still requires index-level `tracker` frontmatter.

**Detect** — inspect the legacy array and every local brief before updating:

```bash
yq --front-matter=extract '.tracker // []' .cumaru/intake/index.md
for file in .cumaru/intake/*.md; do
  [ "$file" = .cumaru/intake/index.md ] && continue
  printf '%s\t' "$file"
  yq --front-matter=extract -r '.tracker // "<missing>"' "$file"
done
```

**Do** — during base step 3, before any canonical refresh:

1. Preserve every existing scalar brief `tracker:` exactly. Never replace one
   scalar from the index array.
2. For a brief without `tracker:`, use the sole legacy tracker only when its
   source confirms that choice. With multiple or conflicting candidates, read
   the source or ask the user; do not guess.
3. Remove `tracker!` from `.root.entities.intake.frontmatter` in
   `.cumaru/config.yaml`, removing the empty `frontmatter` property afterward.
4. Remove the legacy tracker array from `intake/index.md` only after every brief
   has reliable scalar provenance. Do not refresh the index here; base step 12
   performs the canonical refresh after the converted tree has an authorized
   recovery commit.

**Blockers** — a brief without reliable tracker provenance, a registry value
that conflicts with its source, or an uncommitted reconciliation. STOP before
canonical refresh and keep the registry until every affected brief is adjudicated.

**Verify** — the index and intake config entity no longer declare a tracker
registry; every tracker-backed brief has one scalar `tracker:` matching its
source. Record these files in the base step 11 checkpoint before refresh; the
post-refresh second preview and `cumaru doctor` must then be stable.
