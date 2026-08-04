---
name: compactness over duplication; reference templates
description: Across the framework, prefer compactness; reference canonical sources instead of duplicating their content
type: feedback
originSessionId: 507d571c-f4de-4425-8d7c-cb5b12395a28
---
**Rule:** when documenting in `.cumaru/` (roles, skills, indexes), reference the canonical source instead of duplicating its content.

**Why:** the user repeatedly trimmed verbose passages in `roles/ghost.md`, the `Subcommands` help table, and the JIRA-RAW / archive instructions. Skills and indexes are loaded into LLM context — every line that doesn't pull weight bloats it.

**How to apply:**
- Mention the template path (`templates/intake-<type>.md`, `templates/handoff.md`, etc.) instead of repeating its sections.
- When two paragraphs say the same thing in different words, keep one.
- Compactness > completeness in role and skill files. The schema and templates are the canonical contracts.
- "Universal rules" in `.cumaru/index.md` are the single source for cross-cutting conventions; don't restate them per role.
