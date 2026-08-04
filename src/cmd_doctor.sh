# cmd_doctor.sh — run health checks on a .cumaru/ tree.
#
# `cumaru doctor` validates framework v8 trees. Each check emits one of:
#   [✓] label                     — pass
#   [⚠] label   detail            — soft issue (warning; never fails)
#   [✗] label   detail            — hard issue (error; exit 1 at end)
#
# Pre-v8 trees must migrate before doctor runs; the migration document is
# independent and does not call doctor internally.
#
# Workflow-specific checks (tasks-done-without-handoff, orphan delta-drafts
# after close-out) **moved out of doctor in v4** — workflow integrity is
# LLM-driven; doctor stays mechanical and pillar-agnostic.
#
# Expects from the entry-point: CUMARU_DIR, SCHEMA, QUIET. Reuses fm_*
# helpers from common.sh.

cmd_doctor_help() {
  cat <<'EOF'
cumaru doctor — run health checks on the .cumaru/ tree

Usage:
  cumaru doctor [--quiet]

Options:
  --quiet   suppress [✓] pass lines; warnings, errors, and the summary still print.

Framework version 8 runs nine mechanical checks:
    1. directory indexes and Markdown summaries
    2. balanced tag structure and unknown tag contracts
    3. stale `*.delete-me.md` work markers
    4. unrefined `<!-- BEGIN RAW` blocks
    5. retained project-file references
    6. external tools (curl, git, rg, jq, yq)
    7. discovered Cumaru agent integrations
    8. retired config field visibility
    9. configuration drift context for agent review

Pre-v8 configurations are refused. Run `cumaru migrate`; a fresh `cumaru install`
already creates a v8 tree.

Doctor stays mechanical and pillar-agnostic. Workflow integrity remains in
domain recipe skills.

Exit codes:
  0   all checks pass (warnings allowed)
  1   at least one error
  2   usage error (unknown flag)

Examples:
  cumaru                                       equivalent to cumaru doctor (default)
  cumaru doctor --quiet                      hide pass lines; show warnings + errors
EOF
}

# --- output helpers (orchestrator level) ---

_doctor_ok=0
_doctor_warn=0
_doctor_err=0

_doctor_pass() {
  [[ "${QUIET:-0}" == "1" ]] || printf '\033[32m[✓]\033[0m %s\n' "$1"
  _doctor_ok=$((_doctor_ok + 1))
}

_doctor_warn_emit() {
  printf '\033[33m[⚠]\033[0m %s\n' "$1"
  if [[ -n "${2:-}" ]]; then
    printf '%s\n' "$2" | sed 's/^/    /'
  fi
  _doctor_warn=$((_doctor_warn + 1))
}

_doctor_fail() {
  printf '\033[31m[✗]\033[0m %s\n' "$1"
  if [[ -n "${2:-}" ]]; then
    printf '%s\n' "$2" | sed 's/^/    /'
  fi
  _doctor_err=$((_doctor_err + 1))
}

# --- schema conformance check ----------------------
#
# Walks `root.entities` recursively (via the helpers above) and validates
# every entity's frontmatter against the spec declared in config.yaml. NO
# hardcoded pillar names anywhere — adding a new pillar to the config is
# enough; this check picks it up automatically. The previous v2 version had
# hand-rolled sub-passes for plans / specs / exploring; v4 collapses
# them into the schema walk.

# Read meta.targets.values. Each line is one valid target key.
_doctor_target_values() {
  [[ -f "$CONFIG" ]] || return 0
  yq '.meta.targets.values // [] | .[]' "$CONFIG"
}

