---
name: design-as-code-specification
description: "Six-pillar design lifecycle, role ownership, canonical briefs, and reviewed delivery evidence"
type: project
status: implemented
version: 9
---

# Design as Code specification

## Purpose

Define the domain-owned design workflow added by issues 046–048. It keeps
implementation-facing experience contracts in durable specs and reusable asset
records while research, concepts, briefs, and delivery plans remain transient.
The kernel and CLI primitives remain domain-neutral.

## Public surface

```text
cumaru install [agent <none|claude|codex|opencode>] --domain design-as-code
skills: cumaru-intake, cumaru-concept, cumaru-plan, cumaru-specs, cumaru-absorb
domains/design-as-code/{config.yaml,domain.md,roles/,templates/,skills/,commands/}
```

The five workflow skills have namesake command launchers where the selected
adapter supports commands. The domain-owned `cumaru-install` recipe configures
project surfaces and routes spec authoring to `cumaru-specs`. Installation uses
an explicit stateless adapter target; it does not persist an `agent` config field.

## Invariants

1. The six pillars are intake, research, concepts, plans, specs, and assets.
   Research informs selection; not every task must traverse every pillar.
2. Intake uses `intake/<KEY>.md`; assets uses `assets/<slug>.md`. Research,
   concepts, plans, and spec areas use directories with `index.md`.
3. The upstream tracker is authoritative source provenance. The refined brief
   is the single local home for tracker-backed Overview and Acceptance Criteria.
   Source refresh preserves curated content and reconciles material differences.
   Each brief stores scalar tracker provenance; the framework intake index has
   no mutable project-wide tracker registry.
4. Concept promotion requires an existing tracker ticket and reconciled brief.
   Accepted design requirements move into the brief's criteria; the concept
   retains evidence, alternatives, and selection rationale.
5. Internal maintenance uses `plans/maintenance-<slug>/` without `key:` or a
   fabricated tracker item. Its acceptance contract lives in the plan. This
   route does not bypass the selected-concept promotion contract.
6. Criterion IDs connect plan coverage, bounded tasks, handoff evidence, review,
   and proposed durable claims without creating competing acceptance sources.
   Handoff `touched` rows name only project-root-relative repository files;
   Cumaru knowledge artifacts and external evidence remain outside that tag.
7. Applicable interaction states, hierarchy, responsive behavior, accessibility,
   and content survive into written requirements and review evidence. Prototype
   links supplement the contract; inspection alone cannot prove runtime behavior.
8. Missing independent review, unresolved findings, or missing required evidence
   block absorption before durable edits or cleanup.
9. Absorption is direct: no archive pillar or completed-plan retention. Specs
   holds current experience truth; assets retains reusable sources and usage.
10. Shared evidence remains while active work needs it. Required provenance and
    verification evidence must survive before transient hosts are removed.
11. Optional `specs/<area>/bootstrap.md` discovery notes satisfy the concern
    metadata contract and remain working evidence, not a second requirements
    store.
12. Active-plan context starts from the plan and current task or review
    artifacts, then follows only their canonical acceptance source, declared
    evidence, assets, auxiliary inputs, scoped specs, and relevant dependencies.
    Empty spec scope remains valid for asset-only maintenance.

## Inputs and ownership

| Surface | Owner | Contract |
|---|---|---|
| Brief, concept selection, plan/DAG | Design Lead | Scope and accepted criteria; no silent source replacement. |
| Bounded task and handoff | Designer | Only allowed writes; actual results and proposed spec/asset deltas. |
| Independent review | Reviewer | Inspected revision, findings, gaps, and rechecks; no implementation or durable edits. |
| Readiness and durable absorption | Design Lead | Reconcile evidence, update owning specs/assets, validate and guard cleanup. |
| Research | Lead or bounded Designer task | Attributable observations, findings, provenance, and limitations. |
| Asset catalog | Design Lead | Source, ownership, license/permission evidence, attribution, restrictions, and usage. |

Role invocation never silently switches ownership or transfers user approvals.
The repository's authorization and delegation boundaries still apply.

