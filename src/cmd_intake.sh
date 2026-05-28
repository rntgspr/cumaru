# cmd_intake.sh — fetch an issue from a tracker and mirror it under
# .llm/intake/ (flat, v3-shape).
#
# Tracker-agnostic by design (v3): the intake pillar's index.md declares
# `tracker:` as a LIST of trackers the project pulls from, and each item
# records its OWN tracker (scalar) in its frontmatter. Only the Jira adapter
# is wired today.
#
# TODO — additional adapters to wire (in rough order of priority):
#   - ClickUp   (REST API v2; auth via Personal API Token; routing on tracker: clickup)
#   - Linear    (GraphQL API;  auth via API key;             routing on tracker: linear)
#   - Basecamp  (REST API v3;  auth via OAuth/HTTP basic;    routing on tracker: basecamp)
# Each new adapter should:
#   (1) detect the tracker value (from the item's frontmatter on re-sync, or
#       from a CLI flag / env on first create) and route the fetch accordingly;
#   (2) emit the same v3 frontmatter shape (key, type, tracker, status,
#       synced-at, apps, relates) — only the SOURCE differs;
#   (3) reuse `_intake_append_raw_block` for the RAW instruction block.
#
# Required environment (or in a .env at the project root, auto-loaded):
#   ATLASSIAN_DOMAIN     e.g. "yourcompany" (subdomain in your atlassian.net URL)
#   ATLASSIAN_EMAIL      account email
#   ATLASSIAN_API_TOKEN  https://id.atlassian.com/manage-profile/security/api-tokens
#
# Layout (v3 flat):
#   intake/<KEY>/index.md   (no per-issuetype subdirs)
#
# Type mapping (Jira → frontmatter `type:`):
#   Epic        → type: epic
#   Story       → type: story
#   Bug         → type: bug
#   Spike/Res.  → type: spike
#   *           → type: task
#
# Cross-item links go in `relates: [<KEY>, …]` (replaces v2's separate
# `epic:`/`story:` fields). The script populates it from the Jira parent /
# epic link.
#
# Expects from the entry-point: DOT_LLM_DIR. Templates are read from the
# adopter's installed `.llm/templates/` (decoupled from the source checkout —
# whatever flavor was installed provides them).

cmd_intake_help() {
  cat <<'EOF'
llm intake — fetch a tracker issue and mirror it under .llm/intake/

Usage:
  llm intake <KEY>

Required env (or in .env at project root, auto-loaded; only Jira is wired today):
  ATLASSIAN_DOMAIN     subdomain in your atlassian.net URL (e.g. "acme")
  ATLASSIAN_EMAIL      account email
  ATLASSIAN_API_TOKEN  https://id.atlassian.com/manage-profile/security/api-tokens

Layout (v3 flat — no per-issuetype subdirs):
  intake/<KEY>/index.md

Frontmatter:
  key:       the issue id (e.g. JET-1234)
  type:      epic | story | task | bug | spike
  tracker:   jira  (only adapter wired today; v3 supports linear / clickup later)
  status:    upstream status (refreshed on re-sync)
  synced-at: ISO datetime (refreshed on re-sync)
  apps:      []  (you set after refining)
  relates:   list of related <KEY>s — epic link, parent story, etc.

Behavior:
  - First run: creates intake/<KEY>/index.md from the type-specific template
    (intake-{epic,story,ticket}.md), fills frontmatter, sets H1 to summary,
    and appends a RAW block at the bottom with the source description plus
    instructions for the LLM to refine the body and delete the block.
  - Re-sync: refreshes only status, synced-at (and tracker if missing). If a
    RAW block is still present, its body is updated with the latest source.

Dependencies: curl, jq.

Examples:
  llm intake JET-1234        first run — pulls template + RAW block
  llm intake JET-1234        later — refresh status/synced-at only
EOF
}

