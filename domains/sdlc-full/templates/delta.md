---
human_revised: false
plan: <PLAN-ID>
date: YYYY-MM-DD
apps: []
summary: Framework guidance for Delta — <PLAN-ID> and its required workflow.
---

# Delta — <PLAN-ID>

Delta applied to `specs/` when this plan was archived. Source of authority for the changes that landed in the system spec on close.

Each section names a path under `specs/` and lists requirement-level changes. Paths may reference an area's `index.md`, a flat concern file (`<area>/<concern>.md`), or a subarea at any depth (`<area>/<subarea>/index.md`, `<area>/<subarea>/<concern>.md`). Use the headings exactly: `### Added Requirements`, `### Modified Requirements`, `### Removed Requirements`.

## specs/<area>/<concern>.md

### Added Requirements

- WHEN <trigger> THE SYSTEM SHALL <new response>.

### Modified Requirements

- WHEN <trigger> THE SYSTEM SHALL <new response>
  (was: WHEN <trigger> THE SYSTEM SHALL <old response>)

### Removed Requirements

- (Quoted previous requirement, with reason for removal.)

## specs/<another-area>/index.md

### Added Requirements

- ...
