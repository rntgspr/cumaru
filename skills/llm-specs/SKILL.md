---
name: llm-specs
description: Use this skill whenever the user wants to work on the `.llm/specs/` pillar of a project that adopts the dot-llm framework — bootstrap fresh spec areas from an existing codebase, deepen the description of an area, or consolidate accumulated plan deltas back into the spec body. Trigger on phrases like "bootstrap specs", "scaffold the specs for this repo", "deepen the auth spec", "consolidate specs/payments", "compactar a área", or any request that frames work in terms of the `specs/` pillar. There is no `llm` CLI subcommand for any of this — the procedures here are LLM-driven, using ordinary Read / Grep / Edit against the repo and `.llm/`. If the user asks "how do I run llm specs" tell them: in v3 there is no specs subcommand; do this manually using this skill.
---

# Specs work — bootstrap, deep, consolidate

The `.llm/specs/` pillar is the **living spec** of system areas: what is true about the codebase right now, organized by area, kept current by absorbing plan deltas on archive. It is **the** thing the LLM loads to understand a feature.

There is no CLI for this in v3 — the v2 `llm specs bootstrap/deep/consolidate` commands were removed because every step is naturally LLM-driven (read the code, decide what's an area, write `index.md`). Use this skill as the procedure.

For the recursive node model and where `specs/` sits in `.llm/`, read `.llm/index.md` and `.llm/schema.yaml` first.

## Bootstrap — seed `specs/` from an existing codebase

**Goal.** Identify the top-level areas of the system and create a skeleton `specs/<area>/index.md` for each, so future plans have somewhere to absorb deltas into.

**When to do this.** First adoption of the framework in a mature codebase, or when a major new subsystem lands and `specs/` doesn't reflect it yet.

**Procedure.**

1. Read the project's `CLAUDE.md` (and any `README`, `docs/`) to understand the stated architecture.
2. List the top-level dirs under `src/` (or `app/`, `lib/`, depending on the stack). Each candidate area is usually one of: a clear subsystem (`auth`, `payments`, `reports`), a cross-cutting concern (`telemetry`, `i18n`), or a deployable surface (`api`, `web`, `worker`).
3. **Talk to the user before scaffolding.** Show the proposed list. The right area split is a judgement call you don't make alone.
4. For each agreed area, create `.llm/specs/<area>/index.md` with the frontmatter declared in `schema.yaml` (`name`, `summary`, `depends-on: []`, `apps: [...]`, etc. — read the schema for the exact required keys). Body: `# <area>`, a one-paragraph `## Overview` derived from your code reading, and an empty `## Requirements (EARS)` section.
5. Run `llm reconcile specs` (or `llm reconcile specs --apply`) so `specs/index.md` lists the new areas.

**What not to do.**
- Don't auto-create areas without confirmation. A bad split poisons every later plan.
- Don't try to write the full spec body in one pass — bootstrap is the skeleton; deepening fills it.
- Don't invent EARS requirements you can't substantiate from the code. Better an empty Requirements section than fabricated ones.

## Deep — deepen an existing area

**Goal.** Take an area that has at minimum an `index.md` and refine its body by reading more code: add real EARS Requirements, split concerns into `<concern>.md` files or `<subarea>/` dirs when they outgrow the index, populate `depends-on:` once you see actual coupling.

**When to do this.**
- The area was bootstrapped but its `## Requirements (EARS)` is empty or sparse.
- A new plan is about to touch the area and the spec is too thin to write a meaningful `scope:` against it.
- The user asks to "flesh out", "deepen", or "compactar e detalhar" an area.

**Procedure.**

1. Read the area's `index.md` to see what's already documented.
2. Read the code in the area's surface: source files, tests, configs. Take notes by **topic** — auth has "login flow", "token storage", "session refresh", etc.
3. For each topic, write EARS-style requirements (`WHEN <trigger> THE SYSTEM SHALL <response>`) grounded in code you can point to. Use the schema's EARS rule as the contract; it's a warning-level check (the validator never blocks on it).
4. If a topic is large enough to deserve its own file, create `specs/<area>/<concern>.md` and link from the area's `index.md`'s `## Files` section. If a topic is itself a subsystem with its own concerns, create `specs/<area>/<subarea>/` with its own `index.md` (recursive — see `schema.yaml`'s area-nests-area rule).
5. After structural changes, run `llm reconcile specs` so the pillar index reflects new rows / nested paths.

**What not to do.**
- Don't split a single concern into multiple files just because the section grew long — split when it's *conceptually* separable, not when it's typographically inconvenient.
- Don't load `depends-on:` with every related area — load only the ones whose contract you actually need to read alongside this area's contract. Soft cross-links go in `relates:`.

## Consolidate — absorb accumulated plan deltas

**Goal.** When a spec area's `deltas:` list has grown long (several plans archived into it), rewrite the body into one coherent spec and replace the long list with a single `consolidated-at: <ISO date>` field.

**When to do this.**
- A spec area's `deltas:` list has ≥5 entries (loose trigger — longer = more value).
- The user asks to "consolidate", "compactar", "compact the history" of an area.
- The spec body reads as a layered stack of "delta from JET-X then delta from JET-Y" instead of a single picture.

**Procedure.**

1. Read `specs/<area>/index.md` (and any `<concern>.md` files, subareas).
2. For each plan ID in the area's frontmatter `deltas:` list, read the corresponding `archive/<PLAN-ID>/delta.md` — those are the chronological changes that built the current spec.
3. Rewrite the area's body into a single coherent spec, integrating every delta as if it had always been part of the system. Drop the layering. Where two deltas contradict (later one supersedes), reflect the **current** state — the deltas are history, the spec is the present.
4. Replace the `deltas: [...]` list in the frontmatter with `consolidated-at: <today's ISO date>`. Keep the archive entries on disk untouched — they remain the verbose history; the spec body is the compact view.
5. If the area had nested subareas / concerns, consolidate each one only if it too has a long `deltas:` list. Don't touch consolidated subareas just because the parent is being consolidated.
6. Run `llm reconcile specs` so the pillar index reflects the new `consolidated-at:` (the column `Relates`/`Depends-on` don't change, but the row's source of truth shifted).

**What not to do.**
- Don't delete the `archive/<PLAN-ID>/` entries. They're the audit trail; consolidation is about the spec body, not history pruning.
- Don't consolidate halfway. Either a delta is folded into the body and removed from the `deltas:` list, or it isn't. No "kept some for clarity".
- Don't trigger this on every plan close. Consolidation has a cost (context to load all the deltas); pay it only when the cumulative weight is real.

## Reading `.llm/schema.yaml` for the contract

Every step above touches frontmatter and tags. The contract for each — which keys are required, which tags belong on which file, what columns the `specs:` array tag carries in `specs/index.md` — lives in `schema.yaml` under `root.entities.specs`. Read it before drafting; cross-check against it after.

`llm doctor` will surface frontmatter and EARS issues; `llm reconcile specs` will surface index drift. Both are validators, not authors — the writing is yours.
