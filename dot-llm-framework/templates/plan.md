---
human_revised: false
generated: false
jira: <JIRA-ID>            # optional — omit for slug-based plans
type: task | story | bug | spike   # optional — omit for slug-based plans
epic: <EPIC-ID>            # optional
story: <STORY-ID>          # optional
scope:
  - <area>/<concern>
  - <area>/<subarea>/<concern>
status: drafting | in-progress | blocked | done
summary: <one-line summary, used in plans/index.md>
apps: [newapp] | [legacy] | [mockoon] | [newapp, legacy] | [platform]
aux: []
---

# <Plan title — short, descriptive>

<!-- ===== Slug-based plans (no Jira) ===== -->
<!-- Include these two sections only when the plan is slug-based (no `jira:` in
     frontmatter). Jira-backed plans defer Overview and Acceptance Criteria to
     intake/tickets/<KEY>/index.md and do not repeat them here. -->

## Overview

Short description of what the plan addresses and why. 1-3 paragraphs.

## Acceptance Criteria (EARS)

- WHEN <trigger> THE SYSTEM SHALL <observable response>.
- WHEN <trigger> AND <condition> THE SYSTEM SHALL <observable response>.
- WHILE <state> THE SYSTEM SHALL <observable response>.

<!-- ===== End slug-only sections ===== -->

## Plan / DAG

| Task | Title | Status | Depends on |
|------|-------|--------|-----------|
| [T1](t1.md) | Short title | pending | — |
| [T2](t2.md) | Short title | pending | T1 |

For multi-app plans, suffix with the app key:

| Task | Title | Status | Depends on |
|------|-------|--------|-----------|
| [T1 (newapp)](t1-newapp.md) | Short title | pending | — |
| [T1 (legacy)](t1-legacy.md) | Short title | pending | — |

Tasks may run in parallel when `depends-on:` is satisfied and their `files:` predictions do not overlap. The Lead verifies before dispatch.

## Out of scope

- Items intentionally not addressed by this plan.

## Risks

- Risk and mitigation/note.
