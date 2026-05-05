# cmd_archive.sh — close a plan and move it to archive/.
#
# Two-phase flow (LLM-driven on the semantic parts, deterministic on the move):
#
#   Phase 1: `llm archive <PLAN-ID>`            (default — "prepare")
#     - Pre-checks: plan exists, all tasks status:done, delta-draft.md present.
#     - Creates archive/<PLAN-ID>/ and copies the plan's index, delta-draft
#       (as delta.md), and any handoff-t<N>.md into it.
#     - Updates the archived index.md frontmatter (status:done, completed-at,
#       delta:delta.md).
#     - Writes archive/<PLAN-ID>/temp-archive-flow.delete-me.md with step-by-step instructions
#       for an LLM to refine the delta wording, absorb it into the affected
#       specs (each path under the plan's scope), and delete the original
#       delta-draft.md.
#
#   Phase 2: `llm archive finalize <PLAN-ID>`  (after the LLM is done)
#     - Verifies the work file is deleted, the delta is no longer status:draft,
#       and the original delta-draft.md is gone.
#     - Removes plans/<PLAN-ID>/ entirely. Specs absorption already happened
#       in Phase 1; the plan tree is no longer needed.
#
# The original plans/ tree is preserved through Phase 1 — if anything goes
# wrong, you still have the source. Only Phase 2 removes it.
#
# Expects from the entry-point: DOT_LLM_DIR.

