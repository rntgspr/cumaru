---
human_revised: false
targets: [meta]
summary: Framework guidance for Intake and its required workflow.
---


# Intake

A pillar for the **local mirror of a tracker** — items the project will work on, authored from directly read or user-provided tracker source. Source of truth stays in the tracker. Every item is a sibling; `type:` and `relates:` replace hierarchy.

## Rules

- **Source and local contract.** The tracker is the authoritative source; this brief is the single local home for tracker-backed Overview and Acceptance Criteria. Entries here are local restatements — `## Overview` and `## Acceptance Criteria (EARS / RFC 2119)` are authored in English from the source description, not pasted verbatim.
- **Source import.** Use the `cumaru-intake` skill to create or refresh an entry without overwriting refined local content.
- **Agent-owned refinement.** `cumaru-intake` refreshes observed source metadata and preserves curated content; no CLI tracker sync exists. `templates/intake-brief.md` defines the local contract for every item type.
- **Flat layout.** Every item lives at `intake/<KEY>.md` regardless of type. `type:` discriminates; `relates:` records cross-item links (parent epic, parent story, …) so a project mixing trackers stays navigable.
- **Per-item `tracker:`.** Each item's frontmatter carries the tracker observed
  from its source. There is no project-wide tracker registry on this index;
  per-brief provenance remains unambiguous when a project uses multiple trackers.
- **Stories with more than one active plan** carry a `## Coordination` section in their own intake file (cross-ticket order, integration points, open decisions). Use `templates/intake-brief.md`.
- **Each entry is one Markdown file.** Attachments or auxiliary files are not stored below intake items; preserve them elsewhere and link them semantically when needed.

## When to use

- Opening a plan: read the linked `intake/<KEY>.md` for the item's `## Overview` and `## Acceptance Criteria (EARS / RFC 2119)` — plans for tracker-backed work reference these instead of repeating them.
- Coordinating multiple plans under the same story — record cross-ticket decisions in the story's `## Coordination` section before dispatching the next plan.
- After upstream changes, use `cumaru-intake` to adjudicate source changes against refined local content.

## When NOT to use

- Discussion of implementation approach → `plans/<PLAN-ID>/`.
- Description of the system as it is today → `specs/<area>/`.
- Open questions or ideas not yet tied to a tracker item → `concepts/<slug>/` or `research/<slug>/`.
- Internal maintenance without a tracker item → `plans/maintenance-<slug>/`. Selected concept promotion requires a tracker-backed brief.
- Completed work → direct absorption into `specs/` using `cumaru-absorb`.

Remove a consumed local brief only after verified absorption and only when no
other active work needs it. Removing a local mirror never deletes its tracker
ticket.
