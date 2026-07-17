---
human_revised: false
key: <KEY>
tracker: <TRACKER>
type: task | bug | spike
status: <TRACKER STATUS>
synced-at: <ISO datetime>
apps: []
relates: []
summary: Framework guidance for <Tracker ticket title> and its required workflow.
---

# <Tracker ticket title>

## Overview

Local restatement of the ticket — what is being asked and why it matters. Written in English even when the source description is in another language. Refined as understanding sharpens; re-sync from the tracker via the intake sync command when the upstream description changes materially.

## Acceptance Criteria (EARS / RFC 2119)

Pick one dominant style for this section: EARS for event/state behavior; RFC 2119 for constraints.

- WHEN <trigger> THE SYSTEM SHALL <observable response>.
- WHEN <trigger> AND <condition> THE SYSTEM SHALL <observable response>.
- WHILE <state> THE SYSTEM SHALL <observable response>.
- The <resource> MUST <behavior>.

Plans for this ticket do not repeat these criteria — they reference this file. Re-sync from the tracker when the AC changes.

<!-- ===== Bug-only sections (when type: bug) ===== -->

## Reproduction

1. Step one.
2. Step two.
3. Observed.

## Expected

What should happen.

## Actual

What happens instead.

<!-- ===== End bug-only sections ===== -->

## Local notes

- (Optional) Notes added locally about scope or links to plans. English only.
