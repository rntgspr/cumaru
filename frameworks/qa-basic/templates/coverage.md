---
human_revised: false
generated: false
name: <area>
summary: <one-line summary, used in coverage/index.md>
depends-on: []           # coverage/ areas whose setup this one presumes (test-prerequisite order, e.g. auth before checkout)
relates: []              # intake/<KEY>s this area covers + sibling areas to consider
apps: [unit] | [integration] | [e2e] | [unit, e2e] | [all]   # levels this area is exercised at
deltas: []               # campaign IDs whose deltas built the current state — drill into archive/<PLAN-ID>/ for the verbose record
---

# <Area name> coverage

## Overview

What part of the system-under-test this area covers, and how it is verified. Name the **runner** that exercises it (Jest / Vitest / Playwright / Cypress / pytest / k6 / …) and where the test code lives. 1-3 paragraphs. Do **not** paste the `.test`/`.spec` source — describe strategy and intent, not the test code.

## Levels

Which levels exercise this area and what each is responsible for. Keep the pyramid: push verification to the lowest level that can catch the defect.

| Level | Responsibility | Notes |
|-------|----------------|-------|
| unit | <what unit tests guard here> | <mocked collaborators> |
| e2e  | <the critical flow e2e guards> | <none mocked> |

## Scenarios (GWT)

The behaviours verified here, in Given-When-Then. Each scenario maps to an acceptance criterion of the `relates:` intake item.

- GIVEN <precondition> WHEN <action> THEN <expected outcome>.
- GIVEN <precondition> WHEN <action> THEN <expected outcome>.

## Gaps

- What is **not** covered here and why (out of scope, covered elsewhere, resists automation), and the manual check that compensates if any.

## Dependencies (test-prerequisite order)

The areas in `depends-on:` must be set up first (their fixtures/state this area presumes). State why each prerequisite is required.

## Decisions

- YYYY-MM-DD: short rationale and link to the originating campaign (e.g. `AAA-1234`). Why this level split / runner / fixture strategy over the alternatives.

## Files

- [<case>.md](<case>.md) — a detailed case within this area, when a scenario grows beyond a flat entry.
- [<subarea>/](<subarea>/) — nested subarea (its own `index.md`), when a flow needs its own cases.

## Reference

Repository source files this area covers (the test sources) — read by
`cumaru coverage`. Every row targets a source file, resolved from the project
root (never a `.cumaru/` path, a directory, or a URL).

<!-- cumaru:reference -->
| Link | Description |
|------|-------------|
| [<flow>](<tests/path/to/file>) | <one-line prose: what this test file verifies for this area> |
<!-- /cumaru:reference -->
