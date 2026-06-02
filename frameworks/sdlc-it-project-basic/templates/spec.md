---
human_revised: false
generated: false
name: <area>
summary: <one-line summary, used in specs/index.md>
depends-on: []           # paths under specs/
apps: [newapp] | [legacy] | [mockoon] | [newapp, legacy] | [platform]
deltas: []               # reference list of plan IDs whose deltas built the current state of this spec — drill into archive/<PLAN-ID>/ for the verbose change record
---

# <Area name>

## Overview

What this area is and how it fits into the system. 1-3 paragraphs.

## Requirements (EARS)

Group requirements by sub-topic when useful.

### <Sub-topic>

- WHEN <trigger> THE SYSTEM SHALL <observable response>.
- WHEN <trigger> AND <condition> THE SYSTEM SHALL <observable response>.

### <Sub-topic>

- WHEN <trigger> THE SYSTEM SHALL <observable response>.

## Decisions

- YYYY-MM-DD: short rationale and link to the originating plan or ticket (e.g. `AAA-1234`).

## Files

- [<concern>.md](<concern>.md) — short description (single-app areas).
- [<subarea>/](<subarea>/) — nested subarea (its own `index.md`), when a concern grew beyond a flat file and needs its own concerns.
- [newapp.md](newapp.md) — newapp-specific spec (only if content diverges).
- [legacy.md](legacy.md) — legacy-specific spec (only if content diverges).

## Reference

Repository source files this spec covers — read by `cumaru coverage`. Every row
targets a source file, resolved from the project root (never a `.cumaru/` path,
a directory, or a URL).

<!-- cumaru:reference -->
| Link | Description |
|------|-------------|
| [<module>](<src/path/to/file>) | <one-line prose: what this file does for this area> |
<!-- /cumaru:reference -->
