---
human_revised: false
name: design-system-first
applies-when: creating or changing design components, screens, or visual direction
strictness: 10/10
summary: Use the project's canonical design source and existing components before introducing visual changes or system departures.
source:
  - plugin: bencium/bencium-marketplace
    skill: design-audit
    url: https://github.com/bencium/bencium-marketplace/blob/main/design-audit/skills/design-audit/SKILL.md
    license: MIT
    license-url: https://github.com/bencium/bencium-marketplace/blob/main/LICENSE
  - plugin: anthropics/skills
    skill: frontend-design
    url: https://github.com/anthropics/skills/blob/main/skills/frontend-design/SKILL.md
    license: Apache-2.0
    license-url: https://github.com/anthropics/skills/blob/main/skills/frontend-design/LICENSE.txt
  - plugin: nextlevelbuilder/ui-ux-pro-max-skill
    skill: ui-ux-pro-max
    url: https://github.com/nextlevelbuilder/ui-ux-pro-max-skill/blob/main/.claude/skills/ui-ux-pro-max/SKILL.md
    license: MIT
    license-url: https://github.com/nextlevelbuilder/ui-ux-pro-max-skill/blob/main/LICENSE
---

# Design system first

**Gate:** ground changes in the project's canonical design source and accepted brief before introducing new visual decisions.

- Use the source and editing destination established by the project or request; no editor or product is mandatory.
- Inspect the affected component's anatomy, properties, tokens, and relevant usage before editing.
- Reuse suitable components and semantic tokens. Preserve established identity, content, and behavior unless the accepted change requires otherwise.
- Keep changes bounded to the request. Explain necessary additions or departures; do not invent an existing system when the project has none.
- Treat external palettes, styles, and generated suggestions as references subordinate to project requirements.

## Red flags

- Switching editing tools or treating an export as the canonical editable source without direction.
- Duplicating an existing component or hardcoding a value already represented by a suitable token.
- Importing another product's identity or expanding a small request into a design-system rebuild.
