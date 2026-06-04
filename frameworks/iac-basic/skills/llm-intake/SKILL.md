---
human_revised: false
version: 1
name: llm-intake
description: Use this skill whenever the user wants to fetch a tracker issue and mirror it under `.llm/intake/` — pull a Jira (or Linear / ClickUp / Basecamp, when wired) change request, provisioning ticket, or incident, refresh an existing item, or refine a freshly fetched item's body. Trigger on phrases like "fetch JET-1234", "pull this ticket into intake", "import this incident", "refresh JET-9999", "atualizar o intake do JET-X", or any task framed as bringing a tracker item into `.llm/intake/`.
---

# `llm intake <KEY>` — mirror a tracker issue under `.llm/intake/`

Fetches an issue from a tracker and creates or refreshes its mirror under `.llm/intake/<KEY>/index.md`. In this flavor intake holds the **change requests / provisioning tickets / incidents** that drive infrastructure work. **Tracker-agnostic by design**; only the Jira adapter is wired today (ClickUp / Linear / Basecamp are TODO in `src/cmd_intake.sh`).

## Layout (v3 flat)

Every item lives at `.llm/intake/<KEY>/index.md` regardless of type. `type:` discriminates (`change`, `incident`, `task`, `bug`, …). The pillar's `intake/index.md` declares the tracker(s) via `tracker:` (a LIST, typically `[jira]`).

## Required env (Jira adapter)

Auto-loaded from `.env` at the project root if present: `ATLASSIAN_DOMAIN`, `ATLASSIAN_EMAIL`, `ATLASSIAN_API_TOKEN`. System deps: `curl`, `jq`.

## Behavior

```bash
llm intake JET-1234       # first run OR re-sync — same command
```

**First run.** Creates `intake/<KEY>/index.md` from the type body template (`intake-*.md` under `.llm/templates/`), fills frontmatter (`key`, `tracker: jira`, `type`, `status`, `synced-at`, `apps: []`, `relates: [...]`), then appends a `<!-- BEGIN RAW (tracker: jira) … END RAW -->` block with the unedited description + refinement instructions.

**Re-sync** (file exists). Refreshes `status:` + `synced-at:`. If the RAW block is present, its description is updated; if removed (already refined), the body is preserved. Missing `tracker:` is added.

## Your job after `llm intake` runs

1. Refine `## Overview` — restate the requested change/incident, in English, 1-3 paragraphs.
2. Refine `## Acceptance Criteria (EARS)` — `WHEN <trigger> THE SYSTEM SHALL <response>` (e.g. *WHEN the change is applied to prod THE SYSTEM SHALL serve traffic with zero 5xx during cutover*).
3. If `type: incident` / `bug`, fill `## Reproduction`, `## Expected`, `## Actual` (or `## Impact`/`## Timeline` for an incident).
4. Set `apps: [...]` — the **environments** the request concerns (keys from `schema.yaml > meta.apps.values`: `dev`/`staging`/`prod`/`all`).
5. Verify `relates: [...]`.
6. **Delete the entire BEGIN/END RAW block** when done — its presence is `llm doctor`'s signal the item is still raw.

`status:`/`synced-at:` are CLI-managed — don't edit by hand.

## Per-item provenance (multi-tracker projects)

Each item's `tracker: jira` (scalar) records its source; the pillar's `tracker: [jira, …]` (list) declares the allowed set. Doctor verifies the per-item `tracker:` is present.

## Future adapters (TODO in `cmd_intake.sh`)

ClickUp / Linear / Basecamp: detect the tracker value, route the fetch, emit the same v3 frontmatter shape, reuse `_intake_append_raw_block`. Until then only Jira works; add others manually.

## Patterns

| User says | You do |
|---|---|
| "Fetch JET-1234 into intake" / "pull JET-X" | `llm intake JET-1234` → read the file → walk the RAW instructions → delete the RAW block |
| "Refresh the intake for JET-X" | Same command. Re-sync updates `status:` + `synced-at:` |
| "What does intake look like for X?" | Read `.llm/intake/<X>/index.md`; if absent, run `llm intake <X>` |
