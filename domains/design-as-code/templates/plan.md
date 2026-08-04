---
human_revised: false
key: <KEY> # omit for internal maintenance
type: <tracker item type> # omit for internal maintenance
scope:
  - <area>/<concern>
status: drafting
summary: Design delivery plan linking accepted requirements to tasks and review.
targets: []
audience: []
platforms: []
aux: []
---

# <Plan title>

## Acceptance source

<!-- Tracker-backed: keep this section; remove the maintenance-only Overview
and Acceptance Criteria sections below. Link the flat brief, selected concept
(if any), and research with paths relative to this plan index. -->

- [Brief](../../intake/<KEY>.md) — canonical local Overview and Acceptance Criteria.
- [Selected concept](../../concepts/<slug>/index.md) — direction and alternatives.
- [Research](../../research/<slug>/index.md) — supporting findings.

<!-- Internal maintenance: omit key/type and the Acceptance source section.
Keep the two sections below. Maintenance may start without intake or a concept;
it is not a bypass for promotion of a selected product design concept. -->

## Overview

Describe the internal maintenance outcome and why it is needed.

## Acceptance Criteria (EARS / RFC 2119)

Use stable IDs and one dominant requirements style. Cover applicable design
dimensions and explain exclusions, using the guidance in `templates/intake-brief.md`.

- AC-1: WHEN <trigger> THE SYSTEM SHALL <observable response>.

## Acceptance coverage

Map every accepted criterion to delivery and verification without copying its
text. For tracker-backed work, link the criterion in `intake/<KEY>.md`; for
maintenance, use the ID above. Resolve gaps before dispatch and keep evidence
and review results in the task handoff.

| Criterion | Task | Required evidence |
|---|---|---|
| <source link / AC-1> | [T1](t1.md) | <artifact, revision, states, viewports, checks> |

For asset-only maintenance, use `scope: []` and task `concerns: []`, link the
affected asset records in task context, and propose an asset delta with an
explicit no-spec-change rationale. Do not invent a spec owner.

## Plan / DAG

| Task | Title | Status | Depends on |
|---|---|---|---|
| [T1](t1.md) | <title> | pending | — |

Use `t<N>.md` filenames and `targets:` for component scope. Tasks may run in
parallel only when dependencies are satisfied and allowed writes do not overlap.

## Out of scope

- <Explicit scope exclusions>.

## Risks

- <Observed risk and its effect on delivery or verification>.
