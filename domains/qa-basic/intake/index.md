---
human_revised: false
apps: [meta]
tracker: [jira]
summary: Framework guidance for Intake and its required workflow.
---


# Intake

Local mirror of the **tracker items that drive test work**, authored from directly read or user-provided tracker source. Source of truth stays in the tracker; every item is a sibling and `type:` plus `relates:` replace hierarchy.

## Rules

- **Mirror, not authoritative.** The tracker owns the item. `## Overview` and `## Acceptance Criteria (EARS / RFC 2119)` are authored in English from the source description, not pasted verbatim. The acceptance criteria are the **requirement to verify**.
- **Source import.** `cumaru-intake` creates or refreshes an entry without overwriting refined local content.
- **CLI-managed `status:`/`synced-at:`.** Body sections are yours to author.
- **Flat layout.** `intake/<KEY>/index.md` regardless of type; `relates:` records cross-item links.
- **Per-item `tracker:`** records provenance even when the project pulls from multiple trackers.

## When to use

- Opening a campaign → read the linked `intake/<KEY>/index.md` for the requirement's intent and acceptance criteria.
- After upstream changes, use `cumaru-intake` to adjudicate source changes.

## When NOT to use

- How the requirement will be covered → `plans/<PLAN-ID>/`.
- What is verified today → `coverage/<area>/`.
- Reusable testing conventions → `standards/`.
- Exploratory charters → `exploring/<slug>/`.
