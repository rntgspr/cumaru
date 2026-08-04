---
human_revised: false
apps: [meta]
summary: Framework guidance for Plans and its required workflow.
---


# Plans

Active **changesets** — one directory per infrastructure change in flight. Authored by the Lead at planning time; moved to `archive/` on close. `Apps` = the environments the change targets.

## Rules

- **One directory per changeset.** `plans/<KEY>/` for tracker-backed changes (the linked intake `<KEY>`), `plans/maintenance-<slug>/` for internal ones (pure kebab-case, no `key:`).
- **The plan body carries the change contract:** `## Plan / DAG` (apply steps), `## Blast radius`, `## Rollback`, `## Promotion path` (environments, in order), `## Out of scope`, `## Risks`. For tracker-backed plans, intent + acceptance live in the linked `intake/<KEY>/` and are not duplicated.
- **`scope:`** names the `topology/` paths the change touches.
- **Tasks = apply steps.** A `t<N>.md` per step; may run in parallel when `depends-on:` is satisfied and `files:` predictions do not overlap. The Lead reconciles cascades from `handoff-t<N>.md`.
- **Authoring:** the Lead writes `index.md` + `t<N>.md`; the Dev writes `handoff-t<N>.md` (per step) and `delta-draft.md` (at close).

## When to use

- Starting an infra change → create `plans/<KEY>/` or `plans/maintenance-<slug>/` (Lead).
- Applying a step → flip `t<N>.md` `status:` and write `handoff-t<N>.md` (Dev).
- Closing → Dev writes `delta-draft.md`; Lead finalizes into `archive/<PLAN-ID>/delta.md`, absorbs into `topology/`, prunes the directory.

## When NOT to use

- Request intent / acceptance criteria → `intake/<KEY>/`.
- The topology as it is today → `topology/<area>/`.
- A repeatable operation → `runbooks/`.
- Pre-change ideation → `exploring/<slug>/`.
