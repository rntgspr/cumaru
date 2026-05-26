---
human_revised: false
name: llm-specs
description: Use this skill whenever the user wants to grow or maintain the `specs/` pillar — bootstrap a new area, deepen an existing one, split into concerns/subareas, or consolidate after many deltas. Trigger on phrases like "bootstrap the specs", "scaffold the spec areas", "deepen the auth spec", "split this area into concerns", "promote a concern to a subarea", "consolidate specs/payments", "compactar a área X", "the spec is too thin to plan against", or any task that frames the work as authoring or refactoring inside `specs/`. Skill is sdlc-only — it knows the pillar's recursive shape (`area` nesting `concern` or child `area`s), the `deltas:` ↔ `consolidated-at:` state model, and the Lead-only authoring contract.
---

# `llm-specs` — author and maintain `specs/`

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
- **Living state**: every body reflects the system as it is now. History lives in `archive/<PLAN-ID>/delta.md`.
- **`deltas:` is the canonical reference** — list of plan IDs whose deltas built the current state. Drill there for verbose change wording.
- **Bootstrap on demand**: an area is created the first time a plan declares it in `scope:` — don't seed empty areas in advance.
- **Lead-only authoring**: Dev never writes inside `specs/` directly. Spec absorption happens during the Lead's archive flow (see `llm-archive`), driven by Dev's `delta-draft.md`.

## Recipe: bootstrap a spec area

When the user agrees on a new area `<area>` (typically during initial install, or the first time a plan touches a yet-undocumented surface):

1. **Read the project surface.** `CLAUDE.md`, `README`, the directory of the area you're about to document, related entry-points (`index.*`, `main.*`, `app.*`). Goal is breadth, not depth.
2. **Confirm with the user** before creating: name, summary, `depends-on:` (other areas whose contract you actually need to read alongside), `apps:` (component keys from `meta.apps.values`).
3. `llm flow specs/<area> create`
4. `llm flow specs/<area>/index.md create`
5. Open `templates/spec.md`; author the frontmatter:
   - `name: <area>`, `summary: <one-line>`.
   - `depends-on: [<other-areas>]` — hard, blocking. Load these WITH this area.
   - `relates: [...]` — soft, non-blocking cross-links.
   - `apps: [...]` — affected components.
   - `deltas: []` — empty at bootstrap; populated as plans close.
6. Body — follow the template:
   - `## Overview` — 1-3 paragraphs grounded in code.
   - `## Requirements (EARS)` — observable behaviors as `WHEN <trigger> THE SYSTEM SHALL <response>`. Light pass produces broad, possibly imprecise EARS; deepen later. **An empty section is better than fabricated requirements.**
   - `## Decisions` — non-obvious design choices visible in the code, or `(none surfaced)`.
   - `## Files` — list each `<concern>.md` and `<subarea>/` with a one-line role.
7. **Optional discovery log.** For larger areas the light/deep pass procedure benefits from a persistent log: copy `templates/bootstrap.md` to `specs/<area>/bootstrap.md` and fill the `## Discovery (light pass <ISO>)` section as you read. Leave it on disk — future deep passes append below.
8. Re-emit `specs/index.md` row via `llm tag set specs/index.md specs <new body>` (columns: Path | Summary | Apps | Depends-on | Relates).
9. `llm doctor` — orphan check should be clean.

**What NOT to do:**
- Don't auto-create areas without confirmation — a bad split poisons every later plan.
- Don't try to write full spec bodies in one pass — bootstrap is the skeleton; deepening fills it.
- Don't invent EARS you can't ground in code.

## Recipe: deepen an area

