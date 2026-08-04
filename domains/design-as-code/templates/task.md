---
human_revised: false
plan: <PLAN-ID>
task: T<N>
depends-on: [] # other task IDs in this plan
concerns: [] # paths under specs/ this task touches
files: [] # predicted affected files; Allowed writes below bounds permission
status: pending
targets: []
aux: [] # files in the plan directory consumed by this task
summary: Bounded design task connecting accepted criteria to delivery evidence.
---

# T<N> — <task title>

## What to do

Concrete outcome, expected artifacts, and implementation steps or source file
references needed to execute. Identify reusable asset changes to propose to Lead.

## Context

Link the plan's acceptance source and criterion IDs, scoped specs, selected
concept, required research findings, and affected asset records. Reference
canonical requirements; do not restate them as a competing acceptance contract.

## Allowed writes

Exact files or bounded paths authorized by Lead, including handoff and delta
contribution locations. Dependencies must be satisfied before execution;
new write needs return to Lead. Predictions in `files:` do not expand permission.

## Verification contract

For each applicable criterion, name the artifact/revision and verification
method, required states, viewports, accessibility checks, and content cases.
Include visual hierarchy and consistency where required. Record a reason for
inapplicable dimensions. Prototype inspection cannot prove runtime behavior;
identify checks that require a running implementation.

| Criterion | Artifact / scope | Method and expected evidence |
|---|---|---|
| <source link / AC-1> | <state, viewport, content case> | <check and evidence to retain> |

## Done when

- [ ] Assigned criteria are met and required verification is recorded.
- [ ] `templates/handoff.md` is completed with actual results and gaps.
- [ ] Proposed durable changes follow `templates/delta-draft.md` and return to Lead.

Execution completion does not replace independent review or authorize absorption.
