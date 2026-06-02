# cmd_intake.sh — fetch an issue from a tracker and mirror it under
# .cumaru/intake/ (flat, v3-shape).
#
# Tracker-agnostic (v3): the intake pillar's index.md declares `tracker:` as a
# LIST of trackers the project pulls from, and each item records its OWN
# tracker (scalar) in its frontmatter. Wired adapters: jira, linear, clickup.
#
# Adapter contract — each `_intake_fetch_<tracker> <KEY>` must:
#   (1) validate its own env + required tools, then fetch the issue;
#   (2) set the normalized globals:
#         INTAKE_SUMMARY    issue title
#         INTAKE_TYPE       epic | story | task | bug | spike
#         INTAKE_TYPE_RAW   the tracker's native type label (RAW block header)
#         INTAKE_STATUS     upstream status
#         INTAKE_DESC       unedited description (markdown/plain)
#         INTAKE_RELATES    array of related <KEY>s (parent epic/story, …)
#   (3) return non-zero with a red message (to stderr) on failure.
# The generic flow (template pick, file write, re-sync, RAW block) is shared.
#
# TODO — remaining adapter to wire:
#   - Basecamp  (REST API v3; auth via OAuth — heavier than a static token)
#
# Required environment per adapter (or in a .env at the project root, auto-loaded):
#   jira      ATLASSIAN_DOMAIN, ATLASSIAN_EMAIL, ATLASSIAN_API_TOKEN
#   linear    LINEAR_API_KEY      (https://linear.app/settings/api)
#   clickup   CLICKUP_API_TOKEN   (ClickUp → Settings → Apps → API Token)
#
# Layout (v3 flat):
#   intake/<KEY>/index.md   (no per-issuetype subdirs)
#
# Type normalization:
#   jira     Epic → epic; Story → story; Bug → bug; Spike/Research → spike; * → task
#   linear   no native issue types — a label named bug / spike / research maps
#            the type; everything else → task (Linear epics are projects, not issues)
#   clickup  custom task types need an extra API call to resolve → always task
#
# Cross-item links go in `relates: [<KEY>, …]`, populated from the source's
# parent / epic link when known.
#
# Expects from the entry-point: CUMARU_DIR. Templates are read from the
# adopter's installed `.cumaru/templates/` (decoupled from the source checkout —
# whatever domain was installed provides them).

cmd_intake_help() {
  cat <<'EOF'
cumaru intake — fetch a tracker issue and mirror it under .cumaru/intake/

Usage:
  cumaru intake <KEY> [--tracker <name>]

Wired adapters and their required env (or in .env at project root, auto-loaded):
  jira      ATLASSIAN_DOMAIN     subdomain in your atlassian.net URL (e.g. "acme")
            ATLASSIAN_EMAIL      account email
            ATLASSIAN_API_TOKEN  https://id.atlassian.com/manage-profile/security/api-tokens
  linear    LINEAR_API_KEY       https://linear.app/settings/api
  clickup   CLICKUP_API_TOKEN    ClickUp → Settings → Apps → API Token

Tracker resolution (first match wins):
  1. the item's own `tracker:` frontmatter (re-sync of an existing item)
  2. --tracker <name>
  3. the first entry of intake/index.md `tracker:` list
The resolved tracker must be declared in intake/index.md `tracker:` list.

Layout (v3 flat — no per-issuetype subdirs):
  intake/<KEY>/index.md

Frontmatter:
  key:       the issue id (e.g. AAA-1234, ABC-42, 86c2abc)
  type:      epic | story | task | bug | spike
  tracker:   jira | linear | clickup (which source this item came from)
  status:    upstream status (refreshed on re-sync)
  synced-at: ISO datetime (refreshed on re-sync)
  apps:      []  (you set after refining)
  relates:   list of related <KEY>s — epic link, parent story/task, etc.

Behavior:
  - First run: creates intake/<KEY>/index.md from the type-specific template
    (intake-{epic,story,ticket}.md), fills frontmatter, sets H1 to summary,
    and appends a RAW block at the bottom with the source description plus
    instructions for the LLM to refine the body and delete the block.
  - Re-sync: refreshes only status, synced-at (and tracker if missing). If a
    RAW block is still present, its body is updated with the latest source.

Type normalization:
  jira     Epic → epic; Story → story; Bug → bug; Spike/Research → spike; * → task
  linear   label bug/spike/research → bug/spike; otherwise task
  clickup  always task (custom task types need an extra API call — not wired)

Dependencies: curl, jq.

Examples:
  cumaru intake AAA-1234                  first run — pulls template + RAW block
  cumaru intake AAA-1234                  later — refresh status/synced-at only
  cumaru intake ABC-42 --tracker linear   first create from a non-default tracker
EOF
}

