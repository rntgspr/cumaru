---
human_revised: false
name: responsive-design
applies-when: adapting or reviewing layouts across viewport sizes or input modes
strictness: 9/10
summary: Adapt affected layouts by content priority and verify legibility, controls, and overflow at relevant viewport sizes.
source:
  - plugin: nextlevelbuilder/ui-ux-pro-max-skill
    skill: ui-ux-pro-max
    url: https://github.com/nextlevelbuilder/ui-ux-pro-max-skill/blob/main/.claude/skills/ui-ux-pro-max/SKILL.md
    license: MIT
    license-url: https://github.com/nextlevelbuilder/ui-ux-pro-max-skill/blob/main/LICENSE
  - plugin: vercel-labs/web-interface-guidelines
    skill: web-interface-guidelines
    url: https://github.com/vercel-labs/web-interface-guidelines/blob/main/command.md
    license: MIT
    license-url: https://github.com/vercel-labs/web-interface-guidelines/blob/main/LICENSE
---

# Responsive design

**Gate:** preserve essential content and usable interactions across the affected layout's supported viewport and input conditions.

## Cycle

1. Resolve relevant viewport ranges, content, and input modes from the project and task.
2. Adapt hierarchy and layout by content priority. Keep text readable and controls usable; choose dimensions for the applicable platform and accessibility target.
3. Inspect representative narrow and wide widths and affected layout transitions, using relevant long labels and safe areas. Define wrapping, truncation, and scrolling deliberately; keep essential identifiers accessible.
4. Record inspected widths and behavior in the existing delivery evidence. Apply `visual-verification.md` to corrections and reinspection; report unverified ranges.

## Red flags

- Shrinking the desktop composition until text or controls become unusable.
- Hiding content to conceal accidental overflow.
- Treating two static frames as proof of responsive runtime behavior.
- Adding intentional component scrolling without a discoverable way to use it.
