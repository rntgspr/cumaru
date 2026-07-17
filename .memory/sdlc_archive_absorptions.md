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

`archive/` is **not** durable history. It is close-out staging. After absorption into `specs/`, `archive/<KEY>/` is removed. `plans/<KEY>/` also leaves no residue unless the user explicitly restores an archive back to plans, which is possible but against the normal flow. V6 maintains no structural archive rows; `cumaru tree archive --rows` projects in-flight entries from disk.

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
- Phase 1: copy/move plan material into transient `archive/<KEY>/` and absorb the delta into scoped specs.
- Phase 2: remove original `plans/<KEY>/` after finalized delta is confirmed.
- Phase 3: commit the spec absorption, capture SHA, append `SHA | KEY | Description` to `specs/index.md` `cumaru:absorptions`, remove `archive/<KEY>/`, and commit cleanup.

**Doctor implication.** V6 validates directory indexes and summaries, not structural inventory rows. An in-flight `archive/<KEY>/` must have a valid `index.md`; durable history belongs only to the absorption ledger and its Git commit.

**Scope.** Implemented for `sdlc-full`, `iac-basic`, and `qa-basic`; their durable ledgers live in `specs/index.md`, `topology/index.md`, and `coverage/index.md`, respectively. `sdlc-light` has no archive and keeps local trace through spec `deltas:`.
