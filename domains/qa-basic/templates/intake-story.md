---
human_revised: false
key: <KEY>
tracker: <TRACKER>
type: story
status: <TRACKER STATUS>
synced-at: <ISO datetime>
apps: []
relates: []
summary: Framework guidance for <Tracker story title> and its required workflow.
---

# <Tracker story title>

## Overview

Story-level objective in English — what is being built and what verifying it as a unit means. 1-3 paragraphs. Refined as understanding sharpens; re-sync from the tracker when the upstream description changes materially.

## Acceptance Criteria (EARS / RFC 2119)

Pick one dominant style for this section: EARS for event/state behavior; RFC 2119 for constraints.

High-level acceptance criteria for the story as a whole. Tickets under this story refine these into ticket-level criteria.

- WHEN <trigger> THE SYSTEM SHALL <observable response>.
- WHEN <trigger> AND <condition> THE SYSTEM SHALL <observable response>.
- The <resource> MUST <behavior>.

Coverage for tickets under this story references the relevant ticket or this file.

## Tickets

(Derived: list of tickets under this story. The CLI will populate; manual updates allowed.)

## Coordination

**Required when more than one campaign under this story is active or planned.**

Stories are executed **linearly** at the Lead level — only one campaign from this story is active at a time. Use this section to record cross-ticket order, dependencies, and integration points so the next campaign picks up cleanly.

### Campaigns under this story

| Plan | Status | Apps | Order | Notes |
|---|---|---|---|---|
| [AAA-XXXX](../../../plans/AAA-XXXX/) | drafting / in-progress / done | unit | 1 | unit coverage |
| [AAA-YYYY](../../../plans/AAA-YYYY/) | drafting | e2e | 2 (depends on AAA-XXXX) | e2e flow |

### Integration points

- `coverage/<area>` — AAA-XXXX bootstraps; AAA-YYYY extends.
- Shared fixtures `<path>` — AAA-XXXX owns; AAA-YYYY reuses.

### Open decisions

- Level split between AAA-XXXX and AAA-YYYY: where does unit stop and e2e begin? (pending)

## Local notes

- (Optional) Notes added locally about scope or coordination not covered by the table above. English only.
