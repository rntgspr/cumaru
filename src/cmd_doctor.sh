# cmd_doctor.sh — run health checks on a .llm/ tree.
#
# `llm doctor` runs all checks: schema conformance plus tree-wide
# structural checks. Each check emits one of:
#   [✓] label                     — pass
#   [⚠] label   detail            — soft issue (warning; never fails)
#   [✗] label   detail            — hard issue (error; exit 1 at end)
#
# Composition:
#   1. Schema conformance — frontmatter, EARS, framework-version match
#   2. Indexes drift      — current shallow indexes vs `regen index` output
#   3. Tasks done w/o handoff
#   4. Orphan archive work files (temp-archive-flow.delete-me.md lingering)
#   5. Orphan delta-drafts (delta-draft.md after archive entry exists)
#   6. File references — paths inside `<!-- llm:files:<tag> -->` blocks exist on disk
#   7. External tools available (curl, jq, git, rsync)
#
# Cross-file checks (path resolution, depends-on, deltas references) are
# listed in schema.yaml under cross_file_checks.deferred and not yet enforced.
#
# Expects from the entry-point: DOT_LLM_DIR, SCHEMA, QUIET. Reuses fm_*
# helpers from common.sh and _reconcile_check_quiet from cmd_reconcile.sh.

cmd_doctor_help() {
  cat <<'EOF'
llm doctor — run health checks on the .llm/ tree

Usage:
  llm doctor [--quiet]

Options:
  --quiet   suppress [✓] pass lines; warnings, errors, and the summary still print.

Checks:
  [1] Schema conformance — frontmatter, EARS, framework-version match
        Sub-passes:
          [0] H1 heading on every markdown
          [1] index.md universal frontmatter (generated, apps; apps values valid)
          [2] Plans + tasks (frontmatter required fields; EARS warning in AC)
          [3] Spec areas + concerns (frontmatter; EARS warning in Requirements)
          [4] Archive index.md required fields
          [5] Exploring index.md required fields
          Cross — framework-version in .llm/index.md must equal version in schema.yaml.
  [2] Shallow index drift vs disk
  [3] Tasks marked done without a sibling handoff-t<N>.md
  [4] Lingering archive work files (Phase 2 pending)
  [5] delta-draft.md left in plans/ after archive completed
  [6] File references in <!-- llm:files:<tag> --> blocks resolve on disk
  [7] External tools available (curl, jq, git, rsync)

  EARS pattern: WHEN .+ THE SYSTEM SHALL .+ — non-conforming bullets emit
  warnings, not errors. Cross-file checks (path resolution, depends-on,
  deltas references) are listed in schema.yaml under cross_file_checks.deferred
  and not yet enforced.

Exit codes:
  0   all checks pass (warnings allowed)
  1   at least one error
  2   usage error (unknown flag)

Examples:
  llm                                       equivalent to llm doctor (default)
  llm doctor --quiet                      hide pass lines; show warnings + errors
  DOT_LLM_DIR=path/to/.llm llm doctor     non-default tree
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
  [[ -n "${2:-}" ]] && printf '    %s\n' "$2"
  _doctor_warn=$((_doctor_warn + 1))
}

_doctor_fail() {
  printf '\033[31m[✗]\033[0m %s\n' "$1"
  [[ -n "${2:-}" ]] && printf '    %s\n' "$2"
  _doctor_err=$((_doctor_err + 1))
}

# --- schema conformance check (verbose pass, used as helper below) ---