## Execution

### Preflight

Read domain role routing, the relevant pillar indexes, and canonical templates.
Use tracker access already available to the agent or user-provided source text;
no new tracker integration or CLI synchronization is introduced.

### Proposal

Lead resolves acceptance decisions, discovers relevant spec owners through
bounded tree traversal, and maps criteria to tasks and required verification.
For asset-only maintenance, `scope: []` and task `concerns: []` are valid;
link asset destinations and record a no-spec-change rationale.

### Apply

1. Designer executes a bounded task and returns its handoff and delta proposals.
2. Lead reconciles execution status, obtains separate Reviewer findings, retains
   dispositions, dispatches corrections, and obtains rechecks of the revision.
3. Lead consolidates the delta, mapping each criterion to a durable change or
   explicit no-change rationale, then follows `cumaru-absorb`.
4. Absorb verifies ownership and readiness, retains accepted claims and evidence,
   validates with doctor and semantic inspection, and confirms exact cleanup.
5. Remove only consumed plan, concept, research, and local brief content. Never
   remove assets or upstream tracker tickets as part of transient cleanup.

## Failure contract

| Condition | Result |
|---|---|
| Missing tracker source or unresolved acceptance decisions | No invented metadata or concept promotion. |
| Missing verification, independent review, or unresolved findings | Keep work open; no absorption. |
| Conflicting ownership or insufficient retained provenance | Resolve before cleanup; keep needed evidence. |
| Failed doctor or semantic verification | Keep transient work intact. |
| Missing committed recovery or Git authorization | Stop at the relevant recovery gate; no implicit Git mutation. |

## Transaction and recovery

Absorption is an agent recipe, not an atomic CLI transaction. Require committed,
tracked transient evidence before durable edits and a committed recovery point
containing the verified durable result plus all removal targets before cleanup.
Git writes require authorization; the absorption commit names every work key.

## Implementation map

| Artifact | Responsibility |
|---|---|
| `domains/design-as-code/domain.md`, `config.yaml` | Pillars, entity shapes, and role routing. |
| `domains/design-as-code/roles/` | Lead, Designer, and Reviewer boundaries and readiness. |
| `domains/design-as-code/templates/index.md` | Canonical body/metadata contracts and destination paths. |
| `domains/design-as-code/skills/` | Intake, selection, planning, spec authoring, and direct absorption recipes. |
| `domains/design-as-code/migration.md` | Legacy lifecycle reconciliation without discarding adopter content. |

## Regression coverage

| Verification | Coverage |
|---|---|
| `tests/spec/contracts/design_artifacts_spec.sh` | Concrete domain-owned recipe dependencies and template/config metadata agreement. |
| `tests/spec/contracts/command_skill_launchers_spec.sh` | Namesake skills and argument forwarding. |
| `tests/spec/integration/schema_spec.sh` | Native source-domain configuration acceptance. |
| `tests/spec/contracts/domain_kernel_sync_spec.sh` | Universal mirror integrity and domain-owned exceptions. |
| Isolated installation, tree, and doctor smoke | Shipped artifacts and installed-tree structural validity. |
| Independent semantic scenario evaluation | Tracker-backed promotion, incomplete/corrected evidence, asset maintenance, source refresh, and cleanup gates. |

Scenario evaluation does not execute a tracker integration, browser verification,
or end-to-end absorption. The generic skill validator rejects Cumaru's existing
`human_revised`, `summary`, and `version` fields; native validation accepts them.
Additional design disciplines remain a later research task; none is selected
by issues 046–048.

## Verification

```bash
shellspec tests/spec/contracts/design_artifacts_spec.sh tests/spec/contracts/command_skill_launchers_spec.sh tests/spec/integration/schema_spec.sh
bash scripts/sync-domain-kernel.sh --check
bash tests/run.sh
```

## References

- [Public domain guide](../../docs/design-as-code.md)
- [Canonical template index](../../domains/design-as-code/templates/index.md)
- [Absorption specification](absorb.md)
- [Domain packaging](domains.md)
