---
human_revised: false
summary: Canonical priority directives used to evaluate incoming work signals.
targets: [meta]
---

# Directives

<!-- cumaru:directives -->
_(empty — replace with the ordered priority view of your directives)_
<!-- /cumaru:directives -->

Store one directive per lowercase-slug Markdown file. Directives define desired
direction and work scope; threads preserve conversations, evidence, and changes.
Link them rather than moving or duplicating thread histories into this pillar.

## Contract

Each leaf has a navigation `summary`, `status` (active, proposed, or paused), and
`priority` (a positive integer for active directives, otherwise null). Lower
priority numbers rank first. Only the user's decisions establish active status
and ordering; unknown rank is not invented. Equal ranks are allowed and resolved
from signal urgency. The directives tag above is the ordered priority view, not a
filesystem inventory. Keep its ranks consistent with the leaf priority fields
whenever an ordering decision changes. Proposed or paused entries without an
established rank remain explicitly unranked; their display order does not imply
importance. An optional `parent` names another directive filename; children do
not inherit approval. No cycles or missing parents are allowed.

Create leaves from `templates/directive.md`; it carries the required fields and
sections (purpose, scope, value scope, completion evidence, decision points,
attention evidence, boundaries, related threads, dated changes). State the benefit the direction pursues and
how a contribution to it is recognized: that statement is the value scope every
outcome serving this directive is assessed against, so an outcome never invents
a scale of its own.
Use `cumaru fs` for structural operations. Keep adopter-specific priority policy
in the domain root tag, not in this contract.

## Applying directives

Load this index and all active directives before ranking threads.
Use `cumaru tree directives` and `cumaru map directives` for discovery; read
relevant proposed or paused directives to understand boundaries, not to activate
them.

For each selected thread, record a Priority rationale containing matched
directive links, relationship (direct, supporting, or unmatched), source
evidence, and why attention rises or falls. Multiple matches do not add up to
artificial priority points. Prefer the strongest justified match; do not use
keyword matching alone. An unmatched item stays visible as a scope-review
candidate.

Rank on two weighted signals: the priority of the matched directives and the
relevant dates. A higher-ranked directive weighs more, and a nearer or more
overdue date weighs more. Neither one overrides the other by rule; when they
disagree, state which dominated and why. Use directness of contribution and
confidence to break a remaining tie, never keyword overlap. Within a confirmed
incident, deadline, or response obligation, assess consequences first and explain
the exception to directive order.

Respect explicit holds and the boundary between the user's own action and
downstream monitoring. Do not treat a proposal, a broad scope, or an assignment
as authority to implement. Ranking is not collection: directive fit orders what
is already captured and never narrows what an adopter workflow chooses to read.