cmd_archive_help() {
  cat <<EOF
llm archive — close a plan and move it to archive/

Usage:
  llm archive <PLAN-ID>             prepare archive entry + work file (Phase 1)
  llm archive finalize <PLAN-ID>  finalize after LLM absorbs deltas (Phase 2)

Behavior:

  Phase 1 (default):
    - Pre-checks: plan exists, every task is status:done, delta-draft.md present.
    - Creates archive/<PLAN-ID>/ and copies index.md, delta-draft.md (renamed
      to delta.md), and any handoff-t<N>.md.
    - Updates the copied index.md frontmatter: status:done, completed-at,
      delta:delta.md.
    - Writes archive/<PLAN-ID>/temp-archive-flow.delete-me.md with instructions for an LLM
      to:
        1. Refine the delta wording (drop status:draft, tighten).
        2. Absorb the delta into each affected spec area.
        3. Delete the original plans/<PLAN-ID>/delta-draft.md.

  Phase 2 (\`llm archive finalize <PLAN-ID>\`):
    - Verifies temp-archive-flow.delete-me.md is gone, delta.md is no longer status:draft,
      and plans/<PLAN-ID>/delta-draft.md is gone.
    - Removes plans/<PLAN-ID>/ entirely.

The original plans/ tree is kept through Phase 1 (safe to retry). Only the
finalize step removes it.
EOF
}

cmd_archive_prepare() {
  local plan_id="$1"
  local plan_dir="$DOT_LLM_DIR/plans/$plan_id"
  local archive_dir="$DOT_LLM_DIR/archive/$plan_id"

  # Pre-checks
  if [[ ! -d "$plan_dir" ]]; then
    red "✗ plan not found: $plan_dir"
    return 1
  fi

  local plan_index="$plan_dir/index.md"
  if [[ ! -f "$plan_index" ]]; then
    red "✗ $plan_index missing"
    return 1
  fi

  local draft="$plan_dir/delta-draft.md"
  if [[ ! -f "$draft" ]]; then
    red "✗ no delta-draft.md in $plan_dir — Dev hasn't drafted the delta yet"
    return 1
  fi

  if [[ -e "$archive_dir" ]]; then
    red "✗ archive entry already exists: $archive_dir"
    yellow "  Resolve the previous archive run or remove the directory."
    return 1
  fi

  # Verify every t*.md (excluding handoff-*.md) has status:done
  local incomplete=()
  local tf base task_status
  for tf in "$plan_dir"/t*.md; do
    [[ -f "$tf" ]] || continue
    base=$(basename "$tf")
    [[ "$base" == handoff-* ]] && continue
    task_status=$(fm_scalar "$tf" status)
    if [[ "$task_status" != "done" ]]; then
      incomplete+=("$base (status: ${task_status:-unset})")
    fi
  done
  if [[ ${#incomplete[@]} -gt 0 ]]; then
    red "✗ not all tasks are done:"
    local t
    for t in "${incomplete[@]}"; do red "    - $t"; done
    return 1
  fi

  # Read scope (paths under specs/) from the plan's frontmatter
  local scope
  scope=$(fm_list "$plan_index" scope)

  local now
  now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Create archive dir and copy artifacts
  mkdir -p "$archive_dir"
  cp "$draft" "$archive_dir/delta.md"

  # Copy plan's index.md, updating the frontmatter:
  #   status:<x> → status:done
  #   add completed-at:<now> if absent
  #   add delta:delta.md if absent
  awk -v completed="$now" '
    BEGIN { c = 0; have_completed = 0; have_delta = 0 }
    /^---$/ {
      c++
      if (c == 2) {
        if (!have_completed) print "completed-at: " completed
        if (!have_delta)     print "delta: delta.md"
      }
      print; next
    }
    c == 1 && /^status:/                    { print "status: done"; next }
    c == 1 && /^completed-at:/              { have_completed = 1; print "completed-at: " completed; next }
    c == 1 && /^delta:/                     { have_delta = 1; print "delta: delta.md"; next }
    { print }
  ' "$plan_index" > "$archive_dir/index.md"

  # Copy handoff files
  local hf
  for hf in "$plan_dir"/handoff-*.md; do
    [[ -f "$hf" ]] && cp "$hf" "$archive_dir/"
  done

  # Build temp-archive-flow.delete-me.md
  local work_file="$archive_dir/temp-archive-flow.delete-me.md"
  {
    echo "# Archive work — $plan_id"
    echo ""
    echo "<!-- BEGIN ARCHIVE-INSTRUCTIONS"
    echo "INSTRUCTION FOR LLM:"
    echo "Plan \`$plan_id\` is ready to close. Its files were copied to"
    echo "\`archive/$plan_id/\` (index.md updated with status:done, completed-at,"
    echo "delta:delta.md; delta-draft.md copied as delta.md; handoffs copied)."
    echo "The original \`plans/$plan_id/\` is intact for now — it will be"
    echo "removed by Phase 2."
    echo ""
    echo "Your job:"
    echo ""
    echo "  1. Refine \`archive/$plan_id/delta.md\`:"
    echo "     - Drop the line \`status: draft\` if present."
    echo "     - Tighten phrasing where the draft was loose."
    echo "     - Verify every Acceptance Criterion (EARS) of the plan is"
    echo "       covered by an Added or Modified Requirement, or explicitly"
    echo "       noted as not requiring a spec change. For Jira-backed plans"
    echo "       the criteria live in \`intake/tickets/<JIRA>/index.md\`;"
    echo "       for slug-based plans they live in the plan body."
    echo ""
    echo "  2. Absorb the delta into each affected spec area listed below."
    echo "     For each \`specs/<area>/\`:"
    echo "       - Edit \`index.md\`: update the body so it reflects the new"
    echo "         state (apply Added/Modified/Removed Requirements)."
    echo "       - Append \"$plan_id\" to the frontmatter \`deltas:\` list."
    echo ""
    echo "  3. Delete \`plans/$plan_id/delta-draft.md\` — the finalized"
    echo "     version now lives in \`archive/$plan_id/delta.md\`."
    echo ""
    echo "  4. Delete this file (\`temp-archive-flow.delete-me.md\`)."
    echo ""
    echo "  5. Run: \`llm archive finalize $plan_id\`"
    echo "     This removes \`plans/$plan_id/\` and finishes the close. Step 4"
    echo "     above is a precondition — finalize refuses if this work file is"
    echo "     still here."
    echo "END ARCHIVE-INSTRUCTIONS -->"
    echo ""
    echo "## Plan"
    echo ""
    echo "See \`archive/$plan_id/index.md\` for the plan's frontmatter and body."
    echo ""
    echo "## Delta to refine"
    echo ""
    echo "See \`archive/$plan_id/delta.md\`."
    echo ""
    echo "## Affected spec areas (from plan \`scope:\`)"

    if [[ -z "$scope" ]]; then
      echo ""
      echo "_The plan declares no \`scope:\` — there are no specs to absorb the delta into._"
    else
      local area area_root area_dir area_index
      while IFS= read -r area; do
        [[ -z "$area" ]] && continue
        area_root="${area%%/*}"
        area_dir="$DOT_LLM_DIR/specs/$area_root"
        area_index="$area_dir/index.md"
        echo ""
        echo "### \`specs/$area_root/\` (referenced by scope: $area)"
        echo ""
        if [[ -f "$area_index" ]]; then
          echo "Current \`specs/$area_root/index.md\`:"
          echo ""
          echo '```markdown'
          cat "$area_index"
          echo '```'
        else
          echo "_(missing on disk: $area_index — bootstrap the area before absorbing)_"
        fi
      done <<< "$scope"
    fi
  } > "$work_file"

  green "✓ archive entry prepared at $archive_dir"
  say "  → Open $work_file and follow the instructions."
  say "  → After absorbing into specs and deleting the work file, run:"
  say "      llm archive finalize $plan_id"
}

