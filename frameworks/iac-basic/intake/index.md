---
human_revised: false
generated: true
generated-at: 2026-06-04T00:00:00Z
apps: [meta]
tracker: [jira]
---

<!-- cumaru:intake -->
| Link | Description |
|------|-------------|

_No entries yet._
<!-- /cumaru:intake -->

# Intake

Local mirror of the **tracker items that drive infrastructure change** — provisioning requests, capacity bumps, incident remediations, change tickets. Source of truth stays in the tracker (Jira today; others planned); this directory is a navigable index synced on demand by `cumaru intake <KEY>`. Every item is a sibling (flat layout); `type:` and `relates:` replace hierarchy.

## Rules

- **Mirror, not authoritative.** The tracker owns the item. `## Overview` and `## Acceptance Criteria (EARS)` are authored in English from the source description, not pasted verbatim.
- **Mechanical sync.** `cumaru intake <KEY>` creates or refreshes an entry. Sync is not a role responsibility; roles only **read** intake.
- **CLI-managed `status:`/`synced-at:`.** Body sections are yours to author.
- **Flat layout.** `intake/<KEY>/index.md` regardless of type; `relates:` records cross-item links.
- **Per-item `tracker:`** records provenance even when the project pulls from multiple trackers.

## When to use

- Opening a changeset → read the linked `intake/<KEY>/index.md` for the request's intent and acceptance criteria.
- After upstream changes → `cumaru intake <KEY>` to refresh `status:` and `synced-at:`.

## When NOT to use

- How the change will be applied → `plans/<PLAN-ID>/`.
- The infrastructure as it is today → `topology/<area>/`.
- Repeatable operational procedures → `runbooks/`.
- Pre-change spikes → `exploring/<slug>/`.
