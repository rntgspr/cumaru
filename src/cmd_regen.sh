# cmd_regen.sh — regenerate derived state inside .llm/.
#
# Subcommands:
#   index [pillar]    regenerate the 5 shallow indexes (or just one) by
#                     scanning the disk and replacing the entries block.
#   <JIRA-KEY>        chain-check a ticket: intake → plan → archive → specs.
#                     Reports inconsistencies (tasks without handoffs, EARS
#                     not covered by deltas, deltas: list missing the plan).
#
# Expects from the entry-point: DOT_LLM_DIR.

cmd_regen_help() {
  cat <<EOF
llm regen — regenerate derived state inside .llm/

Usage:
  llm regen index [pillar]   regenerate shallow indexes (default: all 5)
                             pillar ∈ {intake, plans, archive, specs, exploring}
  llm regen <JIRA-KEY>       chain-check a ticket and print a report

Examples:
  llm regen index            regenerate all 5 shallow indexes
  llm regen index plans      regenerate only plans/index.md
  llm regen JET-1234         report on the chain for JET-1234
EOF
}

# ---------------------------------------------------------------------------
# regen index — rebuild the entries block of each shallow index from disk.
# ---------------------------------------------------------------------------

cmd_regen_index() {
  local pillar="${1:-}"
  case "$pillar" in
    ""|all) for p in intake plans archive specs exploring; do _regen_index_one "$p"; done ;;
    intake|plans|archive|specs|exploring) _regen_index_one "$pillar" ;;
    -h|--help|help) cmd_regen_help; return 0 ;;
    *) red "✗ unknown pillar: $pillar"; cmd_regen_help; return 2 ;;
  esac
}

_regen_index_one() {
  local pillar="$1"
  local index_file="$DOT_LLM_DIR/$pillar/index.md"

  if [[ ! -f "$index_file" ]]; then
    yellow "  ⚠ $index_file missing — skip"
    return 0
  fi

  local table
  case "$pillar" in
    intake)    table=$(_regen_table_intake)    ;;
    plans)     table=$(_regen_table_plans)     ;;
    archive)   table=$(_regen_table_archive)   ;;
    specs)     table=$(_regen_table_specs)     ;;
    exploring) table=$(_regen_table_exploring) ;;
  esac

  if echo "$table" | fm_block_replace "$index_file" entries "$pillar"; then
    local count
    count=$(echo "$table" | grep -c '^|' || echo 0)
    green "✓ $pillar/index.md  ($count rows)"
  else
    red "✗ $index_file has no <!-- llm:entries:$pillar --> block — skip"
    return 1
  fi
}

# Each table generator prints rows like:  | col1 | col2 | ... |
# (header + separator are part of the file outside the block, not regenerated).

_regen_table_intake() {
  local d type key f title status synced epic story
  for type in epics stories tickets; do
    for d in "$DOT_LLM_DIR"/intake/"$type"/*/; do
      [[ -d "$d" ]] || continue
      f="$d/index.md"
      [[ -f "$f" ]] || continue
      key=$(basename "$d")
      title=$(fm_h1 "$f")
      status=$(fm_scalar "$f" status)
      synced=$(fm_scalar "$f" "synced-at")
      epic=$(fm_scalar "$f" epic)
      story=$(fm_scalar "$f" story)
      printf '| [%s](%s/%s/) | %s | %s | %s | %s | %s | %s |\n' \
        "$key" "$type" "$key" "${type%s}" "$title" "${epic:--}" "${story:--}" "${status:--}" "${synced:--}"
    done | sort
  done
}

_regen_table_plans() {
  local d plan title scope tasks status apps updated f
  for d in "$DOT_LLM_DIR"/plans/*/; do
    [[ -d "$d" ]] || continue
    f="$d/index.md"
    [[ -f "$f" ]] || continue
    plan=$(basename "$d")
    title=$(fm_h1 "$f")
    scope=$(fm_list "$f" scope | tr '\n' ' ' | sed 's/ $//; s/  */, /g')
    status=$(fm_scalar "$f" status)
    apps=$(fm_scalar "$f" apps)
    # task count: t*.md excluding handoff-*.md
    tasks=$(find "$d" -maxdepth 1 -name 't*.md' -not -name 'handoff-*' 2>/dev/null | wc -l | tr -d ' ')
    updated=$(date -r "$f" +%Y-%m-%d 2>/dev/null || echo "—")
    printf '| [%s](%s/) | %s | %s | %s tasks | %s | %s | %s |\n' \
      "$plan" "$plan" "$title" "${scope:--}" "$tasks" "${status:--}" "${apps:--}" "$updated"
  done | sort
}

