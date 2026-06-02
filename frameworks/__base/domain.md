---
human_revised: false
generated: false
apps: [meta]
---

# Base flavor

The base is a **minimal kernel** — universal rules and meta scaffolding, with **no domain pillars**. This file is the per-flavor hook the root `index.md` declares as a `depends-on`; in a real flavor it carries the pillars, roles, entry points, and domain conventions. Here it stays intentionally bare.

## Roles

- **Admin** ([`roles/admin.md`](roles/admin.md)) — full read/write across `.llm/` and the project. The starting point for any framework; domain flavors extend this set.

## Pillars

None. Declare your own under `schema.yaml`'s `root.entities`, then create each `<pillar>/index.md` from `templates/any-index.md` and run `llm doctor`.

## Entry

With no pillars, the Admin role loads only what the task names. Build your domain to get pillar indexes the loading rule can traverse.