# ── shared validation helpers ───────────────────────────────────────────────

# Fail (with a hint) if any of the named env vars is empty.
_intake_require_env() {
  local var
  for var in "$@"; do
    if [[ -z "${!var:-}" ]]; then
      red "✗ missing $var (set in env or in .env at project root)" >&2
      return 1
    fi
  done
}

# Fail if curl or jq is missing.
_intake_require_tools() {
  command -v curl >/dev/null || { red "✗ curl not found" >&2; return 1; }
  command -v jq   >/dev/null || { red "✗ jq not found — brew install jq" >&2; return 1; }
}

# Append $1 to INTAKE_RELATES unless empty or already present.
_intake_relates_add() {
  local k="$1" r
  [[ -n "$k" ]] || return 0
  for r in "${INTAKE_RELATES[@]+"${INTAKE_RELATES[@]}"}"; do
    [[ "$r" == "$k" ]] && return 0
  done
  INTAKE_RELATES+=("$k")
}

# Read every tracker declared on the intake pillar's index.md
# (tracker: [jira, linear, ...]) — one per line. Errors go to stderr so the
# caller's command substitution stays clean.
_intake_read_trackers() {
  local idx="$CUMARU_DIR/intake/index.md"
  [[ -f "$idx" ]] || { red "✗ $idx not found — run 'cumaru install' first" >&2; return 1; }
  local names
  names=$(awk '
    /^---$/ { c++; if (c==2) exit; next }
    c==1 && /^tracker:[[:space:]]*\[/ {
      val=$0
      sub(/^tracker:[[:space:]]*\[/, "", val)
      sub(/\].*$/, "", val)
      gsub(/[" ]/, "", val)
      n=split(val, a, ",")
      for (i=1; i<=n; i++) if (a[i] != "") print a[i]
      exit
    }
  ' "$idx")
  if [[ -z "$names" ]]; then
    red "✗ tracker: not declared in $idx — add e.g. 'tracker: [jira]' to its frontmatter" >&2
    return 1
  fi
  printf '%s\n' "$names"
}

# ── adapters ────────────────────────────────────────────────────────────────

# Jira — REST API v2 (description comes back as a plain string).
_intake_fetch_jira() {
  local key="$1"
  _intake_require_env ATLASSIAN_DOMAIN ATLASSIAN_EMAIL ATLASSIAN_API_TOKEN || return 1
  _intake_require_tools || return 1

  local url="https://${ATLASSIAN_DOMAIN}.atlassian.net/rest/api/2/issue/${key}"
  local resp http_code tmp
  tmp=$(mktemp)
  http_code=$(curl -sS -o "$tmp" -w "%{http_code}" \
    -u "${ATLASSIAN_EMAIL}:${ATLASSIAN_API_TOKEN}" \
    -H 'Accept: application/json' "$url" || echo "000")

  if [[ "$http_code" != "200" ]]; then
    red "✗ jira fetch failed (HTTP $http_code) for $key" >&2
    [[ -s "$tmp" ]] && red "  $(head -c 300 "$tmp")" >&2
    rm -f "$tmp"
    return 1
  fi
  resp=$(cat "$tmp"); rm -f "$tmp"

  local issuetype epic_link parent_key parent_type
  INTAKE_SUMMARY=$(jq -r '.fields.summary // ""'                      <<<"$resp")
  issuetype=$(jq -r '.fields.issuetype.name // ""'                    <<<"$resp")
  INTAKE_STATUS=$(jq -r '.fields.status.name // ""'                   <<<"$resp")
  INTAKE_DESC=$(jq -r '.fields.description // ""'                     <<<"$resp")
  epic_link=$(jq -r '.fields.customfield_10014 // ""'                 <<<"$resp")
  parent_key=$(jq -r '.fields.parent.key // ""'                       <<<"$resp")
  parent_type=$(jq -r '.fields.parent.fields.issuetype.name // ""'    <<<"$resp")

  INTAKE_TYPE_RAW="$issuetype"
  case "$issuetype" in
    Epic)            INTAKE_TYPE="epic" ;;
    Story)           INTAKE_TYPE="story" ;;
    Bug)             INTAKE_TYPE="bug" ;;
    Spike|Research)  INTAKE_TYPE="spike" ;;
    *)               INTAKE_TYPE="task" ;;
  esac

  INTAKE_RELATES=()
  [[ "$INTAKE_TYPE" != "epic" ]] && _intake_relates_add "$epic_link"
  if [[ "$parent_type" == "Epic" || "$parent_type" == "Story" ]]; then
    _intake_relates_add "$parent_key"
  fi
}

