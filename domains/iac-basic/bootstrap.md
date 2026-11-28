---
summary: Ordered bootstrap steps for the iac-basic domain after install.
---

## iac-basic — bootstrap steps

The install ships empty `intake/`, `plans/`, `topology/`, `exploring/`, and
`runbooks/` pillars. Work through the steps in order. Where a step allows a
proposal, present it and write only what the user confirms. `disciplines/`,
`roles/`, and `templates/` stay as shipped.

1. **Environments.** Read the infrastructure layout and deployment
   configuration and propose the environment list. Never reinterpret
   environments as software components.
2. **Targets.** Write the confirmed environment keys to
   `config.yaml > meta.targets.values`, keeping the reserved `all` and `meta`
   values.
3. **Intake.** Do not configure a tracker registry on `intake/index.md`;
   `cumaru-intake` records observed scalar provenance on each item from
   `templates/intake-epic.md`, `templates/intake-story.md`, or
   `templates/intake-ticket.md` without adding an integration.
4. **Topology.** When the user is ready, hand off to `cumaru-topology`: it
   proposes infrastructure stacks and creates `topology/<area>/index.md` from
   `templates/bootstrap.md`, then deepens them with `templates/topology.md`.
   Deepen and consolidate are recurring and stay in that skill.
5. **Other pillars.** `cumaru-explore` writes `templates/exploration.md`;
   `cumaru-plan` writes `templates/plan.md`, `templates/task.md`,
   `templates/delta-draft.md`, and `templates/handoff.md`; operational
   procedures follow `templates/runbook.md`. New pillar indexes start from
   `templates/any-index.md`.
6. **Validate.** Run `cumaru doctor`, then report answered and empty topics.
