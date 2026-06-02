# `llm intake`

Fetch a tracker issue and mirror it under `.llm/intake/`. **Tracker-agnostic by design** — only the Jira adapter is wired today (ClickUp / Linear / Basecamp planned; TODO header in `src/cmd_intake.sh`).

## Layout (v3 flat — no per-issuetype subdirs)

Every item lives at `.llm/intake/<KEY>/index.md` regardless of type. The `type:` field discriminates (`epic`, `story`, `task`, `bug`, `spike`). The pillar's `intake/index.md` declares which tracker(s) the project pulls from via `tracker:` (a list — typically `[jira]`).

## Usage

```
llm intake <KEY>
```

## Required environment (Jira adapter)

Set in env or in `.env` at the project root (auto-loaded):

| Variable | Description |
|---|---|
| `ATLASSIAN_DOMAIN` | subdomain in your `<domain>.atlassian.net` URL (e.g. `acme`) |
| `ATLASSIAN_EMAIL` | account email |
| `ATLASSIAN_API_TOKEN` | https://id.atlassian.com/manage-profile/security/api-tokens |

External tools: `curl`, `jq`.

## What it does

**First run (file does not exist yet):**
1. Hits the tracker (Jira REST API v2 today) to fetch the issue.
2. Picks the matching template from `.llm/templates/intake-{epic,story,ticket}.md`.
3. Writes `intake/<KEY>/index.md` with frontmatter:
   - `key`, `tracker: jira`, `type` (issuetype), `status`, `synced-at`, `apps: []`, `relates: [...]`
   - `relates:` is auto-populated from the source (parent epic / parent story / epic link when known) so cross-item links are clear from the start.
4. Sets H1 to the issue summary; body from the template.
5. Appends a `<!-- BEGIN RAW (tracker: jira) ... END RAW -->` block at the bottom carrying the unedited tracker description plus issuetype-tailored instructions for an LLM to refine the body and then **delete the block**.

**Re-sync (file already exists):**
1. Refreshes only `status:` and `synced-at:` in the frontmatter.
2. Missing `tracker:` is added on re-sync (v2 → v3 helper).
3. If a `RAW` block is still present (issue not yet refined), updates its body with the latest tracker description.
4. If the `RAW` block has already been removed (the file has been refined), nothing else changes — the body is preserved.

## Refinement workflow (LLM job)

After `llm intake <KEY>`, open the file and follow the embedded RAW-block instructions:

1. Replace placeholder text under `## Overview` with an English restatement (1-3 paragraphs).
2. Replace placeholder bullets under `## Acceptance Criteria (EARS)` with `WHEN ... THE SYSTEM SHALL ...` criteria.
3. (Bug type only) Fill `## Reproduction`, `## Expected`, `## Actual`. Remove the bug-only HTML comment scaffolding when `type` is anything other than `bug`.
4. Set `apps: [...]` from the project's `meta.apps.values` in `.llm/schema.yaml`.
5. Verify `relates: [...]` lists parent epic / story / cross-item references correctly.
6. **Delete the entire `BEGIN RAW / END RAW` block** when done. The presence of this block is `llm doctor`'s signal that the item is still raw.
7. Add a row for the new item in `intake/index.md` via `llm tag set intake/index.md intake <new body>`.

The `/llm:intake <KEY>` slash command walks all of this with user confirmation.

## Per-item provenance (multi-tracker projects)

Each item's `tracker: jira` (scalar) records its source. A project mixing trackers writes `tracker: [jira, linear]` (list) on the pillar's `intake/index.md` and each item carries its own scalar `tracker:`. `llm doctor` validates the per-item field via the schema's required `tracker!` on `intake.entities.item`.

## Examples

```bash
llm intake JET-1234        # first time — pulls template + RAW block
llm intake JET-1234        # later — refresh status / synced-at only
```

## Related

- [`llm tag`](tag.md) — used by the refinement workflow to add the new item's row to `intake/index.md`.
- [`llm doctor`](doctor.md) — orphan check catches a new item that hasn't been added to the table yet.
- `/llm:intake` slash command — orchestrates fetch + refinement + table row.
