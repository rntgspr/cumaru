---
name: sdlc-archive-transient-and-absorptions-ledger
description: "SDLC archive redesign — plans move into archive as transient staging; durable absorption ledger lives in specs/index.md"
metadata:
  type: project
---

Decision from Renato (2026-07-10): SDLC flow is:

```text
intake/exploring -> plans -> (implementation done) -> archive -> (absorb) -> specs/
```

`archive/` is **not** durable history. It is close-out staging. After absorption into `specs/`, both `archive/<KEY>/` and the row in `archive/index.md` are removed. `plans/<KEY>/` also leaves no residue unless the user explicitly restores an archive back to plans, which is possible but against the normal flow.

**Durable record.** `specs/index.md` now owns a custom table tag:

```markdown
<!-- cumaru:absorptions -->
| SHA | KEY | Description |
|-----|-----|-------------|
| abc1234 | AAA-1234 | Absorbed auth behavior into specs/auth |
<!-- /cumaru:absorptions -->
```

This records the commit SHA that absorbed a plan delta, the plan key, and a one-line summary of what became durable. Spec area `deltas:` remains a local trace listing plan IDs; `absorptions` is the cross-spec durable ledger.

**Skill implications.** `cumaru-archive` in `sdlc-it-project-basic` is now three phases:
- Phase 1: copy/move plan material into transient `archive/<KEY>/`, add in-flight `archive/index.md` row, absorb delta into scoped specs.
- Phase 2: remove original `plans/<KEY>/` after finalized delta is confirmed.
- Phase 3: commit the spec absorption, capture SHA, append `SHA | KEY | Description` to `specs/index.md` `cumaru:absorptions`, remove the archive row, remove `archive/<KEY>/`, commit cleanup.

**Doctor implication.** Missing `archive/index.md` rows are no longer tolerated. A row in `archive/index.md` must point at an existing in-flight `archive/<KEY>/`; if the directory is missing, it is a real incomplete-cleanup warning. The old model "archive row survives with absorbed SHA" is obsolete for SDLC basic.

**Scope.** Implemented first for `sdlc-it-project-basic`. `sdlc-light` has no archive and only gets the v5 tag model. Similar future alignment for `iac-basic` and `qa-basic` should put the final ledger on their durable pillars (`topology/index.md`, `coverage/index.md`) rather than `specs/index.md`.