# Read the first tracker from the intake pillar's index.md (tracker: [jira, ...]).
# Echoes the tracker name (e.g. "jira"); returns 1 if the field is missing.
_intake_read_tracker() {
  local idx="$DOT_LLM_DIR/intake/index.md"
  [[ -f "$idx" ]] || { red "✗ $idx not found — run 'llm install' first"; return 1; }
  local name
  name=$(awk '
    /^---$/ { c++; if (c==2) exit; next }
    c==1 && /^tracker:[[:space:]]*\[/ {
      val=$0
      sub(/^tracker:[[:space:]]*\[/, "", val)
      sub(/,.*$/, "", val)
      sub(/\].*$/, "", val)
      sub(/^[[:space:]]*/, "", val); sub(/[[:space:]]*$/, "", val)
      gsub(/"/, "", val)
      print val; exit
    }
  ' "$idx")
  if [[ -z "$name" ]]; then
    red "✗ tracker: not declared in $idx — add e.g. 'tracker: [jira]' to its frontmatter"
    return 1
  fi
  printf '%s\n' "$name"
}

cmd_intake() {
  local key="${1:-}"
  case "$key" in
    ""|help|-h|--help) cmd_intake_help; [[ -z "$key" ]] && return 2 || return 0 ;;
  esac

  # 1) Auto-load .env if present at project root
  if [[ -f ".env" ]]; then
    set -a; . ./.env; set +a
  fi

  if [[ ! -d "$DOT_LLM_DIR" ]]; then
    red "✗ $DOT_LLM_DIR not found — run 'llm install' first"
    return 1
  fi

  # 2) Resolve tracker from the pillar index; gate on supported adapters.
  local tracker_name
  tracker_name=$(_intake_read_tracker) || return 1
  case "$tracker_name" in
    jira) ;;
    *) red "✗ tracker '$tracker_name' is not yet supported (only 'jira' is wired today)"; return 1 ;;
  esac

  # 3) Jira adapter: validate credentials and tools.
  for var in ATLASSIAN_DOMAIN ATLASSIAN_EMAIL ATLASSIAN_API_TOKEN; do
    if [[ -z "${!var:-}" ]]; then
      red "✗ missing $var (set in env or in .env at project root)"
      return 1
    fi
  done

  command -v curl >/dev/null || { red "✗ curl not found"; return 1; }
  command -v jq   >/dev/null || { red "✗ jq not found — brew install jq"; return 1; }


  # 2) Fetch from Jira (API v2 returns description as plain string)
  local url="https://${ATLASSIAN_DOMAIN}.atlassian.net/rest/api/2/issue/${key}"
  local resp http_code tmp
  tmp=$(mktemp)
  http_code=$(curl -sS -o "$tmp" -w "%{http_code}" \
    -u "${ATLASSIAN_EMAIL}:${ATLASSIAN_API_TOKEN}" \
    -H 'Accept: application/json' "$url" || echo "000")

  if [[ "$http_code" != "200" ]]; then
    red "✗ tracker fetch failed (HTTP $http_code) for $key"
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

  # 3) Determine type + body template + relates
  local tmpl_name jtype="" relates_list=()
  case "$issuetype" in
    Epic)
      jtype="epic"
      tmpl_name="intake-epic.md"
      ;;
    Story)
      jtype="story"
      tmpl_name="intake-story.md"
      [[ -n "$epic_link" ]] && relates_list+=("$epic_link")
      [[ "$parent_type" == "Epic" && -n "$parent_key" ]] && {
        # Avoid duplicate
        local already=0 r
        for r in "${relates_list[@]+"${relates_list[@]}"}"; do [[ "$r" == "$parent_key" ]] && already=1; done
        [[ $already -eq 0 ]] && relates_list+=("$parent_key")
      }
      ;;
    *)
      tmpl_name="intake-ticket.md"
      case "$issuetype" in
        Bug)             jtype="bug" ;;
        Spike|Research)  jtype="spike" ;;
        *)               jtype="task" ;;
      esac
      [[ -n "$epic_link" ]] && relates_list+=("$epic_link")
      [[ "$parent_type" == "Epic" && -n "$parent_key" ]] && {
        local already=0 r
        for r in "${relates_list[@]+"${relates_list[@]}"}"; do [[ "$r" == "$parent_key" ]] && already=1; done
        [[ $already -eq 0 ]] && relates_list+=("$parent_key")
      }
      [[ "$parent_type" == "Story" && -n "$parent_key" ]] && relates_list+=("$parent_key")
      ;;
  esac

  local synced_at
  synced_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # 4) Flat layout (v3): intake/<KEY>/index.md
  local target_dir="${DOT_LLM_DIR}/intake/${key}"
  local target_file="${target_dir}/index.md"

  # Compose relates inline-list form: [A, B] or [] if empty
  local relates_inline="[]"
  if [[ ${#relates_list[@]} -gt 0 ]]; then
    relates_inline="[$(IFS=,; echo "${relates_list[*]}")]"
    # Tidy spacing
    relates_inline="${relates_inline//,/, }"
  fi

  # 5) Re-sync vs first-time
  local existed=0
  if [[ -f "$target_file" ]]; then
    existed=1
    # Refresh status / synced-at; preserve everything else.  If `tracker:` is
    # missing (e.g. an item created before the v3 field), add it.
    awk -v new_status="$status" -v new_synced="$synced_at" -v tracker_name="$tracker_name" '
      BEGIN { fm_count=0; in_fm=0; saw_tracker=0 }
      /^---$/ {
        fm_count++; in_fm=(fm_count==1)
        if (fm_count==2 && saw_tracker==0) print "tracker: " tracker_name
        print; next
      }
      in_fm && /^tracker:[[:space:]]/    { saw_tracker=1; print; next }
      in_fm && /^status:[[:space:]]/     { print "status: " new_status; next }
      in_fm && /^synced-at:[[:space:]]/  { print "synced-at: " new_synced; next }
      { print }
    ' "$target_file" > "$target_file.tmp" && mv "$target_file.tmp" "$target_file"

    # If a raw block is still present, refresh its body.
    if grep -qF "<!-- BEGIN RAW" "$target_file"; then
      awk '
        /<!-- BEGIN.*RAW/ { skip=1; next }
        /END.*RAW -->/    { skip=0; next }
        !skip { print }
      ' "$target_file" > "$target_file.tmp" && mv "$target_file.tmp" "$target_file"
      _intake_append_raw_block "$target_file" "$summary" "$issuetype" "$status" "$description" "$tracker_name"
    fi
  else
    # First-time creation from the type-specific body template.
    local src_template="${DOT_LLM_DIR}/templates/${tmpl_name}"
    if [[ ! -f "$src_template" ]]; then
      red "✗ template not found: $src_template"
      return 1
    fi
    mkdir -p "$target_dir"

    {
      echo "---"
      echo "human_revised: false"
      echo "generated: false"
      echo "key: $key"
      echo "tracker: $tracker_name"
      [[ -n "$jtype" ]] && echo "type: $jtype"
      echo "status: $status"
      echo "synced-at: $synced_at"
      echo "apps: []"
      echo "relates: $relates_inline"
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

    _intake_append_raw_block "$target_file" "$summary" "$issuetype" "$status" "$description" "$tracker_name"
  fi

  # 6) Console output: minimal
  if [[ $existed -eq 1 ]]; then
    green "✓ refreshed $target_file"
  else
    green "✓ created $target_file"
  fi
  if grep -qF "<!-- BEGIN RAW" "$target_file"; then
    say "  → RAW block at the bottom carries the source description and instructions for the LLM to refine."
  fi
}

# Append (or replace) a RAW block at the end of $1, with explicit instructions
# for an LLM to refine the file and then delete the block. Instructions are
# tailored to the issuetype.
_intake_append_raw_block() {
  local file="$1" title="$2" itype="$3" istatus="$4" desc="$5" tracker_name="${6:-jira}"

  local steps=""
  case "$itype" in
    Epic)
      steps="  1. Replace the placeholder text under \`## Overview\` with an English
     restatement (1-3 paragraphs) of the epic-level vision.
  2. Set \`apps: [...]\` in the frontmatter to the affected component(s),
     using keys from the project's schema.yaml meta.apps.values.
  3. If you know related items (parent epics, child stories), populate
     \`relates: [...]\` in the frontmatter.
  4. Delete this entire BEGIN/END RAW block when done."
      ;;
    Story)
      steps="  1. Replace the placeholder text under \`## Overview\` with an English
     restatement (1-3 paragraphs) of the story-level objective.
  2. Replace the placeholder bullets under \`## Acceptance Criteria (EARS)\`
     with story-level criteria in the form
     \`WHEN <trigger> THE SYSTEM SHALL <response>\`.
  3. Set \`apps: [...]\` in the frontmatter to the affected component(s),
     using keys from the project's schema.yaml meta.apps.values.
  4. Verify \`relates: [...]\` contains the parent epic and any related items.
  5. Delete this entire BEGIN/END RAW block when done."
      ;;
    *)
      steps="  1. Replace the placeholder text under \`## Overview\` with an English
     restatement (1-3 paragraphs, what is asked and why it matters).
  2. Replace the placeholder bullets under \`## Acceptance Criteria (EARS)\`
     with criteria in the form \`WHEN <trigger> THE SYSTEM SHALL <response>\`.
  3. If \`type: bug\` in the frontmatter, also fill \`## Reproduction\`,
     \`## Expected\`, and \`## Actual\` from the description below.
  4. Set \`apps: [...]\` in the frontmatter to the affected component(s),
     using keys from the project's schema.yaml meta.apps.values.
  5. Verify \`relates: [...]\` lists the parent epic / story / related items.
  6. Delete this entire BEGIN/END RAW block when done."
      ;;
  esac

  # Use printf instead of an unquoted heredoc so that content coming from the
  # tracker (title, description) is never subject to shell expansion — a Jira
  # description containing `${VAR}` or backtick sequences would be expanded
  # unexpectedly in an unquoted <<EOF heredoc.
  {
    printf '\n<!-- BEGIN RAW (tracker: %s)\n' "$tracker_name"
    printf 'INSTRUCTION FOR LLM:\n'
    printf 'This is the unedited tracker source. Use it to refine the file above:\n'
    printf '%s\n' "$steps"
    printf 'The frontmatter `status:` and `synced-at:` are managed by `llm intake`\n'
    printf 'and will be refreshed on each re-sync. Body content above is yours to edit.\n'
    printf '\nTRACKER SOURCE:\n'
    printf '  Title:  %s\n' "$title"
    printf '  Type:   %s\n' "$itype"
    printf '  Status: %s\n' "$istatus"
    printf '\n  Description:\n'
    printf '%s\n' "$desc"
    printf '\nEND RAW -->\n'
  } >> "$file"
}
