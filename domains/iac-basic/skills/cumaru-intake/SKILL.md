---
human_revised: false
version: 1
name: cumaru-intake
description: Use this skill to bring a user-provided or directly readable infrastructure tracker item into `.cumaru/intake/` and refine it without overwriting curated local content.
summary: Bring infrastructure requests and incidents into intake while preserving refinement and provenance.
---

# Intake workflow

1. Read the tracker item directly when available, or ask the user for its source text. Never invent tracker fields.
2. Create `intake/<KEY>/index.md` from the matching intake template when absent. Preserve curated content on refresh.
3. Record the required frontmatter, including scalar tracker provenance, status, environment-oriented `apps`, and evidence-backed `relates`.
4. Use a temporary RAW block while converting source prose into an English overview and EARS or RFC 2119 acceptance criteria. For incidents, capture impact, timeline, reproduction, expected, and actual behavior where applicable.
5. Set `apps` from `config.yaml > meta.apps.values`, set a valid `summary`, remove the complete RAW block, then run `cumaru tree intake --rows` and `cumaru doctor --quiet`.

On refresh, source status may change; refined body, type, apps, relations, summary, and existing provenance remain adopter-owned.