# Linear — GraphQL API; auth is the bare API key in the Authorization header.
# GraphQL reports errors in-band with HTTP 200, so check `.errors` too.
_intake_fetch_linear() {
  local key="$1"
  _intake_require_env LINEAR_API_KEY || return 1
  _intake_require_tools || return 1

  local gql='query($id: String!) { issue(id: $id) { title description state { name } parent { identifier } labels { nodes { name } } } }'
  local body resp http_code tmp
  body=$(jq -n --arg q "$gql" --arg id "$key" '{query: $q, variables: {id: $id}}')
  tmp=$(mktemp)
  http_code=$(curl -sS -o "$tmp" -w "%{http_code}" -X POST \
    -H "Authorization: ${LINEAR_API_KEY}" \
    -H 'Content-Type: application/json' \
    --data "$body" "https://api.linear.app/graphql" || echo "000")

  if [[ "$http_code" != "200" ]]; then
    red "✗ linear fetch failed (HTTP $http_code) for $key" >&2
    [[ -s "$tmp" ]] && red "  $(head -c 300 "$tmp")" >&2
    rm -f "$tmp"
    return 1
  fi
  resp=$(cat "$tmp"); rm -f "$tmp"

  local gql_err
  gql_err=$(jq -r '.errors[0].message // ""' <<<"$resp")
  if [[ -n "$gql_err" || $(jq -r '.data.issue // ""' <<<"$resp") == "" ]]; then
    red "✗ linear: issue '$key' not found${gql_err:+ — $gql_err}" >&2
    return 1
  fi

  INTAKE_SUMMARY=$(jq -r '.data.issue.title // ""'        <<<"$resp")
  INTAKE_STATUS=$(jq -r '.data.issue.state.name // ""'    <<<"$resp")
  INTAKE_DESC=$(jq -r '.data.issue.description // ""'     <<<"$resp")

  # Linear has no native issue types — map from labels; default task.
  local labels
  labels=$(jq -r '[.data.issue.labels.nodes[].name] | map(ascii_downcase) | join("\n")' <<<"$resp" 2>/dev/null) || labels=""
  INTAKE_TYPE="task"
  grep -qx  "bug"            <<<"$labels" && INTAKE_TYPE="bug"
  grep -qxE "spike|research" <<<"$labels" && INTAKE_TYPE="spike"
  INTAKE_TYPE_RAW="Issue"

  INTAKE_RELATES=()
  _intake_relates_add "$(jq -r '.data.issue.parent.identifier // ""' <<<"$resp")"
}