# Run frontmatter / EARS / version checks against the schema. Verbose by
# default (the [0]..[5] sub-passes); silenced by the orchestrator via QUIET.
# Bumps the local `errors` and `warnings` counters; returns non-zero if any
# error landed.
_doctor_check_schema() {
  # Pre-flight: schema must exist
  if [[ ! -f "$SCHEMA" ]]; then
    red "✗ schema not found at $SCHEMA"
    return 1
  fi

  # Read valid apps from schema (single source of truth)
  local VALID_APPS=()
  while IFS= read -r line; do
    VALID_APPS+=("$line")
  done < <(awk '
    /^apps:[[:space:]]*$/                           { state="apps"; next }
    state=="apps"   && /^[[:space:]]+values:[[:space:]]*$/ { state="values"; next }
    state=="values" && /^[[:space:]]+-[[:space:]]+/ {
      sub(/^[[:space:]]+-[[:space:]]+/, "")
      sub(/[[:space:]]+#.*/, "")
      sub(/[[:space:]]+$/, "")
      if (length($0) > 0) print
      next
    }
    state=="values" && /^[a-zA-Z]/                  { exit }
  ' "$SCHEMA")

  if [[ ${#VALID_APPS[@]} -eq 0 ]]; then
    red "✗ failed to parse apps.values from $SCHEMA"
    return 1
  fi

  # Framework-version check
  local schema_version
  schema_version=$(awk '/^version:[[:space:]]/ {print $2; exit}' "$SCHEMA")
  local front_door="$DOT_LLM_DIR/index.md"
  if [[ -f "$front_door" ]]; then
    local fd_version
    fd_version=$(awk '/^---$/{c++; if(c==2) exit; next} c==1 && /^framework-version:[[:space:]]/ {print $2; exit}' "$front_door")
    if [[ -z "$fd_version" ]]; then
      red "✗ $front_door missing framework-version: in frontmatter (schema is at version $schema_version)"
      errors=$((errors + 1))
    elif [[ "$fd_version" != "$schema_version" ]]; then
      red "✗ framework-version mismatch: $front_door declares $fd_version, schema is $schema_version"
      errors=$((errors + 1))
    fi
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

  check_apps_value() {
    local file="$1"
    local line
    line=$(fm "$file" | grep -E '^apps:' | head -1 || true)
    [[ -z "$line" ]] && return 0
    local raw
    raw=$(echo "$line" | sed -E 's/^apps:[[:space:]]*\[(.*)\][[:space:]]*$/\1/' | tr -d ' ' | tr ',' '\n')
    local v ok valid
    for v in $raw; do
      [[ -z "$v" ]] && continue
      valid=0
      for ok in "${VALID_APPS[@]}"; do
        [[ "$v" == "$ok" ]] && valid=1 && break
      done
      if [[ $valid -eq 0 ]]; then
        local valid_list
        valid_list=$(IFS=,; echo "${VALID_APPS[*]}")
        red "  ✗ $file: apps value '$v' not in {${valid_list//,/, }}"
        errors=$((errors + 1))
      fi
    done
  }

  check_ears() {
    local file="$1" section_marker="$2"
    local found
    found=$(awk -v marker="$section_marker" -v f="$file" '
      $0 ~ marker {section=1; next}
      /^## / {section=0}
      section && /^- / && !/WHEN .+ THE SYSTEM SHALL .+/ {
        print f ":" NR ": " $0
      }
    ' "$file")
    if [[ -n "$found" ]]; then
      while IFS= read -r line; do
        yellow "  ⚠ EARS form: $line"
        warnings=$((warnings + 1))
      done <<< "$found"
    fi
  }

  check_h1() {
    local file="$1"
    if ! grep -qE '^# ' "$file"; then
      red "  ✗ $file: missing H1 heading"
      errors=$((errors + 1))
    fi
  }

  say "Running diagnostic checks on $DOT_LLM_DIR/ ..."

  # [0] Every .md has an H1
  say ""
  say "[0] H1 heading on every markdown"
  while IFS= read -r f; do
    check_h1 "$f"
  done < <(find "$DOT_LLM_DIR" -name '*.md' -type f 2>/dev/null | sort)

  # [1] Universal: every index.md
  say ""
  say "[1] index.md universal frontmatter"
  while IFS= read -r f; do
    check_required "$f" "index" generated apps
    check_apps_value "$f"
  done < <(find "$DOT_LLM_DIR" -name index.md -type f 2>/dev/null | sort)

  # [2] Plans + tasks
  say ""
  say "[2] Plans and tasks"
  for d in "$DOT_LLM_DIR"/plans/*/; do
    [[ -d "$d" ]] || continue
    pi="$d/index.md"
    if [[ -f "$pi" ]]; then
      check_required "$pi" "plan" generated apps status summary scope
      check_apps_value "$pi"
      check_ears "$pi" '## Acceptance Criteria'
    fi
    for tf in "$d"/t*.md; do
      [[ -f "$tf" ]] || continue
      base=$(basename "$tf")
      [[ "$base" == handoff-* ]] && continue
      check_required "$tf" "task" plan task depends-on concerns files status apps
      check_apps_value "$tf"
    done
  done

  # [3] Spec areas + concerns (recursive: areas may nest as subareas at any depth)
  say ""
  say "[3] Spec areas and concerns"
  while IFS= read -r ai; do
    d=$(dirname "$ai")
    check_required "$ai" "spec area" generated name summary depends-on apps deltas
    check_apps_value "$ai"
    check_ears "$ai" '## Requirements'
    for cf in "$d"/*.md; do
      [[ -f "$cf" ]] || continue
      base=$(basename "$cf")
      [[ "$base" == "index.md" ]] && continue
      [[ "$base" == "history.md" ]] && continue
      [[ "$base" == "bootstrap.md" ]] && continue
      check_required "$cf" "spec concern" generated apps
      check_apps_value "$cf"
    done
  done < <(find "$DOT_LLM_DIR/specs" -mindepth 2 -name index.md -type f 2>/dev/null)

  # [4] Archive
  say ""
  say "[4] Archive"
  for d in "$DOT_LLM_DIR"/archive/*/; do
    [[ -d "$d" ]] || continue
    ai="$d/index.md"
    [[ -f "$ai" ]] || continue
    check_required "$ai" "archive" generated status summary apps
    check_apps_value "$ai"
  done

  # [5] Exploring
  say ""
  say "[5] Exploring"
  for d in "$DOT_LLM_DIR"/exploring/*/; do
    [[ -d "$d" ]] || continue
    ei="$d/index.md"
    [[ -f "$ei" ]] || continue
    check_required "$ei" "exploring idea" generated status apps summary
    check_apps_value "$ei"
  done

  # Schema-pass returns based on local error count; orchestrator owns the overall summary.
  if [[ $errors -gt 0 ]]; then
    return 1
  fi
  return 0
}

# --- orchestrator-level checks (each emits exactly one [✓]/[⚠]/[✗] line) ---

_doctor_check_schema_pass() {
  local out exit_code
  # Subshell so the schema pass's local errors/warnings counters don't leak.
  out=$(QUIET=1 errors=0 warnings=0 _doctor_check_schema 2>&1)
  exit_code=$?
  if [[ $exit_code -eq 0 ]]; then
    _doctor_pass "Schema conformance (frontmatter, EARS, version)"
  else
    _doctor_fail "Schema conformance" "$(echo "$out" | tr '\n' ';' | sed 's/;$//')"
  fi
}

_doctor_check_indexes_drift() {
  # Delegates to the schema-driven reconcile walker — no hardcoded pillar list,
  # no per-pillar table builders. Pillars come from `root.entities` in schema.yaml.
  _reconcile_check_quiet
  case $? in
    0) _doctor_pass "Shallow indexes are up to date" ;;
    1) _doctor_warn_emit "Shallow indexes drifted from disk" "→ Run: llm reconcile" ;;
    2) _doctor_warn_emit "Schema has no v3 pillars (root.entities) — likely a pre-v3 tree" \
         "→ Run the v2 → v3 migration (see the llm-cli skill); reconcile cannot validate until then" ;;
  esac
}

_doctor_check_tasks_handoffs() {
  local missing=()
  local plan_dir tf base num task_status
  for plan_dir in "$DOT_LLM_DIR"/plans/*/; do
    [[ -d "$plan_dir" ]] || continue
    for tf in "$plan_dir"/t*.md; do
      [[ -f "$tf" ]] || continue
      base=$(basename "$tf")
      [[ "$base" == handoff-* ]] && continue
      task_status=$(fm_scalar "$tf" status)
      if [[ "$task_status" == "done" ]]; then
        num="${base#t}"; num="${num%.md}"; num="${num%-*}"
        if [[ ! -f "$plan_dir/handoff-t${num}.md" && ! -f "$plan_dir/handoff-${base}" ]]; then
          missing+=("${plan_dir#$DOT_LLM_DIR/}$base")
        fi
      fi
    done
  done

  if [[ ${#missing[@]} -eq 0 ]]; then
    _doctor_pass "Tasks done have handoffs"
  else
    _doctor_warn_emit "Tasks done without handoff: ${missing[*]}" "→ Dev should write handoff-t<N>.md per template/handoff.md"
  fi
}

_doctor_check_orphan_archive_work() {
  local files
  files=$(find "$DOT_LLM_DIR/archive" -name 'temp-archive-flow.delete-me.md' -type f 2>/dev/null)
  if [[ -z "$files" ]]; then
    _doctor_pass "No lingering archive work files"
  else
    local rels
    rels=$(echo "$files" | sed "s|$DOT_LLM_DIR/||g" | tr '\n' ' ' | sed 's/ $//')
    _doctor_warn_emit "Archive work files lingering (Phase 2 pending): $rels" "→ Finish absorbing the delta and run \`llm archive finalize <PLAN-ID>\`"
  fi
}

_doctor_check_orphan_delta_drafts() {
  local orphans=()
  local plan_dir plan_id
  for plan_dir in "$DOT_LLM_DIR"/plans/*/; do
    [[ -d "$plan_dir" ]] || continue
    plan_id=$(basename "$plan_dir")
    if [[ -f "$plan_dir/delta-draft.md" && -d "$DOT_LLM_DIR/archive/$plan_id" ]]; then
      orphans+=("$plan_id")
    fi
  done

  if [[ ${#orphans[@]} -eq 0 ]]; then
    _doctor_pass "No orphan delta-drafts"
  else
    _doctor_fail "delta-draft.md still in plans/ after archive entry exists: ${orphans[*]}" "→ Inconsistent state: archive flow Phase 2 was likely interrupted; remove the draft if redundant"
  fi
}

_doctor_check_file_refs() {
  local repo_root
  repo_root=$(cd "$(dirname "$DOT_LLM_DIR")" && pwd)

  local missing=()
  local f name path resolved
  while IFS= read -r f; do
    while IFS= read -r name; do
      [[ "$name" == files:* ]] || continue
      while IFS= read -r path; do
        [[ -z "$path" ]] && continue
        [[ "$path" == *'<'*'>'* ]] && continue
        resolved="$repo_root/$path"
        [[ -e "$resolved" ]] || missing+=("${f#$DOT_LLM_DIR/}: $path")
      done < <(fm_block_extract "$f" "$name" | awk '
        /^[[:space:]]*-[[:space:]]+`[^`]+`/ {
          match($0, /`[^`]+`/)
          print substr($0, RSTART+1, RLENGTH-2)
        }
      ')
    done < <(fm_block_list "$f")
  done < <(find "$DOT_LLM_DIR" -name '*.md' -type f 2>/dev/null | sort)

  if [[ ${#missing[@]} -eq 0 ]]; then
    _doctor_pass "File references resolve on disk"
  else
    local detail
    detail=$(printf '  • %s\n' "${missing[@]}")
    _doctor_warn_emit "File references not found (${#missing[@]}):" "$detail"
  fi
}

_doctor_check_external_tools() {
  local missing=()
  local tool
  for tool in curl jq git rsync; do
    command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
  done
  if [[ ${#missing[@]} -eq 0 ]]; then
    _doctor_pass "External tools available (curl, jq, git, rsync)"
  else
    _doctor_warn_emit "Missing external tools: ${missing[*]}" "→ Some commands won't work (intake needs curl+jq; sync via git URL needs git)"
  fi
}

# --- driver ---

cmd_doctor() {
  if [[ ! -d "$DOT_LLM_DIR" ]]; then
    red "✗ $DOT_LLM_DIR not found — run 'llm install' first"
    return 1
  fi

  echo "Running diagnostic checks on $DOT_LLM_DIR/ ..."
  echo

  # Reset orchestrator counters (subcommand may be called more than once in a process)
  _doctor_ok=0
  _doctor_warn=0
  _doctor_err=0

  _doctor_check_schema_pass
  _doctor_check_indexes_drift
  _doctor_check_tasks_handoffs
  _doctor_check_orphan_archive_work
  _doctor_check_orphan_delta_drafts
  _doctor_check_file_refs
  _doctor_check_external_tools

  echo
  printf 'Summary: %d error(s), %d warning(s), %d ok\n' "$_doctor_err" "$_doctor_warn" "$_doctor_ok"

  if [[ $_doctor_err -gt 0 ]]; then
    return 1
  fi
  return 0
}
