---
human_revised: false
version: 1
name: cumaru-flow
description: Execute one named user-configured Cumaru workflow as a dependency graph, preserving every prerequisite gate and stopping for failures or required input.
summary: Execute one named configured Cumaru workflow while enforcing its dependency gates.
---

# `cumaru-flow` — execute a configured dependency graph

Use the invocation arguments as `<flow_name> [scope]`. This skill executes an
adopter-defined workflow from `.cumaru/config.yaml`; it does not define,
modify, or persist workflows or step state.

## Preflight

1. Require one plain `flow_name`. If it is absent, inspect
   `.cumaru/config.yaml` and ask the user to choose from `workflows`; never
   infer a default. Keep all remaining invocation text as the user-provided
   scope for every invoked step.
2. Run `cumaru doctor` before scheduling. Stop if it reports an invalid
   configuration or a result that prevents reliable workflow execution.
3. Load the named `workflows.<flow_name>.steps` entry from
   `.cumaru/config.yaml`. Require that it exists and has passed configuration
   validation. If it is missing or invalid, stop and report the issue.
4. Treat the configured `skill` value as the namespaced installed skill to
   invoke. Do not replace it with a similar skill, invent a step, or load a
   recipe into this launcher.

## Scheduling

Maintain completion only in the current invocation. A step is ready only when
every name in its optional `needs` list has completed successfully.

1. From unstarted ready steps, choose the lexically first step name. Recompute
   readiness after each successful step; this is the stable ready-step order.
2. Invoke that step's installed skill with the original user-provided scope.
   Follow its guards, evidence requirements, and authorization boundaries.
3. Mark a step successful only after its skill completes with sufficient
   evidence for its own recipe. Never treat a partial result, a proposed edit,
   or an unanswered question as success.
4. On success, select the next ready step. Do not rerun any completed step
   automatically.

## Stops

Stop immediately when a step fails, needs user input, requests authorization,
or cannot establish success. Report the step name, its skill, and the blocking
reason. Do not start any dependent step, including absorption or close-out,
after an unsatisfied prerequisite.

Do not bypass a failed gate by running a downstream skill directly. Resume only
from a new explicit invocation after the user resolves the blocker; review the
workflow again instead of assuming prior completion state.
