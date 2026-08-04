---
human_revised: false
plan: <PLAN-ID>
task: T<N>
status: partial # complete | partial | blocked
date: YYYY-MM-DD
summary: Design task handoff with criterion evidence and independent review findings.
---

# Hand-off — <PLAN-ID> / T<N>

## Files touched

List only repository files created, modified, or removed by the task. Paths are
relative to the project root; do not use `.cumaru/` paths or paths containing
`..`. Leave the table empty when the task changed only Cumaru knowledge
artifacts or external design artifacts.

<!-- cumaru:touched -->
| Link | Description |
|---|---|
| [<file>](<project-root-relative-path>) | <created/modified/removed and purpose> |
<!-- /cumaru:touched -->

## Delivered artifacts

List Cumaru knowledge artifacts, prototype/frame links, external evidence, and
the delivered revision here, outside `touched`. Retain each location and
revision. Link supporting screenshots or other evidence with their inspected
state and viewport. Visual links supplement the written acceptance source and
verification results.

## Verification results

Use the task's verification contract; retain criterion IDs rather than copying
requirements. Report observed results, commands/manual checks, and untested
cases. Missing evidence is not a pass. Explain inapplicable dimensions.

| Criterion | Artifact / revision / state / viewport | Method | Observed result / evidence | Gaps |
|---|---|---|---|---|
| <AC-1> | <inspected scope> | <check> | <pass/fail and evidence link> | <missing checks or none> |

## Decisions and proposed delta

Record deviations and rationale, source/concept evidence, and proposed spec or
asset changes using `templates/delta-draft.md`. Lead consolidates contributions.
If Lead executed directly, record the reason; independent review still applies.

## Independent review

Lead retains the separate Reviewer's report here. Identify reviewer, reviewed
revision, checked criteria and scope, findings, and untestable cases. For no
findings, explicitly record what was checked; an empty section is missing review.

| Finding / criterion | Location / state | Expected vs observed / evidence | User impact / correction | Disposition / recheck |
|---|---|---|---|---|
| <ID / AC-1> | <artifact location> | <finding and evidence> | <impact and required work> | <open or resolution with reviewer, revision, evidence> |

Record acceptance decisions from the user and rechecks of corrected artifacts.
Unresolved findings or missing verification block readiness; Lead reconciles
status and the plan DAG after examining the evidence.

## Pending / follow-ups

Remaining work, blockers, and proposed out-of-scope follow-ups, or `None`.
