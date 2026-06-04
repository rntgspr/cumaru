---
human_revised: false
generated: true
generated-at: 2026-06-04T00:00:00Z
apps: [meta]
---

<!-- llm:exploring -->
| Idea | Apps | Summary |
|------|------|---------|

_No explorations yet._
<!-- /llm:exploring -->

# Exploring

Incubator for **infrastructure spikes** that are not yet changesets — a provider migration to weigh, a cost-optimization hypothesis, a multi-region sketch. No tracker item and no commitment: an exploration either matures into a plan or is dropped. This file is the only entry point; drilling into a specific `<slug>/` requires explicit instruction.

## What goes in

A refactor of the network layout someone might attempt, a "should we move to OpenTofu" analysis, an architecture sketch, a decision-in-progress with pros/cons to revisit. Anything too premature for a `plans/maintenance-<slug>/` directory but worth keeping.

## Lifecycle

- **Promote** — the idea matured into committed work: the Lead moves the directory to `plans/maintenance-<slug>/` (or `plans/<KEY>/` when a tracker item lands), authors the plan-level frontmatter (`scope:`, blast radius, DAG), and removes the `exploring/` entry.
- **Drop** — the idea won't happen: the Lead deletes the directory. Explorations never migrate to `archive/`; only applied changes do.

Stale entries are a smell: prune or promote, don't accumulate.

## When NOT to use

- Anything with acceptance criteria → `plans/`.
- The topology as it is today → `topology/`.
- A repeatable operation → `runbooks/`.
- Anything already applied → `archive/`.