_regen_table_archive() {
  local d plan f type apps story epic completed summary
  for d in "$DOT_LLM_DIR"/archive/*/; do
    [[ -d "$d" ]] || continue
    f="$d/index.md"
    [[ -f "$f" ]] || continue
    plan=$(basename "$d")
    type=$(fm_scalar "$f" type)
    apps=$(fm_scalar "$f" apps)
    story=$(fm_scalar "$f" story)
    epic=$(fm_scalar "$f" epic)
    completed=$(fm_scalar "$f" "completed-at")
    summary=$(fm_scalar "$f" summary)
    [[ -z "$summary" ]] && summary=$(fm_h1 "$f")
    printf '| [%s](%s/) | %s | %s | %s | %s | %s | %s |\n' \
      "$plan" "$plan" "${type:--}" "${apps:--}" "${story:--}" "${epic:--}" "${completed:--}" "${summary:--}"
  done | sort
}

_regen_table_specs() {
  local d area f summary apps deps
  for d in "$DOT_LLM_DIR"/specs/*/; do
    [[ -d "$d" ]] || continue
    f="$d/index.md"
    [[ -f "$f" ]] || continue
    area=$(basename "$d")
    summary=$(fm_scalar "$f" summary)
    apps=$(fm_scalar "$f" apps)
    deps=$(fm_list "$f" "depends-on" | tr '\n' ',' | sed 's/,$//; s/,/, /g')
    printf '| [%s/](%s/) | %s | %s | %s |\n' \
      "$area" "$area" "${summary:--}" "${apps:--}" "${deps:--}"
  done | sort
}

