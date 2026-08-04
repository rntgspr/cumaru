---
human_revised: false
version: 1
name: cumaru-release
description: Use this skill whenever the user wants to prepare a release in the full SDLC domain — bump version, update changelog, tag, and produce a release report anchored to the current plan.
summary: Use this skill whenever the user wants to prepare a release in the full SDLC domain — bump version, update changelog, tag, and produce a release report anchored to the current plan.
---

# cumaru-release — narrate a GitLab version diff into a consistent release report

Turns "what's in version X" into a prose report with a fixed structure. A deterministic fetch
(the bundled script) + a fixed template give consistent output every time; the LLM only writes
the prose. This is NOT a discipline (it has runtime/I-O) and NOT a pillar — the report is a
standalone artifact.

## Inputs — two heads

You need FROM (previous version) and TO (current version) — tags, SHAs, or branches.
- If the user gave both, use them.
- If not, ask: "Quais os dois pontos da comparação — versão anterior (FROM) e atual (TO)?"
  List recent local tags with `git tag --sort=-v:refname | head -20` and
  branches with `git branch -a --sort=-committerdate | head -20`.
- A bare version such as `1.4` may not be a literal ref. Never guess it.
- If candidates exist only remotely, use `glab` or the GitLab API to list them.
- State the resolved range and project explicitly, then wait for confirmation:
  `Comparing FROM=<x> -> TO=<y> in project <GITLAB_PROJECT>.`

## Environment (or `.env` at the project root, auto-loaded)

- `GITLAB_TOKEN` — token with `read_api` on the project (required).
- `GITLAB_PROJECT` — numeric id or url-encoded path, e.g. `group%2Frepo` (required).
- `GITLAB_HOST` — for self-hosted instances; defaults to `gitlab.com`.

External tools: `curl`, `jq`.

If `GITLAB_PROJECT` or `GITLAB_TOKEN` is unavailable, ask for it before running
the fetch. Never fail silently or infer a project.

## Recipe

1. **Resolve FROM/TO** (see Inputs).
2. **Fetch the raw range** — run, from this skill's directory:
   ```bash
   bash scripts/gitlab-compare.sh "<FROM>" "<TO>"
   ```
   It prints commits, authors, changed files, referenced tracker keys, and a
   Range footer as Markdown. If it errors, surface the message verbatim — never
   fabricate a report.
3. **Fill the template** — open `templates/release-report.md` (under `.cumaru/templates/`) and write
   every section IN ORDER:
   - Narrate, don't paste: turn commit titles into user-facing prose; group by area using the
     project's `meta.apps.values` when they map.
   - **Breaking changes**: scan the range for API/behaviour breaks; if none, write `None`.
   - Fold trivial churn (typos, formatting, version bumps) into a single line.
   - Fill the `Range` block from the script's footer (the two refs + commit/file counts).
4. **Save** as `release-<TO>.md` at the project root, unless the user explicitly
   names another project-root path. Never write the report under `.cumaru/`.
5. **Close out** with the saved path and one line reporting commit, file,
   author, and delivered tracker-key counts.

## Rules

- Consistency comes from the template — keep its sections, order, and headings unchanged.
- The diff is the source of truth; the report is its readable narration, not a substitute.
- Empty range → say so; never invent changes that aren't there.
- Resolve and confirm FROM and TO before any fetch.

## Not in scope (yet)

- Merge-request bodies — the compare API returns commits, not MRs. Future enrichment: cross commits
  to MRs, or query MRs merged in the range.
- Quantitative team metrics (LOC, leaderboards, streaks) — deliberately out. This is a release
  narrative, not the cadence dashboard that `gstack`'s `retro` was.
