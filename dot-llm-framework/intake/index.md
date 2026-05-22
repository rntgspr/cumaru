---
human_revised: false
generated: true
generated-at: 2026-05-01T00:00:00Z
apps: [meta]
---

<!-- llm:intake -->
| ID | Type | Title | Epic | Story | Status | Synced |
|----|------|-------|------|-------|--------|--------|

_No entries yet._
<!-- /llm:intake -->

# Intake

A pillar for **the local mirror of Jira** — epics, stories, and tickets that the project will work on. Source of truth stays in Jira; this directory is a navigable index synced on demand by `llm intake <KEY>`.

## Rules

- **Mirror, not authoritative.** Jira is the source of truth. Entries here are local restatements — `## Overview` and `## Acceptance Criteria (EARS)` are authored in English from the Jira description, not pasted verbatim.
- **Mechanical sync.** Any role (Lead, Dev) or the user can trigger `llm intake <KEY>` to create or refresh an entry. Sync is not a role responsibility; roles only **read** intake.
- **Frontmatter `status:` and `synced-at:` are managed by the CLI.** Body sections (`## Overview`, `## Acceptance Criteria`, `## Coordination`, `## Local notes`) are yours to author and refine.
- **Three subdirectories by issuetype.** Jira `Epic` → `epics/<KEY>/`, `Story` → `stories/<KEY>/`, anything else → `tickets/<KEY>/`. The CLI routes automatically.
- **Stories with more than one active plan** carry a `## Coordination` section in their `index.md` (cross-ticket order, integration points, open decisions). See `templates/intake-story.md`.
- **Each entry is a directory** with `index.md` and any aux files, following the universal entity rules.

## When to use

- Opening a plan: read the linked `intake/<type>/<KEY>/index.md` for the ticket's `## Overview` and `## Acceptance Criteria (EARS)` — plans for Jira-backed work reference these instead of repeating them.
- Coordinating multiple plans under the same story — record cross-ticket decisions in the story's `## Coordination` section before dispatching the next plan.
- After upstream changes — run `llm intake <KEY>` to refresh `status:` and `synced-at:`; if the body still has a JIRA-RAW block, the description is updated too.

## When NOT to use

- Discussion of implementation approach → `plans/<PLAN-ID>/`.
- Description of the system as it is today → `specs/<area>/`.
- Open questions or ideas not yet tied to a Jira ticket → `exploring/<slug>/`.
- Completed work → `archive/<PLAN-ID>/`.
