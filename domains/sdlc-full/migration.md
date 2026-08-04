---
release: 2026-08-01
targets:
---

## sdlc-full — domain notes

The durable pillar is `specs/`; the ledger lived on `specs/index.md`.

### Pre-refresh tracker provenance

Preserve item provenance first; only then retire the tracker registry.

**Applies when** — `intake/index.md` has a tracker array or the intake entity in
`config.yaml` still requires index-level `tracker` frontmatter.
**Detect** — inspect the legacy array and the scalar `tracker:` on every intake
item, including legacy `<KEY>/index.md` files, before updating.
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

### Flat intake layout

**Applies when** — `intake/` contains directories rather than `<KEY>.md` files.
**Detect** — `find .cumaru/intake -mindepth 1 -maxdepth 1 -type d`
**Do** — every intake item is a single `intake/<KEY>.md`. For a directory whose
only content is `index.md`, move it to `intake/<KEY>.md` and remove the
directory.
**Blockers** — a directory holding auxiliary files beyond `index.md`, or a case
where both `intake/<KEY>/` and `intake/<KEY>.md` exist. STOP and ask; do not
discard attachments and do not guess which layout wins.
**Verify** — `cumaru tree intake --rows` lists only `.md` files.

### Archive is transient, and stays that way

`archive/<KEY>/` was already close-out staging. Nothing changes about that,
except that after absorption there is no ledger row to write: the updated
`specs/` files are the whole durable result. If the tree still has
`archive/<KEY>/` directories for plans that were already absorbed, remove them.
