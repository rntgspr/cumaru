# `cumaru intake`

Fetch a tracker issue and mirror it under `.cumaru/intake/`. **Tracker-agnostic by design** — wired adapters: **Jira, Linear, ClickUp** (Basecamp planned; TODO header in `src/cmd_intake.sh`).

## Layout

In `sdlc-full`, every item lives at `.cumaru/intake/<KEY>.md` regardless of type. The `type:` field discriminates (`epic`, `story`, `task`, `bug`, `spike`). IaC and QA retain their directory-item layouts. The pillar's `intake/index.md` declares which tracker(s) the project pulls from via `tracker:` (a list — e.g. `[jira]` or `[jira, linear]`).

## Usage

```
cumaru intake <KEY> [--tracker <name>]
```

## Tracker resolution (first match wins)

1. The item's own `tracker:` frontmatter — re-sync of an existing item always goes back to its source.
2. `--tracker <name>` — for first-creates from a non-default tracker.
3. The first entry of the pillar's `tracker:` list.

The resolved tracker must be declared in the pillar's `tracker:` list; `--tracker` conflicting with an existing item's recorded tracker is refused. The `.env` file at the project root is auto-loaded if present.

## Required environment (per adapter)

Set in env or in `.env` at the project root (auto-loaded):

| Adapter | Variables |
|---|---|
| `jira` | `ATLASSIAN_DOMAIN` (subdomain in `<domain>.atlassian.net`), `ATLASSIAN_EMAIL`, `ATLASSIAN_API_TOKEN` ([create](https://id.atlassian.com/manage-profile/security/api-tokens)) |
| `linear` | `LINEAR_API_KEY` ([create](https://linear.app/settings/api)) |
| `clickup` | `CLICKUP_API_TOKEN` (ClickUp → Settings → Apps → API Token) |

External tools: `curl`, `jq`.

## What it does

**First run (file does not exist yet):**
1. Resolves the tracker (see above) and dispatches to its adapter; each adapter normalizes the issue into the same shape (summary, type, status, description, relates).
2. Picks the matching template from `.cumaru/templates/intake-{epic,story,ticket}.md`.
3. Writes the schema-declared intake item path (`intake/<KEY>.md` in `sdlc-full`) with frontmatter:
   - `key`, `tracker` (scalar — which source this item came from), `type`, `status`, `synced-at`, `apps: []`, `relates: [...]`
   - `relates:` is auto-populated from the source (parent epic / parent story / epic link when known) so cross-item links are clear from the start.
4. Sets H1 to the issue summary; body from the template.
5. Appends a `<!-- BEGIN RAW (tracker: <name>) ... END RAW -->` block at the bottom carrying the unedited tracker description plus type-tailored instructions for an LLM to refine the body and then **delete the block**.

**Re-sync (file already exists):**
1. Routes by the item's own `tracker:` — no flag needed.
2. Refreshes only `status:` and `synced-at:` in the frontmatter.
3. Missing `tracker:` is added on re-sync (v2 → v3 migration helper).
4. If a `RAW` block is still present (issue not yet refined), updates its body with the latest tracker description.
5. If the `RAW` block has already been removed (the file has been refined), nothing else changes — the body is preserved.

## Type normalization (per adapter)

| Adapter | Mapping |
|---|---|
| `jira` | Epic → `epic`; Story → `story`; Bug → `bug`; Spike/Research → `spike`; anything else → `task` |
| `linear` | No native issue types — a label named `bug` / `spike` / `research` maps the type; otherwise `task`. Linear epics are projects, not issues. |
| `clickup` | Always `task` (resolving ClickUp custom task types needs an extra API call — not wired). |

## Refinement workflow (LLM job)

After `cumaru intake <KEY>`, open the file and follow the embedded RAW-block instructions:

1. Replace placeholder text under `## Overview` with an English restatement (1-3 paragraphs).
2. Replace placeholder bullets under `## Acceptance Criteria (EARS / RFC 2119)` with EARS or RFC 2119 criteria. Prefer one dominant style per section.
3. (Bug type only) Fill `## Reproduction`, `## Expected`, `## Actual`. Remove the bug-only HTML comment scaffolding when `type` is anything other than `bug`.
4. Set `apps: [...]` from the project's `meta.apps.values` in `.cumaru/schema.yaml`.
5. Verify `relates: [...]` lists parent epic / story / cross-item references correctly.
6. **Delete the entire `BEGIN RAW / END RAW` block** when done. The presence of this block is `cumaru doctor`'s signal that the item is still raw.
7. Set a valid `summary:` on the new item. Do not add a structural row to `intake/index.md`; `cumaru tree intake` discovers the directory.

The `/cumaru:intake <KEY>` slash command walks all of this with user confirmation.

## Per-item provenance (multi-tracker projects)

Each item's `tracker:` (scalar) records its source. A project mixing trackers writes `tracker: [jira, linear]` (list) on the pillar's `intake/index.md` and each item carries its own scalar `tracker:`. `cumaru doctor` validates the per-item field via the schema's required `tracker!` on `intake.entities.item`.

The `relates:` frontmatter is auto-populated from the source tracker — for Jira, the parent epic link (`customfield_10014`), parent story key, and parent story issue type are all checked to build the relates list.

## Examples

```bash
cumaru intake AAA-1234                  # first time — pulls template + RAW block
cumaru intake AAA-1234                  # later — refresh status / synced-at only
cumaru intake ENG-42 --tracker linear   # first create from a non-default tracker
cumaru intake 86c2abc --tracker clickup # ClickUp task id
```

## Related

- [`cumaru tree`](tree.md) — lists the new intake item after its summary is valid.
- [`cumaru doctor`](doctor.md) — validates the new item's navigation contract, frontmatter, and summary.
- `/cumaru:intake` slash command — orchestrates fetch, refinement, and summary curation.
