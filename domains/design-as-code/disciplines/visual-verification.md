---
human_revised: false
name: visual-verification
applies-when: finishing a design change or reporting visual work complete
strictness: 10/10
summary: Verify the saved design revision against its accepted reference and report the evidence and limits of visual completion.
source:
  - plugin: anthropics/skills
    skill: frontend-design
    url: https://github.com/anthropics/skills/blob/main/skills/frontend-design/SKILL.md
    license: Apache-2.0
    license-url: https://github.com/anthropics/skills/blob/main/skills/frontend-design/LICENSE.txt
  - plugin: bencium/bencium-marketplace
    skill: design-audit
    url: https://github.com/bencium/bencium-marketplace/blob/main/design-audit/skills/design-audit/SKILL.md
    license: MIT
    license-url: https://github.com/bencium/bencium-marketplace/blob/main/LICENSE
---

# Visual verification

**Gate:** inspect the saved result at the delivered revision before reporting visual work complete.

## Cycle

1. Compare the rendered result with accepted references and requirements at a useful scale. Use the applicable design disciplines for inspection criteria; verify the states and viewport examples required by the task.
2. Record observed defects. The authorized implementer corrects within task scope and reinspects; Reviewer reports findings to Lead and rechecks the corrected revision without editing it.
3. Confirm the intended destination and saved revision. Verify source editability where the deliverable requires it; an export alone does not demonstrate source persistence.
4. Record result location, inspected revision, evidence, and verification limits in the existing handoff or review report. Independent review and absorption still follow the domain workflow.

## Red flags

- Claiming completion from tool success, an unsaved canvas, or an earlier screenshot.
- Calling a static specimen a working interaction or claiming checks that were not performed.
- Using verification to authorize edits, replace independent review, or declare plan readiness.
