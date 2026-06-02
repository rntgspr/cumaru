# `/cumaru:explore`

Loads the `cumaru-explore` skill and dispatches by the user's natural-language input. Covers capturing new explorations, promote to plans, and dropping stale ideas.

## Workflow

1. Load `.cumaru/skills/cumaru-explore/SKILL.md` and the `roles/lead.md`.
2. Load `exploring/index.md`.
3. Classify the user's request against the **Patterns** table in the skill.
4. Execute the matching recipe with user confirmation at each step.
5. Run `cumaru doctor` at the end.

## Related

- [`cumaru-plan` -> `/cumaru:plan`](plan.md) — receives promoted explorations.