# Given an entity path pattern (e.g. `plans/<PLAN-ID>` or `plans/<PLAN-ID>/t<N>.md`),
# expand placeholders into shell globs and emit each matching file on disk:
#   <KEY> / <PLAN-ID> / <slug> / <area> / <concern>  →  *
#   <N>                                              →  [0-9]*
# Patterns without a `.md` suffix point at a directory whose entity-file is
# `index.md`, so we glob for that.
_doctor_disk_files_for_path() {
  local pat="$1" glob
  [[ "$pat" == *.md ]] || pat="$pat/index.md"
  glob="$pat"
  glob="${glob//<N>/[0-9]*}"
  glob=$(printf '%s' "$glob" | sed -E 's/<[a-zA-Z][a-zA-Z0-9_-]*>/*/g')
  shopt -s nullglob
  local f
  # Quote the dir (it may contain spaces) but leave $glob unquoted so it still
  # expands; an unquoted $CUMARU_DIR would word-split a path with spaces and
  # silently match nothing, making this sub-pass check zero files.
  for f in "$CUMARU_DIR"/$glob; do
    [[ -f "$f" ]] && printf '%s\n' "$f"
  done
  shopt -u nullglob
}

# Run frontmatter / pattern-rule / version checks against the schema. Verbose by
# default (the [0]..[5] sub-passes); silenced by the orchestrator via QUIET.
# Bumps the local `errors` and `warnings` counters; returns non-zero if any
# error landed.
_doctor_check_schema() {
  # Pre-flight: schema must exist
  if [[ ! -f "$CONFIG" ]]; then
    red "✗ schema not found at $CONFIG"
    return 1
  fi

  # Read valid targets from schema (v4: meta.targets.values)
  local VALID_TARGETS=()
  while IFS= read -r line; do
    VALID_TARGETS+=("$line")
  done < <(_doctor_target_values)

  if [[ ${#VALID_TARGETS[@]} -eq 0 ]]; then
    red "✗ failed to parse meta.targets.values from $CONFIG"
    return 1
  fi

  # frontmatter helpers
  fm() { awk '/^---$/{c++; if(c==2) exit; next} c>=1' "$1"; }
  has_key() { fm "$1" | grep -qE "^${2}:" 2>/dev/null; }

  check_required() {
    local file="$1" label="$2"; shift 2
    local missing=()
    local f
    for f in "$@"; do
      has_key "$file" "$f" || missing+=("$f")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
      local joined
      joined=$(IFS=,; echo "${missing[*]}")
      red "  ✗ $file ($label): missing $joined"
      errors=$((errors + ${#missing[@]}))
    fi
  }

  check_target_values() {
    local file="$1"
    local line
    line=$(fm "$file" | grep -E '^targets:' | head -1 || true)
    [[ -z "$line" ]] && return 0
    local raw
    raw=$(echo "$line" | sed -E 's/^targets:[[:space:]]*\[(.*)\][[:space:]]*$/\1/' | tr -d ' ' | tr ',' '\n')
    local v ok valid
    for v in $raw; do
      [[ -z "$v" ]] && continue
      valid=0
      for ok in "${VALID_TARGETS[@]}"; do
        [[ "$v" == "$ok" ]] && valid=1 && break
      done
      if [[ $valid -eq 0 ]]; then
        local valid_list
        valid_list=$(IFS=,; echo "${VALID_TARGETS[*]}")
        red "  ✗ $file: targets value '$v' not in {${valid_list//,/, }}"
        errors=$((errors + 1))
      fi
    done
  }

  # Validate every required (suffix `!`) field listed in <fm_csv> on <file>.
  check_required_from_csv() {
    local file="$1" label="$2" csv="$3"
    local field req missing=()
    for field in $(printf '%s' "$csv" | tr ',' ' '); do
      [[ -z "$field" ]] && continue
      [[ "$field" == *'!' ]] || continue   # only required
      req="${field%!}"
      has_key "$file" "$req" || missing+=("$req")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
      local joined
      joined=$(IFS=,; echo "${missing[*]}")
      red "  ✗ $file ($label): missing $joined"
      errors=$((errors + ${#missing[@]}))
    fi
  }

  check_h1() {
    local file="$1"
    if ! grep -qE '^# ' "$file"; then
      red "  ✗ $file: missing H1 heading"
      errors=$((errors + 1))
    fi
  }

  check_human_revised() {
    local file="$1"
    has_key "$file" "human_revised" || {
      red "  ✗ $file: missing human_revised (required by rules.markdown)"
      errors=$((errors + 1))
    }
  }

  say "Running diagnostic checks on $CUMARU_DIR/ ..."

  # [0] H1 + human_revised on every .md (rules.markdown)
  say ""
  say "[0] Universal markdown (H1, human_revised)"
  while IFS= read -r f; do
    check_h1 "$f"
    check_human_revised "$f"
  done < <(find "$CUMARU_DIR" -name '*.md' -type f 2>/dev/null | sort)

  # [1] index.md universal frontmatter (rules.index_md: generated, targets)
  say ""
  say "[1] index.md universal frontmatter (generated, targets)"
  while IFS= read -r f; do
    check_required "$f" "index" generated targets
    check_target_values "$f"
  done < <(find "$CUMARU_DIR" -name index.md -type f 2>/dev/null | sort)

  # [2] Pillar index.md — rules.pillar_index (generated) + pillar's own extras.
  say ""
  say "[2] Pillar index.md (generated + pillar extras)"
  local pillar pextras
  while IFS=$'\t' read -r pillar pextras; do
    [[ -z "$pillar" ]] && continue
    local pidx="$CUMARU_DIR/$pillar/index.md"
    [[ -f "$pidx" ]] || continue
    check_required "$pidx" "$pillar pillar index" generated
    [[ -n "$pextras" ]] && check_required_from_csv "$pidx" "$pillar pillar" "$pextras"
  done < <(_doctor_schema_pillar_extras)

  # [3] Entity frontmatter — walk root.entities recursively (no pillar names hardcoded).
  say ""
  say "[3] Entity frontmatter (schema-driven walk of root.entities)"
  local path_pattern fm_csv
  while IFS=$'\t' read -r path_pattern fm_csv; do
    [[ -z "$path_pattern" || -z "$fm_csv" ]] && continue
    while IFS= read -r f; do
      check_required_from_csv "$f" "$path_pattern" "$fm_csv"
      check_target_values "$f"
    done < <(_doctor_disk_files_for_path "$path_pattern")
  done < <(_doctor_schema_entities)

  # Schema-pass returns based on local error count; orchestrator owns the overall summary.
  # Clean up inner helpers — bash functions defined inside a function are NOT
  # scoped to it; they persist in the global namespace after return. Remove them
  # explicitly so they don't shadow unrelated code in future callers.
  unset -f fm has_key check_required check_target_values \
            check_required_from_csv check_h1 check_human_revised

  # Emit the warning tally on a sentinel line so the orchestrator — which runs
  # this function in a captured subshell — can surface pattern warnings even
  # when there are zero errors. The orchestrator strips this line.
  printf 'WARNCOUNT:%s\n' "$warnings"

  if [[ $errors -gt 0 ]]; then
    return 1
  fi
  return 0
}

# --- orchestrator-level checks (each emits exactly one [✓]/[⚠]/[✗] line) ---

_doctor_check_schema_pass() {
  local out exit_code warn_count
  # Subshell so the schema pass's local errors/warnings counters don't leak.
  out=$(QUIET=1 errors=0 warnings=0 _doctor_check_schema 2>&1)
  exit_code=$?

  # Pull the warning tally out of the sentinel line, then strip it from the
  # detail. With QUIET=1 the captured `out` holds only the red/yellow problem
  # lines (the [0]..[4] headers are suppressed), so when there are no errors it
  # is exactly the pattern-rule warnings.
  warn_count=$(printf '%s\n' "$out" | sed -n 's/^WARNCOUNT:\([0-9][0-9]*\)$/\1/p' | tail -1)
  [[ -z "$warn_count" ]] && warn_count=0
  out=$(printf '%s\n' "$out" | grep -v '^WARNCOUNT:')

  if [[ $exit_code -ne 0 ]]; then
    # Errors present — the detail already includes any warning lines too.
    _doctor_fail "Schema conformance" "$out"
  elif [[ "$warn_count" -gt 0 ]]; then
    # No errors, but pattern rules flagged bullets — surface them in the summary
    # instead of swallowing them (the old behaviour discarded `out` on pass).
    _doctor_warn_emit "Schema conformance: ${warn_count} pattern warning(s)" "$out"
  else
    _doctor_pass "Schema conformance (frontmatter, patterns, version)"
  fi
}

# --- orphan check (raiz + pilares) -----------------------------------------
# Walks every `index.md` declared in the schema (raiz + each pillar key under
# root.entities), shows every markdown-table tag found, and lists orphans in
# both directions:
#   ✗ row points at a missing file/dir
#   ⚠ file/dir on disk not claimed by any row (pilares only — raiz's tables
#       hold project-general entities, so reverse scope is too broad there).
# Bash is mechanical (discover + report); the LLM reconciles per the cumaru-doctor
# skill. Pillar set is schema-driven — never hardcoded, framework-agnostic.

# Pillar keys from schema's root.entities. Empty if pre-v4 or unreadable.
_doctor_orphan_pillars() {
  [[ -f "$CONFIG" ]] || return 0
  yq '.root.entities // {} | keys[]' "$CONFIG"
}

# Walk root.entities recursively and emit one TAB-separated record per entity:
#   <disk_path_pattern>\t<frontmatter_csv>
# disk_path is the OS path composed from ancestor `path:` declarations (a node
# without `path:` defaults to its key). frontmatter is the inline-list value
# verbatim from schema (with `!` markers preserved).
#
# Recursive YAML walk via yq→jq pipe (yq v4 lacks `def`, so jq handles the
# recursion).
_doctor_schema_entities() {
  [[ -f "$CONFIG" ]] || return 0
  yq -o=json "$CONFIG" | jq -r '
    def walk_entities(node; parent_path):
      (node.entities // {}) | to_entries[] |
      (
        (.value.path // .key) as $seg |
        (if parent_path == "" then $seg else "\(parent_path)/\($seg)" end) as $new_path |
        (.value.frontmatter // []) as $fm |
        (if ($fm | length) > 0 then "\($new_path)\t\($fm | join(","))" else empty end),
        walk_entities(.value; $new_path)
      );
    {entities: .root.entities} | walk_entities(.; "")
  '
}

# Same as above but limited to pillars (top-level under root.entities) — emits
# `<pillar_key>\t<frontmatter_csv>`, even when the pillar's frontmatter is
# empty (so `intake → tracker!` and `plans → ` both surface).
_doctor_schema_pillar_extras() {
  [[ -f "$CONFIG" ]] || return 0
  yq '.root.entities // {} | to_entries[] | [.key, (.value.frontmatter // []) | join(",")] | @tsv' "$CONFIG"
}

# Anchor dir for resolving a table's row paths.
_doctor_orphan_anchor() {
  fm_tag_anchor_dir "$CUMARU_DIR" "$1"
}

# Extract candidate paths from one table row. Each markdown link target and
# each backtick-quoted token is a candidate. The orphan check then resolves
# each against the anchor and picks the first that exists.
_doctor_row_paths() {
  printf '%s\n' "$1" | grep -oE '\[[^]]+\]\([^)]+\)' | sed -E 's/.*\(([^)]+)\)/\1/'
  printf '%s\n' "$1" | grep -oE '`[^`]+`'           | sed -E 's/`//g'
}

_doctor_check_orphans() {
  local pillars=() p
  while IFS= read -r p; do [[ -n "$p" ]] && pillars+=("$p"); done < <(_doctor_orphan_pillars)
  if [[ ${#pillars[@]} -eq 0 ]]; then
    _doctor_warn_emit "Orphan check skipped — schema has no pilares declared under root.entities" \
      "→ Likely a pre-v4 tree; apply the migration first (consult the project's migration docs)."
    return
  fi

  # Indexes to walk: raiz + domain.md (hosts the components table) + each
  # pilar declared by the schema.
  local indexes=("$CUMARU_DIR/index.md" "$CUMARU_DIR/domain.md")
  for p in "${pillars[@]}"; do
    indexes+=("$CUMARU_DIR/$p/index.md")
  done

  local total_rows=0 total_files=0 total_missing=0
  local report=()
  local idx anchor rel name body header

  for idx in "${indexes[@]}"; do
    rel="${idx#"$CUMARU_DIR"/}"
    if [[ ! -f "$idx" ]]; then
      report+=("─── ${rel}")
      report+=("  ✗ missing — expected by schema")
      total_missing=$((total_missing + 1))
      continue
    fi

    anchor=$(_doctor_orphan_anchor "$idx")
    local printed_header=0

    while IFS= read -r name; do
      [[ -z "$name" ]] && continue
      fm_schema_tag_is_default "$CUMARU_DIR" "$name" || continue
      body=$(fm_block_extract "$idx" "$name")
      header=$(printf '%s\n' "$body" | awk 'NF && /^[[:space:]]*\|/ { print; exit }')
      [[ -z "$header" ]] && continue   # not a markdown-table tag

      if [[ $printed_header -eq 0 ]]; then
        report+=("─── ${rel}")
        printed_header=1
      fi
      report+=("  Table: $name")
      report+=("    $header")

      local claimed=() row found cand label
      while IFS= read -r row; do
        [[ -z "$row" ]] && continue
        [[ "$row" =~ ^[[:space:]]*\| ]] || continue
        [[ "$row" == "$header" ]] && continue
        # Separator row: only |, -, :, spaces.
        if printf '%s\n' "$row" | grep -qE '^[[:space:]]*\|[-:[:space:]\|]+$'; then
          continue
        fi

        # Try each candidate path; first that resolves wins.
        found=""
        while IFS= read -r cand; do
          [[ -z "$cand" ]] && continue
          if [[ -e "$anchor/${cand%/}" ]]; then
            found="${cand%/}"
            break
          fi
        done < <(_doctor_row_paths "$row")

        if [[ -n "$found" ]]; then
          report+=("    ✓ $found")
          claimed+=("$found")
        else
          label=$(_doctor_row_paths "$row" | head -1)
          if [[ -z "$label" ]]; then
            label=$(printf '%s\n' "$row" | awk -F'|' '{print $2}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
          fi
          report+=("    ✗ ${label:-?} — orphan row (no file/dir on disk)")
          total_rows=$((total_rows + 1))
        fi
      done <<< "$body"

      # Reverse direction: pilares only (raiz/domain anchor is project-wide,
      # too broad).
      if [[ "$idx" != "$CUMARU_DIR/index.md" && "$idx" != "$CUMARU_DIR/domain.md" ]]; then
        local pdir base c cl reverse_found
        pdir="$(dirname "$idx")"
        while IFS= read -r c; do
          base=$(basename "$c")
          [[ "$base" == "index.md" ]] && continue
          [[ "$base" =~ ^\. ]] && continue
          reverse_found=0
          for cl in "${claimed[@]+"${claimed[@]}"}"; do
            # Three forms a claimed path can take for the same entry:
            #   "AAA-1234"            → ${cl%/}  matches base directly
            #   "AAA-1234/"           → ${cl%/} = "AAA-1234" matches base
            #   "AAA-1234/index.md"   → ${cl%%/*} = "AAA-1234" matches base
            # Without the third check a link to `path/index.md` would cause
            # the directory to be falsely reported as an orphan file.
            if [[ "$base" == "${cl%/}" || "${base%/}" == "${cl%/}" || "$base" == "${cl%%/*}" ]]; then
              reverse_found=1
              break
            fi
          done
          if [[ $reverse_found -eq 0 ]]; then
            report+=("    ⚠ $base — orphan file (on disk, not in table)")
            total_files=$((total_files + 1))
          fi
        done < <(find "$pdir" -mindepth 1 -maxdepth 1 \( -type d -o -name '*.md' \) 2>/dev/null | sort)
      fi
    done < <(fm_block_list "$idx")
  done

  if [[ $total_missing -eq 0 && $total_rows -eq 0 && $total_files -eq 0 ]]; then
    _doctor_pass "Pillar tables aligned with disk (no orphans)"
    return
  fi

  local summary=""
  [[ $total_missing -gt 0 ]] && summary+="${total_missing} missing index.md, "
  [[ $total_rows    -gt 0 ]] && summary+="${total_rows} orphan row(s), "
  [[ $total_files   -gt 0 ]] && summary+="${total_files} orphan file(s), "
  summary="${summary%, }"

  _doctor_warn_emit "Orphan check found drift: $summary" "$(printf '%s\n' "${report[@]}")"
}

# Generic stale-marker detector — any `*.delete-me.md` anywhere under .cumaru/
# is a work-file the LLM was supposed to delete after finishing a recipe.
# Pillar-agnostic; replaces the v2 close-out-specific check.
_doctor_check_stale_markers() {
  local files="" rels file
  for file in "${FM_INVENTORY_MARKDOWN[@]+"${FM_INVENTORY_MARKDOWN[@]}"}"; do
    [[ "$file" == *.delete-me.md ]] && files+="${files:+$'\n'}$file"
  done
  if [[ -z "$files" ]]; then
    _doctor_pass "No stale work-marker files (*.delete-me.md)"
  else
    # Strip the .cumaru/ prefix per-line via parameter expansion (the quoted
    # prefix is matched literally) — a sed `s|$CUMARU_DIR/|` would break if the
    # install path contained `|`, `&`, `\`, or a glob char.
    rels=$(printf '%s\n' "$files" | while IFS= read -r _df; do
      [[ -n "$_df" ]] && printf '%s\n' "${_df#"$CUMARU_DIR"/}"
    done)
    _doctor_warn_emit "Stale work-marker file(s) lingering:" \
      "$rels"$'\n'"→ Complete the recipe step that owns each marker and delete the file (likely the LLM forgot to remove it)."
  fi
}

# A RAW block is an explicit handoff marker: the source content still needs
# LLM refinement. Detect by marker shape across the tree, without hardcoding a
# pillar or entity type.
_doctor_check_raw_blocks() {
  local files="" rels file
  for file in "${FM_INVENTORY_MARKDOWN[@]+"${FM_INVENTORY_MARKDOWN[@]}"}"; do
    grep -qF '<!-- BEGIN RAW' "$file" 2>/dev/null && files+="${files:+$'\n'}$file"
  done
  if [[ -z "$files" ]]; then
    _doctor_pass "No unrefined RAW blocks"
  else
    rels=$(printf '%s\n' "$files" | while IFS= read -r _rf; do
      [[ -n "$_rf" ]] && printf '%s\n' "${_rf#"$CUMARU_DIR"/}"
    done)
    _doctor_warn_emit "Unrefined RAW block(s) found:" \
      "$rels"$'\n'"→ Refine each item and delete its BEGIN/END RAW block."
  fi
}

# Workflow-specific checks (tasks-done-without-handoff, orphan delta-drafts
# after close-out) **moved out of doctor in v4**. Doctor stays schema-driven and
# pillar-agnostic; workflow integrity is the LLM's responsibility per the
# recipe skills (e.g. cumaru-absorb for SDLC, which owns close-out).

# v5: default tag bodies are [Link, Description] tables. Validate that each
# link target resolves on disk. Custom table tags are deterministic but not
# path-resolved by default; prose/mixed/other tags are preserved-only here.
_doctor_check_file_refs() {
  local missing=() invalid=() shape=() file tag link desc target status expected actual
  while IFS=$'\t' read -r file tag link desc target status; do
    case "$status" in
      missing) missing+=("${file} [${tag}]: ${target}") ;;
      invalid) invalid+=("${file} [${tag}]: ${target}") ;;
    esac
  done < <(fm_tag_table_rows "$CUMARU_DIR")

  while IFS=$'\t' read -r file tag expected actual; do
    shape+=("${file} [${tag}]: expected ${expected}; saw ${actual}")
  done < <(fm_tag_table_shape_issues "$CUMARU_DIR")

  if [[ ${#missing[@]} -eq 0 && ${#invalid[@]} -eq 0 && ${#shape[@]} -eq 0 ]]; then
    _doctor_pass "File references resolve on disk"
  else
    local detail=""
    if [[ ${#missing[@]} -gt 0 ]]; then
      detail+=$(printf '  • %s\n' "${missing[@]}")
    fi
    if [[ ${#invalid[@]} -gt 0 ]]; then
      [[ -n "$detail" ]] && detail+=$'\n'
      detail+=$(printf '  • %s — invalid reference (must be a repository source file, project-root-relative)\n' "${invalid[@]}")
    fi
    if [[ ${#shape[@]} -gt 0 ]]; then
      [[ -n "$detail" ]] && detail+=$'\n'
      detail+=$(printf '  • %s — table header/column mismatch\n' "${shape[@]}")
    fi
    _doctor_warn_emit "File references not found, invalid, or malformed ($((${#missing[@]} + ${#invalid[@]} + ${#shape[@]}))):" "$detail"
  fi
}

_doctor_check_external_tools() {
  local missing=()
  local tool
  for tool in curl git rg jq yq; do
    command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
  done
  if [[ ${#missing[@]} -eq 0 ]]; then
    _doctor_pass "External tools available (curl, git, rg, jq, yq)"
  else
    _doctor_warn_emit "Missing external tools: ${missing[*]}" "→ Some commands won't work (remote install needs curl; Git-backed operations need git; map needs rg; config operations need jq+yq)"
  fi
}

# Report green when one complete Cumaru instruction set is present. Hooks,
# skills, and commands are outside doctor's scope.
_doctor_check_agent_hook() {
  local parent agent instructions existing expected created
  parent="$(dirname "$CUMARU_DIR")"
  for agent in claude codex; do
    instructions=$(_agent_instructions_file "$parent" "$agent")
    [[ -f "$instructions" ]] || continue
    existing=$(awk '/<!-- BEGIN CUMARU-HOOK/ { p=1 } p { print } /<!-- END CUMARU-HOOK -->/ { exit }' "$instructions")
    grep -qF '<!-- BEGIN CUMARU-HOOK created -->' "$instructions" && created=1 || created=0
    expected=$(_cumaru_hook_block "$CUMARU_DIR/index.md" "$created" "$agent")
    if [[ "$existing" == "$expected" ]]; then
      _doctor_pass "Complete Cumaru $agent instructions are installed"
      return 0
    fi
  done
  if [[ -f "$parent/opencode.json" ]] && _agent_opencode_instructions_valid "$parent/opencode.json" >/dev/null 2>&1; then
    _doctor_pass "Complete Cumaru opencode instructions are installed"
    return 0
  fi
  _doctor_warn_emit "No complete Cumaru agent instruction set is installed" "→ Install one with 'cumaru update agent <agent> --apply'."
}

# The retired field remains valid for a no-migration transition, but never
# selects an adapter or changes artifact routing.
_doctor_check_retired_agent_config() {
  if yq -e 'has("agent")' "$CONFIG" >/dev/null 2>&1; then
    _doctor_warn_emit "Retired config field: agent" "→ The value is ignored. Remove it when convenient."
  fi
}

# Report source-schema drift without mutating the adopter-owned config. The
# candidate is context for the agent, never an instruction for the CLI to apply.
_doctor_check_config_drift() {
  local domain source_schema source_display custom_domain plan_dir plan_file candidate removed candidate_json local_json base_json detail
  domain=$(schema_get_domain "$CONFIG") || return 0
  source_schema="$SCRIPT_DIR/domains/$( [[ "$domain" == "base" ]] && echo "__base" || echo "$domain" )/config.yaml"
  custom_domain=0
  if [[ ! -f "$source_schema" || -L "$source_schema" ]]; then
    custom_domain=1
    source_display="$SCRIPT_DIR/domains/__base/config.yaml"
    source_schema="$source_display"
  else
    source_display="$source_schema"
  fi

  plan_dir=$(mktemp -d) || return 0
  plan_file="$plan_dir/plan.json"
  if [[ "$custom_domain" == 1 ]]; then
    base_json=$(schema_canonical_json "$source_schema") || { rm -rf "$plan_dir"; return 0; }
    local_json=$(schema_canonical_json "$CONFIG") || { rm -rf "$plan_dir"; return 0; }
    source_schema="$plan_dir/source-defaults.yaml"
    jq -n --argjson base "$base_json" --argjson local "$local_json" '
      $base
      | .domain = $local.domain
      | .rules = $local.rules
      | .root = $local.root
      | .meta.targets = $local.meta.targets
      | if $local | has("workflows") then .workflows = $local.workflows else del(.workflows) end
    ' | yq -P > "$source_schema" || { rm -rf "$plan_dir"; return 0; }
  fi
  if ! config_reconcile_plan "$source_schema" "$CONFIG" "$plan_file"; then
    rm -rf "$plan_dir"
    _doctor_warn_emit "Configuration drift could not be checked" "→ Re-run 'cumaru update config' to inspect the schema and diagnostics."
    return 0
  fi

  candidate="$plan_dir/candidate.yaml"
  jq '.value' "$plan_file" | yq -P > "$candidate" || { rm -rf "$plan_dir"; return 0; }
  removed=$(jq -r '.removed[]? | "\(.path): \(.reason)"' "$plan_file")
  candidate_json=$(jq -cS '.value' "$plan_file")
  local_json=$(schema_canonical_json "$CONFIG" | jq -cS .) || { rm -rf "$plan_dir"; return 0; }
  if [[ "$candidate_json" == "$local_json" ]]; then
    _doctor_pass "Configuration matches the current schema and domain defaults"
  else
    printf -v detail 'Schema: %s\nSource defaults: %s' "$CUMARU_SCHEMA_METAMODEL" "$source_display"
    [[ -z "$removed" ]] || printf -v detail '%s\nModel-incompatible properties:\n%s' "$detail" "$removed"
    printf -v detail '%s\n→ Run %s, then edit config.yaml deliberately.' "$detail" "'cumaru update config'"
    _doctor_warn_emit "Configuration needs agent review" "$detail"
  fi
  rm -rf "$plan_dir"
}

# --- driver ---

cmd_doctor() {
  if [[ ! -d "$CUMARU_DIR" ]]; then
    red "✗ $CUMARU_DIR not found — run 'cumaru install' first"
    return 1
  fi

  local version
  version=$(schema_get_version "$CONFIG" 2>/dev/null || true)
  if [[ -n "$version" && "$version" != "8" && "$version" != "9" ]]; then
    red "✗ doctor supports framework versions 8 and 9; found version $version"
    yellow "→ Run: cumaru migrate"
    return 1
  fi

  schema_validate_installed "$CONFIG" "$CUMARU_DIR/index.md" || return $?

  echo "Running diagnostic checks on $CUMARU_DIR/ ..."
  echo
  cmd_doctor_checks
}
