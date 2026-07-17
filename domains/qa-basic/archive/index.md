---
human_revised: false
apps: [meta]
summary: Framework guidance for Archive and its required workflow.
---


# Archive

**Transient close-out staging.** A completed campaign exists here only while its delta is being absorbed into `coverage/` and the absorption commit is being recorded.

## Rules

- **No structural rows.** `cumaru tree archive --rows` projects the in-flight directories from the filesystem.
- **The coverage ledger is durable.** After absorption, append `SHA | KEY | Description` to the `cumaru:absorptions` block in `coverage/index.md`, then prune `archive/<KEY>/`.
- **In-flight archives** (between copy and prune) carry a full directory with `index.md`, `delta.md`, and `handoff-t<N>.md`.
- **Never loaded by default.** Use the coverage ledger SHA with `git show <sha>` for the absorbed change.
- **Plan IDs are immutable.** The ledger `KEY` matches the original plan ID exactly.

## When to consult

- Tracing why a coverage area looks the way it does — follow its local `deltas:` list to the matching coverage ledger entry, then run `git show <sha>`.
- Reviewing how a past campaign was sequenced (cases, handoffs) before authoring a new one.

## When NOT to consult

- Routine planning of new work — start at `intake/` + `plans/`.
- Anything still in flight — that lives in `plans/`.
