---
human_revised: false
version: 1
name: cumaru-intake
description: Create or refresh a flat design brief from directly readable or user-provided tracker source while preserving refined requirements and provenance.
summary: Import tracker-backed design briefs and reconcile source changes without losing accepted local requirements.
---

# Cumaru intake — design briefs

Read `.cumaru/domain.md` and apply its role routing boundary. Design Lead owns
brief refinement; Designer and Reviewer return proposed changes to Lead.
As Lead, load `roles/lead.md`, `intake/index.md`, and `templates/intake-brief.md`.

1. Read the tracker item through access already available to the active agent,
   or request its source text from the user. Do not invent a ticket, missing
   fields, or tracker integration. This recipe does not write to the tracker.
2. Create `intake/<KEY>.md` from the template when absent. Record observed
   source metadata, the actual tracker in scalar `tracker:`, source link, and
   when it was read in `synced-at:`. Select `targets:` from
   `config.yaml > meta.targets.values` and verify `relates:`.
3. Stage unedited source prose in a `<!-- BEGIN RAW (tracker: <name>) ... END RAW -->`
   block during refinement. Follow the brief template for the English contract;
   preserve the source meaning and distinguish proposed clarifications.
4. On refresh, preserve refined prose, criterion IDs, local notes, provenance,
   and curated metadata. Update source-derived status and `synced-at:` only
   after reading the source. Reconcile material differences with Lead and the
   user; do not silently replace accepted criteria or erase pending differences.
5. Before concept promotion, reconcile accepted concept requirements into this
   brief and link their evidence. Resolve source conflicts and pending decisions
   before planning. Plans reference these criteria instead of copying them.
6. Remove the complete RAW block after refinement. Run `cumaru tree intake --rows`
   and `cumaru doctor --quiet`; report remaining decisions explicitly.

The upstream tracker is authoritative source provenance; the refined brief is
the single local home for tracker-backed Overview and Acceptance Criteria.
Internal maintenance uses `templates/plan.md` without creating an intake item.
