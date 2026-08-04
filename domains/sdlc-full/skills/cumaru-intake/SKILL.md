---
human_revised: false
version: 1
name: cumaru-intake
description: Use this skill to bring a user-provided or directly readable tracker item into `.cumaru/intake/`, refresh its source fields without overwriting refined content, and turn raw tracker prose into the domain intake contract.
summary: Bring tracker work into the flat SDLC intake pillar while preserving refined adopter content and provenance.
---

# Intake workflow

1. Read the tracker item directly when the active agent can access it; otherwise ask the user for the source text. Never invent missing tracker data.
2. Resolve the item type and use `templates/intake-epic.md`, `templates/intake-story.md`, or `templates/intake-ticket.md` to create `intake/<KEY>.md` when absent.
3. Set the template-required frontmatter. Preserve an existing refined item's `type`, `apps`, `relates`, `summary`, provenance, and body; refresh source-derived status only when the source was actually read.
4. Stage unedited source prose in a `<!-- BEGIN RAW (tracker: <name>) ... END RAW -->` block while refining. Record `key`, scalar `tracker`, `type`, `status`, `synced-at`, `apps`, and `relates` from evidence.
5. Replace `## Overview` with a concise English restatement. Write EARS or RFC 2119 acceptance criteria, using one dominant style per section. For bugs, fill `## Reproduction`, `## Expected`, and `## Actual`.
6. Set `apps` from `config.yaml > meta.apps.values`, verify parent and cross-item `relates`, set a valid `summary`, then remove the complete RAW block.
7. Run `cumaru tree intake --rows` and `cumaru doctor --quiet`.

The tracker remains source provenance; the refined intake file is the local work contract. On refresh, never replace curated content with raw upstream prose.
