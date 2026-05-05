# cmd_doctor.sh — aggregate health checks on a .llm/ tree.
#
# Runs a series of independent checks and prints a summary.  Each check emits
# one of:
#   [✓] label                     — pass (incremented to ok counter)
#   [⚠] label   detail            — soft issue (warnings; never fails)
#   [✗] label   detail            — hard issue (errors; exit 1 at end)
#
# Composition (delegates to existing functions whenever possible):
#   1. Validate            — runs cmd_validate (subshell so its counters don't leak)
#   2. Indexes drift       — compares current shallow indexes vs what `regen index` would produce
#   3. Tasks done w/o handoff
#   4. Orphan archive work files (temp-archive-flow.delete-me.md lingering)
#   5. Orphan delta-drafts (delta-draft.md in a plan that already has an archive entry)
#   6. File references     — paths inside `<!-- llm:files:<tag> -->` blocks exist on disk
#   7. External tools available (curl, jq, git, rsync)
#
# Expects from the entry-point: DOT_LLM_DIR, SCHEMA. Reuses fm_* helpers from
# common.sh and _regen_table_* from cmd_regen.sh.

cmd_doctor_help() {
  cat <<EOF
llm doctor — aggregate health checks on the .llm/ tree

Usage:
  llm doctor

Reports:
  - Validate (frontmatter, EARS, version)
  - Shallow index drift vs disk
  - Tasks marked done without a sibling handoff
  - Lingering archive work files (Phase 2 pending)
  - delta-draft.md left in plans/ after archive completed
  - File references in <!-- llm:files:<tag> --> blocks exist on disk
  - External tools available (curl, jq, git, rsync)

Exits 0 if all checks pass (warnings allowed), 1 if any check errors.
EOF
}

# --- output helpers ---

_doctor_ok=0
_doctor_warn=0
_doctor_err=0

_doctor_pass() {
  printf '\033[32m[✓]\033[0m %s\n' "$1"
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

# --- individual checks ---

_doctor_check_validate() {
  local out exit_code
  # Subshell so cmd_validate's local errors/warnings counters don't leak into doctor's.
  out=$(QUIET=1 errors=0 warnings=0 cmd_validate 2>&1)
  exit_code=$?
  if [[ $exit_code -eq 0 ]]; then
    _doctor_pass "Validate (frontmatter, EARS, version)"
  else
    _doctor_fail "Validate" "$(echo "$out" | tr '\n' ';' | sed 's/;$//')"
  fi
}

_doctor_check_indexes_drift() {
  local drifted=()
  local pillar index_file table tmp expected
  for pillar in intake plans archive specs exploring; do
    index_file="$DOT_LLM_DIR/$pillar/index.md"
    [[ -f "$index_file" ]] || continue

    case "$pillar" in
      intake)    table=$(_regen_table_intake)    ;;
      plans)     table=$(_regen_table_plans)     ;;
      archive)   table=$(_regen_table_archive)   ;;
      specs)     table=$(_regen_table_specs)     ;;
      exploring) table=$(_regen_table_exploring) ;;
    esac

    tmp=$(mktemp)
    cp "$index_file" "$tmp"
    if echo "$table" | fm_block_replace "$tmp" entries "$pillar" 2>/dev/null; then
      if ! cmp -s "$tmp" "$index_file"; then
        drifted+=("$pillar/index.md")
      fi
    fi
    rm -f "$tmp"
  done

  if [[ ${#drifted[@]} -eq 0 ]]; then
    _doctor_pass "Shallow indexes are up to date"
  else
    _doctor_warn_emit "Shallow indexes drifted from disk: ${drifted[*]}" "→ Run: llm regen index"
  fi
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
  # Repo root is the parent of .llm/. Paths inside `llm:files:*` blocks are
  # interpreted relative to the repo root.
  local repo_root
  repo_root=$(cd "$(dirname "$DOT_LLM_DIR")" && pwd)

  local missing=()
  local f kind tag path resolved
  while IFS= read -r f; do
    while IFS=$'\t' read -r kind tag; do
      [[ "$kind" == "files" ]] || continue
      while IFS= read -r path; do
        [[ -z "$path" ]] && continue
        # Skip placeholders left from templates (no real project would commit `<...>`).
        [[ "$path" == *'<'*'>'* ]] && continue
        resolved="$repo_root/$path"
        [[ -e "$resolved" ]] || missing+=("${f#$DOT_LLM_DIR/}: $path")
      done < <(fm_block_extract "$f" files "$tag" | awk '
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
    _doctor_warn_emit "Missing external tools: ${missing[*]}" "→ Some commands won't work (intake needs curl+jq; update needs rsync; framework sync via git URL needs git)"
  fi
}

# --- driver ---

cmd_doctor() {
  case "${1:-}" in
    -h|--help|help) cmd_doctor_help; return 0 ;;
    "") ;;
    *) red "✗ unknown arg: $1"; cmd_doctor_help; return 2 ;;
  esac

  if [[ ! -d "$DOT_LLM_DIR" ]]; then
    red "✗ $DOT_LLM_DIR not found — run 'llm install' first"
    return 1
  fi

  echo "Running diagnostic checks on $DOT_LLM_DIR/ ..."
  echo

  # Reset counters (subcommand may be called more than once in a process)
  _doctor_ok=0
  _doctor_warn=0
  _doctor_err=0

  _doctor_check_validate
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
