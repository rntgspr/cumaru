---
human_revised: false
apps: [meta]
summary: Framework guidance for locally authored SDLC issues and their required workflow.
---

# Issues

Locally authored work items created from the current chat and repository context. Unlike `intake/`, this pillar does not mirror a tracker and has no external key. Each issue is specific enough to plan, but is not an execution plan yet.

## What goes in

Capture a bug, feature, improvement, task, or chore that is worth preserving before planning. Write the observed problem or opportunity, its impact, a bounded acceptance contract, and the decision that would promote it.

### When to use

- The user identifies work that has no tracker item.
- Context makes a bug, improvement, or follow-up concrete enough to state its outcome.
- A chat needs a durable issue without creating a plan prematurely.

### When not to use

- A tracker item already exists or must remain authoritative → `intake/<KEY>.md`.
- The topic is still an open-ended sketch or question → `exploring/<slug>/`.
- The implementation approach and task breakdown are ready → `plans/maintenance-<slug>/`.

## Structure

```
issues/<slug>/
├── index.md          ← required; locally authored issue contract
└── *.md              ← optional aux, declared in the body when needed
```

`<slug>` is plain kebab-case with no tracker key or `maintenance-` prefix. Required frontmatter stays deliberately small: `type`, `priority`, `status`, `apps`, and `summary`. Use standard SDLC types (`bug`, `feature`, `improvement`, `task`, `chore`) and priorities (`critical`, `high`, `medium`, `low`).

## Lifecycle

An issue is transient. It has two exits:

- **Promote** — create `plans/maintenance-<slug>/`, distill the issue's description and acceptance criteria into the plan, then remove the issue directory.
- **Drop** — remove the directory when the issue is resolved elsewhere, rejected, or no longer relevant.

Issues never go directly to `archive/`. Only completed plans do.

## Loading and ownership

`issues/` is opt-in: open this index or an issue only when the user references it or its subject is relevant. The Lead owns capture, refinement, promotion, and removal. Dev and Ghost do not write here.
