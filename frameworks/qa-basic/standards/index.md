---
human_revised: false
generated: true
generated-at: 2026-06-05T00:00:00Z
apps: [meta]
---

<!-- cumaru:standards -->
| Link | Description |
|------|-------------|

_No standards yet._
<!-- /cumaru:standards -->

# Standards

**Durable testing conventions** — naming, fixtures/factories, mocking policy per level, coverage gates, flakiness policy, test environments. Unlike the transient pillars (`intake`/`plans`/`archive`, which distill into `coverage/` then get pruned), standards persist: they are consulted repeatedly and apply ACROSS coverage areas, not to one campaign.

## Rules

- **One directory per standard.** `standards/<slug>/index.md` — a convention, not a coverage tree (flat: no nested subareas, unlike `coverage/`).
- **`apps:`** = which levels the convention applies to (`unit`, `all`, …).
- **`relates:`** = the `coverage/<area>` slices the convention governs — the link back into the coverage map.
- **Prescriptive and concrete.** A standard states the rule, the rationale, and a short do/don't example — not loose prose. It is something an author can comply with and a reviewer can check.
- **Owned by the Lead.** Kept current as the system and the toolchain change; a standard that drifts from practice is worse than none.

## Suggested starting set

`test-structure` (AAA / GWT, colocation, naming) · `test-data` (fixtures, factories, seeding, teardown) · `mocking-policy` (what to mock per level) · `coverage-policy` (gates per level, exclusions) · `flakiness-policy` (quarantine, retry budget, deflake) · `environments` (ephemeral/containers/CI, seed data). Author each as a campaign first needs it — don't seed empty standards.

## When to use

- Authoring or reviewing tests → consult the relevant standard; do not improvise the convention.
- A campaign introduces a new cross-cutting convention → author its standard as part of closing.

## When NOT to use

- The coverage of a specific area → `coverage/<area>/`.
- A one-off campaign → `plans/<PLAN-ID>/`.
- An exploratory charter → `exploring/<slug>/`.
