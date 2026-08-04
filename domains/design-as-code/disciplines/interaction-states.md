---
human_revised: false
name: interaction-states
applies-when: designing or reviewing interactive components and feedback
strictness: 9/10
summary: Represent relevant states and transitions without losing selection, focus, or action feedback.
source:
  - plugin: vercel-labs/web-interface-guidelines
    skill: web-interface-guidelines
    url: https://github.com/vercel-labs/web-interface-guidelines/blob/main/command.md
    license: MIT
    license-url: https://github.com/vercel-labs/web-interface-guidelines/blob/main/LICENSE
  - plugin: bencium/bencium-marketplace
    skill: design-audit
    url: https://github.com/bencium/bencium-marketplace/blob/main/design-audit/skills/design-audit/SKILL.md
    license: MIT
    license-url: https://github.com/bencium/bencium-marketplace/blob/main/LICENSE
  - plugin: nextlevelbuilder/ui-ux-pro-max-skill
    skill: ui-ux-pro-max
    url: https://github.com/nextlevelbuilder/ui-ux-pro-max-skill/blob/main/.claude/skills/ui-ux-pro-max/SKILL.md
    license: MIT
    license-url: https://github.com/nextlevelbuilder/ui-ux-pro-max-skill/blob/main/LICENSE
---

# Interaction states

**Gate:** make relevant interaction states and transitions distinguishable under the project's supported input modes.

- Distinguish selection, hover, press, focus, and disabled where applicable. Hover or press styling must not hide selection; activation may change it when the behavior requires that transition.
- Keep keyboard focus visible and provide touch feedback without relying on hover.
- Represent loading, success, empty, and error feedback when the affected flow can reach those states; preserve existing behavior and state names unless the task changes them.
- Use motion to explain change, with reduced-motion behavior and interruptible transitions where relevant.
- Keep written state requirements in the existing acceptance/spec contract and reference them from tasks. Apply `design-accessibility.md` to accessibility evidence.

## Red flags

- Showing only the default state of a control with relevant stateful behavior.
- Using hover as the sole way to discover or operate an action.
- Treating a drawn state as proof that its runtime transition works.
