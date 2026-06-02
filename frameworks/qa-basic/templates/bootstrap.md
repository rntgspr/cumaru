---
human_revised: false
generated: false
---

# Bootstrap — <area>

<!-- BEGIN BOOTSTRAP-INSTRUCTIONS
INSTRUCTION FOR LLM:

This file is the persistent discovery log for this coverage area. It is created
by the `cumaru-coverage` bootstrap (light pass) and grown by future deep passes.
Leave it on disk after editing — it is the area's evolving record of how the
coverage map was inferred from the test suite and the code under test.

The light pass output below is filled in deterministically; the sections under
`## Files` and `## Topics` are yours to write.

# Light pass — your job

  1. Read the existing test files for this area (start with the obvious
     `*.test.*` / `*.spec.*` / `e2e/` entry points; expand to a handful more if
     needed) AND skim the code under test. The goal is breadth: what is already
     verified, at what level, and what visibly is not.

  2. Write `coverage/<area>/index.md` following `templates/coverage.md`:
     - frontmatter: `name`, `summary` (one line), `depends-on:` (areas whose
       setup this one presumes), `relates:` (intake `<KEY>`s covered), `apps:`
       (the levels actually exercised, from `schema.yaml` `apps.values`),
       `deltas: []`.
     - `## Overview` — what the area covers and the runner that exercises it.
     - `## Levels` — what each level is responsible for here.
     - `## Scenarios (GWT)` — observable behaviours as
       `GIVEN <precondition> WHEN <action> THEN <outcome>`, inferred from the
       existing tests. Light pass produces broad scenarios; the deep pass refines.
     - `## Gaps` — behaviours with no test, or `(none surfaced)` if you cannot tell.

  3. Below, populate `## Topics` — each item is a named investigation a future
     deep pass can target. Pick topics that surfaced as **under-covered,
     complex, or flaky** during the light read. Use kebab-case slugs and one
     short rationale each.

  4. Leave this file on disk. Do NOT delete it.

# Deep pass — your job (when invoked later)

  1. Read this file end-to-end (light + prior deep passes, if any).

  2. Either iterate **every topic** under `## Topics` (default), or focus on
     the one passed via `--topic <slug>`.

  3. Append a new `## Discovery (deep pass <ISO>) — <scope>` section at the end.
     Do NOT edit prior sections.

  4. Refine `coverage/<area>/index.md` with what you learned: tighten scenarios,
     close gaps, update `## Levels`, split into `<area>/<case>.md` or promote a
     flow to a `<area>/<subarea>/` directory when it grows beyond a flat file.

END BOOTSTRAP-INSTRUCTIONS -->

## Discovery (light pass <ISO datetime>)

- **Path:** `<test-path>/<area>/`
- **Test files:** N (M scenarios)
- **Levels present:**
  - `<unit | integration | e2e>` (N files)
- **Runner(s) detected:**
  - `<jest | vitest | playwright | pytest | …>`
- **Visible gaps (code paths with no test):**
  - `<path>:<symbol>` — `<what is unverified>`

## Files

_The CLI lists the files below; you describe them after the light read._

- `<file>` — _(LLM: one-line description after light read — what it verifies, at what level)_

## Topics

_LLM populates this section during the light pass — one bullet per investigation
worth deepening later._

- **<topic-slug>** — _(one-line rationale: what's under-covered / complex / flaky)_

<!-- Future deep passes append below. Each pass starts a new
     `## Discovery (deep pass <ISO>) — <scope>` section and never edits
     prior sections. -->
