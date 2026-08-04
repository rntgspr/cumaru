---
name: cumaru-workflows-specification
description: "Optional v9 skill dependency graphs and the cumaru-flow orchestrator"
type: project
status: implemented
version: 9
---

# Cumaru workflows specification

## Purpose

Allow an adopter to define a deterministic order for installed domain skills
without embedding skill recipes or execution state in config.

## Public surface

```text
.cumaru/config.yaml: workflows.<name>.steps.<step_id>
/cumaru:flow <flow_name> [scope]
domains/<domain>/skills/cumaru-flow/SKILL.md
```

## Invariants

1. `workflows` is optional; shipped domain configs do not invent a default
   delivery sequence.
2. Every step has a `skill` naming a regular installed skill in the selected
   domain. Its optional `needs` is an array of unique step identifiers; an
   omitted or empty array means the step is initially ready.
3. Validation rejects empty graphs, unknown properties, invalid names, missing
   dependencies, duplicate prerequisites, self-dependencies, cycles, unavailable
   domains, and unavailable skills before execution.
4. When multiple unstarted steps are ready, choose the lexically first step
   identifier and recompute readiness after each successful step.
5. A prerequisite succeeds only when its skill finishes with evidence required
   by its own recipe. Failure, missing input, or unresolved authorization stops
   scheduling; no dependent step runs and no completion is persisted.
6. `cumaru fs` remains the mechanical filesystem CLI. `cumaru-flow` is the
   agent skill; its slash command is a thin argument-forwarding launcher.

## Inputs and ownership

| Input or surface | Owner | Contract |
|---|---|---|
| `.cumaru/config.yaml` workflow graph | adopter | Named order and skill references; no prose or execution state. |
| Installed domain skills | framework/domain | Recipes and their existing guards. |
| User-provided scope | user | Passed unchanged to each invoked skill. |
| `cumaru-flow` skill and launcher | framework | Validate, schedule, and stop without inventing steps. |

## Execution

1. Require an explicit workflow name and run `cumaru doctor` before scheduling.
2. Load and validate the named graph against the installed domain skills.
3. Invoke the lexical first ready step with the original scope. Mark it complete
   only after its own success conditions are met, then recompute readiness.
4. Stop at a failed or unresolved step and report its name, skill, and blocker.
   A new invocation rechecks the graph rather than trusting prior session state.

## Implementation and verification

| Artifact | Responsibility |
|---|---|
| [`../../schemas/schema-validate-v9.jq`](../../schemas/schema-validate-v9.jq) | Graph shape and dependency validation. |
| [`../../src/schema.sh`](../../src/schema.sh) | Domain-skill availability and stable topological order. |
| [`../../domains/__base/skills/cumaru-flow/SKILL.md`](../../domains/__base/skills/cumaru-flow/SKILL.md) | Runtime orchestration and stop gates. |
| [`../../tests/spec/integration/workflow_graph_spec.sh`](../../tests/spec/integration/workflow_graph_spec.sh) | Graph validity and ordering. |
| [`../../tests/spec/contracts/workflow_orchestrator_skill_spec.sh`](../../tests/spec/contracts/workflow_orchestrator_skill_spec.sh) | Universal skill and launcher contract. |

```bash
shellspec tests/spec/integration/workflow_graph_spec.sh tests/spec/contracts/workflow_orchestrator_skill_spec.sh
```
