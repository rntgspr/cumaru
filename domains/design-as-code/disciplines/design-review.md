---
human_revised: false
name: design-review
applies-when: reviewing a design or evaluating a proposed visual change
strictness: 9/10
summary: Review the requested design revision against accepted requirements and report actionable findings within role boundaries.
source:
  - plugin: bencium/bencium-marketplace
    skill: design-audit
    url: https://github.com/bencium/bencium-marketplace/blob/main/design-audit/skills/design-audit/SKILL.md
    license: MIT
    license-url: https://github.com/bencium/bencium-marketplace/blob/main/LICENSE
---

# Design review

**Gate:** tie findings to the requested scope, inspected revision, and observable mismatches with accepted requirements.

## Cycle

1. Inspect the component or flow in its relevant context. Check hierarchy, alignment, spacing, typography, density, content, and consistency.
2. Apply `interaction-states.md`, `responsive-design.md`, and `design-accessibility.md` where relevant; record untested dimensions and reasons for exclusions.
3. Report location/state, expected versus observed behavior, evidence, user impact, and the smallest useful correction. Separate preferences from defects; report checked scope even when no defects remain.
4. Follow `roles/reviewer.md` for independent review and rechecks. Reviewer returns findings to Lead without implementing fixes; Lead owns readiness and reconciliation.

## Red flags

- Broadening a component review into an unrelated redesign.
- Inventing defects to fill a report or treating personal taste as a requirement.
- Presenting self-review as independent review, or review completion as approval.
