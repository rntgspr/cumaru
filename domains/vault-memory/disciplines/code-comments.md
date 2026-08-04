---
human_revised: false
name: code-comments
applies-when: writing, editing, reviewing, refactoring, or documenting code, tests, scripts, configuration, or infrastructure definitions where comments may be created, preserved, changed, or removed; or deciding whether an explanation belongs in source code or the domain's durable prose
strictness: 9/10
summary: Framework guidance for documenting real functions, capping other comments at 512 characters, and moving explanation into domain prose.
---

# Code comments

**Gate:** document **real functions** — the actual units of the codebase. Do not document the code
*inside* them. Every other comment is capped at **one line of at most 512 characters** and must earn
its place by naming something **ambiguous, unfinished, technically indebted, or hostile to DX**.
Explanation that is none of those belongs in the domain's durable prose, related back to the code by
the mechanism the domain declares — not in a comment.

Strictness 9/10 — a hard hand. A real function deserves a description of what it does; a block in
the middle of a function body does not. Prose buried in a function body is unversioned, untested,
and unreachable by the loading rule: nothing relates it to a concern, nothing validates it, and it
drifts from the code beneath it until it lies. The framework already has a home for explanation, and
it is not the source file.

## What an in-code comment is for

A comment inside a function is a **signal**, not documentation. Write one only when the reader would
otherwise be misled:

- **Ambiguous** — the intent is not recoverable from the code, and no rename fixes it.
- **Unfinished** — a known gap, a partial implementation, a deliberate stub.
- **Technical debt** — a shortcut taken knowingly; state the cost, not the apology.
- **DX friction** — a sharp edge, an ordering trap, a surprise the next reader will hit.

Write it in plain, short, self-explanatory language: one clear sentence beats a paragraph. 512 is a
ceiling, not a target.

## Where the explanation goes instead

Redirect the effort. Behavior, contracts, decisions and rationale become **prose in the domain's
durable pillar**, connected with the relation that domain declares — a `reference` row to the source
file, `depends-on` / `relates` between concerns, or the domain's own graph fields. Honor the
domain's and the framework's constraints while doing it:

- Prose under `.cumaru/` is English, carries a valid `summary:`, and lives in the pillar its
  `domain.md` declares — never a second copy of something already canonical elsewhere.
- Every relation is declared, never implied by proximity; an unrelated note is unreachable prose.
- Where the domain declares a specification pillar, `cumaru coverage` is the measure of whether the
  code is actually described.

## Red flags

- A comment narrating *what* the next lines do — the code already says that; rename instead.
- A design decision, trade-off, or contract argued inside a function body.
- Two or more consecutive comment lines below a real function's description.
- A `TODO` with no stated cost, owner, or condition — that is a shrug, not a signal.
- A comment that outlived the code it described, because nothing related it to a concern.
- Reaching for a second line to keep a paragraph you like. Cut the paragraph, write the spec.
