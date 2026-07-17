---
human_revised: false
name: <area>
summary: <one-line summary, used by cumaru tree>
depends-on: []           # paths under specs/
apps: "[<app>] | [<app-a>, <app-b>] | [platform]"
deltas: []               # reference list of plan IDs whose deltas built the current state of this spec — drill into archive/<PLAN-ID>/ for the verbose change record
---

# <Area name>

## Overview

What this area is and how it fits into the system. 1-3 paragraphs.

## Requirements (EARS / RFC 2119)

Pick one dominant style for this section: EARS for event/state behavior; RFC 2119 for constraints.

Group requirements by sub-topic when useful.

### <Sub-topic>

- WHEN <trigger> THE SYSTEM SHALL <observable response>.
- WHEN <trigger> AND <condition> THE SYSTEM SHALL <observable response>.
- The <resource> MUST <behavior>.

### <Sub-topic>

- WHEN <trigger> THE SYSTEM SHALL <observable response>.

## Decisions

- YYYY-MM-DD: short rationale and link to the originating plan or ticket (e.g. `AAA-1234`).

## Files

- [<concern>.md](<concern>.md) — short description (single-app areas).
- [<subarea>/](<subarea>/) — nested subarea (its own `index.md`), when a concern grew beyond a flat file and needs its own concerns.
- [<app-a>.md](<app-a>.md) — app-specific spec for one component when content diverges.
- [<app-b>.md](<app-b>.md) — app-specific spec for another component when content diverges.

## Reference

Repository source files this spec covers — read by `cumaru coverage`. Every row
targets a source file, resolved from the project root (never a `.cumaru/` path,
a directory, or a URL).

<!-- cumaru:reference -->
| Link | Description |
|------|-------------|
| [<module>](<src/path/to/file>) | <one-line prose: what this file does for this area> |
<!-- /cumaru:reference -->
