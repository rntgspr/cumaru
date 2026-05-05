# cmd_intake.sh — fetch a Jira issue and create/refresh its mirror under
# .llm/intake/.
#
# Required environment (or in a .env at the project root, auto-loaded):
#   ATLASSIAN_DOMAIN     e.g. "yourcompany" (subdomain in your atlassian.net URL)
#   ATLASSIAN_EMAIL      account email
#   ATLASSIAN_API_TOKEN  https://id.atlassian.com/manage-profile/security/api-tokens
#
# Mapping by issuetype:
#   Epic   → intake/epics/<KEY>/index.md
#   Story  → intake/stories/<KEY>/index.md
#   else   → intake/tickets/<KEY>/index.md
#
# Expects from the entry-point: SCRIPT_DIR, DOT_LLM_DIR.

cmd_intake_help() {
  cat <<'EOF'
llm intake — fetch a Jira issue and mirror it under .llm/intake/

Usage:
  llm intake <JIRA-KEY>

Required env (or in .env at project root, auto-loaded):
  ATLASSIAN_DOMAIN     subdomain in your atlassian.net URL (e.g. "acme")
  ATLASSIAN_EMAIL      account email
  ATLASSIAN_API_TOKEN  https://id.atlassian.com/manage-profile/security/api-tokens

Behavior:
  - First run: creates intake/<epics|stories|tickets>/<KEY>/index.md from the
    matching template, fills frontmatter (jira, type, epic, story, status,
    synced-at), sets H1 to the Jira summary, and appends a JIRA-RAW block
    at the bottom of the file. The block carries the unedited Jira source
    plus explicit instructions for an LLM to refine the body sections and
    then delete the block.
  - Re-sync: refreshes only status: and synced-at: in the frontmatter. If a
    JIRA-RAW block is still present (issue not yet refined), its body is
    updated with the latest description. If the block has already been
    removed (LLM has refined the file), nothing else is changed — the body
    is preserved.

Dependencies: curl, jq.

Examples:
  llm intake JET-1234        first run — pulls template + JIRA-RAW block
  llm intake JET-1234        later — refresh status/synced-at only
EOF
}

cmd_intake() {
  local jira_id="${1:-}"
  case "$jira_id" in
    ""|help|-h|--help) cmd_intake_help; [[ -z "$jira_id" ]] && return 2 || return 0 ;;
  esac

  # 1) Auto-load .env if present at project root
  if [[ -f ".env" ]]; then
    set -a; . ./.env; set +a
  fi

  for var in ATLASSIAN_DOMAIN ATLASSIAN_EMAIL ATLASSIAN_API_TOKEN; do
    if [[ -z "${!var:-}" ]]; then
      red "✗ missing $var (set in env or in .env at project root)"
      return 1
    fi
  done

  command -v curl >/dev/null || { red "✗ curl not found"; return 1; }
  command -v jq   >/dev/null || { red "✗ jq not found — brew install jq"; return 1; }

  if [[ ! -d "$DOT_LLM_DIR" ]]; then
    red "✗ $DOT_LLM_DIR not found — run 'llm install' first"
    return 1
  fi

  # 2) Fetch from Jira (API v2 returns description as plain string)
  local url="https://${ATLASSIAN_DOMAIN}.atlassian.net/rest/api/2/issue/${jira_id}"
  local resp http_code tmp
  tmp=$(mktemp)
  http_code=$(curl -sS -o "$tmp" -w "%{http_code}" \
    -u "${ATLASSIAN_EMAIL}:${ATLASSIAN_API_TOKEN}" \
    -H 'Accept: application/json' "$url" || echo "000")

  if [[ "$http_code" != "200" ]]; then
    red "✗ Jira fetch failed (HTTP $http_code) for $jira_id"
    [[ -s "$tmp" ]] && red "  $(head -c 300 "$tmp")"
    rm -f "$tmp"
    return 1
  fi
  resp=$(cat "$tmp"); rm -f "$tmp"

  local summary issuetype status epic_link parent_key parent_type description
  summary=$(echo "$resp"      | jq -r '.fields.summary // ""')
  issuetype=$(echo "$resp"    | jq -r '.fields.issuetype.name // ""')
  status=$(echo "$resp"       | jq -r '.fields.status.name // ""')
  epic_link=$(echo "$resp"    | jq -r '.fields.customfield_10014 // ""')
  parent_key=$(echo "$resp"   | jq -r '.fields.parent.key // ""')
  parent_type=$(echo "$resp"  | jq -r '.fields.parent.fields.issuetype.name // ""')
  description=$(echo "$resp"  | jq -r '.fields.description // ""')

  # 3) Determine path + relationships
  local subdir tmpl_name epic="" story="" jtype=""
  case "$issuetype" in
    Epic)
      subdir="epics"; tmpl_name="intake-epic.md"; jtype="epic"
      ;;
    Story)
      subdir="stories"; tmpl_name="intake-story.md"; jtype="story"
      epic="$epic_link"; [[ -z "$epic" && "$parent_type" == "Epic" ]] && epic="$parent_key"
      ;;
    *)
      subdir="tickets"; tmpl_name="intake-ticket.md"
      case "$issuetype" in
        Bug) jtype="bug" ;;
        Spike|Research) jtype="spike" ;;
        *) jtype="task" ;;
      esac
      epic="$epic_link"; [[ -z "$epic" && "$parent_type" == "Epic" ]] && epic="$parent_key"
      [[ "$parent_type" == "Story" ]] && story="$parent_key"
      ;;
  esac

  local synced_at
  synced_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  local target_dir="${DOT_LLM_DIR}/intake/${subdir}/${jira_id}"
  local target_file="${target_dir}/index.md"

  # 4) Re-sync vs first-time
  local existed=0
  if [[ -f "$target_file" ]]; then
    existed=1
    # Refresh status: and synced-at: in frontmatter; preserve everything else.
    awk -v new_status="$status" -v new_synced="$synced_at" '
      BEGIN { fm_count=0; in_fm=0 }
      /^---$/ { fm_count++; in_fm=(fm_count==1); print; next }
      in_fm && /^status:[[:space:]]/ { print "status: " new_status; next }
      in_fm && /^synced-at:[[:space:]]/ { print "synced-at: " new_synced; next }
      { print }
    ' "$target_file" > "$target_file.tmp" && mv "$target_file.tmp" "$target_file"

    # If a JIRA-RAW block is still present, the issue hasn't been refined yet —
    # update its body with the latest description. If it's been removed (LLM
    # already processed it), don't re-inject; that would undo the refinement.
    if grep -q "BEGIN JIRA-RAW" "$target_file"; then
      awk '
        /<!-- BEGIN JIRA-RAW/ { skip=1; next }
        /END JIRA-RAW -->/    { skip=0; next }
        !skip { print }
      ' "$target_file" > "$target_file.tmp" && mv "$target_file.tmp" "$target_file"
      _intake_append_raw_block "$target_file" "$summary" "$issuetype" "$status" "$description"
    fi
  else
    # First-time creation from template
    local src_template="${SCRIPT_DIR}/dot-llm-framework/templates/${tmpl_name}"
    if [[ ! -f "$src_template" ]]; then
      red "✗ template not found: $src_template"
      return 1
    fi
    mkdir -p "$target_dir"

    {
      echo "---"
      echo "generated: false"
      echo "jira: $jira_id"
      [[ -n "$jtype" ]] && echo "type: $jtype"
      [[ -n "$epic"  ]] && echo "epic: $epic"
      [[ -n "$story" ]] && echo "story: $story"
      echo "status: $status"
      echo "synced-at: $synced_at"
      echo "apps: []"
      echo "---"
      echo ""
      echo "# $summary"
      echo ""
      # Body of the template (skip its frontmatter and original H1)
      awk '
        BEGIN { fm_count=0; past_h1=0 }
        /^---$/ { fm_count++; next }
        fm_count < 2 { next }
        /^# / && !past_h1 { past_h1=1; next }
        past_h1 { print }
      ' "$src_template"
    } > "$target_file"

    _intake_append_raw_block "$target_file" "$summary" "$issuetype" "$status" "$description"
  fi

  # 5) Console output: minimal
  if [[ $existed -eq 1 ]]; then
    green "✓ refreshed $target_file"
  else
    green "✓ created $target_file"
  fi
  if grep -q "BEGIN JIRA-RAW" "$target_file"; then
    say "  → JIRA-RAW block at the bottom carries the source description and instructions for the LLM to refine."
  fi
}

