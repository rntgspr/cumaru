---
human_revised: false
version: 1
name: cumaru-intake
description: Use this skill whenever the user wants to fetch a tracker issue and mirror it under `.cumaru/intake/` — pull a Jira / Linear / ClickUp (or Basecamp, when wired) item, refresh an existing item, or refine a freshly fetched item's body. Trigger on phrases like "fetch AAA-1234", "pull this ticket into intake", "import this issue", "refresh AAA-9999", "atualizar o intake do AAA-X", or any task that frames the work as bringing a tracker item into `.cumaru/intake/`.
summary: Use this skill whenever the user wants to fetch a tracker issue and mirror it under `.cumaru/intake/` — pull a Jira / Linear / ClickUp (or Basecamp, when wired) item, refresh an existing item, or refine a freshly fetched item's body. Trigger on phrases like "fetch AAA-1234", "pull this ticket into intake", "import this issue", "refresh AAA-9999", "atualizar o intake do AAA-X", or any task that frames the work as bringing a tracker item into `.cumaru/intake/`.
---

# `cumaru intake <KEY>` — mirror a tracker issue under `.cumaru/intake/`

Fetches an issue from a tracker and creates or refreshes its mirror under `.cumaru/intake/<KEY>.md`. **Tracker-agnostic by design**; wired adapters: Jira, Linear, ClickUp (Basecamp is TODO in `src/cmd_intake.sh`).

## Layout (v3 flat — no per-issuetype subdirs)

Every item lives at `.cumaru/intake/<KEY>.md` regardless of type. The `type:` field discriminates (`epic`, `story`, `task`, `bug`, `spike`). The pillar's `intake/index.md` declares which tracker(s) the project pulls from via `tracker:` (a LIST — typically one, e.g. `[jira]`).

## Required env (per adapter)

Auto-loaded from `.env` at the project root if present:
- `jira` — `ATLASSIAN_DOMAIN` (subdomain in your `atlassian.net` URL), `ATLASSIAN_EMAIL`, `ATLASSIAN_API_TOKEN` (from `id.atlassian.com/manage-profile/security/api-tokens`)
- `linear` — `LINEAR_API_KEY` (from `linear.app/settings/api`)
- `clickup` — `CLICKUP_API_TOKEN` (ClickUp → Settings → Apps → API Token)

System deps: `curl`, `jq`.

## Behavior

```bash
cumaru intake AAA-1234                  # first run OR re-sync — same command
cumaru intake ENG-42 --tracker linear   # first create from a non-default tracker
```

Tracker resolution (first match wins): the item's own `tracker:` frontmatter (re-sync) → `--tracker <name>` → first entry of the pillar's `tracker:` list. The resolved tracker must be in the pillar list.

**First run.** Creates `intake/<KEY>.md` from the type-specific body template (`intake-epic.md` / `intake-story.md` / `intake-ticket.md` under `.cumaru/templates/`), fills frontmatter:
- `key`, `tracker` (scalar — which source this item came from), `type`, `status`, `synced-at`, `apps: []`, `relates: [...]`

Then appends a `<!-- BEGIN RAW (tracker: <name>) ... END RAW -->` block at the bottom carrying the unedited tracker description plus step-by-step refinement instructions tailored to the issuetype.

The `relates:` list is auto-populated from the source (parent epic / parent story / epic link when known) so cross-item links are clear from the start.

**Re-sync** (file exists). Refreshes only `status:` and `synced-at:`. If the RAW block is still present, its description is updated with the latest. If it's been removed (the issue was refined), the body is preserved untouched. Missing `tracker:` is added on re-sync (v2 → v3 helper).

## Your job after `cumaru intake` runs

Open the created/refreshed file. The RAW block has explicit per-issuetype instructions; the gist:

1. Refine `## Overview` — restate what's asked, in English, 1-3 paragraphs.
2. Refine `## Acceptance Criteria (EARS / RFC 2119)` — EARS for event/state behavior, RFC 2119 for constraints. Prefer one dominant style per section.
3. If `type: bug`, fill `## Reproduction`, `## Expected`, `## Actual` from the description.
4. Set `apps: [...]` in the frontmatter to the affected components (keys from `schema.yaml > meta.apps.values`).
5. Verify `relates: [...]` lists parent epic / story / cross-item references correctly.
6. **Delete the entire BEGIN/END RAW block** when done. The presence of this block is `cumaru doctor`'s signal that the item is still raw — leaving it after refinement creates noise.

The frontmatter `status:` and `synced-at:` are managed by `cumaru intake` and refreshed on each re-sync; the body sections are yours to author. **Don't** edit `status:` or `synced-at:` by hand.

## Per-item provenance (multi-tracker projects)

Each item's `tracker:` (scalar) records its source — so a project mixing Jira + Linear stays unambiguous. The pillar's `tracker: [jira, linear]` (list, on `intake/index.md`) declares the set of allowed sources. `cumaru doctor`'s schema-conformance verifies the per-item `tracker:` is present.

## Future adapters (TODO in `cmd_intake.sh`)

When wiring **Basecamp** (REST API v3, OAuth — heavier than a static token): route by the tracker value, emit the same v3 frontmatter shape, reuse `_intake_append_raw_block` (with the tracker name in the BEGIN RAW marker). Until then, Basecamp items should be added manually.

## Patterns

| User says | You do |
|---|---|
| "Fetch AAA-1234 into intake" / "pull AAA-X" | `cumaru intake AAA-1234` → read the created file → walk the RAW block instructions → delete the RAW block when done |
| "Refresh the intake for AAA-X" | Same command. Re-sync updates `status:` and `synced-at:` automatically |
| "What does intake look like for X?" | Read `.cumaru/intake/<X>.md` directly; if absent, run `cumaru intake <X>` |
| "Why does navigation show intake/X as invalid?" | It may use the old `intake/<type>/X/` layout; migrate it with `cumaru flow` |
