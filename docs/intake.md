# `llm intake`

Fetch a Jira issue and mirror it under `.llm/intake/`. Issues map by type:

| Jira type | Path |
|---|---|
| Epic | `intake/epics/<KEY>/index.md` |
| Story | `intake/stories/<KEY>/index.md` |
| anything else | `intake/tickets/<KEY>/index.md` |

## Usage

```
llm intake <JIRA-KEY>
```

## Required environment

Set in env or in `.env` at the project root (auto-loaded):

| Variable | Description |
|---|---|
| `ATLASSIAN_DOMAIN` | subdomain in your `<domain>.atlassian.net` URL (e.g. `acme`) |
| `ATLASSIAN_EMAIL` | account email |
| `ATLASSIAN_API_TOKEN` | https://id.atlassian.com/manage-profile/security/api-tokens |

External tools: `curl`, `jq`.

## What it does

**First run (file does not exist yet):**
1. Hits Jira REST API v2 to fetch the issue.
2. Picks the matching template from `dot-llm-framework/templates/intake-{epic,story,ticket}.md`.
3. Writes `intake/<type>/<KEY>/index.md` with frontmatter (`jira`, `type`, `epic`, `story`, `status`, `synced-at`, `apps: []`), H1 set to the Jira summary, body from the template.
4. Appends a `<!-- BEGIN JIRA-RAW ... END JIRA-RAW -->` block at the bottom carrying the unedited Jira description plus issuetype-tailored instructions for an LLM to refine the body sections and then **delete the block**.

**Re-sync (file already exists):**
1. Refreshes only `status:` and `synced-at:` in the frontmatter.
2. If a `JIRA-RAW` block is still present (issue not yet refined), updates its body with the latest Jira description.
3. If the `JIRA-RAW` block has already been removed (LLM has refined the file), nothing else changes — the body is preserved.

## Refinement workflow (LLM job)

After `llm intake <KEY>`, the file carries the raw Jira source plus instructions. The LLM should:

1. Replace placeholder text under `## Overview` with an English restatement.
2. Replace placeholder bullets under `## Acceptance Criteria (EARS)` with `WHEN ... THE SYSTEM SHALL ...` criteria.
3. (Bug type only) Fill `## Reproduction`, `## Expected`, `## Actual`.
4. Set `apps: [...]` from the project's `schema.yaml apps.values`.
5. **Delete the entire `BEGIN JIRA-RAW / END JIRA-RAW` block** when done.

## Examples

```bash
llm intake JET-1234        # first time — pulls template + JIRA-RAW
llm intake JET-1234        # later — refresh status/synced-at only
```

## Related

- [`llm regen <JIRA-KEY>`](regen.md) — chain-check intake → plan → archive → specs for a ticket.
