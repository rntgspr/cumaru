---
human_revised: false
version: 1
name: cumaru-specs
description: Bootstrap, deepen, or consolidate durable design specifications under Design Lead ownership.
summary: Bootstrap, deepen, or consolidate durable design specifications under Design Lead ownership.
---

# `cumaru-specs` — author and maintain `specs/`

Read `.cumaru/domain.md` and apply its role routing boundary. Spec authoring
belongs to Design Lead; Designer and Reviewer return proposed changes to Lead
without assuming its role. As Lead, load `roles/lead.md` and `specs/index.md`.
Use invocation arguments as the area or action. Existing authorization covers
routine metadata grounded in project evidence; ask only when area boundaries,
ownership, destructive cleanup, or intended scope remain unresolved.

The living-spec skill. Three recipes: **bootstrap** (initial scaffold), **deepen** (light → deep pass), **consolidate** (rewrite a changelog-shaped body as current state).

## Layout (recap from schema)

```
specs/
└── <area>/
    ├── index.md          ← [name!, summary!, depends-on!, relates, targets!]
    ├── <concern>.md      ← same frontmatter shape
    └── <subarea>/        ← nested area (recursive)
        └── index.md
```

**Contract:**
- **Living state**: every body reflects the system as it is now. There is no second store of absorbed work — this pillar *is* the record.
- **Bootstrap on demand**: an area is created the first time a plan declares it in `scope:`.
- **Design Lead owns durable authoring.** Designer proposes deltas; Reviewer
  reports findings without editing specs.

## Recipe: bootstrap a spec area

1. **Read the project surface.** The active agent instructions, `README`, the directory of the area, and related entry points.
2. Derive name, summary, `depends-on:`, and `targets:` from the authorized scope
   and project evidence. Stop only if an unresolved boundary or ownership
   conflict would make creation unsafe.
3. `cumaru fs specs/<area> create`
4. `cumaru fs specs/<area>/index.md create`
5. Open `templates/spec.md`; author the frontmatter.
6. Follow `templates/spec.md` for the written experience contract, applicable
   design dimensions, and evidence provenance. Read existing design material,
   prototypes, source, and verification; distinguish observed behavior from
   intended behavior and unresolved findings.
7. Optionally copy and fill `templates/bootstrap.md` at
   `specs/<area>/bootstrap.md` for a discovery log.
8. run `cumaru tree specs --rows` .
9. `cumaru doctor`.

## Recipe: deepen an area

When a plan is about to touch an area and its spec is too thin:

1. Read `specs/<area>/index.md` end-to-end.
2. Inspect the relevant implementation, design sources, prototype revisions,
   and checks; record what remains unverified.
3. Refine current requirements and retained evidence through `templates/spec.md`.
   New delivery proposals remain in the active plan until `cumaru-absorb`.
4. **Split into a concern file** when a topic is large enough.
5. **Promote a concern to a subarea** when it has grown beyond a flat file.
6. Run `cumaru tree specs --rows` if the filesystem structure changed.
7. `cumaru doctor`.

## Recipe: consolidate an area (changelog → single coherent body)

Runs **on request**. There is no automatic trigger and no frontmatter state to
read: the signal is the body reading like a changelog instead of a flat
statement of what is true now.

1. Read the area's files.
2. When the history behind a passage is unclear, recover it from git:
   `git log --follow --oneline -- .cumaru/specs/<path>`.
3. **Rewrite the area's body into a single coherent spec.**
4. run `cumaru tree specs --rows`.
5. `cumaru doctor`.

## Spec absorption during absorb (NOT this skill)

When a plan closes, Design Lead follows `cumaru-absorb` for review readiness,
claim ownership, durable edits, and cleanup. Plan scope is a discovery hint;
the recipe verifies the actual owning spec areas before applying the delta.

This skill provides the recipes to **grow** the spec tree (bootstrap, deepen, consolidate). The `cumaru-absorb` skill provides the recipe to **absorb** a closed plan's delta into already-existing areas.

## What this skill does NOT do

- **Delta absorption** — `cumaru-absorb`.
- **Plan authoring** — `cumaru-plan`.

## Patterns

| User says | You do |
|---|---|
| "Bootstrap the specs" / "scaffold the spec areas" | Bootstrap recipe → derive area list and routine metadata → stop only for unresolved scope or ownership → create each area |
| "Deepen the auth spec" | Deepen recipe on `specs/auth/` → light-or-deep read → write requirements → split/promote as needed |
| "Split this area into concerns" | Deepen recipe step 4 (split) or step 5 (promote) |
| "Consolidate specs/payments" | Consolidate recipe → read the body → recover history from git if needed → rewrite as current state |

Use `cumaru tree specs` for navigation; pair with `cumaru-plan` (scope paths) and `cumaru-absorb` (absorbs deltas).
