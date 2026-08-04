---
release: 2026-08-01
targets:
  framework-version: 7
---

## sdlc-full — domain notes

The durable pillar is `specs/`; the ledger lived on `specs/index.md`.

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
