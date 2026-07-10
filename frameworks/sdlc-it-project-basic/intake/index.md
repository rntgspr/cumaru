---
human_revised: false
generated: true
generated-at: 2026-05-01T00:00:00Z
apps: [meta]
tracker: [jira]
---

<!-- cumaru:intake -->
| Link | Description |
|------|-------------|

_No entries yet. Each row links to `intake/<KEY>/index.md` with a one-line description of the item (type, status, summary)._
<!-- /cumaru:intake -->

# Intake

A pillar for the **local mirror of a tracker** — items the project will work on, pulled from one or more trackers (Jira today; ClickUp, Linear, Basecamp planned). Source of truth stays in the tracker; this directory is a navigable index synced on demand by `cumaru intake <KEY>`. Every item is a sibling (flat layout); `type:` (epic | story | task | bug | spike | …) and `relates:` (cross-item links) replace the v2 hierarchy.

## Rules

- **Mirror, not authoritative.** The tracker is the source of truth. Entries here are local restatements — `## Overview` and `## Acceptance Criteria (EARS / RFC 2119)` are authored in English from the source description, not pasted verbatim.
- **Mechanical sync.** Any role (Lead, Dev) or the user can trigger `cumaru intake <KEY>` to create or refresh an entry. Sync is not a role responsibility; roles only **read** intake.
- **Frontmatter `status:` and `synced-at:` are managed by the CLI.** Body sections (`## Overview`, `## Acceptance Criteria`, `## Coordination`, `## Local notes`) are yours to author and refine.
- **Flat layout.** Every item lives at `intake/<KEY>/index.md` regardless of type. `type:` discriminates; `relates:` records cross-item links (parent epic, parent story, …) so a project mixing trackers stays navigable.
- **Per-item `tracker:`.** Each item's frontmatter carries `tracker: jira` (or `linear`, when wired) — unambiguous provenance even when the project pulls from multiple trackers (declared as the list on this index's `tracker:` frontmatter).
- **Stories with more than one active plan** carry a `## Coordination` section in their `index.md` (cross-ticket order, integration points, open decisions). See `templates/intake-story.md`.
- **Each entry is a directory** with `index.md` and any aux files, following the universal entity rules.

## When to use

- Opening a plan: read the linked `intake/<KEY>/index.md` for the item's `## Overview` and `## Acceptance Criteria (EARS / RFC 2119)` — plans for tracker-backed work reference these instead of repeating them.
- Coordinating multiple plans under the same story — record cross-ticket decisions in the story's `## Coordination` section before dispatching the next plan.
- After upstream changes — run `cumaru intake <KEY>` to refresh `status:` and `synced-at:`; if the body still has a RAW block, the description is updated too.

## When NOT to use

- Discussion of implementation approach → `plans/<PLAN-ID>/`.
- Description of the system as it is today → `specs/<area>/`.
- Open questions or ideas not yet tied to a tracker item → `exploring/<slug>/`.
- Completed work → `archive/<PLAN-ID>/`.
