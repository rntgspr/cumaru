# cmd_uninstall.sh — reverse `cumaru install` for a project.
#
# Removes only what `cumaru install` creates: the schema-selected adapter's
# Cumaru-owned commands, skills, durable instructions, and the .cumaru/ tree.
#
# Destructive: prompts before acting. Pass --yes for non-interactive runs
# (an agent or CI has no TTY; without --yes and without a TTY it refuses).
# Idempotent: a second run is a silent no-op.

cmd_uninstall() {
  local target="$CUMARU_DIR" assume_yes=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -y|--yes)        assume_yes=1; shift ;;
      -h|--help|help)  cmd_uninstall_help; return 0 ;;
      -*)              red "unknown flag: $1"; cmd_uninstall_help; return 2 ;;
      *)
        red "unexpected arg: $1"; cmd_uninstall_help; return 2 ;;
    esac
  done
  local parent
  parent=$(dirname "$target")

  # --- discover what exists to remove ---
  local has_target=0
  [[ -d "$target" ]] && has_target=1

  # Validate an existing tree before removing any part of the install footprint.
  local target_abs=""
  if [[ $has_target -eq 1 ]]; then
    target_abs="$(cd "$target" 2>/dev/null && pwd)" || target_abs=""
    if [[ -z "$target_abs" || "$target_abs" == "/" || "$target_abs" == "$HOME" || \
          ! -f "$target/index.md" || ! -f "$target/schema.yaml" ]]; then
      red "✗ refusing to uninstall — $target is not a cumaru install (expected index.md + schema.yaml)"
      return 1
    fi
  fi

  local agent="generic"
  if [[ $has_target -eq 1 ]]; then
    agent=$(_agent_current) || {
      red "✗ invalid agent value in $SCHEMA; refusing to guess uninstall targets"
      return 1
    }
  fi
  local skills_dir commands_dir instructions
  skills_dir=$(_agent_skills_dir "$parent" "$agent")
  commands_dir=$(_agent_commands_dir "$parent" "$agent")
  instructions=$(_agent_instructions_file "$parent" "$agent")

  local has_artifacts=0
  compgen -G "$skills_dir/cumaru-*" >/dev/null && has_artifacts=1
  [[ -n "$commands_dir" && -d "$commands_dir/cumaru" ]] && has_artifacts=1
  [[ -n "$instructions" && -f "$instructions" ]] &&
    grep -qE "BEGIN (CUMARU|DOT-LLM)-HOOK" "$instructions" && has_artifacts=1
  [[ "$agent" == "opencode" && -f "$parent/opencode.json" ]] &&
    jq -e '.instructions | index(".cumaru/index.md") != null' "$parent/opencode.json" >/dev/null 2>&1 &&
    has_artifacts=1

  if [[ $has_target -eq 0 && $has_artifacts -eq 0 ]]; then
    say "Nothing to uninstall — no .cumaru tree or active adapter footprint at $parent."
    return 0
  fi

  # --- summary ---
  echo "cumaru uninstall will remove:"
  [[ $has_target -eq 1 ]] && echo "  - directory: $target"
  echo "  - Cumaru-owned artifacts for adapter: $agent"
  _agent_describe "$parent" "$agent"

  # --- confirm ---
  if [[ $assume_yes -ne 1 ]]; then
    if [[ ! -t 0 ]]; then
      red "✗ refusing to uninstall non-interactively; pass --yes to confirm"
      return 1
    fi
    local answer=""
    read -r -p "Proceed? This cannot be undone. [y/N] " answer
    case "${answer:-N}" in
      [Yy]*) ;;
      *) red "✗ aborted; nothing was removed"; return 1 ;;
    esac
  fi

  # --- act ---
  _agent_remove_adapter "$parent" "$agent" "" || {
    red "✗ failed to remove adapter artifacts; .cumaru was preserved"
    return 1
  }

  if [[ $has_target -eq 1 ]]; then
    rm -rf "$target_abs" && green "  - removed directory: $target"
  fi

  green "✓ uninstalled"
}

# Remove now-empty subdirs under a generic .agents/ adapter.
_uninstall_prune_dirs() {
  local base="$1"
  [[ -d "$base" ]] || return 0
  if [[ -d "$base/commands" ]]; then
    rmdir "$base/commands" 2>/dev/null || true
  fi
  if [[ -d "$base/skills" ]]; then
    rmdir "$base/skills" 2>/dev/null || true
  fi
  rmdir "$base" 2>/dev/null || true
}

# Strip the CUMARU-HOOK block (and the blank line install put before it) from
# a Markdown instruction file. Accepts CUMARU-HOOK and legacy DOT-LLM-HOOK
# marker for backward compatibility. If only install-created boilerplate
# remains (empty, or just the "# Project instructions" header), remove the
# file entirely.
_uninstall_strip_hook() {
  local file="$1"
  local tmp
  tmp=$(mktemp)
  awk '
    { lines[NR] = $0 }
    END {
      b = 0; e = 0
      for (i = 1; i <= NR; i++) {
        if (lines[i] ~ /BEGIN (CUMARU|DOT-LLM)-HOOK/) b = i
        if (lines[i] ~ /END (CUMARU|DOT-LLM)-HOOK/)   e = i
      }
      if (b == 0 || e == 0) { for (i = 1; i <= NR; i++) print lines[i]; exit }
      drop = (b > 1 && lines[b-1] ~ /^[[:space:]]*$/) ? b - 1 : 0
      for (i = 1; i <= NR; i++) {
        if (i >= b && i <= e) continue
        if (i == drop)        continue
        print lines[i]
      }
    }
  ' "$file" > "$tmp"

  local created=0
  grep -Eq "BEGIN (CUMARU|DOT-LLM)-HOOK created" "$file" 2>/dev/null && created=1
  local stripped
  stripped=$(grep -v '^[[:space:]]*$' "$tmp" 2>/dev/null || true)
  if [[ $created -eq 1 && ( -z "$stripped" || "$stripped" == "# Project instructions" ) ]]; then
    rm -f "$file" "$tmp"
    green "  - removed AGENTS.md (install-created, only our content remained): $file"
  else
    mv "$tmp" "$file"
    green "  - removed CUMARU-HOOK block from: $file"
  fi
}

cmd_uninstall_help() {
  cat <<'EOF'
cumaru uninstall — reverse `cumaru install` for a project

Usage:
  cumaru uninstall [--yes]

Options:
  -y, --yes        skip the confirmation prompt (required for non-interactive
                   / agent / CI runs — without a TTY and without --yes it
                   refuses rather than guessing).

What it removes (only what `cumaru install` created):
  1. The .cumaru/ tree.
  2. Cumaru-owned skills and commands from the schema-selected adapter.
  3. The CUMARU-HOOK block in its native instruction file, or Cumaru's exact
     entries from opencode.json. Unrelated project content is preserved.

Idempotent: running it again when nothing is installed is a silent no-op.

Examples:
  cumaru uninstall                     # remove ./.cumaru + active adapter footprint
  cumaru uninstall --yes               # same, no prompt (agent/CI)
EOF
}
