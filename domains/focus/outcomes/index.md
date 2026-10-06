---
human_revised: false
summary: Results derived from threads and organized by their primary area.
targets: [meta]
---

# Outcomes

- Store results as `outcomes/<area>/<slug>.md`. Use lowercase kebab-case slugs
  matching `[a-z0-9]+(-[a-z0-9]+)*`, describing what resulted from the thread(s).
- Areas are adopter-declared; this domain ships none, so `outcomes` starts with
  no area key at all. Add each area as its own key under `outcomes` in
  `config.yaml`, shaped `<area>: {"*.md": {tags: [threads]}}`, then create its
  `index.md` from `templates/any-index.md`. Name every area explicitly; a `"*"`
  wildcard would also match each area's own `index.md` and demand the `threads`
  tag from it. Use the primary area, and declare one fallback area for results
  that fit no other. An outcome always lives in exactly one area.
- Describe the actual result and relevant rationale in plain Markdown. An
  outcome can be a decision, finding, or delivered change; do not present planned
  work as completed. No EARS or RFC format is required.
- Every outcome has a nonempty `<!-- cumaru:threads -->` table with `Link` and
  `Contribution` columns. Each row links to an existing source thread using
  `../../threads/<name>.md` or `../../threads/archive-YYYY/<name>.md`, matching
  its current location, and explains its contribution. Deduplicate rows.
- The `threads` tag is the canonical many-to-many relationship. The generic
  `reference` tag is reserved by Cumaru for repository source code.
- Read linked source threads when loading an outcome. Custom tag links require
  explicit existence checks; `cumaru doctor` does not resolve them automatically.
- Reclassify with `cumaru fs ... move ...`, preserving prose and provenance.
  Check the destination before moving and repair incoming links afterward.

Use [the outcome template](../templates/outcome.md) for new entries and
`cumaru tree outcomes` for discovery. External evidence remains in the threads.

## Cumulative views

Every outcome maintains three views and a concise current overview. Use dated
ledger entries with stable IDs and links to evidence in source threads. Repeated
scans must not add the same contribution again. Later updates can increase or
decrease totals; preserve the original entry and record a linked correction.
Unknown is not zero. Outcomes stay updateable after source threads are archived.

### Kudos per item

Every row added to the value, work, or policy ledger has a `Kudos` count,
initialized to `0`. Award kudos in increments of `10`, allowing `5` for smaller
contributions; totals are nonnegative multiples of `5`. Increase the count only
for explicit recognition of that item, retaining the source and award rationale
in its existing evidence field. Deduplicate repeated observations of the same
recognition. Preserve counts when editing,
correcting, or reclassifying entries; a new correction row starts at `0` and does
not inherit the original row's kudos. Existing entries without a count remain
unknown until their recognition history is checked. Kudos do not change value
deltas, work minutes, or feedback dispositions.

### Value

Describe the benefit to the product or tool and who benefits. Assess it against
the value scope of the directives this outcome serves: the directive states the
benefit being pursued, and this view measures the contribution to it. An outcome
serving no directive records that gap instead of inventing a scale. Use a
measured unit when supported, otherwise explicitly labeled artificial value
points. For artificial points, define the scale and rationale before scoring,
deriving it from the directive rather than from a generic default; no automatic
conversion from effort, approvals, or ticket count. Separate
estimated from evidenced contributions. Show the cumulative total per unit and
method, with dated signed deltas for additions, reassessments, and reversals.
Never sum incompatible units or count the same benefit in multiple outcomes:
record allocation where a shared result contributes to more than one outcome.

### Work

Track accumulated work in minutes, keeping recorded and estimated effort
separate. Each entry identifies date or interval, activity, contributor, duration,
source, and allocation to this outcome. Deduplicate shared sessions and overlapping
time; allocations across outcomes must not exceed the original session duration.
Waiting for QA, review, or a response is elapsed time, not labor. Do not infer
work hours from issue age, message timestamps, or number of comments. Missing
time stays unknown; totals explicitly state their coverage and exclusions.

### Policy and feedback

Track how feedback and comments were received and handled inside the system,
not personal sentiment or hidden motives. For each identifiable feedback item,
record author, date, source, proposal, response or decision, decision-maker when
known, rationale, and implementation evidence. Distinguish pending, accepted,
partially accepted, rejected, deferred, and superseded decisions; separately
record whether the accepted change was implemented or remains unverified.
Preserve decision reversals. Silence, an approval, or a resolved discussion alone
does not prove every suggestion was accepted or implemented. The overview shows
current counts by disposition, open disagreements, and pending responses, based
on the latest recorded state of each item rather than counting every transition.
