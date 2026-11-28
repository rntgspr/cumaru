---
summary: Ordered bootstrap steps for the design-as-code domain after install.
---

## design-as-code — bootstrap steps

The install ships empty `intake/`, `research/`, `plans/`, `specs/`, `assets/`,
and `concepts/` pillars. Work through the steps in order. Where a step allows a
proposal, present it and write only what the user confirms. `disciplines/`,
`roles/`, and `templates/` stay as shipped.

1. **Context.** Read `.cumaru/index.md`, `.cumaru/domain.md`, and the installed
   disciplines. Apply domain role routing before Design Lead work.
2. **Surfaces.** Propose the product surfaces from project instructions,
   source, and existing design material, or take the user's list.
3. **Components.** Write the confirmed surfaces in the `components` tag of
   `domain.md` with `cumaru tag`; paths resolve from the project root.
4. **Targets.** Align `config.yaml > meta.targets.values` with the component
   keys, retaining `platform` and `meta`.
5. **Intake.** Do not set a tracker registry on `intake/index.md`;
   `cumaru-intake` records the observed tracker on each brief from
   `templates/intake-brief.md` without configuring an integration.
6. **Hand-off.** Route initial foundations, components, or journey
   specifications to `cumaru-specs` (`templates/bootstrap.md`,
   `templates/spec.md`). Use `cumaru-concept` for a design direction
   (`templates/concept.md`, `templates/research.md`) and `cumaru-plan` for work
   (`templates/plan.md`, `templates/task.md`, `templates/delta-draft.md`,
   `templates/handoff.md`); `cumaru-absorb` records `templates/asset.md`
   entries. New pillar indexes start from `templates/any-index.md`. Do not
   create speculative pillar entries.
7. **Validate.** Run `cumaru doctor`, then report answered and empty topics.