# ClickUp — REST API v2; auth is the personal token in the Authorization header.
_intake_fetch_clickup() {
  local key="$1"
  _intake_require_env CLICKUP_API_TOKEN || return 1
  _intake_require_tools || return 1

  local url="https://api.clickup.com/api/v2/task/${key}"
  local resp http_code tmp
  tmp=$(mktemp)
  http_code=$(curl -sS -o "$tmp" -w "%{http_code}" \
    -H "Authorization: ${CLICKUP_API_TOKEN}" \
    -H 'Accept: application/json' "$url" || echo "000")

  if [[ "$http_code" != "200" ]]; then
    red "✗ clickup fetch failed (HTTP $http_code) for $key" >&2
    [[ -s "$tmp" ]] && red "  $(head -c 300 "$tmp")" >&2
    rm -f "$tmp"
    return 1
  fi
  resp=$(cat "$tmp"); rm -f "$tmp"

  INTAKE_SUMMARY=$(jq -r '.name // ""'                       <<<"$resp")
  INTAKE_STATUS=$(jq -r '.status.status // ""'               <<<"$resp")
  INTAKE_DESC=$(jq -r '.text_content // .description // ""'  <<<"$resp")

  # Resolving ClickUp custom task types takes a second API call — not wired.
  INTAKE_TYPE="task"
  INTAKE_TYPE_RAW="Task"

  INTAKE_RELATES=()
  _intake_relates_add "$(jq -r '.parent // ""' <<<"$resp")"
}

# ── generic flow ────────────────────────────────────────────────────────────

