---
human_revised: false
plan: <PLAN-ID>
task: T<N>
status: complete | partial | blocked
date: YYYY-MM-DD
summary: Framework guidance for Hand-off — <PLAN-ID> / T<N> and its required workflow.
---

# Hand-off — <PLAN-ID> / T<N>

## Files touched

<!-- cumaru:touched -->
| Link | Description |
|------|-------------|
| [`<relative/path/file.spec.ts>`](<relative/path/file.spec.ts>) | created/modified/removed — one-line description of the change |
<!-- /cumaru:touched -->

## Scenarios covered

- GIVEN <precondition> WHEN <action> THEN <outcome> — at `<level>`, maps to `intake/<KEY>` AC.
- ...

## Decisions made during authoring

- Decision and short rationale. Only record what was NOT in the task — deviations, choices between alternatives (what to mock, which fixture), discoveries in the code under test.

## Commands run / verification

- `<runner cmd>` — result (passed / failed / relevant output).
- Flakiness check — N repeated runs, all green / quarantined with reason.

## Pending / follow-ups

- What was out of scope for this case and deserves a new task or a coverage gap note.
- "None" is a valid answer.

## Suggestions for the Lead

- Convention, gotcha, or pattern that surfaced and is not yet in `coverage/` or `standards/`.
- "None" is a valid answer.
