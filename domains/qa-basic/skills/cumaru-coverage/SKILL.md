---
human_revised: false
version: 1
name: cumaru-coverage
description: Use this skill whenever the user wants to grow or maintain the `coverage/` pillar — bootstrap a new coverage area, deepen an existing one, split into cases/subareas (per flow/feature), or consolidate a body that reads like a changelog. Trigger on phrases like "bootstrap the coverage", "map what's tested", "document the checkout coverage", "deepen the auth coverage", "split this area into cases", "consolidate coverage/checkout", "compactar a área X", "this area is too thin to plan a campaign against", or any task framed as authoring/refactoring inside `coverage/`. Knows the pillar's recursive shape (`area` nesting `case` or child `area`s), the `## Scenarios (GWT)` section, and the Lead-only authoring contract.
summary: Use this skill whenever the user wants to grow or maintain the `coverage/` pillar — bootstrap a new coverage area, deepen an existing one, split into cases/subareas (per flow/feature), or consolidate a body that reads like a changelog. Trigger on phrases like "bootstrap the coverage", "map what's tested", "document the checkout coverage", "deepen the auth coverage", "split this area into cases", "consolidate coverage/checkout", "compactar a área X", "this area is too thin to plan a campaign against", or any task framed as authoring/refactoring inside `coverage/`. Knows the pillar's recursive shape (`area` nesting `case` or child `area`s), the `## Scenarios (GWT)` section, and the Lead-only authoring contract.
---

# `cumaru-coverage` — author and maintain `coverage/`

The living-coverage-map skill. Three recipes that grow the `coverage/` tree over a project's lifetime: **bootstrap** (initial scaffold of an area), **deepen** (light → deep pass), **consolidate** (rewrite a changelog-shaped body as current state). `coverage/` is the durable truth of how the system is verified — which areas are tested, at what level, and the scenarios that prove them — **never a copy of the `.test`/`.spec` source** (that is the executable verification; it drifts and lies).

## Layout (recap from schema)

```
coverage/
└── <area>/                  ← a slice of the system-under-test
    ├── index.md             ← [name!, summary!, depends-on!, relates, apps!]
    ├── <case>.md            ← same frontmatter shape — a detailed case (a complex scenario)
    └── <subarea>/           ← nested area (recursive — per flow/feature)
        └── index.md
```

**Contract:**
- **Living state**: every body reflects the coverage as it is now. History lives in `archive/<PLAN-ID>/delta.md`.
- **`depends-on:` is the test-prerequisite order** — the areas whose setup/state this one presumes (auth before checkout). It is both the strongest load signal AND the prerequisite sequence. `relates:` is soft ("consider") — including the `intake/<KEY>`s this area covers (the traceability link).
- **This pillar is the record** — there is no second store of absorbed work. `git log` is the only cross-reference back to the campaigns that built it.
- **Bootstrap on demand**: an area is created the first time a campaign declares it in `scope:` — don't seed empty areas.
- **Lead-only authoring**: the Dev never writes inside `coverage/` directly. Absorption happens during the Lead's archive flow (`cumaru-archive`), driven by the Dev's `delta-draft.md`.

## Recipe: bootstrap an area

When the user agrees on a new area `<area>` (initial install, or the first campaign to a yet-undocumented slice):

1. **Read the real surface.** The existing test files for the area (`*.test.*` / `*.spec.*` / `e2e/`), the code under test, and the relevant `standards/`. Goal is breadth: what is already verified, at what level, and what visibly is not.
2. **Confirm with the user** before creating: name, summary, `depends-on:` (areas whose setup this presumes), `relates:` (the `intake/<KEY>`s it covers), `apps:` (the levels it is exercised at, from `meta.apps.values`).
3. `cumaru flow coverage/<area> create`
4. `cumaru flow coverage/<area>/index.md create`
5. Open `templates/coverage.md`; author the frontmatter (`name`, `summary`, `depends-on` = test-prerequisite areas, `relates`, `apps`).
6. Body — follow the template:
   - `## Overview` — what the area covers, the **runner** that owns it, where the test code lives. **No `.test`/`.spec` paste.**
   - `## Levels` — what each level (unit/integration/e2e) is responsible for and why; keep the pyramid and call out any e2e scenario a lower level could catch.
   - `## Scenarios (GWT)` — observable behaviours as `GIVEN <precondition> WHEN <action> THEN <outcome>`. Each maps to an acceptance criterion of a `relates:` intake item. Light pass produces broad scenarios; the deep pass refines.
   - `## Gaps` — behaviours with no test (and why) or `(none surfaced)`.
   - `## Dependencies (test-prerequisite order)` — why each `depends-on` is required.
   - `## Decisions` — non-obvious choices (level split / runner / fixture strategy) or `(none surfaced)`.
   - `## Files` — each `<case>.md` / `<subarea>/` with a one-line role.
