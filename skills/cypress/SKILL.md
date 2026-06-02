---
human_revised: false
version: 1
name: cypress
description: Use this skill whenever the work involves Cypress — writing or reading `*.cy.ts` e2e/component tests, running the suite, debugging via the command log / screenshots / videos, stubbing network with cy.intercept, or handling retry-ability. Opt-in companion to the qa-basic domain (`cumaru install --with cypress`); the tool mechanics are general, the integration notes assume the `.cumaru/` QA pillars (coverage/, standards/, plans/) when present. Trigger on `*.cy.*` files, `cypress` commands, "write an e2e for X", "why is this cypress test flaky", "stub this request".
---

# Cypress

How to operate Cypress safely inside the QA workflow. Cypress drives a real browser. The golden rule: **e2e is the top of the pyramid — reserve it for the critical user journeys; mock only what you don't own.**

## The core loop

```bash
npx cypress run                         # headless, CI-style — the verification command (exits non-zero)
npx cypress run --spec "path/to.cy.ts"  # a single spec
npx cypress open                        # interactive runner — author/debug
```

- `cypress run` is what you gate on. `open` is for authoring/debugging.
- On failure, Cypress saves a **screenshot** and (in `run`) a **video**; the in-runner **command log** shows every step with a time-travel snapshot.

## Reading a failure

Read the **command log** at the failed step — hover to time-travel the DOM to that moment. The screenshot/video shows the page state. The error names the failed assertion or the command that couldn't find an element.

## Retry-ability kills most flakiness

- Cypress commands and assertions **auto-retry** until they pass or time out — `cy.get('[data-cy=submit]').should('be.visible')` keeps trying. Lean on this.
- **Never** `cy.wait(<ms>)` to "let it settle" — wait on a thing: `cy.wait('@alias')` for a stubbed request, or an assertion that retries. Arbitrary waits are the #1 flaky-e2e cause.
- Prefer stable `data-cy`/`data-test` selectors over brittle CSS/text.

## Levels (the `apps` axis)

Cypress serves `e2e` (browser journeys) and **component testing** (`cypress/component`, mounting a component directly). Keep e2e scarce — one happy path + the few high-risk flows per area; push everything provable lower to `unit`/`integration` (see `vitest`/`pytest`).

## Network: stub what you don't own (per `standards/mocking-policy`)

- `cy.intercept(...)` stubs/inspects network — legitimate for **third-party** systems (fake a flaky payment gateway) and for deterministic seed responses.
- In a true `e2e`, hit your **real** backend; stubbing your own API turns it into an integration test. Use `cy.session` to cache login and isolate state.

## Flakiness is a defect

- `retries` (config) stabilizes CI signal, but **a test that only passes on retry is a bug** — read the command log, find the race (usually a missing retried assertion or leaked state), fix it.
- Isolate: reset/seed state before each test (`beforeEach`, a task or API call); never depend on another spec's side effects or on run order.

## Within the `.cumaru/` qa domain

- **`coverage/<area>/## Scenarios (GWT)`** ← each `GIVEN … WHEN … THEN …` maps to an `it(...)`. The spec is the verification; the coverage area records which journeys are covered, not a copy of the spec.
- **`apps:`** on a coverage area / case / task = `e2e` (and `component` where used).
- **`standards/`** govern usage: `test-data` (seeding via `cy.task`/API), `environments` (target env, `baseUrl`), `flakiness-policy`. Comply; don't restate.
- **Handoff** — record the `cypress run` summary, the screenshot/video for any investigated failure, and the **flakiness check** (ran clean N times, or quarantined with the artifact attached).

## "The test is the spec" still holds

`coverage/` documents which journeys are verified and why; the `*.cy.ts` files are the verification. Keep them distinct.
