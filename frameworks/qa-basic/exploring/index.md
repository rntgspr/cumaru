---
human_revised: false
generated: true
generated-at: 2026-06-05T00:00:00Z
apps: [meta]
---

<!-- cumaru:exploring -->
| Link | Description |
|------|-------------|

_No explorations yet._
<!-- /cumaru:exploring -->

# Exploring

Incubator for **exploratory-testing charters and spikes** that are not yet campaigns — a session to probe a risky area, a "can we even automate this?" experiment, a heuristic to try against a new feature. No tracker item and no commitment: a charter either matures into a campaign (or a logged bug in `intake/`) or is dropped. This file is the only entry point; drilling into a specific `<slug>/` requires explicit instruction.

## What goes in

A charter ("explore checkout under flaky network for 45 min, focus on retcharge"), a tooling spike ("is Playwright trace viewer worth adopting?"), a heuristic experiment, a coverage hypothesis worth keeping. Anything too premature for a `plans/maintenance-<slug>/` directory but worth not losing.

## Lifecycle

- **Promote** — the charter matured into committed work: the Lead moves the directory to `plans/maintenance-<slug>/` (or `plans/<KEY>/` when a tracker item lands), authors the plan-level frontmatter (`scope:`, strategy, cases), and removes the `exploring/` entry. A bug found during exploration is logged in the tracker → `intake/`.
- **Drop** — the charter is spent: the Lead deletes the directory. Explorations never migrate to `archive/`; only closed campaigns do.

Stale entries are a smell: prune or promote, don't accumulate.

## When NOT to use

- Anything with acceptance criteria to cover → `plans/`.
- The coverage map as it is today → `coverage/`.
- A reusable convention → `standards/`.
- Anything already closed → `archive/`.
