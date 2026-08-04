---
release: 2026-08-01
targets:
---

## iac-basic — domain notes

The durable pillar is `topology/`; the ledger lived on `topology/index.md`.

### Pre-refresh tracker provenance

Preserve item provenance first; only then retire the tracker registry.

**Applies when** — `intake/index.md` has a tracker array or the intake entity in
`config.yaml` still requires index-level `tracker` frontmatter.
**Detect** — inspect the legacy array and the scalar `tracker:` on every
`intake/<KEY>/index.md` before updating.
**Do** — during the base preservation step, before any canonical refresh:

1. Preserve every existing scalar item `tracker:` exactly.
2. For an item without `tracker:`, use a sole legacy value only when the item's
   source confirms it. With multiple or conflicting candidates, read the source
   or ask the user; never default to Jira.
3. Remove `tracker!` from `.root.entities.intake.frontmatter` in
   `.cumaru/config.yaml`, removing the property only when it becomes empty.
4. Remove the legacy array from `intake/index.md` only after every item has
   reliable scalar provenance. Leave canonical refresh to the base procedure.

**Blockers** — missing reliable provenance, a registry value conflicting with
the item source, or an uncommitted reconciliation. STOP before refresh and keep
the registry until every affected item is adjudicated.
**Verify** — the index and intake config entity no longer declare a registry;
every tracker-backed item has one scalar `tracker:` matching its source. Include
the reconciliation in the required pre-refresh recovery checkpoint.

### Durable archive rows must be distributed, never deleted

**Applies when** — `archive/index.md` still carries a `<!-- cumaru:archive -->`
block with rows.
**Detect** — `cumaru tag archive/index.md`

In this domain those rows are **durable content**, not transient inventory —
unlike `sdlc-full`, where the archive block only ever mirrored directories. They
previously had `topology/index.md`'s `absorptions` ledger as their destination.
That destination no longer exists.

**Do**
1. For each row, read its Description and place every durable claim in the
   `topology/` area that owns it — the same classification as base step 6.
2. Only when a row has nothing left that is not already in `topology/` may it be
   dropped.
3. Remove the `<!-- cumaru:archive -->` block once every row is accounted for.
**Blockers** — a row you cannot place with confidence. STOP and ask. Deleting
these rows is irreversible loss; there is no ledger to catch them anymore.
**Verify** — no `cumaru:archive` block remains. Defer `cumaru doctor` to base
step 13, after version convergence and canonical refresh.

### Runbooks are untouched

`runbooks/` is durable and sits outside the absorb flow. This migration does not
touch it.
