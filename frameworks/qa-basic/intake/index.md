---
human_revised: false
generated: true
generated-at: 2026-06-05T00:00:00Z
apps: [meta]
tracker: [jira]
---

<!-- cumaru:intake -->
| Link | Description |
|------|-------------|

_No entries yet._
<!-- /cumaru:intake -->

# Intake

Local mirror of the **tracker items that drive test work** — features whose acceptance criteria need coverage, bug reports to reproduce and guard against regression, explicit test requests. Source of truth stays in the tracker (Jira today; others planned); this directory is a navigable index synced on demand by `cumaru intake <KEY>`. Every item is a sibling (flat layout); `type:` and `relates:` replace hierarchy.

## Rules

- **Mirror, not authoritative.** The tracker owns the item. `## Overview` and `## Acceptance Criteria (EARS)` are authored in English from the source description, not pasted verbatim. The acceptance criteria are the **requirement to verify**.
- **Mechanical sync.** `cumaru intake <KEY>` creates or refreshes an entry. Sync is not a role responsibility; roles only **read** intake.
- **CLI-managed `status:`/`synced-at:`.** Body sections are yours to author.
- **Flat layout.** `intake/<KEY>/index.md` regardless of type; `relates:` records cross-item links.
- **Per-item `tracker:`** records provenance even when the project pulls from multiple trackers.

## When to use

- Opening a campaign → read the linked `intake/<KEY>/index.md` for the requirement's intent and acceptance criteria.
- After upstream changes → `cumaru intake <KEY>` to refresh `status:` and `synced-at:`.

## When NOT to use

- How the requirement will be covered → `plans/<PLAN-ID>/`.
- What is verified today → `coverage/<area>/`.
- Reusable testing conventions → `standards/`.
- Exploratory charters → `exploring/<slug>/`.