cmd_archive_finalize() {
  local plan_id="$1"
  local plan_dir="$DOT_LLM_DIR/plans/$plan_id"
  local archive_dir="$DOT_LLM_DIR/archive/$plan_id"

  if [[ ! -d "$archive_dir" ]]; then
    red "✗ archive entry not found at $archive_dir"
    yellow "  Run 'llm archive $plan_id' (Phase 1) first."
    return 1
  fi

  # The work file must be deleted (LLM has finished absorbing).
  if [[ -f "$archive_dir/temp-archive-flow.delete-me.md" ]]; then
    red "✗ $archive_dir/temp-archive-flow.delete-me.md still exists"
    yellow "  Complete the instructions in that file (refine delta + absorb specs + delete work file),"
    yellow "  then re-run \`llm archive finalize <PLAN-ID>\`."
    return 1
  fi

  # The delta must be finalized (no status:draft).
  local delta_file="$archive_dir/delta.md"
  if [[ -f "$delta_file" ]] && grep -qE '^status:[[:space:]]*draft' "$delta_file"; then
    red "✗ $delta_file still carries 'status: draft' — finalize the wording first"
    return 1
  fi

  # The original delta-draft.md must be gone (LLM should have deleted it).
  if [[ -f "$plan_dir/delta-draft.md" ]]; then
    yellow "  Note: $plan_dir/delta-draft.md still exists. Removing it (already absorbed)."
    rm "$plan_dir/delta-draft.md"
  fi

  # Remove the plan tree.
  if [[ -d "$plan_dir" ]]; then
    rm -rf "$plan_dir"
    green "✓ removed $plan_dir"
  fi
  green "✓ $plan_id archived at $archive_dir"
  say ""
  say "Next: regenerate plans/index.md and archive/index.md (manual edit, or"
  say "wait for 'llm regen-indexes' when it lands)."
}

cmd_archive() {
  local sub="${1:-}"
  case "$sub" in
    "")              red "✗ usage: llm archive <PLAN-ID>  |  llm archive finalize <PLAN-ID>"; return 2 ;;
    -h|--help|help)  cmd_archive_help; return 0 ;;
    finalize)
      shift
      local plan_id="${1:-}"
      [[ -z "$plan_id" ]] && { red "✗ usage: llm archive finalize <PLAN-ID>"; return 2; }
      [[ ! -d "$DOT_LLM_DIR" ]] && { red "✗ $DOT_LLM_DIR not found — run 'llm install' first"; return 1; }
      cmd_archive_finalize "$plan_id"
      return $?
      ;;
    -*)              red "unknown flag: $sub"; cmd_archive_help; return 2 ;;
  esac

  # Default: prepare phase. $sub is the PLAN-ID.
  local plan_id="$sub"
  shift
  if [[ $# -gt 0 ]]; then
    red "✗ unexpected arg: $1"; cmd_archive_help; return 2
  fi

  if [[ ! -d "$DOT_LLM_DIR" ]]; then
    red "✗ $DOT_LLM_DIR not found — run 'llm install' first"
    return 1
  fi

  cmd_archive_prepare "$plan_id"
  return $?
}
