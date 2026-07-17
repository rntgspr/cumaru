---
human_revised: false
apps: [meta]
summary: Framework guidance for Plans and its required workflow.
---


# Plans

Active **test campaigns** — one directory per campaign in flight. Authored by the Lead at planning time; moved to `archive/` on close. `Apps` = the levels the campaign authors tests at.

## Rules

- **One directory per campaign.** `plans/<KEY>/` for tracker-backed work (the linked intake `<KEY>`), `plans/maintenance-<slug>/` for internal ones (pure kebab-case, no `key:`).
- **The plan body carries the campaign contract:** `## Test Strategy` (which levels, why), `## Scope` (the `coverage/` paths touched), `## Risks / Gaps`, `## Out of scope`. For tracker-backed campaigns, the requirement + acceptance criteria live in the linked `intake/<KEY>/` and are not duplicated.
- **`scope:`** names the `coverage/` paths the campaign touches.
- **Tasks = cases to author/automate.** A `t<N>.md` per case or slice of cases; may run in parallel when `depends-on:` is satisfied and `files:` predictions do not overlap. `apps:` on a task = the levels it writes at. The Lead reconciles cascades from `handoff-t<N>.md`.
- **Authoring:** the Lead writes `index.md` + `t<N>.md`; the Dev writes `handoff-t<N>.md` (per case) and `delta-draft.md` (at close).

## When to use

- Starting a test campaign → create `plans/<KEY>/` or `plans/maintenance-<slug>/` (Lead).
- Authoring/automating a case → flip `t<N>.md` `status:` and write `handoff-t<N>.md` (Dev).
- Closing → Dev writes `delta-draft.md`; Lead finalizes into `archive/<PLAN-ID>/delta.md`, absorbs into `coverage/`, prunes the directory.

## When NOT to use

- Requirement intent / acceptance criteria → `intake/<KEY>/`.
- The coverage map as it is today → `coverage/<area>/`.
- A reusable convention → `standards/`.
- Exploratory ideation → `exploring/<slug>/`.
