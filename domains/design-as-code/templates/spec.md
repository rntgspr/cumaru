---
human_revised: false
name: <area or concern>
summary: Current design experience requirements with durable supporting evidence.
depends-on: [] # paths under specs/
relates: []
targets: []
---

# <Area or concern name>

## Overview

Audience, outcome, and boundaries of this foundation, component, or journey.
Describe the current experience; proposals remain in active work.

## Requirements (EARS / RFC 2119)

Assign stable local requirement IDs and use one dominant style. Group by concern
where useful. Carry accepted interaction states and transitions, hierarchy and
consistency, responsive behavior, accessibility, and content into observable
requirements. State applicable viewports, input/focus behavior, project
accessibility criteria, labels/messages, and content variants where relevant.
Record reasons for inapplicable dimensions; do not invent requirements.

- R-1: WHEN <trigger> THE SYSTEM SHALL <observable response>.

## Decisions

Record current choices and their rationale. Retain accepted research findings
and limitations with original provenance. Link original tracker/source material
or durable owners; do not leave links to transient work scheduled for cleanup.

## Evidence and design sources

| Requirement | Original source / prototype revision | Verification evidence and limits |
|---|---|---|
| R-1 | <source location and revision/date> | <observed state, viewport, method, result, limits> |

Retain enough written detail to implement and review without a Figma link.
Links supplement the contract. Keep required evidence in a retained location
before deleting its transient host; reference reusable assets in `assets/`
without duplicating their source, license, or usage records.

## Reference

Source implementation files only, resolved from the project root. Keep external
URLs, prototypes, and `.cumaru/` evidence in the section above, outside this tag.

<!-- cumaru:reference -->
| Link | Description |
|---|---|
| [<source>](<src/path/to/file>) | <implementation responsibility> |
<!-- /cumaru:reference -->
