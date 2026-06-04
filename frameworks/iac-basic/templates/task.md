---
human_revised: false
plan: <PLAN-ID>
task: T<N>
depends-on: []           # other task IDs in this plan (apply order within the change)
concerns: []             # paths under topology/ this step touches
files: []                # PREDICTED files (HCL / manifests / modules) this step creates or modifies (not exhaustive)
status: pending | in-progress | done | blocked
apps: [dev] | [staging] | [prod] | [all]   # environments this step applies to
aux: []
---

# T<N> — <apply-step title>

## What to do

The concrete change: which stack/module, which resources, which inputs. Files to create or modify.

## Context

Background not in `topology/`: rationale, links, prior decisions, the upstream change request.

## Apply

Step-by-step. The exact commands (`terraform plan` / `apply`, `pulumi up`, `kubectl apply`, …), the expected plan diff, and any manual gate before applying.

## Verify

How to confirm the resources are healthy after apply — stack outputs, health checks, smoke tests.

## Done when

- [ ] Applied to the target environment(s) in `apps:`.
- [ ] The `plan` diff matched expectation — no unintended destroys/replaces.
- [ ] Verification passed.
