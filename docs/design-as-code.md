# Design as Code

The `design-as-code` domain keeps implementation-facing experience contracts
under version control. Its six pillars separate active evidence and delivery
from durable design knowledge.

| Pillar | Purpose | Lifetime |
|---|---|---|
| `intake/` | Flat tracker briefs at `<KEY>.md`; upstream tickets remain authoritative. | Transient |
| `research/` | Interviews, audits, experiments, and evidence. | Transient |
| `concepts/` | Design directions, alternatives, sketches, and prototypes. | Transient |
| `plans/` | Scoped tasks, handoffs, and proposed specification deltas. | Transient |
| `specs/` | Current foundations, components, journeys, behavior, and requirements. | Durable |
| `assets/` | Reusable asset sources, licenses, and usage guidance. | Durable |

## Lifecycle

```text
intake/ + research/ --> concepts/ --> plans/ --> specs/
                                          \--> assets/ (reusable asset records)
```

Research informs selection rather than imposing a phase on every task. Scoped
maintenance can begin directly in plans. Selected concepts and their evidence
stay available during delivery. Binary assets remain in the repository or asset
manager; Figma and prototype links support the written contract.

`cumaru-absorb` updates the owning spec concerns and relevant asset records
directly. There is no archive staging pillar. It validates accepted claims and
retained links, runs doctor, and confirms the durable result and exact cleanup
set before deletion. A committed Git recovery point must contain the durable
result and transient evidence; Git writes require user authorization.

Successful absorption removes the completed plan and consumed concept,
research, and local intake entries. Shared evidence and briefs remain while
other active work needs them. Assets and upstream tracker tickets are never
cleanup targets. Unresolved claims or failed verification block removal.
Git history links closed work to the durable result; completed plans are not
retained as a second record.

## Briefs and acceptance ownership

`cumaru-intake` reads a tracker item through access already available to the
agent, or from user-provided source text. It creates `intake/<KEY>.md` using
`templates/intake-brief.md` for every item type. No new tracker integration or
CLI synchronization is involved. Refresh preserves curated prose and stable
criterion IDs; source differences are reconciled rather than silently replacing
accepted requirements.

Tracker provenance lives on each brief as scalar `tracker:` metadata. There is
no project-wide tracker registry on `intake/index.md`, so framework updates
cannot reset an adopter choice and briefs from multiple trackers remain
independently attributable. Existing installs should follow the domain migration
guidance before removing a legacy index array: preserve current brief values and
adjudicate missing provenance from the original source.

The tracker remains the authoritative source. Its refined brief is the single
local home for Overview and Acceptance Criteria. Before concept promotion,
Lead reconciles accepted design requirements into that brief and resolves open
decisions. `plans/<KEY>/index.md` links the brief, concept, and research, then
maps criterion IDs to tasks and required evidence without duplicating criteria.

Internal maintenance can use `plans/maintenance-<slug>/` without `key:` or a
tracker brief, with Overview and Acceptance Criteria in the plan. This route
does not bypass the tracker-backed contract for selected concept promotion.

## Plan-scoped context

Active work enters through its plan and current task or review artifacts. From
there, load only the canonical brief or maintenance criteria, explicitly linked
concepts, research, delivered evidence, asset records and auxiliary files, plus
specs named by plan `scope:` or task `concerns:` and their relevant semantic
dependencies. Nearby pillar entries are not context merely by proximity.

Asset-only maintenance may keep both `scope:` and `concerns:` empty. Its plan,
task, and linked asset records provide the bounded context; no spec owner is
invented.

## Written contracts and evidence

The canonical templates carry applicable interaction states, hierarchy,
responsive behavior, accessibility, and content through delivery. Inapplicable
dimensions have an explicit reason. Accessibility checks use the project's
accepted target; inspecting a prototype does not prove runtime behavior.

| Artifact | Contract |
|---|---|
| `intake-brief.md` / `concept.md` | Accepted outcomes, evidence, alternatives, and selection decisions. |
| `plan.md` / `task.md` | Criterion coverage, bounded writes, artifact revisions, and verification scope. |
| `handoff.md` | Observed results, evidence gaps, independent review, finding dispositions, and rechecks; `touched` lists project-root files only. |
| `delta-draft.md` / `spec.md` | Criterion-to-claim mapping, current requirements, and retained source/evidence provenance. |
| `research.md` | Method, original observations, attributable findings, and limitations. |
| `asset.md` | Source, ownership, permission evidence, attribution, restrictions, and usage. |

Research entries use `research/<slug>/index.md`; asset records use
`assets/<slug>.md`. Binaries remain at their source locations. Required evidence
must survive transient cleanup through retained locations and durable links.
Figma links supplement written behavior and reviewed results.

## Roles and delivery review

Design Lead owns scope, plans, concept selection, bounded dispatch, review
reconciliation, and durable absorption. Designer executes assigned tasks and
returns artifacts, verification, handoffs, and proposed deltas. Reviewer
independently checks the delivered revision for applicable interaction,
hierarchy, responsive, accessibility, and content requirements without editing
the implementation or durable specs.

Lead retains review evidence and finding dispositions in task handoffs,
dispatches corrections, and obtains rechecks. Missing independent review,
unresolved findings, or missing required verification block absorption. When
Lead implements directly, independent review is still required. Role routing
never silently combines permissions or transfers user approvals.

## Installation and existing trees

```bash
cumaru install --domain design-as-code
```

Existing adopters should inspect the domain migration guidance before removing
legacy content. Update preserves local-only files: deleting an obsolete starter
from the distribution does not delete an adopter's old directory.

## References

- [Installation](install.md)
- [Migration](migrate.md)
- [Architecture](architecture.md)
- [Domain lifecycle](../domains/design-as-code/domain.md)
- [Authoring templates](../domains/design-as-code/templates/index.md)
- [W3C WAI: WCAG evaluation methodology](https://www.w3.org/WAI/test-evaluate/conformance/wcag-em/)
- [GOV.UK: Analyse a research session](https://www.gov.uk/service-manual/user-research/analyse-a-research-session)
- [GOV.UK Design System: Patterns](https://design-system.service.gov.uk/patterns/)
- [Absorption recipe](../domains/design-as-code/skills/cumaru-absorb/SKILL.md)
- [Design Council: Framework for Innovation](https://www.designcouncil.org.uk/resources/framework-for-innovation/)
