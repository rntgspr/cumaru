---
human_revised: false
generated: false
framework-version: 3
apps: [meta]
---

<!-- llm:components -->
| Key | Folder | Stack / Notes |
|---|---|---|
_(replace with your actual stack)_
<!-- /llm:components -->

<!-- llm:root -->
_(empty — replace with adopter-specific context, or delete this placeholder)_
<!-- /llm:root -->

# `.llm/`

Entry point for any LLM (or human) interacting with this repository. This is the **base** framework — a minimal kernel with universal rules + meta scaffolding, **no pillars yet**.

To build your own domain:
1. Edit `schema.yaml` — under `root.entities`, declare your pillars (look at the commented example).
2. For each pillar you declare, create `<pillar>/index.md` from `templates/any-index.md`.
3. Run `llm doctor` — it walks the schema and validates entities; no code change needed when you add/remove pillars.

For pre-built domain frameworks, see `dot-llm/frameworks/` (e.g. `sdlc-it-project-basic` for software-development workflows).

## Roles

The base ships one role: **Admin** ([`roles/admin.md`](roles/admin.md)) — full read/write across `.llm/` and the project. It is the starting point for any flavor. Domain-specific roles (Lead, Dev, Ghost in the SDLC flavor; whatever fits your discipline) are defined by the flavor and extend this set.

## Loading rule

The LLM loads only what is **declared** — never what is physically near. Declarations come from the schema's `root.entities` (which pillars exist) and from each pillar's own index table (which entries exist).

## Project context

Adopter-specific orientation the LLM should keep in mind: stack, monorepo layout, conventions not yet captured in pillar specs, important external links, current focus, hard constraints. Edit the `<!-- llm:root -->` block above — its body is preserved across `llm sync` upgrades.
