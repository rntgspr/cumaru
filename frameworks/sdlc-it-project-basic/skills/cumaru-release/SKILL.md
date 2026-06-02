---
human_revised: false
version: 1
name: cumaru-release
description: Use this skill whenever the user wants to prepare a release of an IT project — bump version, update changelog, tag, and produce a release report anchored to the current plan. Trigger on phrases like "prepare a release", "cut a release", "bump version", "atualizar changelog e tag", or any task that ends a delivery cycle. Skill is sdlc-it-project-basic — knows the full cycle (plan → spec → implement → verify → release → archive). Only skill with exclusive write to CHANGELOG.md. Blocks non-admin roles from running this.
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
  Hint they can list recent tags with `git tag --sort=-v:refname | head`.

## Environment (or `.env` at the project root, auto-loaded)

- `GITLAB_TOKEN` — token with `read_api` on the project (required).
- `GITLAB_PROJECT` — numeric id or url-encoded path, e.g. `group%2Frepo` (required).
- `GITLAB_HOST` — for self-hosted instances; defaults to `gitlab.com`.

External tools: `curl`, `jq`.

## Recipe

1. **Resolve FROM/TO** (see Inputs).
2. **Fetch the raw range** — run, from this skill's directory:
   ```bash
   bash scripts/gitlab-compare.sh "<FROM>" "<TO>"
   ```
   It prints the commit list, authors, and diffstat as markdown. If it errors, surface the
   message verbatim — never fabricate a report.
3. **Fill the template** — open `templates/release-report.md` (under `.cumaru/templates/`) and write
   every section IN ORDER:
   - Narrate, don't paste: turn commit titles into user-facing prose; group by area using the
     project's `meta.apps.values` when they map.
   - **Breaking changes**: scan the range for API/behaviour breaks; if none, write `None`.
   - Fold trivial churn (typos, formatting, version bumps) into a single line.
   - Fill the `Range` block from the script's footer (the two refs + commit/file counts).
4. **Save** as a standalone file — default `release-<TO>.md` at the project root (NOT under
   `.cumaru/`), or a path the user names. It is not a pillar entity; the loading rule won't track it.

## Rules

- Consistency comes from the template — keep its sections, order, and headings unchanged.
- The diff is the source of truth; the report is its readable narration, not a substitute.
- Empty range → say so; never invent changes that aren't there.

## Not in scope (yet)

- Merge-request bodies — the compare API returns commits, not MRs. Future enrichment: cross commits
  to MRs, or query MRs merged in the range.
- Quantitative team metrics (LOC, leaderboards, streaks) — deliberately out. This is a release
  narrative, not the cadence dashboard that `gstack`'s `retro` was.
