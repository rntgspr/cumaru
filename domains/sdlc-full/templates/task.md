---
human_revised: false
plan: <PLAN-ID>
task: T<N>
depends-on: [] # other task IDs in this plan
concerns: [] # paths under specs/ this task touches
files: [] # PREDICTED files the task is expected to create or modify (Lead's best estimate; not exhaustive — cascades are normal)
status: "pending | in-progress | done | blocked"
apps: "[<app>] | [platform]"
aux: [] # files in the plan directory consumed by this task
summary: Framework guidance for T<N> — <task title> and its required workflow.
---

# T<N> — <task title>

## What to do

Concrete description of the action. Files to create/modify, snippets, constraints.

## Context

Background the Dev needs that is not in `specs/`: rationale, links, code references, prior decisions affecting this task.

## Implementation

Step-by-step instructions. Include code snippets and file references with line ranges when helpful.

## Done when

- [ ] Concrete checkbox(es) describing the post-condition.
- [ ] Build/test command result, if applicable.
