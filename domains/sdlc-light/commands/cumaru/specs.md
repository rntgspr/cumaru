---
human_revised: false
summary: Framework command guidance for `/cumaru:specs` workflow execution.
---

# `/cumaru:specs`

Loads the `cumaru-specs` skill and dispatches by the user's natural-language input. Covers bootstrapping, deepening, splitting, and consolidating spec areas.

## Workflow

1. Load `.cumaru/skills/cumaru-specs/SKILL.md` and the `roles/lead.md`.
2. Load `specs/index.md`.
3. Classify the user's request against the **Patterns** table in the skill.
4. Execute the matching recipe with user confirmation at each step.
5. Run `cumaru doctor` at the end.

## Related

- [`cumaru-plan` -> `/cumaru:plan`](plan.md) — declares `scope:` paths that `specs/` must satisfy.
- [`cumaru-absorb` -> `/cumaru:absorb`](absorb.md) — absorbs closed plan deltas into specs.
