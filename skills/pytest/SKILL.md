---
human_revised: false
version: 1
name: pytest
description: Use this skill whenever the work involves pytest — writing or reading `test_*.py`/`*_test.py`, running the suite, reading a failure or traceback, using fixtures/parametrize/markers, measuring coverage, or mocking at the unit/integration level in Python. Opt-in companion to the qa-basic domain (`cumaru install --with pytest`); the tool mechanics are general, the integration notes assume the `.cumaru/` QA pillars (coverage/, standards/, plans/) when present. Trigger on `test_*.py` files, `pytest` commands, "run the python tests", "why is this test failing", "add a fixture for X".
---

# pytest

How to operate pytest safely inside the QA workflow. The golden rule: **a test is the executable spec of a behaviour — it must fail when the behaviour breaks and never be flaky.**

## The core loop

```bash
pytest                          # run the suite — the verification command (exits non-zero on failure)
pytest path/to/test_x.py        # a single file
pytest -k "scenario or expr"    # select by name expression
pytest -x                       # stop at first failure (triage)
pytest --lf                     # re-run only last-failed
pytest --cov=pkg                # coverage (pytest-cov)
```

- `-q` quiet, `-v` verbose (lists each test), `-ra` shows the reason summary for skips/xfails.
- A new test must **fail first** when the behaviour is broken, then pass — proof it asserts something real. `assert` with a helpful message; pytest rewrites assertions to show the operands.

## Reading a failure

pytest prints the failing `assert` with both operands inline and the traceback to the assertion. `--tb=short` trims noise; `-l` shows locals at the failure. `pytest -k name --pdb` drops into the debugger at the failure when you need to poke.

## Fixtures, parametrize, markers

- **Fixtures** (`@pytest.fixture`, `conftest.py`) provide setup/teardown and shared state — prefer `yield` fixtures for cleanup. Scope deliberately (`function` default; `session` only for truly immutable setup — broad scope leaks state).
- **`@pytest.mark.parametrize`** turns one test into many cases — the idiomatic way to cover a scenario's input space.
- **Markers** (`@pytest.mark.<name>`, registered in config) tag levels/slow tests; select with `-m "not slow"`.

## Levels (the `apps` axis)

pytest serves the **lower pyramid**:
- `unit` — a function/class in isolation; collaborators stubbed (`unittest.mock`, `monkeypatch`, `pytest-mock`'s `mocker`).
- `integration` — real collaborators together (a service + a test DB / `tmp_path`), mocking only true edges.

Push verification to the lowest level that catches the defect.

## Mock by level (per `standards/mocking-policy`)

- `unit` mocks dependencies — `mocker.patch('pkg.mod.dep')`, `monkeypatch.setattr`.
- `integration` uses real collaborators; mock only network/clock/randomness.
- Patch at the **point of use**, not definition, and let fixtures undo patches — leaked patches are a top flakiness source.

## Flakiness is a defect

- **Never `pytest-rerunfailures` into green.** A non-deterministic test is a bug — quarantine (`@pytest.mark.skip(reason=...)` + a ticket) and fix it.
- Common causes: order coupling (`pytest-randomly` surfaces it), real time (`freezegun`/inject a clock), shared session-scoped fixtures, unisolated tmp dirs/DB rows.

## Within the `.cumaru/` qa domain

- **`coverage/<area>/## Scenarios (GWT)`** ← each `GIVEN … WHEN … THEN …` maps to a `test_…` (or a `parametrize` case). The test module is the verification; the coverage area records intent, not a copy.
- **`apps:`** on a coverage area / case / task = `unit`, `integration`.
- **`standards/`** govern usage: `mocking-policy`, `test-data` (fixtures/factories, e.g. `factory_boy`), `coverage-policy`. Comply; don't restate.
- **Handoff** — record the `pytest` summary (`N passed`), the coverage delta if relevant, and the **flakiness check** (e.g. `pytest -p randomly` ran clean N times).

## "The test is the spec" still holds

`coverage/` documents which behaviours are verified and why; the `test_*.py` files are the verification. Keep them distinct.
