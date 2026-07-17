---
version: 1
description: Narrate a release report from the GitLab compare between two refs. FROM = previous version, TO = current. Resolves the two heads (lists tags/branches when ambiguous and confirms), fetches the commit range via the cumaru-release skill, extracts tracker keys delivered, and writes a consistent prose report from templates/release-report.md as a standalone file.
allowed-tools: Bash, Read, Edit, Write
argument-hint: <FROM-ref> <TO-ref>
summary: Narrate a release report from the GitLab compare between two refs. FROM = previous version, TO = current. Resolves the two heads (lists tags/branches when ambiguous and confirms), fetches the commit range via the cumaru-release skill, extracts tracker keys delivered, and writes a consistent prose report from templates/release-report.md as a standalone file.
---

Arguments: `$ARGUMENTS` should be two refs — `$1` = FROM (previous version), `$2` = TO (current). They may be tags, branches, or SHAs.

1. **Resolve the two heads — never compare guessed refs.**
   - If both `$1` and `$2` are present, take them as FROM and TO.
   - If either is missing, or is a bare version (e.g. `1.4`) that may not be a literal ref, DON'T guess. Surface the candidate context and confirm:
     - Tags: `git tag --sort=-v:refname | head -20` (tags are the usual version markers).
     - Branches: `git branch -a --sort=-committerdate | head -20` (for branch-to-branch comparisons, e.g. `release/1.4` vs `release/1.3`).
     - If the tags/branches live only on the remote, list them with `glab` or the GitLab API instead of local `git`.
   - Map the user's "previous" and "current" onto concrete refs and **state them back explicitly**: "Comparando FROM=`<x>` → TO=`<y>` no projeto `<GITLAB_PROJECT>`." Wait for confirmation before fetching.

2. **Confirm the GitLab target.** The fetch reads `GITLAB_PROJECT` (numeric id or url-encoded path), `GITLAB_TOKEN`, and optional `GITLAB_HOST` from env or `.env`. If `GITLAB_PROJECT`/`GITLAB_TOKEN` are unset, ask for them before running — don't fail silently.

3. **Fetch the range.** Run the bundled fetch (path is under `.agents/skills/` once installed):
   `bash cumaru-release/scripts/gitlab-compare.sh "<FROM>" "<TO>"`
   It prints markdown: commits, authors, files changed, **tracker keys referenced**, and a Range footer. If it errors (non-200, missing env, bad refs), surface the message verbatim and stop.

4. **Narrate into the template.** Follow the `cumaru-release` skill recipe: open `templates/release-report.md` and fill every section IN ORDER — narrate (don't paste) commit titles, group changes by area using `.cumaru/schema.yaml` `meta.apps.values` when they map, write `None` explicitly under Breaking changes if there are none, and fill the Range block from the script footer.

5. **Save** the report as `release-<TO>.md` at the project root — a standalone artifact, NOT under `.cumaru/` (it is not a pillar entity).

6. **Close out.** Print the saved path and a one-line summary (commits, files, authors, tracker keys delivered).

Hard rules:
- Resolve and confirm FROM/TO before any fetch — a release report off the wrong range is worse than none.
- The GitLab compare is the source of truth; never invent changes that aren't in the range.
- Empty range → say so and stop; don't emit an empty report.
- The report is avulso — do not write it inside `.cumaru/`, and do not register it as a pillar.