When a plan is about to touch an area and its spec is too thin to plan against (the AC in `intake/<KEY>/` can't be mapped cleanly onto requirements that already live in `specs/<area>/`):

1. Read `specs/<area>/index.md` end-to-end (and any prior `bootstrap.md` discovery log if present).
2. Read the code in the area's surface — sources, tests, configs. Take notes by **topic**: auth has "login flow", "token storage", "session refresh", etc.
3. For each topic, write EARS-style requirements grounded in code you can point to. Group under `## Requirements (EARS)` subheaders.
4. **Split into a concern file** when a topic is large enough to deserve its own file:
   - `llm flow specs/<area>/<concern>.md create`
   - Copy the frontmatter shape from `templates/spec.md`. Set `name: <concern>`, repeat `apps:`, give it its own `summary:`.
   - Move the topic's requirements + decisions into the new file.
   - In the area's `index.md`, replace the moved content with a one-line link under `## Files`.
5. **Promote a concern to a subarea** when it has grown beyond a flat file and has its own internal concerns:
   - `llm flow specs/<area>/<subarea> create`
   - `llm flow specs/<area>/<subarea>/index.md create`
   - Move the file's content into the subarea index; spawn child concern files as needed. Subareas follow the same shape as areas — same frontmatter, same body sections.
   - Update parent's `## Files` to link the subarea dir.
6. **Append to the discovery log** if you're using one (`specs/<area>/bootstrap.md`):
   - New `## Discovery (deep pass <ISO>) — <scope>` section at the end (don't edit prior sections).
   - Topic-by-topic findings: file refs, decisions discovered, reconciliations made.
7. Re-emit `specs/index.md` to reflect new rows (concerns/subareas may surface as nested paths).
8. `llm doctor`.

**What NOT to do:**
- Don't split a single concern into multiple files just because the section grew long — split when it's *conceptually* separable, not typographically inconvenient.
- Don't load `depends-on:` with every related area — load only the ones whose contract you actually need to read alongside; soft cross-links go in `relates:`.
- Don't edit prior discovery sections — they're a chronological log.

## Recipe: consolidate an area (deltas → single coherent body)

When an area's `deltas:` list has grown long (≥5 entries) and the per-plan history makes the spec hard to read as "what's true now":

1. Read the area's `index.md` and any `<concern>.md` files / subareas.
2. For each plan ID in `deltas:`, read `archive/<PLAN-ID>/delta.md` — chronological changes that built the current spec.
3. **Rewrite the area's body into a single coherent spec.** Integrate every delta as if it had always been part of the system. Where two deltas contradict, reflect the **current** state. Old EARS that were modified should appear in their modified form; removed EARS should be gone.
4. Replace `deltas: [...]` in the frontmatter with `consolidated-at: <today's ISO date>`. Keep `archive/<PLAN-ID>/` entries on disk — they remain the verbose history; the spec body is the compact view.
5. Re-emit `specs/index.md` row (Path | Summary | Apps | Depends-on | Relates — same columns, possibly updated wording).
6. `llm doctor`.

**What NOT to do:**
- Don't delete archive entries — they're the verbose history.
- Don't consolidate halfway ("kept some for clarity" violates the model). Either consolidate or don't.
- Don't trigger consolidation on every plan close — pay the cost only when the cumulative weight is real (the user is asking, or the area's `deltas:` is genuinely long).

## Spec absorption during archive (NOT this skill)

When a plan closes via `llm-archive`, the Lead's archive flow opens each `specs/<area>` in the plan's `scope:` and:
1. Updates the area's body to reflect the new state (per Dev's `delta-draft.md`).
2. Appends the plan's `<KEY>` to the area's `deltas:` frontmatter list.
3. Re-emits the area's row in `specs/index.md`.

This skill provides the recipes to **grow** the spec tree (bootstrap, deepen, consolidate). The `llm-archive` skill provides the recipe to **absorb** a closed plan's delta into already-existing areas. Both write to `specs/` — but only the Lead, never the Dev.

## What this skill does NOT do

- **Delta absorption** — `llm-archive`. This skill grows specs from first principles or refactors them; archive merges plan deltas into them.
- **Plan authoring** — `llm-plan`. Plans declare which `specs/<area>[/<subarea>]/<concern>` paths they touch via `scope:`; this skill creates/maintains those paths.
- **Cross-area dependency enforcement** — `depends-on:` resolution is documented in `meta.cross_file_checks.deferred` (not yet enforced by `llm doctor`).

## Patterns

| User says | You do |
|---|---|
| "Bootstrap the specs" / "scaffold the spec areas" | Bootstrap recipe → propose area list from CLAUDE.md/README/code → confirm → create each area |
| "Deepen the auth spec" / "specs/auth está muito raso" | Deepen recipe on `specs/auth/` → light-or-deep read → write EARS by topic → split/promote as needed |
| "Split this area into concerns" / "promote `auth/login` to a subarea" | Deepen recipe, step 4 (split) or step 5 (promote) |
| "Consolidate specs/payments" / "compactar a área de payments" | Consolidate recipe → read deltas → rewrite body → swap `deltas` for `consolidated-at` |
| "Add a new spec area for telemetry" | Bootstrap recipe with `<area>=telemetry` |

Use `llm tag get/set` (CLI, no skill) for `specs/index.md` table round-trip; pair with `llm-plan` (which declares `scope:` paths), `llm-archive` (which absorbs deltas), and `llm-doctor` to verify post-op.
