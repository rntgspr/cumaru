---
human_revised: false
summary: Base domain context for Cumaru projects that need local framework extensions.
apps: [meta]
---

<!-- cumaru:components -->
| Link | Description |
|------|-------------|
_(replace with your actual stack)_
<!-- /cumaru:components -->

<!-- cumaru:root -->
_(empty — replace with adopter-specific context, or delete this placeholder)_
<!-- /cumaru:root -->

# Base domain

The base is a **minimal domain kernel** — universal rules and meta scaffolding, with **no domain pillars**. This file is the per-domain hook the root `index.md` declares as a `depends-on`; in a real domain it carries the pillars, roles, entry points, and domain conventions. Here it stays intentionally bare.

## Roles

- **Admin** ([`roles/admin.md`](roles/admin.md)) — full read/write across `.cumaru/` and the project. The starting point for any framework; domains extend this set.

## Pillars

None. Declare your own under `schema.yaml`'s `root.entities`, then create each `<pillar>/index.md` from `templates/any-index.md` and run `cumaru doctor`.

## Flow

No predefined flow — the base defines no pillars. Declare your own entities
in `schema.yaml`'s `root.entities`, seed their `index.md`, and `cumaru doctor`
validates the graph. The loading-rule traversal then follows whatever
structure you build.

## Entry

With no pillars, the Admin role loads only what the task names. Build your domain to get pillar indexes the loading rule can traverse.
