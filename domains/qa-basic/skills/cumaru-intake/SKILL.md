---
human_revised: false
version: 1
name: cumaru-intake
description: Use this skill to bring a user-provided or directly readable feature, bug, or test request into `.cumaru/intake/` and refine it without overwriting curated local content.
summary: Bring QA work into intake while preserving refinement, verification intent, and provenance.
---

# Intake workflow

1. Read the tracker item directly when available, or ask the user for its source text. Never invent tracker fields.
2. Create `intake/<KEY>/index.md` from the matching intake template when absent. Preserve curated content on refresh.
3. Record required frontmatter, scalar tracker provenance, test-level `apps`, and evidence-backed `relates`.
4. Use a temporary RAW block while writing an English overview and EARS or RFC 2119 acceptance criteria. For bugs and regressions, fill reproduction, expected, and actual behavior so coverage can lock it in.
5. Set `apps` from `config.yaml > meta.apps.values`, set a valid `summary`, remove the complete RAW block, then run `cumaru tree intake --rows` and `cumaru doctor --quiet`.

On refresh, source status may change; refined body, type, apps, relations, summary, and existing provenance remain adopter-owned.
