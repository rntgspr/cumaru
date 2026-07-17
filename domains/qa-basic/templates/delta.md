---
human_revised: false
plan: <PLAN-ID>
date: YYYY-MM-DD
apps: []
summary: Framework guidance for Delta — <PLAN-ID> and its required workflow.
---

# Delta — <PLAN-ID>

Delta applied to `coverage/` when this campaign was archived. Source of authority for the coverage changes that landed on close.

Each section names a path under `coverage/` and lists scenario-level changes. Paths may reference an area's `index.md`, a flat case file (`<area>/<case>.md`), or a subarea at any depth. Use the headings exactly: `### Added Scenarios`, `### Modified Scenarios`, `### Removed Scenarios`.

## coverage/<area>

### Added Scenarios

- GIVEN <precondition> WHEN <action> THEN <outcome> — at <level>.

### Modified Scenarios

- GIVEN <precondition> WHEN <action> THEN <new outcome>
  (was: THEN <old outcome>)

### Removed Scenarios

- (Quoted previous scenario, with reason for removal.)

### Levels / Gaps changed

- <what changed in the pyramid or in the known gaps for this area.>

## coverage/<another-area>

### Added Scenarios

- ...
