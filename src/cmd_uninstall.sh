# cmd_uninstall.sh — reverse `cumaru install` for a project.
#
# Removes only what `cumaru install` creates, in reverse order:
#   1. .agents/commands/cumaru/ — the entire dir. The `cumaru` subdir
#      is the framework namespace; everything inside is ours. Adopter-
#      authored commands at other paths (or other namespaces) are not
#      touched.
#   2. .agents/skills/cumaru-*/ — the `cumaru-` prefix is the
#      skill namespace marker; same ownership rule.
#   3. .agents/hooks/ — framework hook scripts.
#   4. the UserPromptSubmit context hook in .agents/hooks.json.
#   5. the <!-- BEGIN/END CUMARU-HOOK --> block (or the legacy DOT-LLM-HOOK)
#      in .agents/AGENTS.md, plus the single blank line install inserted before
#      it. The file is removed entirely when nothing but the install-created
#      header remains.
#   6. the <target> tree (.cumaru/).
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
  local parent agents_dir agents_md hooks_json
  parent=$(dirname "$target")
  agents_dir="$parent/$AGENTS_DIR"
  agents_md="$agents_dir/AGENTS.md"
  hooks_json="$agents_dir/hooks.json"

  # --- discover what exists to remove ---
  local has_target=0 has_agents_hook=0 has_context_hook=0
  [[ -d "$target" ]] && has_target=1
  [[ -f "$agents_md" ]] && (grep -q "BEGIN CUMARU-HOOK" "$agents_md" || grep -q "BEGIN DOT-LLM-HOOK" "$agents_md") && has_agents_hook=1
  [[ -f "$hooks_json" ]] && grep -q "context-loader" "$hooks_json" && has_context_hook=1

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

  # Framework-owned namespaces under .agents/:
  #   commands/cumaru/ — the `cumaru` subdir is the framework namespace
  #   skills/cumaru-*/ — the `cumaru-` prefix marks these as ours
  #   hooks/ — framework hook scripts
  local removable_cmds_dir="$agents_dir/commands/cumaru"
  [[ -d "$removable_cmds_dir" ]] || removable_cmds_dir=""

  local removable_skill_dirs=()
  local skill_dir
  for skill_dir in "$agents_dir/skills"/cumaru-*/; do
    [[ -d "$skill_dir" ]] || continue
    removable_skill_dirs+=("${skill_dir%/}")
  done

  local removable_hooks_dir="$agents_dir/hooks"
  [[ -d "$removable_hooks_dir" ]] || removable_hooks_dir=""

  if [[ $has_target -eq 0 && $has_agents_hook -eq 0 && $has_context_hook -eq 0 && \
        -z "$removable_cmds_dir" && ${#removable_skill_dirs[@]} -eq 0 && -z "$removable_hooks_dir" ]]; then
    say "Nothing to uninstall — no .cumaru tree, no .agents/ install footprint at $parent."
    return 0
  fi

  # --- summary ---
  echo "cumaru uninstall will remove:"
  [[ $has_target -eq 1 ]] && echo "  - directory: $target"
  [[ $has_agents_hook -eq 1 ]] && echo "  - CUMARU-HOOK block in: $agents_md"
  [[ $has_context_hook -eq 1 ]] && echo "  - context hook in: $hooks_json"
  [[ -n "$removable_cmds_dir" ]] && echo "  - commands: $removable_cmds_dir/"
  for d in "${removable_skill_dirs[@]+"${removable_skill_dirs[@]}"}"; do echo "  - skill: $d"; done
  [[ -n "$removable_hooks_dir" ]] && echo "  - hooks: $removable_hooks_dir/"

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
  if [[ -n "$removable_cmds_dir" ]]; then
    rm -rf "$removable_cmds_dir" && green "  - removed commands: $removable_cmds_dir/"
  fi
  for d in "${removable_skill_dirs[@]+"${removable_skill_dirs[@]}"}"; do
    rm -rf "$d" && green "  - removed skill: $d"
  done
  if [[ -n "$removable_hooks_dir" ]]; then
    rm -rf "$removable_hooks_dir" && green "  - removed hooks: $removable_hooks_dir/"
  fi
  if [[ $has_context_hook -eq 1 ]]; then
    _uninstall_strip_context_hook "$hooks_json"
  fi
  _uninstall_prune_dirs "$agents_dir"

  if [[ $has_agents_hook -eq 1 ]]; then
    _uninstall_strip_hook "$agents_md"
  fi

  if [[ $has_target -eq 1 ]]; then
    rm -rf "$target_abs" && green "  - removed directory: $target"
  fi

  green "✓ uninstalled"
}

# Remove now-empty subdirs under .agents/.
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
# .agents/AGENTS.md. Accepts both CUMARU-HOOK and the legacy DOT-LLM-HOOK
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

# Remove only the install-managed UserPromptSubmit command that points to the
# context loader under .agents/. Other hooks and settings remain untouched.
_uninstall_strip_context_hook() {
  local file="$1"
  command -v jq >/dev/null 2>&1 || { red "✗ jq is required to remove context hook from $file"; return 1; }
  local tmp
  tmp=$(mktemp)
  jq '
    if .hooks.UserPromptSubmit then
      .hooks.UserPromptSubmit |= (
        map(
          .hooks = ((.hooks // []) | map(select((.command // "" | contains("context-loader")) | not)))
        )
        | map(select((.hooks // []) | length > 0))
      )
    else
      .
    end |
    if (.hooks.UserPromptSubmit? // [] | length) == 0 then
      del(.hooks.UserPromptSubmit)
    else
      .
    end |
    if (.hooks? // {} | length) == 0 then
      del(.hooks)
    else
      .
    end
  ' "$file" > "$tmp"

  if [[ "$(jq 'length' "$tmp")" == "0" ]]; then
    rm -f "$file" "$tmp"
  else
    mv "$tmp" "$file"
  fi
  green "  - removed context hook from: $file"
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
  2. The .agents/commands/cumaru/ dir — the `cumaru` subdir is the framework
     namespace; every command inside is ours. Adopter-authored commands at
     other paths are NEVER touched.
  3. Every .agents/skills/cumaru-*/ dir — the `cumaru-` prefix is the skill
     namespace marker. Opt-ins (any skill without the `cumaru-` prefix) and
     adopter-authored skills are NEVER touched.
  4. The .agents/hooks/ dir — framework hook scripts.
  5. The UserPromptSubmit context hook in .agents/hooks.json when it points
     to the context loader.
   6. The <!-- BEGIN/END CUMARU-HOOK --> block (or legacy DOT-LLM-HOOK)
      in .agents/AGENTS.md (and the file itself if only install-created
      boilerplate remains).

Idempotent: running it again when nothing is installed is a silent no-op.

Examples:
  cumaru uninstall                     # remove ./.cumaru + .agents/ install footprint
  cumaru uninstall --yes               # same, no prompt (agent/CI)
EOF
}
