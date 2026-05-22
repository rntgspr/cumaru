# cmd_uninstall.sh — reverse `llm install` for a project.
#
# Removes only what `llm install` creates, in reverse order:
#   1. the slash commands it copied — but ONLY when byte-identical to the
#      source in COMMANDS_SRC. User-modified commands are kept (mirrors
#      install's skip-if-exists), so local edits are never destroyed.
#   2. the <!-- BEGIN/END DOT-LLM-HOOK --> block in <parent>/CLAUDE.md, plus
#      the single blank line install inserted before it. The file is removed
#      entirely when nothing but the install-created header remains.
#   3. the <target> tree (.llm/).
#
# Destructive: prompts before acting. Pass --yes for non-interactive runs
# (an agent or CI has no TTY; without --yes and without a TTY it refuses).
# Idempotent: a second run is a silent no-op.
#
# Expects from entry-point: COMMANDS_SRC.

cmd_uninstall() {
  local target="" assume_yes=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -y|--yes)        assume_yes=1; shift ;;
      -h|--help|help)  cmd_uninstall_help; return 0 ;;
      -*)              red "unknown flag: $1"; cmd_uninstall_help; return 2 ;;
      *)
        if [[ -z "$target" ]]; then target="$1"; else red "unexpected arg: $1"; return 2; fi
        shift ;;
    esac
  done
  : "${target:=./.llm}"
  local parent claude_md
  parent=$(dirname "$target")
  claude_md="$parent/CLAUDE.md"

  # --- discover what exists to remove ---
  local has_target=0 has_hook=0
  [[ -d "$target" ]] && has_target=1
  [[ -f "$claude_md" ]] && grep -q "BEGIN DOT-LLM-HOOK" "$claude_md" && has_hook=1

  local removable_cmds=() kept_cmds=()
  if [[ -d "$COMMANDS_SRC" ]]; then
    local cmd_file rel dest
    while IFS= read -r -d '' cmd_file; do
      rel="${cmd_file#"$COMMANDS_SRC"/}"
      dest="$parent/.claude/commands/$rel"
      [[ -f "$dest" ]] || continue
      if cmp -s "$cmd_file" "$dest"; then
        removable_cmds+=("$dest")
      else
        kept_cmds+=("$dest")
      fi
    done < <(find "$COMMANDS_SRC" -type f -name '*.md' -print0)
  fi

  if [[ $has_target -eq 0 && $has_hook -eq 0 && ${#removable_cmds[@]} -eq 0 ]]; then
    say "Nothing to uninstall — no .llm tree, no CLAUDE.md hook, no install-managed commands at $parent."
    return 0
  fi

  # --- summary ---
  echo "llm uninstall will remove:"
  [[ $has_target -eq 1 ]] && echo "  - directory: $target"
  [[ $has_hook   -eq 1 ]] && echo "  - DOT-LLM-HOOK block in: $claude_md"
  local d
  for d in "${removable_cmds[@]+"${removable_cmds[@]}"}"; do echo "  - command: $d"; done
  for d in "${kept_cmds[@]+"${kept_cmds[@]}"}";      do yellow "  · keeping (modified, not install's): $d"; done

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

  # --- act (reverse order of install) ---
  for d in "${removable_cmds[@]+"${removable_cmds[@]}"}"; do
    rm -f "$d" && green "  - removed command: $d"
  done
  _uninstall_prune_dirs "$parent"

  if [[ $has_hook -eq 1 ]]; then
    _uninstall_strip_hook "$claude_md"
  fi

  if [[ $has_target -eq 1 ]]; then
    rm -rf "$target" && green "  - removed directory: $target"
  fi

  green "✓ uninstalled"
}

# Remove now-empty command namespace dirs, then .claude/commands/ and .claude/
# itself when empty. rmdir fails safe on non-empty dirs (other tooling kept).
_uninstall_prune_dirs() {
  local base="$1/.claude"
  [[ -d "$base/commands" ]] || return 0
  find "$base/commands" -depth -type d -empty -exec rmdir {} + 2>/dev/null || true
  rmdir "$base/commands" 2>/dev/null || true
  rmdir "$base"          2>/dev/null || true
}

# Strip the DOT-LLM-HOOK block (and the blank line install put before it) from
# CLAUDE.md. If only install-created boilerplate remains (empty, or just the
# "# Project instructions" header), remove the file entirely.
_uninstall_strip_hook() {
  local file="$1"
  local tmp
  tmp=$(mktemp)
  awk '
    { lines[NR] = $0 }
    END {
      b = 0; e = 0
      for (i = 1; i <= NR; i++) {
        if (lines[i] ~ /BEGIN DOT-LLM-HOOK/) b = i
        if (lines[i] ~ /END DOT-LLM-HOOK/)   e = i
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

  local stripped
  stripped=$(grep -v '^[[:space:]]*$' "$tmp" 2>/dev/null || true)
  if [[ -z "$stripped" || "$stripped" == "# Project instructions" ]]; then
    rm -f "$file" "$tmp"
    green "  - removed CLAUDE.md (only install-created content remained): $file"
  else
    mv "$tmp" "$file"
    green "  - removed DOT-LLM-HOOK block from: $file"
  fi
}

cmd_uninstall_help() {
  cat <<'EOF'
llm uninstall — reverse `llm install` for a project

Usage:
  llm uninstall [TARGET] [--yes]

Arguments:
  TARGET           the .llm directory to remove (default: ./.llm).

Options:
  -y, --yes        skip the confirmation prompt (required for non-interactive
                   / agent / CI runs — without a TTY and without --yes it
                   refuses rather than guessing).

What it removes (only what `llm install` created):
  1. Slash commands under <parent>/.claude/commands/ that are byte-identical
     to the source. User-modified commands are KEPT and reported.
  2. The <!-- BEGIN/END DOT-LLM-HOOK --> block in <parent>/CLAUDE.md (and the
     file itself if only install-created boilerplate remains).
  3. The TARGET tree (.llm/).

Idempotent: running it again when nothing is installed is a silent no-op.

Examples:
  llm uninstall                     # remove ./.llm + its install footprint
  llm uninstall --yes               # same, no prompt (agent/CI)
  llm uninstall /path/.llm --yes    # custom target
EOF
}
