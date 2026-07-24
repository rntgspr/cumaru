---
human_revised: false
version: 1
name: cumaru-specs
description: Use this skill whenever the user wants to grow or maintain the `specs/` pillar — bootstrap a new area, deepen an existing one, split into concerns/subareas, or consolidate after many deltas. Trigger on phrases like "bootstrap the specs", "scaffold the spec areas", "deepen the auth spec", "split this area into concerns", "promote a concern to a subarea", "consolidate specs/payments", "compactar a área X", "the spec is too thin to plan against", or any task that frames the work as authoring or refactoring inside `specs/`. Skill is sdlc-only — it knows the pillar's recursive shape (`area` nesting `concern` or child `area`s), the `deltas:` ↔ `consolidated-at:` state model, and the Lead-only authoring contract.
summary: Use this skill whenever the user wants to grow or maintain the `specs/` pillar — bootstrap a new area, deepen an existing one, split into concerns/subareas, or consolidate after many deltas. Trigger on phrases like "bootstrap the specs", "scaffold the spec areas", "deepen the auth spec", "split this area into concerns", "promote a concern to a subarea", "consolidate specs/payments", "compactar a área X", "the spec is too thin to plan against", or any task that frames the work as authoring or refactoring inside `specs/`. Skill is sdlc-only — it knows the pillar's recursive shape (`area` nesting `concern` or child `area`s), the `deltas:` ↔ `consolidated-at:` state model, and the Lead-only authoring contract.
---

# `cumaru-specs` — author and maintain `specs/`

The living-spec skill. Three recipes that grow the `specs/` tree across the project's lifetime: **bootstrap** (initial scaffold), **deepen** (light → deep pass), **consolidate** (compact accumulated deltas).

## Layout (recap from schema)

```
specs/
└── <area>/
    ├── index.md          ← [name!, summary!, depends-on!, relates, apps!, deltas, consolidated-at]
    ├── <concern>.md      ← same frontmatter shape — a per-topic file inside an area
    └── <subarea>/        ← nested area (recursive — same shape as area)
        └── index.md
```

**Contract:**
- **Living state**: every body reflects the system as it is now. Absorbed work is summarized in `specs/index.md` `cumaru:absorptions`.
- **`deltas:` is the local trace** — list of plan IDs whose deltas built that spec area. Cross-area durable history is the `absorptions` table.
- **Bootstrap on demand**: an area is created the first time a plan declares it in `scope:` — don't seed empty areas in advance.
- **Lead-only authoring**: Dev never writes inside `specs/` directly. Spec absorption happens during the Lead's archive flow (see `cumaru-archive`), driven by Dev's `delta-draft.md`.

## Recipe: bootstrap a spec area

When the user agrees on a new area `<area>` (typically during initial install, or the first time a plan touches a yet-undocumented surface):

1. **Read the project surface.** The active agent instructions, `README`, the directory of the area you're about to document, and related entry points (`index.*`, `main.*`, `app.*`). Goal is breadth, not depth.
2. **Confirm with the user** before creating: name, summary, `depends-on:` (other areas whose contract you actually need to read alongside), `apps:` (component keys from `meta.apps.values`).
3. `cumaru flow specs/<area> create`
4. `cumaru flow specs/<area>/index.md create`
5. Open `templates/spec.md`; author the frontmatter:
   - `name: <area>`, `summary: <one-line>`.
   - `depends-on: [<other-areas>]` — hard, blocking. Load these WITH this area.
   - `relates: [...]` — soft, non-blocking cross-links.
   - `apps: [...]` — affected components.
   - `deltas: []` — empty at bootstrap; populated as plans close.
6. Body — follow the template:
   - `## Overview` — 1-3 paragraphs grounded in code.
   - `## Requirements (EARS / RFC 2119)` — EARS for observable behaviors, RFC 2119 for constraints/invariants. Light pass produces broad, possibly imprecise requirements; deepen later. **An empty section is better than fabricated requirements.**
   - `## Decisions` — non-obvious design choices visible in the code, or `(none surfaced)`.
   - `## Files` — list each `<concern>.md` and `<subarea>/` with a one-line role.
7. **Optional discovery log.** For larger areas the light/deep pass procedure benefits from a persistent log: copy `templates/bootstrap.md` to `specs/<area>/bootstrap.md` and fill the `## Discovery (light pass <ISO>)` section as you read. Leave it on disk — future deep passes append below.
8. run `cumaru tree specs --rows`  — default shape: `| [<area>](<area>/index.md) | <one-line description fusing summary, apps, depends-on, relates> |`.
9. `cumaru doctor` — navigation and summary checks clean.

**What NOT to do:**
- Don't auto-create areas without confirmation — a bad split poisons every later plan.
- Don't try to write full spec bodies in one pass — bootstrap is the skeleton; deepening fills it.
- Don't invent requirements you can't ground in code.

## Recipe: deepen an area

