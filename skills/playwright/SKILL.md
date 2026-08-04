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
- Keep retries disabled. A minimal configuration is:

  ```ts
  import { defineConfig } from '@playwright/test'

  export default defineConfig({
    retries: 0,
    use: {
      screenshot: 'only-on-failure',
      trace: 'retain-on-failure',
    },
  })
  ```

- Do not enable retries merely to obtain traces. If the repository already has
  retries enabled, tell the user and report first-attempt failures instead of
  treating a retry pass as clean verification.

## Reading a failure

When `trace: 'retain-on-failure'` produced a trace, open it with `show-trace`;
it contains the DOM snapshot, network, and console at each step. If no trace was
produced, say so and use the error, HTML report, screenshot, or a deliberate
debug run. Never promise a trace before checking the configuration and output.

## Web-first assertions kill most flakiness

- Use `await expect(locator).toBeVisible()` / `.toHaveText()` — they **auto-retry** until the condition holds or times out. This is the single biggest defense against flaky e2e.
- **Never** `waitForTimeout(<ms>)` to "let the page settle" — that is the #1 cause of flaky e2e. Wait for a condition (a locator, a response), not a clock.
- Prefer role/label locators (`getByRole`, `getByLabel`) over CSS/XPath — resilient to markup churn.

## Levels (the `targets` axis)

Playwright serves `e2e` (full browser journeys) and optionally **component testing** (`@playwright/experimental-ct-*`). Keep e2e scarce: one happy path + the few high-risk flows per area. Everything provable lower (a validation rule, a reducer) belongs at `unit`/`integration` (see the `vitest` skill).

## Mock nothing (per `standards/mocking-policy`)

`e2e` exercises the real stack. The only legitimate boundary controls are network stubs for **third-party** systems you don't own (`page.route` to fake a flaky payment provider) and deterministic seed data. Mocking your own backend in an e2e defeats its purpose — that's an integration test.

## Flakiness is a defect

- Keep retries at `0`. A flaky result remains a failure to diagnose, not a
  candidate for automatic retry. Use the retained failure trace when available
  to find the race, usually a missing web-first wait or shared state.
- Isolate state: a fresh `context`/`storageState` per test; seed and tear down test data; never depend on another test's side effects or on run order.

## Within the `.cumaru/` qa domain

- **`coverage/<area>/## Scenarios (GWT)`** ← each `GIVEN … WHEN … THEN …` maps to a `test(...)`. The spec is the verification; the coverage area records which journeys are covered, not a copy of the spec.
- **`targets:`** on a coverage area / case / task = `e2e` (and `component` where used).
- **`standards/`** govern usage: `test-data` (seeding/fixtures), `environments` (against which env e2e runs), `flakiness-policy`. Comply; don't restate.
- **Handoff** — record the `playwright test` summary, state that retries remained
  disabled, attach the trace only when one was actually produced, and include
  the **flakiness check** (ran clean N times, or quarantined with the available
  evidence attached).

## "The test is the spec" still holds

`coverage/` documents which journeys are verified and why; the `*.spec.ts` files are the verification. Keep them distinct.

Reference: [Playwright trace modes](https://playwright.dev/docs/trace-viewer).
