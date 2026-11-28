---
summary: Ordered bootstrap steps for the sdlc-light domain after install.
---

## sdlc-light — bootstrap steps

The install ships empty `plans/`, `specs/`, and `exploring/` pillars. Work through the steps in order.
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
4. **Specs.** When the user is ready, hand off to `cumaru-specs`: it proposes
   functional areas and creates `specs/<area>/index.md` from
   `templates/bootstrap.md`, then deepens them with `templates/spec.md`.
   Deepen and consolidate are recurring and stay in that skill.
5. **Other pillars.** `cumaru-explore` records `exploring/` notes from
   `templates/exploration.md`; `cumaru-plan` writes `templates/plan.md`,
   `templates/task.md`, `templates/delta-draft.md`, and
   `templates/handoff.md`. New pillar indexes start from
   `templates/any-index.md`.
6. **Validate.** Run `cumaru doctor`, then report answered and empty topics.
