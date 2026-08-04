---
release: 2026-08-01
targets:
  framework-version: 7
---

## iac-basic — domain notes

The durable pillar is `topology/`; the ledger lived on `topology/index.md`.

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
   `topology/` area that owns it — the same classification as base step 5.
2. Only when a row has nothing left that is not already in `topology/` may it be
   dropped.
3. Remove the `<!-- cumaru:archive -->` block once every row is accounted for.
**Blockers** — a row you cannot place with confidence. STOP and ask. Deleting
these rows is irreversible loss; there is no ledger to catch them anymore.
**Verify** — no `cumaru:archive` block remains and `cumaru doctor` is clean.

### Runbooks are untouched

`runbooks/` is durable and sits outside the absorb flow. This migration does not
touch it.
