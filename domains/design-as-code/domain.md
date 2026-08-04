---
human_revised: false
targets: [meta]
summary: Design-as-code workflow for versioned research, design delivery, and durable implementation-facing experience specifications.
---

<!-- cumaru:components -->
| Link | Description |
|------|-------------|
_(replace with your actual stack)_
<!-- /cumaru:components -->

<!-- cumaru:root -->
_(empty — replace with adopter-specific context, or delete this placeholder)_
<!-- /cumaru:root -->

# Design as Code domain

Design is a versioned product contract. Research evidence and visual exploration
are transient; specs holds the durable foundations, components, patterns,
journeys, screens, content, responsive behavior, and accessibility requirements.

## Pillars (root's children)

This file defines the design domain. `index.md` remains the shared kernel;
`config.yaml` declares the six pillars and their entity shapes.

| Pillar | Content | Lifetime |
|---|---|---|
| `intake/` | Tracker-backed briefs at `<KEY>.md`; the tracker remains authoritative. | Transient local mirror |
| `research/` | Studies, interviews, audits, experiments, and evidence at `<slug>/index.md`. | Transient evidence |
| `concepts/` | Design alternatives, sketches, and prototype hypotheses at `<slug>/index.md`. | Transient direction |
| `plans/` | Scoped delivery tasks, handoffs, and delta drafts at `<PLAN-ID>/`. | Transient execution |
| `specs/` | Current experience contracts, organized by area and concern. | Durable design truth |
| `assets/` | Reusable asset records at `<slug>.md`, including sources, licenses, and usage rules. | Durable catalog |

`roles/`, `templates/`, and `disciplines/` support the workflow; they are not
content pillars. Binary assets stay in their repository or asset-management
location. Figma and prototype links support the written implementation contract.

## Lifecycle

```text
intake/ + research/ --> concepts/ --> plans/ --> specs/
                                          \--> assets/ (reusable asset records)
```

Research informs concept selection; this is not a mandatory sequence for every
request. A scoped maintenance change may start directly in `plans/`. Selected
concepts link their evidence to the plan and remain available until absorption.
Tracker-backed work uses `cumaru-intake` only after the tracker ticket exists.
The flat brief is the single local home for Overview and Acceptance Criteria;
concept promotion reconciles accepted requirements there before planning.
Internal maintenance keeps its criteria in the plan without inventing a ticket.

`cumaru-absorb` merges accepted experience claims directly into their owning
spec concerns and retains reusable asset provenance and usage rules in assets.
There is no archive staging pillar or completed-plan history inside the tree.
Before cleanup, validate the durable result, confirm the exact removal set, and
require tracked Git recovery for that result and the transient evidence.

After successful absorption, remove the completed plan and its consumed
concept, research, and local intake entries. Preserve shared evidence or briefs
still required by other active work; unresolved claims and failed verification
block cleanup. Durable specs and asset records remain. Git history is the
cross-reference to closed work, with every absorbed work key named in the
absorption commit when Git mutation is authorized.

## Roles

- **Design Lead** (`roles/lead.md`) — owns scope, concept selection, planning,
  dispatch, review reconciliation, and durable spec and asset absorption.
- **Designer** (`roles/designer.md`) — executes bounded plan tasks and returns
  artifacts, verification evidence, handoffs, and proposed deltas to Lead.
- **Reviewer** (`roles/reviewer.md`) — independently evaluates delivery and
  reports findings to Lead; does not implement fixes or edit durable content.

Role boundaries and dispatch contracts live in the role files. A skill does
not switch an active role or expand its permissions. Route work to a separate
agent with the required role, or request an explicit `cumaru-role` switch;
never combine roles or transfer user approvals. Repository authorization and
delegation rules still apply.

### Shallow indexes per role (entry into the loading rule)

| Role  | Shallow indexes loaded                                       |
|-------|--------------------------------------------------------------|
| Lead | Relevant pillar indexes, then the plan-scoped entry below for active work |
| Designer | `plans/index.md`, then the dispatched plan-scoped entry |
| Reviewer | `plans/index.md`, then the dispatched plan-scoped entry and review artifacts |

### Plan-scoped entry

For active work, begin with `plans/index.md`, the active
`plans/<PLAN-ID>/index.md`, and the current task or review artifacts. From that
entry, load only:

1. The canonical acceptance source: the linked `intake/<KEY>.md` brief for
   tracker-backed work, or the active plan's own criteria for maintenance.
2. Concept, research, delivered evidence, asset records, and `aux:` inputs
   explicitly linked or listed by the plan, task, or review dispatch.
3. Spec candidates named by plan `scope:` or task `concerns:`, followed only
   through relevant semantic dependencies under the kernel loading rule.

Asset-only maintenance may use `scope: []` and task `concerns: []`; its plan,
task, and linked asset records remain valid entry points without inventing a
spec owner. Do not load sibling briefs, concepts, research, assets, plans, or
specs merely because they share a pillar or directory.

## Execution disciplines

Framework-shipped conduct for *how* work is done — distinct from the
pillars, which hold *what* the project is. Every modular file in `disciplines/`
is loaded at context start; `applies-when:` controls when its rules apply,
never whether its body is loaded. `disciplines/index.md` defines how
`strictness:` controls required consideration.

| Discipline | Applies when | File |
|---|---|---|
| cumaru-first | repository work can benefit from a relevant Cumaru surface | `disciplines/cumaru-first.md` |
| design-accessibility | creating or reviewing visual accessibility and interaction requirements | `disciplines/design-accessibility.md` |
| design-review | reviewing a design or evaluating a proposed visual change | `disciplines/design-review.md` |
| design-system-first | creating or changing design components, screens, or visual direction | `disciplines/design-system-first.md` |
| interaction-states | designing or reviewing interactive components and feedback | `disciplines/interaction-states.md` |
| responsive-design | adapting or reviewing layouts across viewport sizes or input modes | `disciplines/responsive-design.md` |
| visual-verification | finishing a design change or reporting visual work complete | `disciplines/visual-verification.md` |

## Design context

Specs describe current foundations, components, patterns, journeys, screens,
content, responsive behavior, and accessibility requirements. Research and
concepts explain the evidence and alternatives while work is active; accepted
findings become current requirements rather than a second permanent work log.
