---
human_revised: false
version: 1
name: cumaru-concept
description: Create, compare, refine, select, or reject design concepts before they become scoped delivery plans.
summary: Create, compare, refine, select, or reject design concepts before they become scoped delivery plans.
---

# Cumaru concept

Use concepts for deliberate design directions, not generic brainstorming. Each
concept links its research evidence, audience, prototype or sketch, constraints,
trade-offs, and criteria for selection.

Read `.cumaru/domain.md` and apply its role routing boundary. Design Lead owns
concept selection and promotion; this recipe never silently switches roles.
As Lead, load `roles/lead.md` and `concepts/index.md`. Use invocation arguments
to classify the request as create, compare, select, or reject. Run `cumaru
doctor` after every mutation.

## Create

1. Confirm a kebab-case slug and create concepts/<slug>/ and its index.
2. Use `templates/concept.md`, setting status to considering.
3. Follow its evidence and written design contract; use `templates/research.md`
   when new research is needed, without requiring a study for every concept.
4. Validate with cumaru tree concepts --rows and cumaru doctor.

## Select

1. Compare alternatives against user outcome, evidence, implementation cost,
   accessibility, and product constraints.
2. Require an existing tracker ticket. Use `cumaru-intake` to create or refresh
   `intake/<KEY>.md` and reconcile accepted design requirements into its criteria.
   Resolve source conflicts and open acceptance decisions before promotion;
   keep hypotheses distinct from accepted requirements.
3. Record the selection decision and status `selected` in the concept, linking
   the brief criterion IDs. Use `cumaru-plan` to create `plans/<KEY>/index.md`
   through `templates/plan.md`; link the selected direction, alternatives, and
   research rather than copying their content. Keep the concept until absorption.

Internal maintenance may start directly in plans without a concept or tracker;
that path does not bypass this promotion contract.

## Reject

Record the rejection rationale in related active research or a plan when
useful; put any durable finding in its owning spec. Before removal, run
`cumaru doctor`, verify tracked Git recovery for the concept and retained
result, and confirm the removal with the user. If verification fails, claims
remain unresolved, recovery is absent, or other active work still needs the
concept, keep it. Remove only the confirmed concept through `cumaru fs`,
then run doctor again.
