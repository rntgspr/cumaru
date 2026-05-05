---
human_revised: false
generated: false
apps: [meta]
---

# Reviews

Optional location for structured reviews written by the Lead when a plan closes.

## When to create

- Tickets with non-trivial technical decisions (feature, refactor) where the rationale should outlive the diff.
- Bugs that require a post-mortem.
- Spikes that produced conclusions worth preserving.

**Do not create** for: dependency bumps, trivial fixes, obvious patches — the commit message is sufficient.

## How to create

Use [templates/review.md](../templates/review.md) and write to `reviews/<PLAN-ID>-review.md`. Reviews are written in English (see `.llm/index.md` language rule).

## Existing reviews

Use `ls reviews/*-review.md` to enumerate.
