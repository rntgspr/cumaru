---
human_revised: false
version: 1
name: vitest
description: Use this skill whenever the work involves Vitest (or Jest — the runner mechanics map 1:1) — writing or reading `*.test.ts`/`*.spec.ts`, running the suite, reading a failure, measuring coverage, or mocking at the unit/integration level. Opt-in companion to the qa-basic domain (`cumaru install --with vitest`); the tool mechanics are general, the integration notes assume the `.cumaru/` QA pillars (coverage/, standards/, plans/) when present. Trigger on `*.test.*`/`*.spec.*` files, `vitest`/`jest` commands, "run the unit tests", "why is this test failing", "add coverage for X".
---

# Vitest (and Jest)

How to operate Vitest safely inside the QA workflow. Jest is a near drop-in — `describe`/`it`/`expect`, mocks, and the CLI flags below map 1:1. The golden rule: **a test is the executable spec of a behaviour — it must fail when the behaviour breaks and never be flaky.**

## The core loop

```bash
vitest run                      # one-shot, CI-style (exits) — use this to verify
vitest                          # watch mode — fast feedback while authoring
vitest run path/to/file.test.ts # a single file
vitest run -t "scenario name"   # a single test by name
vitest run --coverage           # coverage report (v8 / istanbul)
```

- `vitest run` is the verification command (it exits non-zero on failure). Plain `vitest` watches — never the thing you gate on.
- A new test must **fail first** when the behaviour is broken (delete the impl line / flip the assertion to confirm), then pass — that proves it asserts something real.

## Reading a failure

The diff under `AssertionError: expected … to … ` is the headline — read the expected-vs-received before touching code. `--reporter=verbose` lists every test; `--bail=1` stops at the first failure when triaging. A test that passes but asserts nothing (no `expect`) is worse than no test — Vitest's `--allowOnly=false` and an `expect.assertions(n)` guard catch some of these.

## Levels (the `apps` axis)

Vitest serves the **lower pyramid**:
- `unit` — a function/module in isolation; collaborators mocked (`vi.mock`, `vi.fn`).
- `integration` — several real modules together (a service + its in-memory repo), or a component via `jsdom`/`@vitest/browser`.

Push verification to the lowest level that catches the defect. A behaviour provable at `unit` does not earn an `e2e`.

## Mock by level (per `standards/mocking-policy`)

- `unit` mocks dependencies — `vi.mock('./dep')`, `vi.spyOn`, `vi.fn`.
- `integration` uses real collaborators; mock only the true edges (network, clock, randomness).
- Reset between tests — `vi.restoreAllMocks()` / `restoreMocks: true`. Leaked mock state is a top flakiness source.

## Flakiness is a defect

- **Never `--retry` into green.** Vitest can retry, but a non-deterministic test is a bug — quarantine (`it.skip` + a tracked ticket) and fix it.
- Common causes: shared mutable state between tests, real timers (`vi.useFakeTimers()`), real dates (inject a clock), unawaited promises, test order coupling (`--sequence.shuffle` surfaces it).

## Within the `.cumaru/` qa domain

- **`coverage/<area>/## Scenarios (GWT)`** ← each `GIVEN … WHEN … THEN …` maps to a `describe`/`it` block. The test file is the executable verification; the coverage area records intent, not a copy of the test.
- **`apps:`** on a coverage area / case / task = the levels exercised — `unit`, `integration`.
- **`standards/`** govern usage: `mocking-policy`, `test-data` (factories/fixtures), `coverage-policy` (gates). Comply; don't restate them in the test.
- **Handoff** — record the actual `vitest run` summary (`N passed`), the coverage delta if relevant, and the **flakiness check** (e.g. `vitest run --sequence.shuffle` ran clean N times).

## "The test is the spec" still holds

`coverage/` documents which behaviours are verified and why; the `*.test.ts` files are the verification itself. Keep them distinct — never paste test source into the coverage map.
