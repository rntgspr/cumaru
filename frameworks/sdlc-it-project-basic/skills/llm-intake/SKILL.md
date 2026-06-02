---
human_revised: false
version: 1
name: llm-intake
description: Use this skill whenever the user wants to fetch a tracker issue and mirror it under `.llm/intake/` — pull a Jira (or Linear / ClickUp / Basecamp, when wired) item, refresh an existing item, or refine a freshly fetched item's body. Trigger on phrases like "fetch JET-1234", "pull this ticket into intake", "import this issue", "refresh JET-9999", "atualizar o intake do JET-X", or any task that frames the work as bringing a tracker item into `.llm/intake/`.
---

# `llm intake <KEY>` — mirror a tracker issue under `.llm/intake/`

Fetches an issue from a tracker and creates or refreshes its mirror under `.llm/intake/<KEY>/index.md`. **Tracker-agnostic by design**; only the Jira adapter is wired today (ClickUp / Linear / Basecamp are TODO in `src/cmd_intake.sh`).

## Layout (v3 flat — no per-issuetype subdirs)

Every item lives at `.llm/intake/<KEY>/index.md` regardless of type. The `type:` field discriminates (`epic`, `story`, `task`, `bug`, `spike`). The pillar's `intake/index.md` declares which tracker(s) the project pulls from via `tracker:` (a LIST — typically one, e.g. `[jira]`).

## Required env (Jira adapter)

Auto-loaded from `.env` at the project root if present:
- `ATLASSIAN_DOMAIN` — subdomain in your `atlassian.net` URL (e.g. "acme")
- `ATLASSIAN_EMAIL` — account email
- `ATLASSIAN_API_TOKEN` — from `id.atlassian.com/manage-profile/security/api-tokens`

System deps: `curl`, `jq`.

## Behavior

```bash
llm intake JET-1234       # first run OR re-sync — same command
```

**First run.** Creates `intake/<KEY>/index.md` from the type-specific body template (`intake-epic.md` / `intake-story.md` / `intake-ticket.md` under `.llm/templates/`), fills frontmatter:
- `key`, `tracker: jira`, `type`, `status`, `synced-at`, `apps: []`, `relates: [...]`

Then appends a `<!-- BEGIN RAW (tracker: jira) ... END RAW -->` block at the bottom carrying the unedited tracker description plus step-by-step refinement instructions tailored to the issuetype.

The `relates:` list is auto-populated from the source (parent epic / parent story / epic link when known) so cross-item links are clear from the start.

**Re-sync** (file exists). Refreshes only `status:` and `synced-at:`. If the RAW block is still present, its description is updated with the latest. If it's been removed (the issue was refined), the body is preserved untouched. Missing `tracker:` is added on re-sync (v2 → v3 helper).

## Your job after `llm intake` runs

Open the created/refreshed file. The RAW block has explicit per-issuetype instructions; the gist:

1. Refine `## Overview` — restate what's asked, in English, 1-3 paragraphs.
2. Refine `## Acceptance Criteria (EARS)` — `WHEN <trigger> THE SYSTEM SHALL <response>`.
3. If `type: bug`, fill `## Reproduction`, `## Expected`, `## Actual` from the description.
4. Set `apps: [...]` in the frontmatter to the affected components (keys from `schema.yaml > meta.apps.values`).
5. Verify `relates: [...]` lists parent epic / story / cross-item references correctly.
6. **Delete the entire BEGIN/END RAW block** when done. The presence of this block is `llm doctor`'s signal that the item is still raw — leaving it after refinement creates noise.

The frontmatter `status:` and `synced-at:` are managed by `llm intake` and refreshed on each re-sync; the body sections are yours to author. **Don't** edit `status:` or `synced-at:` by hand.

## Per-item provenance (multi-tracker projects)

Each item's `tracker: jira` (scalar) records its source — so a project mixing Jira + Linear stays unambiguous. The pillar's `tracker: [jira, linear]` (list, on `intake/index.md`) declares the set of allowed sources. `llm doctor`'s schema-conformance verifies the per-item `tracker:` is present.

## Future adapters (TODO in `cmd_intake.sh`)

When wiring **ClickUp** (REST API v2, Personal API Token), **Linear** (GraphQL, API key), or **Basecamp** (REST API v3, OAuth/HTTP basic):

1. Detect the tracker value (from the item's frontmatter on re-sync, or from a CLI flag/env on first create) and route the fetch.
2. Emit the same v3 frontmatter shape — only the SOURCE differs.
3. Reuse `_intake_append_raw_block` (with the tracker name in the BEGIN RAW marker).

Until then: only Jira works; other trackers should be added manually for now.

## Patterns

| User says | You do |
|---|---|
| "Fetch JET-1234 into intake" / "pull JET-X" | `llm intake JET-1234` → read the created file → walk the RAW block instructions → delete the RAW block when done |
| "Refresh the intake for JET-X" | Same command. Re-sync updates `status:` and `synced-at:` automatically |
| "What does intake look like for X?" | Read `.llm/intake/<X>/index.md` directly; if absent, run `llm intake <X>` |
| "Why does the orphan check flag intake/X?" | Probably the item was created in v2 layout (`intake/<type>/X/`); migrate via `llm flow` |
