---
human_revised: false
version: 1
name: playwright
description: Use this skill whenever the work involves Playwright — writing or reading `*.spec.ts` e2e/browser tests, running the suite, debugging with the trace viewer, handling auto-waiting and web-first assertions, or testing across browsers. Opt-in companion to the qa-basic domain (`cumaru install --with playwright`); the tool mechanics are general, the integration notes assume the `.cumaru/` QA pillars (coverage/, standards/, plans/) when present. Trigger on Playwright specs, `playwright test` commands, "write an e2e for X", "why is this e2e flaky", "open the trace".
---

# Playwright

How to operate Playwright safely inside the QA workflow. Playwright drives a real browser end-to-end. The golden rule: **e2e is the top of the pyramid — reserve it for the critical user journeys; mock nothing.**

## The core loop

```bash
npx playwright test                       # run the suite (headless) — the verification command
npx playwright test path/to/file.spec.ts  # a single file
npx playwright test -g "scenario name"    # by title
npx playwright test --ui                  # UI mode — author/debug interactively
npx playwright show-trace trace.zip       # open a recorded trace after a failure
```

- `playwright test` exits non-zero on failure — gate on it. `--ui` and `--headed` are for authoring/debugging, not for CI gating.
- Configure `trace: 'on-first-retry'` and `screenshot: 'only-on-failure'` — the trace is how you diagnose a failure without re-running blind.

## Reading a failure

Open the **trace** (`show-trace`) — it has the DOM snapshot, network, and console at each step. The error line names the failed assertion/locator; the snapshot shows the page state at that moment. Prefer this over staring at a stack trace.

## Web-first assertions kill most flakiness

- Use `await expect(locator).toBeVisible()` / `.toHaveText()` — they **auto-retry** until the condition holds or times out. This is the single biggest defense against flaky e2e.
- **Never** `waitForTimeout(<ms>)` to "let the page settle" — that is the #1 cause of flaky e2e. Wait for a condition (a locator, a response), not a clock.
- Prefer role/label locators (`getByRole`, `getByLabel`) over CSS/XPath — resilient to markup churn.

## Levels (the `apps` axis)

Playwright serves `e2e` (full browser journeys) and optionally **component testing** (`@playwright/experimental-ct-*`). Keep e2e scarce: one happy path + the few high-risk flows per area. Everything provable lower (a validation rule, a reducer) belongs at `unit`/`integration` (see the `vitest` skill).

## Mock nothing (per `standards/mocking-policy`)

`e2e` exercises the real stack. The only legitimate boundary controls are network stubs for **third-party** systems you don't own (`page.route` to fake a flaky payment provider) and deterministic seed data. Mocking your own backend in an e2e defeats its purpose — that's an integration test.

## Flakiness is a defect

- `retries` in CI buys signal stability, but **a test that only passes on retry is a bug** — open the trace, find the race, fix it (usually a missing web-first wait or shared state between tests).
- Isolate state: a fresh `context`/`storageState` per test; seed and tear down test data; never depend on another test's side effects or on run order.

## Within the `.cumaru/` qa domain

- **`coverage/<area>/## Scenarios (GWT)`** ← each `GIVEN … WHEN … THEN …` maps to a `test(...)`. The spec is the verification; the coverage area records which journeys are covered, not a copy of the spec.
- **`apps:`** on a coverage area / case / task = `e2e` (and `component` where used).
- **`standards/`** govern usage: `test-data` (seeding/fixtures), `environments` (against which env e2e runs), `flakiness-policy`. Comply; don't restate.
- **Handoff** — record the `playwright test` summary, the trace artifact for any investigated failure, and the **flakiness check** (ran clean N times, or quarantined with the trace attached).

## "The test is the spec" still holds

`coverage/` documents which journeys are verified and why; the `*.spec.ts` files are the verification. Keep them distinct.
