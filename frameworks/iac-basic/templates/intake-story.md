---
human_revised: false
generated: false
key: <KEY>
tracker: <TRACKER>
type: story
status: <TRACKER STATUS>
synced-at: <ISO datetime>
apps: []
relates: []
---

# <Tracker story title>

## Overview

Story-level objective in English — what is being built and why it matters as a unit. 1-3 paragraphs. Refined as understanding sharpens; re-sync from the tracker when the upstream description changes materially.

## Acceptance Criteria (EARS / RFC 2119)

Pick one dominant style for this section: EARS for event/state behavior; RFC 2119 for constraints.

High-level acceptance criteria for the story as a whole. Tickets under this story refine these into ticket-level criteria.

- WHEN <trigger> THE SYSTEM SHALL <observable response>.
- WHEN <trigger> AND <condition> THE SYSTEM SHALL <observable response>.
- The <resource> MUST <behavior>.

Plans for tickets under this story do not repeat these — they reference the relevant ticket or this file.

## Tickets

(Derived: list of tickets under this story. The CLI will populate; manual updates allowed.)

## Coordination

**Required when more than one plan under this story is active or planned.**

Stories are executed **linearly** at the Lead level — only one plan from this story is active at a time. Use this section to record cross-ticket order, dependencies, and integration points so the next plan picks up cleanly.

### Plans under this story

| Plan | Status | Apps | Order | Notes |
|---|---|---|---|---|
| [AAA-XXXX](../../../plans/AAA-XXXX/) | drafting / in-progress / done | dev | 1 | foundation |
| [AAA-YYYY](../../../plans/AAA-YYYY/) | drafting | dev | 2 (depends on AAA-XXXX) | UI integration |

### Integration points

- `<path/to/file.ts>` — AAA-XXXX owns; AAA-YYYY consumes (read-only).
- API contract `/foo` — AAA-XXXX ships v2; AAA-ZZZZ must continue working with v1 until cutover.

### Open decisions

- Cutover strategy for AAA-ZZZZ → AAA-XXXX: feature flag or hard switch? (pending)

## Local notes

- (Optional) Notes added locally about scope or coordination not covered by the table above. English only.
