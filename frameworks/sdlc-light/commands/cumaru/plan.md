# `/cumaru:plan`

Loads the `cumaru-plan` skill and dispatches by the user's natural-language input. Covers bootstrap, task creation, handoff writing, and delta drafting.

## Workflow

1. Load `.cumaru/skills/cumaru-plan/SKILL.md` and the `roles/lead.md`.
2. Load the three shallow indexes — `plans/index.md`, `specs/index.md`, `exploring/index.md`.
3. Classify the user's request against the **Patterns** table in the skill.
4. Execute the matching recipe with user confirmation at each step.
5. Run `cumaru doctor` at the end.

## Related

- [`cumaru-absorb` -> `/cumaru:absorb`](absorb.md) — for plan close + delta absorption.
- [`cumaru-specs` -> `/cumaru:specs`](specs.md) — for spec maintenance.
- [`cumaru-doctor` -> `/cumaru:doctor`](../doctor.md) — for health checks.