_regen_table_exploring() {
  local d slug f status apps updated summary
  for d in "$DOT_LLM_DIR"/exploring/*/; do
    [[ -d "$d" ]] || continue
    f="$d/index.md"
    [[ -f "$f" ]] || continue
    slug=$(basename "$d")
    status=$(fm_scalar "$f" status)
    apps=$(fm_scalar "$f" apps)
    summary=$(fm_scalar "$f" summary)
    updated=$(date -r "$f" +%Y-%m-%d 2>/dev/null || echo "—")
    printf '| [%s](%s/) | %s | %s | %s | %s |\n' \
      "$slug" "$slug" "${status:--}" "${apps:--}" "$updated" "${summary:--}"
  done | sort
}

# ---------------------------------------------------------------------------
# regen <JIRA-KEY> — chain-check a ticket and print a report.
# ---------------------------------------------------------------------------

cmd_regen_chain() {
  local key="$1"

  # Resolve intake file (which subdir)
  local intake_file=""
  local intake_subdir=""
  local sub
  for sub in epics stories tickets; do
    if [[ -f "$DOT_LLM_DIR/intake/$sub/$key/index.md" ]]; then
      intake_file="$DOT_LLM_DIR/intake/$sub/$key/index.md"
      intake_subdir="$sub"
      break
    fi
  done

  local plan_dir=""
  [[ -d "$DOT_LLM_DIR/plans/$key" ]] && plan_dir="$DOT_LLM_DIR/plans/$key"

  local archive_dir=""
  [[ -d "$DOT_LLM_DIR/archive/$key" ]] && archive_dir="$DOT_LLM_DIR/archive/$key"

  echo
  echo "Chain check — $key"
  echo "──────────────────────────────────────────"

  # Intake
  if [[ -n "$intake_file" ]]; then
    local synced
    synced=$(fm_scalar "$intake_file" "synced-at")
    echo "  Intake:   ✓ intake/$intake_subdir/$key/  (synced-at: ${synced:-?})"
    if grep -q "BEGIN JIRA-RAW" "$intake_file"; then
      yellow "            ⚠ JIRA-RAW block still present (not yet refined)"
    fi
  else
    echo "  Intake:   — not found"
    say   "            (suggest: llm intake $key)"
  fi

  # Plan
  if [[ -n "$plan_dir" ]]; then
    local plan_status
    plan_status=$(fm_scalar "$plan_dir/index.md" status)
    local task_count done_count
    task_count=$(find "$plan_dir" -maxdepth 1 -name 't*.md' -not -name 'handoff-*' | wc -l | tr -d ' ')
    done_count=0
    local tf
    for tf in "$plan_dir"/t*.md; do
      [[ -f "$tf" ]] || continue
      [[ "$(basename "$tf")" == handoff-* ]] && continue
      [[ "$(fm_scalar "$tf" status)" == "done" ]] && done_count=$((done_count+1))
    done
    echo "  Plan:     ✓ plans/$key/  (status: ${plan_status:-?}; $done_count/$task_count tasks done)"
    _regen_check_tasks_handoffs "$plan_dir"
  else
    echo "  Plan:     — not found"
  fi

  # Archive
  if [[ -n "$archive_dir" ]]; then
    local archived_at
    archived_at=$(fm_scalar "$archive_dir/index.md" "completed-at")
    echo "  Archive:  ✓ archive/$key/  (completed-at: ${archived_at:-?})"
    if [[ -f "$archive_dir/temp-archive-flow.delete-me.md" ]]; then
      yellow "            ⚠ temp-archive-flow.delete-me.md still present (Phase 2 pending)"
    fi
    _regen_check_specs_deltas "$key" "${plan_dir:-$archive_dir}"
  else
    echo "  Archive:  — not yet"
  fi

  # EARS coverage (only if both intake and archive exist)
  if [[ -n "$intake_file" && -n "$archive_dir" ]]; then
    _regen_check_ears_coverage "$intake_file" "$archive_dir/delta.md"
  fi

  # Specs scope summary
  if [[ -n "$plan_dir" ]]; then
    local scope
    scope=$(fm_list "$plan_dir/index.md" scope)
    if [[ -n "$scope" ]]; then
      echo "  Scope:    $(echo "$scope" | tr '\n' ' ' | sed 's/ $//')"
    fi
  fi

  echo
}

# Check that every t<N>.md with status:done has a sibling handoff-t<N>.md.
_regen_check_tasks_handoffs() {
  local plan_dir="$1"
  local tf base num task_status missing=()
  for tf in "$plan_dir"/t*.md; do
    [[ -f "$tf" ]] || continue
    base=$(basename "$tf")
    [[ "$base" == handoff-* ]] && continue
    task_status=$(fm_scalar "$tf" status)
    if [[ "$task_status" == "done" ]]; then
      # extract N from t<N>.md (strip 't' and '.md', also drop -<component> suffix)
      num="${base#t}"; num="${num%.md}"; num="${num%-*}"
      if [[ ! -f "$plan_dir/handoff-t${num}.md" && ! -f "$plan_dir/handoff-${base}" ]]; then
        missing+=("$base")
      fi
    fi
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    yellow "            ⚠ tasks done without handoff: ${missing[*]}"
  fi
}

# Check that the spec areas in the plan's scope: have <PLAN-ID> in their
# frontmatter deltas: list. If they don't, the absorb step was skipped.
_regen_check_specs_deltas() {
  local key="$1" plan_or_archive_dir="$2"
  local plan_index="$plan_or_archive_dir/index.md"
  [[ -f "$plan_index" ]] || return 0
  local scope
  scope=$(fm_list "$plan_index" scope)
  [[ -z "$scope" ]] && return 0
  local missing=()
  local area area_root area_index found_deltas
  while IFS= read -r area; do
    [[ -z "$area" ]] && continue
    area_root="${area%%/*}"
    area_index="$DOT_LLM_DIR/specs/$area_root/index.md"
    if [[ ! -f "$area_index" ]]; then
      missing+=("$area_root (spec missing)")
      continue
    fi
    found_deltas=$(fm_list "$area_index" deltas)
    if ! echo "$found_deltas" | grep -qFx "$key"; then
      missing+=("$area_root (no $key in deltas:)")
    fi
  done <<< "$scope"
  if [[ ${#missing[@]} -gt 0 ]]; then
    yellow "            ⚠ specs missing $key in deltas: ${missing[*]}"
  fi
}

# Check that every "WHEN ... THE SYSTEM SHALL ..." line in the intake is
# present in the archive's delta.md (any section). This is a coarse check
# — text matching, not semantic — but catches the common case where a Dev
# forgot to translate an AC into a Requirement.
_regen_check_ears_coverage() {
  local intake_file="$1" delta_file="$2"
  [[ -f "$intake_file" && -f "$delta_file" ]] || return 0
  local missing=()
  local line trigger response
  while IFS= read -r line; do
    # extract the meaningful part (between WHEN and end of line) for matching
    local frag
    frag=$(echo "$line" | sed -E 's/^[[:space:]]*-[[:space:]]*//; s/[[:space:]]+$//')
    [[ -z "$frag" ]] && continue
    if ! grep -qF "$frag" "$delta_file"; then
      missing+=("$frag")
    fi
  done < <(grep -E '^[[:space:]]*-[[:space:]]+WHEN .+ THE SYSTEM SHALL .+' "$intake_file" 2>/dev/null)
  if [[ ${#missing[@]} -gt 0 ]]; then
    yellow "  EARS:     ⚠ ${#missing[@]} criterion(s) from intake not present in delta.md:"
    local f
    for f in "${missing[@]}"; do yellow "              - $f"; done
  else
    echo "  EARS:     ✓ all intake criteria match the delta"
  fi
}

# Top-level dispatch.
cmd_regen() {
  local arg="${1:-}"
  case "$arg" in
    "")             cmd_regen_help; return 2 ;;
    -h|--help|help) cmd_regen_help; return 0 ;;
    index)          shift; cmd_regen_index "$@" ;;
    *)
      # If it looks like a JIRA key (e.g. JET-1234) or a slug, do chain check.
      if [[ ! -d "$DOT_LLM_DIR" ]]; then
        red "✗ $DOT_LLM_DIR not found — run 'llm install' first"
        return 1
      fi
      cmd_regen_chain "$arg"
      ;;
  esac
}