# Append (or replace) a JIRA-RAW block at the end of $1, with explicit
# instructions for an LLM to refine the file and then delete the block.
# Instructions are tailored to the issuetype:
#   Epic   → only ## Overview (no AC)
#   Story  → ## Overview + ## Acceptance Criteria (EARS)
#   Ticket → ## Overview + ## Acceptance Criteria (EARS); plus the four bug
#            sections (## Reproduction, ## Expected, ## Actual, ## Root cause)
#            when the frontmatter type is bug.
_intake_append_raw_block() {
  local file="$1" title="$2" itype="$3" istatus="$4" desc="$5"

  local steps=""
  case "$itype" in
    Epic)
      steps="  1. Replace the placeholder text under \`## Overview\` with an English
     restatement (1-3 paragraphs) of the epic-level vision.
  2. Set \`apps: [...]\` in the frontmatter to the affected component(s),
     using keys from the project's schema.yaml apps.values.
  3. Delete this entire BEGIN JIRA-RAW / END JIRA-RAW block when done."
      ;;
    Story)
      steps="  1. Replace the placeholder text under \`## Overview\` with an English
     restatement (1-3 paragraphs) of the story-level objective.
  2. Replace the placeholder bullets under \`## Acceptance Criteria (EARS)\`
     with story-level criteria in the form
     \`WHEN <trigger> THE SYSTEM SHALL <response>\`.
  3. Set \`apps: [...]\` in the frontmatter to the affected component(s),
     using keys from the project's schema.yaml apps.values.
  4. Delete this entire BEGIN JIRA-RAW / END JIRA-RAW block when done."
      ;;
    *)
      steps="  1. Replace the placeholder text under \`## Overview\` with an English
     restatement (1-3 paragraphs, what is asked and why it matters).
  2. Replace the placeholder bullets under \`## Acceptance Criteria (EARS)\`
     with criteria in the form \`WHEN <trigger> THE SYSTEM SHALL <response>\`.
  3. If \`type: bug\` in the frontmatter, also fill \`## Reproduction\`,
     \`## Expected\`, and \`## Actual\` from the description below.
  4. Set \`apps: [...]\` in the frontmatter to the affected component(s),
     using keys from the project's schema.yaml apps.values.
  5. Delete this entire BEGIN JIRA-RAW / END JIRA-RAW block when done."
      ;;
  esac

  cat >> "$file" <<EOF

<!-- BEGIN JIRA-RAW
INSTRUCTION FOR LLM:
This is the unedited Jira source. Use it to refine the file above:
${steps}
The frontmatter \`status:\` and \`synced-at:\` are managed by \`llm intake\`
and will be refreshed on each re-sync. Body content above is yours to edit.

JIRA SOURCE:
  Title:  ${title}
  Type:   ${itype}
  Status: ${istatus}

  Description:
${desc}

END JIRA-RAW -->
EOF
}