7. **Optional discovery log** for large areas: copy `templates/bootstrap.md` to `coverage/<area>/bootstrap.md`, fill `## Discovery (light pass <ISO>)`. Leave on disk; deep passes append below.
8. Run `cumaru tree coverage --rows` and verify the area summary.
9. `cumaru doctor` — navigation and summary checks clean.

Surface every navigation or summary defect introduced by structural changes.

**What NOT to do:** don't auto-create areas without confirmation (a bad split poisons every later campaign); don't paste the test code into the map; don't invent scenarios the tests don't actually assert.

## Recipe: deepen an area

When a campaign is about to touch an area and its coverage is too thin to plan against:

1. Read `coverage/<area>/index.md` end-to-end (and any prior `bootstrap.md`).
2. Read the test files (and the code under test) by **flow** — checkout has "empty cart", "payment failure", "address validation"; take notes with file refs.
3. For each flow, document the scenarios (GWT), the level each is verified at, and the gaps, grounded in tests you can point to. Update `## Levels` as the split becomes clear.
4. **Split into a case file** when a scenario deserves its own file (`cumaru flow coverage/<area>/<case>.md create`; copy the frontmatter shape; move the content; link it under `## Files`).
5. **Promote a case to a subarea** when a flow grows its own internal cases (`cumaru flow coverage/<area>/<subarea> create` + its `index.md`; move content; spawn child cases). Subareas follow the same shape recursively.
6. **Append to the discovery log** if used (`## Discovery (deep pass <ISO>) — <scope>` at the end; don't edit prior sections).
7. run `cumaru tree coverage --rows`. `cumaru doctor`.

**What NOT to do:** split when *conceptually* separable, not when typographically long; don't load every related area into `depends-on:` — only the test-prerequisite ones; soft links (incl. covered `<KEY>`s) go in `relates:`.

## Recipe: consolidate an area

Runs **on request**. There is no automatic trigger and no frontmatter state to
read: the signal is the body reading like a changelog instead of a flat
statement of what is verified now.

1. Read the area's `index.md` + case/subarea files.
2. When the history behind a passage is unclear, recover it from git:
   `git log --follow --oneline -- .cumaru/coverage/<path>`.
3. **Rewrite the body into a single coherent coverage map.** Integrate every past change as if always present; where two contradict, reflect the **current** state.
4. run `cumaru tree coverage --rows`. `cumaru doctor`.

**What NOT to do:** don't consolidate halfway; don't consolidate on every campaign close — pay the cost only when the body genuinely reads as history rather than state.

## Uses GWT (not Requirements Language)

A coverage area carries `## Scenarios (GWT)` — `GIVEN … WHEN … THEN …` (a warning-level check, doctor sub-pass [4]). EARS / RFC 2119 is the **requirement language** and lives in `intake/` (and slug-based plans) as `## Acceptance Criteria (EARS / RFC 2119)`. The pairing — requirements on the intake item, GWT on the covering scenario that `relates:` back to the `<KEY>` — is the requirement→test traceability.

## What this skill does NOT do

- **Delta absorption** — `cumaru-archive` (merges a closed campaign's delta into existing areas).
- **Campaign authoring** — `cumaru-plan` (declares the `scope:` paths this skill creates/maintains).
- **Testing conventions** — `standards/` (mocking, data, gates); a coverage area `relates:` to the standards that govern it but does not restate them.

## Patterns

| User says | You do |
|---|---|
| "Bootstrap the coverage" / "map what's tested" | Bootstrap recipe → propose area list from the test tree → confirm → create each |
| "Document the checkout coverage" / "deepen coverage/auth" | Deepen recipe → read tests + code → scenarios/levels/gaps by flow → split/promote |
| "Split this area per flow" / "promote checkout/payment to a subarea" | Deepen recipe step 4 (split) or 5 (promote) |
| "Consolidate coverage/checkout" | Consolidate recipe → read the body → recover history from git if needed → rewrite as current state |

Use `cumaru tag get/set` (CLI) for the `coverage/index.md` round-trip; pair with `cumaru-plan` (`scope:`), `cumaru-archive` (absorb), and `cumaru-doctor`.
