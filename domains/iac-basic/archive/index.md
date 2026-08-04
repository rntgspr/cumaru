---
human_revised: false
apps: [meta]
summary: Framework guidance for Archive and its required workflow.
---


# Archive

**Transient close-out staging.** A completed plan exists here only while its delta is being absorbed into `topology/` and the absorption commit is being recorded.

## Rules

- **No structural rows.** `cumaru tree archive --rows` projects the in-flight directories from the filesystem.
- **`topology/` is the durable record.** After absorption, prune `archive/<KEY>/`; nothing is carried forward out of it.
- **In-flight archives** (between copy and prune) carry a full directory with `index.md`, `delta.md`, and `handoff-t<N>.md`.
- **Never loaded by default.** Use `git log --all --grep=<KEY> --name-only -- .cumaru/topology/` to find the absorbed change.
- **Plan IDs are immutable.** The KEY in an absorption commit message matches the original plan ID exactly — that is what makes the commit greppable.

## When to consult

- Tracing why a topology area looks the way it does — read the area, then `git log --all --grep=<KEY> --name-only -- .cumaru/topology/`.
- Reviewing how a past change was sequenced (DAG, handoffs) before authoring a new one.

## When NOT to consult

- Routine planning of new work — start at `intake/` + `plans/`.
- Anything still in flight — that lives in `plans/`.
