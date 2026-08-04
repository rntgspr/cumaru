---
human_revised: false
name: design-accessibility
applies-when: creating or reviewing visual accessibility and interaction requirements
strictness: 10/10
summary: Ground accessibility findings in applicable criteria and separate design evidence from runtime and human verification.
source:
  - plugin: AccessLint/skills
    skill: accessibility-inspect
    url: https://github.com/AccessLint/skills/blob/main/plugins/accesslint/skills/accessibility-inspect/SKILL.md
    license: MIT
    license-url: https://github.com/AccessLint/skills/blob/main/plugins/accesslint/.claude-plugin/plugin.json
  - plugin: vercel-labs/web-interface-guidelines
    skill: web-interface-guidelines
    url: https://github.com/vercel-labs/web-interface-guidelines/blob/main/command.md
    license: MIT
    license-url: https://github.com/vercel-labs/web-interface-guidelines/blob/main/LICENSE
  - plugin: nextlevelbuilder/ui-ux-pro-max-skill
    skill: ui-ux-pro-max
    url: https://github.com/nextlevelbuilder/ui-ux-pro-max-skill/blob/main/.claude/skills/ui-ux-pro-max/SKILL.md
    license: MIT
    license-url: https://github.com/nextlevelbuilder/ui-ux-pro-max-skill/blob/main/LICENSE
---

# Design accessibility

**Gate:** support accessibility claims with the applicable project criteria and evidence from the inspected artifact.

## Cycle

1. Resolve the project's accessibility target and affected criteria before claiming conformance; an unspecified target remains an open requirement.
2. Measure rendered foreground/background pairs for relevant states. Check applicable contrast, focus, control identification, and alternatives to color-only, hover-only, or gesture-only interaction.
3. Separate measured facts from judgments and identify checks requiring a running implementation, assistive technology, or a person. Static designs cannot establish keyboard or screen-reader behavior.
4. Record the revision, criterion, evidence, and remaining verification in the existing handoff or review report; use `design-review.md` for findings.

## Red flags

- Treating token names or visual impressions as contrast measurements.
- Reporting untested criteria as passed or claiming product-wide conformance from a specimen.
- Treating automated results as evidence of a person's experience.
