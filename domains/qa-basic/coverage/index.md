---
human_revised: false
apps: [meta]
summary: Framework guidance for Coverage and its required workflow.
---

<!-- cumaru:absorptions -->
| SHA | KEY | Description |
|-----|-----|-------------|

_No absorbed campaigns yet. Each row records the commit SHA that absorbed a campaign delta into coverage, the campaign key, and a one-line summary of what became durable._
<!-- /cumaru:absorptions -->

# Coverage

The **living coverage map** — what is verified right now about the system-under-test: which areas are tested, at which levels, and the scenarios that verify them. Authored and refactored by the Lead; deltas are absorbed here on campaign close.

## Rules

- **Coverage map, not a test-code copy.** Each `coverage/<area>/index.md` describes the area's purpose, the levels it is exercised at (`apps:`), its **`## Scenarios (GWT)`**, known gaps, and the runner that exercises it — **never** a paste of the `.test`/`.spec` source. The test files are the executable verification; this is the strategy and intent the code can't carry.
- **Scenarios use Given-When-Then.** Bullets under `## Scenarios (GWT)` follow `GIVEN … WHEN … THEN …` (a warning, not a blocker — doctor sub-pass [4]). Each scenario verifies a requirement; the area `relates:` back to the intake `<KEY>` it covers.
- **`depends-on:` is the test-prerequisite order.** An area's `depends-on` lists the areas its setup presumes (auth → checkout). It is both the strongest load signal and the prerequisite sequence. `relates:` is "consider" — including the requirements it covers.
- **`deltas:` frontmatter is the local trace.** Each area lists the campaign IDs whose deltas built its current state. The durable cross-coverage ledger is `cumaru:absorptions` on this index.
- **Bootstrap on demand.** An area is created the first time a campaign declares it in `scope:`. Don't seed empty areas.
- **Areas split into cases / subareas** as they grow (per-feature, per-flow), recursively — same shape as areas. A scenario detailed enough to need its own file becomes a `case` (`<case>.md`).
- **Authoring is the Lead's.** Dev never writes inside `coverage/` directly; absorption happens during the archive flow, driven by the Dev's `delta-draft.md`.

## When to use

- A campaign declares a `coverage/` path in `scope:` → load the area and the cases the active task touches.
- Determining test-prerequisite order → read the `depends-on` chain.
- Tracing why an area is covered the way it is → follow the area's `deltas:`, find the corresponding KEY in `cumaru:absorptions`, and inspect the recorded SHA.

## When NOT to use

- A campaign in flight → `plans/<PLAN-ID>/`.
- A reusable convention → `standards/`.
- Active close-out details → `archive/<KEY>/delta.md` only while absorption is in flight.
- Mirror of tracker items → `intake/`.
