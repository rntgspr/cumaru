---
human_revised: false
generated: false
---

# Bootstrap — <area>

<!-- BEGIN BOOTSTRAP-INSTRUCTIONS
INSTRUCTION FOR LLM:

This file is the persistent discovery log for this spec area. It is created
by `cumaru specs bootstrap` (light pass) and grown by future
`cumaru specs deep <area>` invocations. Leave it on disk after editing — it is
the area's evolving record of how the spec was inferred from code.

The light pass output below is filled in deterministically by the CLI; the
sections under `## Files` and `## Topics` are yours to write.

# Light pass — your job

  1. Read the entry-point files listed under `## Files` (start with
     `index.*`, `main.*`, `app.*`, or similar; expand to a handful more if
     needed). The goal is breadth, not depth.

  2. Write `specs/<area>/index.md` following `templates/spec.md`:
     - frontmatter: `name`, `summary` (one line), `depends-on:` (use the
       cross-area imports detected below), `apps:` (from the project's
       `schema.yaml` `apps.values`), `deltas: []`.
     - `## Overview` — 1-3 paragraphs: what the area does, why it exists.
     - `## Requirements (EARS / RFC 2119)` — EARS for observable behaviors,
        RFC 2119 for constraints/invariants. Light pass produces
        broad, possibly imprecise requirements; the deep pass refines.
     - `## Decisions` — non-obvious design choices visible in the code, or
       `(none surfaced)` if you cannot tell.
     - `## Files` — markdown list with one-line role descriptions per file.

  3. Below, populate `## Topics` — each item is a named investigation
     ("topic") that a future deep pass can target. Pick topics that surfaced
     as **unclear, complex, or under-specified** during the light read.
     Use kebab-case slugs and one short rationale each.

  4. Leave this file on disk. Do NOT delete it.

# Deep pass — your job (when invoked later)

  1. Read this file end-to-end (light + prior deep passes, if any).

  2. Either iterate **every topic** under `## Topics` (default), or focus on
     the one passed via `--topic <slug>`.

  3. Append a new `## Discovery (deep pass <ISO>) — <scope>` section at the
     end of this file. Do NOT edit prior sections.
     - `<scope>` is `topic: <slug>` or `all topics`.
     - For each topic addressed: `### Topic: <slug>` followed by findings
       (file refs, decisions discovered, reconciliations made).

  4. Refine `specs/<area>/index.md` with what you learned: tighten requirements,
     add `## Decisions`, update `## Files` descriptions, split into
     `<area>/<concern>.md` if it grows large — or promote a concern to a
     `<area>/<subarea>/` directory (with its own `index.md`) when it grows
     beyond a flat file and needs its own concerns.

END BOOTSTRAP-INSTRUCTIONS -->

## Discovery (light pass <ISO datetime>)

- **Path:** `<scan-path>/<area>/`
- **Files:** N (M LOC)
- **Top-level imports** (external packages used):
  - `<package>` (used in N files)
- **Cross-area imports** (candidates for `depends-on:`):
  - `<other-area>` (used in N files)
- **TODO/FIXME found:**
  - `<path>:<line>` — `<text>`

## Files

_The CLI lists the files below; you describe them after the light read._

- `<file>` — _(LLM: one-line description after light read)_

## Topics

_LLM populates this section during the light pass — one bullet per
investigation worth deepening later._

- **<topic-slug>** — _(one-line rationale: what's unclear / complex /
  under-specified)_

<!-- Future deep passes append below. Each pass starts a new
     `## Discovery (deep pass <ISO>) — <scope>` section and never edits
     prior sections. -->
