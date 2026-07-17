#!/usr/bin/env bash
# gitlab-compare.sh <from-ref> <to-ref>
#
# Fetch the GitLab compare between two refs and emit it as raw markdown
# (commit list + authors + diffstat) for the cumaru-release skill to narrate.
#
# Env (or .env at the project root, auto-loaded by the harness):
#   GITLAB_TOKEN    token with read_api on the project (required)
#   GITLAB_PROJECT  numeric id or url-encoded path, e.g. group%2Frepo (required)
#   GITLAB_HOST     host for self-hosted instances (default: gitlab.com)
set -euo pipefail

FROM="${1:?usage: gitlab-compare.sh <from-ref> <to-ref>}"
TO="${2:?usage: gitlab-compare.sh <from-ref> <to-ref>}"
HOST="${GITLAB_HOST:-gitlab.com}"
: "${GITLAB_TOKEN:?set GITLAB_TOKEN (in env or .env at project root)}"
: "${GITLAB_PROJECT:?set GITLAB_PROJECT (numeric id or url-encoded path)}"
command -v curl >/dev/null || { echo "curl not found" >&2; exit 1; }
command -v jq   >/dev/null || { echo "jq not found"   >&2; exit 1; }

tmp=$(mktemp); trap 'rm -f "$tmp"' EXIT
code=$(curl -sS -o "$tmp" -w '%{http_code}' --get \
  "https://${HOST}/api/v4/projects/${GITLAB_PROJECT}/repository/compare" \
  --data-urlencode "from=${FROM}" \
  --data-urlencode "to=${TO}" \
  -H "PRIVATE-TOKEN: ${GITLAB_TOKEN}")

if [[ "$code" != "200" ]]; then
  echo "✗ GitLab compare failed (HTTP $code):" >&2
  jq -r '.message // .error // .' "$tmp" 2>/dev/null >&2 || cat "$tmp" >&2
  exit 1
fi

resp=$(cat "$tmp")
n_commits=$(jq -r '.commits | length' <<<"$resp")
n_files=$(jq -r '.diffs | length' <<<"$resp")

printf '# Compare %s..%s  (project %s)\n\n' "$FROM" "$TO" "$GITLAB_PROJECT"
printf '## Commits (%s)\n' "$n_commits"
jq -r '.commits[] | "- \(.short_id) \(.title)  —  \(.author_name)"' <<<"$resp"
printf '\n## Authors\n'
jq -r '[.commits[].author_name] | unique | .[] | "- \(.)"' <<<"$resp"
printf '\n## Files changed (%s)\n' "$n_files"
jq -r '.diffs[] | "- \(.new_path)\(if .new_file then " (added)" elif .deleted_file then " (deleted)" elif .renamed_file then " (renamed)" else "" end)"' <<<"$resp"
keys=$(jq -r '.commits[].title' <<<"$resp" | grep -oE '[A-Z][A-Z0-9]+-[0-9]+' | sort -u || true)
printf '\n## Tracker keys referenced\n'
if [[ -n "$keys" ]]; then printf '%s\n' "$keys" | sed 's/^/- /'; else echo "- (none found in commit titles)"; fi

printf '\n## Range\n- from: %s\n- to: %s\n- commits: %s\n- files: %s\n' "$FROM" "$TO" "$n_commits" "$n_files"
