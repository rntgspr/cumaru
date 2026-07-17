---
human_revised: false
plan: <PLAN-ID>
task: T<N>
depends-on: [] # other task IDs in this plan (authoring order within the campaign)
concerns: [] # paths under coverage/ this case touches
files: [] # PREDICTED test files (specs/fixtures/factories) this case creates or modifies (not exhaustive)
status: "pending | in-progress | done | blocked"
apps: "[unit] | [integration] | [e2e] | [all]   # test levels this case is written at"
aux: []
summary: Framework guidance for T<N> — <case title> and its required workflow.
---

# T<N> — <case title>

## What to do

The concrete case(s) to author/automate: which area, which scenarios (Given-When-Then), at which level. The test files to create or modify.

## Context

Background not in `coverage/`: the requirement being verified (`intake/<KEY>` acceptance criterion), prior decisions, links to the feature under test.

## Author / Automate

Step-by-step. Which fixtures/factories to use (per `standards/test-data`), what to mock at this level (per `standards/mocking-policy`), the runner command to execute the new tests.

## Verify

How to confirm the tests are meaningful and stable — they fail when the behaviour breaks (mutation/red check), pass when it holds, and are not flaky across repeated runs.

## Done when

- [ ] Scenarios authored at the level(s) in `apps:`, each mapping to an acceptance criterion.
- [ ] Tests pass and are non-flaky (verified across repeated runs).
- [ ] Mocking / data / naming comply with the relevant `standards/`.
