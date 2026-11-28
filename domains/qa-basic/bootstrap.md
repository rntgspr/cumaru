---
summary: Ordered bootstrap steps for the qa-basic domain after install.
---

## qa-basic — bootstrap steps

The install ships empty `intake/`, `plans/`, `coverage/`, `exploring/`, and
`standards/` pillars. Work through the steps in order. Where a step allows a
proposal, present it and write only what the user confirms. `disciplines/`,
`roles/`, and `templates/` stay as shipped.

1. **Test levels.** Read the test layout and runner configuration and propose
   the level list. Never reinterpret levels as software components.
2. **Targets.** Write the confirmed test-level keys to
   `config.yaml > meta.targets.values`, keeping the reserved `all` and `meta`
   values.
3. **Intake.** Do not configure a tracker registry on `intake/index.md`;
   `cumaru-intake` records observed scalar provenance on each item from
   `templates/intake-epic.md`, `templates/intake-story.md`, or
   `templates/intake-ticket.md` without adding an integration.
4. **Coverage.** When the user is ready, hand off to `cumaru-coverage`: it
   proposes coverage areas and creates `coverage/<area>/index.md` from
   `templates/bootstrap.md`, then deepens them with `templates/coverage.md`.
   Deepen and consolidate are recurring and stay in that skill.
5. **Other pillars.** `cumaru-explore` writes `templates/exploration.md`;
   `cumaru-plan` writes `templates/plan.md`, `templates/task.md`,
   `templates/delta-draft.md`, and `templates/handoff.md`; testing standards
   follow `templates/standard.md`. New pillar indexes start from
   `templates/any-index.md`.
6. **Validate.** Run `cumaru doctor`, then report answered and empty topics.
