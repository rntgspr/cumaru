---
human_revised: false
name: acceptance-testing
applies-when: a plan is implemented and about to close; verifying its acceptance criteria with evidence before archive
source:
  plugin: xhyqaq/superpowers-plus
  skill: acceptance-testing
  url: https://github.com/xhyqaq/superpowers-plus/blob/main/skills/acceptance-testing/SKILL.md
  license: MIT
summary: Framework guidance for Acceptance testing and its required workflow.
---

# Acceptance testing

**Gate:** a plan is not done until every acceptance criterion has recorded evidence of a pass. A
failing criterion is a blocker, not a review comment — never close or archive with one in FAIL.

## Cycle

1. **Source the criteria** — the EARS / RFC 2119 criteria already authored for the work: `## Acceptance
   Criteria (EARS / RFC 2119)` in `intake/<KEY>.md`, plus any `## Requirements (EARS / RFC 2119)` in the spec areas the
   plan's `scope:` touches. If a behavior has no criterion, write it first — don't invent a pass.
2. **Prove each one** — run a deterministic check appropriate to the criterion (unit / integration
   test, API call, UI driver, or a recorded manual repro) and capture the evidence. Each criterion
   is exactly PASS, FAIL, or Blocked — "looks fine" is not a verdict.
3. **Act on the result:**
   - All PASS → proceed to close / `archive`.
   - Any FAIL → create targeted fix tasks in the plan, fix, then re-prove. Loop until green.
   - Blocked on missing infrastructure → stop and get explicit user approval to defer that
     specific criterion; never silently skip it.
4. **Never weaken to pass** — fixing the code is the only move; editing the criterion so it passes
   is fraud, not progress.

Pairs with `verification` (fresh evidence in the same message) and `tdd` (the per-behavior tests
this gate aggregates). Distinct from code review: review judges *how* it's built; this judges
*whether it does what was asked*.

## Red flags

- Closing / archiving while any criterion shows FAIL.
- Relaxing or deleting a criterion because it's hard to pass.
- Accepting "should be fine" from a check as a PASS.
- Skipping it because "the unit tests pass" — unit tests and acceptance criteria test different things.
