---
human_revised: false
targets: [meta]
summary: Framework guidance for Intake and its required workflow.
---


# Intake

Local mirror of the **tracker items that drive infrastructure change**, authored from directly read or user-provided tracker source. Source of truth stays in the tracker; every item is a sibling and `type:` plus `relates:` replace hierarchy.

## Rules

- **Mirror, not authoritative.** The tracker owns the item. `## Overview` and `## Acceptance Criteria (EARS / RFC 2119)` are authored in English from the source description, not pasted verbatim.
- **Source import.** `cumaru-intake` creates or refreshes an entry without overwriting refined local content.
- **CLI-managed `status:`/`synced-at:`.** Body sections are yours to author.
- **Flat layout.** `intake/<KEY>/index.md` regardless of type; `relates:` records cross-item links.
- **Per-item `tracker:`** records the tracker observed from the item's source.
  There is no project-wide tracker registry on this index, so Jira, Linear, and
  other items retain independent provenance.

## When to use

- Opening a changeset → read the linked `intake/<KEY>/index.md` for the request's intent and acceptance criteria.
- After upstream changes, use `cumaru-intake` to adjudicate source changes.

## When NOT to use

- How the change will be applied → `plans/<PLAN-ID>/`.
- The infrastructure as it is today → `topology/<area>/`.
- Repeatable operational procedures → `runbooks/`.
- Pre-change spikes → `exploring/<slug>/`.
