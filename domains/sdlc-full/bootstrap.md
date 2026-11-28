---
summary: Ordered bootstrap steps for the sdlc-full domain after install.
---

## sdlc-full — bootstrap steps

The install ships empty `intake/`, `plans/`, `specs/`, `exploring/`, and `issues/` pillars. Work through the steps in order.
Where a step allows a proposal, present it and write only what the user
confirms. `disciplines/`, `roles/`, and `templates/` stay as shipped.

1. **Components.** Read the project's `README`, manifests (`package.json`,
   `pyproject.toml`, `go.mod`, ...), and top-level layout, and propose the
   components: deployable surfaces or coherent codebase chunks.
2. **Components tag.** Replace the placeholder `webapp` and `api` rows of the
   `components` tag in `domain.md` with the confirmed list, using
   `cumaru tag set domain.md components`.
3. **Targets.** List the same keys in `config.yaml > meta.targets.values`,
   keeping the reserved `platform` and `meta` values.
4. **Intake.** Do not configure a tracker registry on `intake/index.md`;
   `cumaru-intake` records observed scalar provenance on each item from
   `templates/intake-epic.md`, `templates/intake-story.md`, or
   `templates/intake-ticket.md` without adding an integration.
5. **Specs.** When the user is ready, hand off to `cumaru-specs`: it proposes
   functional areas and creates `specs/<area>/index.md` from
   `templates/bootstrap.md`, then deepens them with `templates/spec.md`.
   Deepen and consolidate are recurring and stay in that skill.
6. **Other pillars.** `cumaru-explore` writes `templates/exploration.md`;
   `cumaru-issue` writes `templates/issue.md`; `cumaru-plan` writes
   `templates/plan.md`, `templates/task.md`, `templates/delta-draft.md`, and
   `templates/handoff.md`. New pillar indexes start from
   `templates/any-index.md`.
7. **Validate.** Run `cumaru doctor`, then report answered and empty topics.