When a plan is about to touch an area and its spec is too thin to plan against (the AC in `intake/<KEY>.md` can't be mapped cleanly onto requirements that already live in `specs/<area>/`):

1. Read `specs/<area>/index.md` end-to-end (and any prior `bootstrap.md` discovery log if present).
2. Read the code in the area's surface — sources, tests, configs. Take notes by **topic**: auth has "login flow", "token storage", "session refresh", etc.
3. For each topic, write EARS/RFC 2119 requirements grounded in code you can point to. Group under `## Requirements (EARS / RFC 2119)` subheaders.
4. **Split into a concern file** when a topic is large enough to deserve its own file:
   - `cumaru flow specs/<area>/<concern>.md create`
   - Copy the frontmatter shape from `templates/spec.md`. Set `name: <concern>`, repeat `apps:`, give it its own `summary:`.
   - Move the topic's requirements + decisions into the new file.
   - In the area's `index.md`, replace the moved content with a one-line link under `## Files`.
5. **Promote a concern to a subarea** when it has grown beyond a flat file and has its own internal concerns:
   - `cumaru flow specs/<area>/<subarea> create`
   - `cumaru flow specs/<area>/<subarea>/index.md create`
   - Move the file's content into the subarea index; spawn child concern files as needed. Subareas follow the same shape as areas — same frontmatter, same body sections.
   - Update parent's `## Files` to link the subarea dir.
6. **Append to the discovery log** if you're using one (`specs/<area>/bootstrap.md`):
   - New `## Discovery (deep pass <ISO>) — <scope>` section at the end (don't edit prior sections).
   - Topic-by-topic findings: file refs, decisions discovered, reconciliations made.
7. Run `cumaru tree specs --rows` to verify new concerns or nested subareas.
8. `cumaru doctor`.

**What NOT to do:**
- Don't split a single concern into multiple files just because the section grew long — split when it's *conceptually* separable, not typographically inconvenient.
- Don't load `depends-on:` with every related area — load only the ones whose contract you actually need to read alongside; soft cross-links go in `relates:`.
- Don't edit prior discovery sections — they're a chronological log.

## Recipe: consolidate an area (deltas → single coherent body)

When an area's `deltas:` list has grown long (≥5 entries) and the per-plan history makes the spec hard to read as "what's true now":

1. Read the area's `index.md` and any `<concern>.md` files / subareas.
2. For each plan ID in `deltas:`, find the corresponding KEY in `specs/index.md` `cumaru:absorptions` and inspect the recorded SHA if details are needed.
3. **Rewrite the area's body into a single coherent spec.** Integrate every delta as if it had always been part of the system. Where two deltas contradict, reflect the **current** state. Old requirements that were modified should appear in their modified form; removed requirements should be gone.
4. Replace `deltas: [...]` in the frontmatter with `consolidated-at: <today's ISO date>`. Keep the `absorptions` ledger; the spec body is the compact view.
5. run `cumaru tree specs --rows` — default shape: `| [<area>](<area>/index.md) | <one-line description, possibly updated wording> |`.
6. `cumaru doctor`.

**What NOT to do:**
- Don't delete `absorptions` rows — they're the durable ledger.
- Don't consolidate halfway ("kept some for clarity" violates the model). Either consolidate or don't.
- Don't trigger consolidation on every plan close — pay the cost only when the cumulative weight is real (the user is asking, or the area's `deltas:` is genuinely long).

## Spec absorption during archive (NOT this skill)

When a plan closes via `cumaru-archive`, the Lead's archive flow opens each `specs/<area>` in the plan's `scope:` and:
1. Updates the area's body to reflect the new state (per Dev's `delta-draft.md`).
2. Appends the plan's `<KEY>` to the area's `deltas:` frontmatter list.
3. Keeps the area's `summary:` accurate if its durable purpose changed.
4. Records the absorption in `specs/index.md` `cumaru:absorptions` as `SHA | KEY | Description`.

This skill provides the recipes to **grow** the spec tree (bootstrap, deepen, consolidate). The `cumaru-archive` skill provides the recipe to **absorb** a closed plan's delta into already-existing areas. Both write to `specs/` — but only the Lead, never the Dev.

## What this skill does NOT do

- **Delta absorption** — `cumaru-archive`. This skill grows specs from first principles or refactors them; archive merges plan deltas into them.
- **Plan authoring** — `cumaru-plan`. Plans declare which `specs/<area>[/<subarea>]/<concern>` paths they touch via `scope:`; this skill creates/maintains those paths.
- **Cross-area dependency enforcement** — `depends-on:` resolution is not yet enforced by `cumaru doctor`.

## Patterns

| User says | You do |
|---|---|
| "Bootstrap the specs" / "scaffold the spec areas" | Bootstrap recipe → propose area list from the active agent instructions, README, and code → confirm → create each area |
| "Deepen the auth spec" / "specs/auth está muito raso" | Deepen recipe on `specs/auth/` → light-or-deep read → write requirements by topic → split/promote as needed |
| "Split this area into concerns" / "promote `auth/login` to a subarea" | Deepen recipe, step 4 (split) or step 5 (promote) |
| "Consolidate specs/payments" / "compactar a área de payments" | Consolidate recipe → read deltas → rewrite body → swap `deltas` for `consolidated-at` |
| "Add a new spec area for telemetry" | Bootstrap recipe with `<area>=telemetry` |

Use `cumaru tree specs` for navigation; pair with `cumaru-plan` (which declares `scope:` paths), `cumaru-archive` (which absorbs deltas), and `cumaru-doctor` to verify post-op.