cmd_intake() {
  local key="" tracker_flag=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      help|-h|--help) cmd_intake_help; return 0 ;;
      --tracker)
        tracker_flag="${2:-}"
        [[ -n "$tracker_flag" ]] || { red "✗ --tracker requires a value"; return 2; }
        shift 2
        ;;
      -*) red "✗ unknown flag: $1"; cmd_intake_help; return 2 ;;
      *)
        if [[ -z "$key" ]]; then key="$1"; else
          red "✗ unexpected extra arg: $1"; cmd_intake_help; return 2
        fi
        shift
        ;;
    esac
  done
  [[ -n "$key" ]] || { cmd_intake_help; return 2; }

  # 1) Auto-load .env if present at project root
  if [[ -f ".env" ]]; then
    set -a; . ./.env; set +a
  fi

  if [[ ! -d "$CUMARU_DIR" ]]; then
    red "✗ $CUMARU_DIR not found — run 'cumaru install' first"
    return 1
  fi

  local target_dir="${CUMARU_DIR}/intake/${key}"
  local target_file="${target_dir}/index.md"

  # 2) Resolve the tracker: item's own frontmatter → --tracker → pillar default.
  local trackers tracker_name=""
  trackers=$(_intake_read_trackers) || return 1
  if [[ -f "$target_file" ]]; then
    tracker_name=$(fm_scalar "$target_file" tracker)
    if [[ -n "$tracker_flag" && -n "$tracker_name" && "$tracker_flag" != "$tracker_name" ]]; then
      red "✗ $key is recorded as tracker '$tracker_name' — refusing --tracker $tracker_flag on an existing item"
      return 1
    fi
  fi
  [[ -z "$tracker_name" ]] && tracker_name="${tracker_flag:-$(head -n1 <<<"$trackers")}"
  if ! grep -qxF "$tracker_name" <<<"$trackers"; then
    red "✗ tracker '$tracker_name' is not declared in intake/index.md — add it to the 'tracker:' list first"
    return 1
  fi

  # 3) Dispatch to the adapter; it fills the INTAKE_* globals.
  case "$tracker_name" in
    jira)    _intake_fetch_jira "$key"    || return 1 ;;
    linear)  _intake_fetch_linear "$key"  || return 1 ;;
    clickup) _intake_fetch_clickup "$key" || return 1 ;;
    *)
      red "✗ tracker '$tracker_name' is not yet supported (wired: jira, linear, clickup)"
      return 1
      ;;
  esac

  # 4) Pick the body template from the normalized type.
  local tmpl_name
  case "$INTAKE_TYPE" in
    epic)  tmpl_name="intake-epic.md" ;;
    story) tmpl_name="intake-story.md" ;;
    *)     tmpl_name="intake-ticket.md" ;;
  esac

  local synced_at
  synced_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Compose relates inline-list form: [A, B] or [] if empty
  local relates_inline="[]"
  if [[ ${#INTAKE_RELATES[@]} -gt 0 ]]; then
    relates_inline="[$(IFS=,; echo "${INTAKE_RELATES[*]}")]"
    relates_inline="${relates_inline//,/, }"
  fi

  # 5) Re-sync vs first-time
  local existed=0
  if [[ -f "$target_file" ]]; then
    existed=1
    # Refresh status / synced-at; preserve everything else.  If `tracker:` is
    # missing (e.g. an item created before the v3 field), add it.
    awk -v new_status="$INTAKE_STATUS" -v new_synced="$synced_at" -v tracker_name="$tracker_name" '
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
      _intake_append_raw_block "$target_file" "$INTAKE_SUMMARY" "$INTAKE_TYPE" "$INTAKE_TYPE_RAW" "$INTAKE_STATUS" "$INTAKE_DESC" "$tracker_name"
    fi
  else
    # First-time creation from the type-specific body template.
    local src_template="${CUMARU_DIR}/templates/${tmpl_name}"
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
      echo "type: $INTAKE_TYPE"
      echo "status: $INTAKE_STATUS"
      echo "synced-at: $synced_at"
      echo "apps: []"
      echo "relates: $relates_inline"
      echo "---"
      echo ""
      echo "# $INTAKE_SUMMARY"
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

    _intake_append_raw_block "$target_file" "$INTAKE_SUMMARY" "$INTAKE_TYPE" "$INTAKE_TYPE_RAW" "$INTAKE_STATUS" "$INTAKE_DESC" "$tracker_name"
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
# tailored to the normalized type; the header shows the tracker's native label.
# Args: file, title, ntype (epic|story|task|bug|spike), rawtype, status, desc, tracker.
_intake_append_raw_block() {
  local file="$1" title="$2" ntype="$3" rawtype="$4" istatus="$5" desc="$6" tracker_name="${7:-jira}"

  local steps=""
  case "$ntype" in
    epic)
      steps="  1. Replace the placeholder text under \`## Overview\` with an English
     restatement (1-3 paragraphs) of the epic-level vision.
  2. Set \`apps: [...]\` in the frontmatter to the affected component(s),
     using keys from the project's schema.yaml meta.apps.values.
  3. If you know related items (parent epics, child stories), populate
     \`relates: [...]\` in the frontmatter.
  4. Delete this entire BEGIN/END RAW block when done."
      ;;
    story)
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
  # tracker (title, description) is never subject to shell expansion — a
  # description containing `${VAR}` or backtick sequences would be expanded
  # unexpectedly in an unquoted <<EOF heredoc.
  {
    printf '\n<!-- BEGIN RAW (tracker: %s)\n' "$tracker_name"
    printf 'INSTRUCTION FOR LLM:\n'
    printf 'This is the unedited tracker source. Use it to refine the file above:\n'
    printf '%s\n' "$steps"
    printf 'The frontmatter `status:` and `synced-at:` are managed by `cumaru intake`\n'
    printf 'and will be refreshed on each re-sync. Body content above is yours to edit.\n'
    printf '\nTRACKER SOURCE:\n'
    printf '  Title:  %s\n' "$title"
    printf '  Type:   %s\n' "$rawtype"
    printf '  Status: %s\n' "$istatus"
    printf '\n  Description:\n'
    printf '%s\n' "$desc"
    printf '\nEND RAW -->\n'
  } >> "$file"
}
