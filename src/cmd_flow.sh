# cmd_flow.sh — safe mechanical file ops inside .llm/.
#
# Bash is mechanical here; workflows (archive, finalize, etc.) live in skills.
# The LLM composes flow calls via the skill to enact recipes. No content
# mutation, no workflow knowledge in the script.
#
# Verbs:
#   move    <src> <dst>   move (or rename) a file/dir
#   copy    <src> <dst>   copy a file/dir
#   create  <path>        create an empty dir; if <path> ends in `.md`, a file
#   remove  <path>        delete a file/dir
#
# Path semantics:
#   <src> and <dst> are relative to DOT_LLM_DIR (the .llm/ tree root).
#   `..` segments are NOT allowed — write the clean path from the root.
#
# Guardrails:
#   1. all paths must resolve inside .llm/ (the `..` ban above enforces this).
#   2. any file path manipulated must end in `.md`.
#   3. `remove` refuses if the target is literally named `index.md`.
#   4. `remove` refuses if the target is a direct child of .llm/ (pillar root).
#
# Expects from the entry-point: DOT_LLM_DIR.

cmd_flow_help() {
  cat <<'EOF'
llm flow — safe file ops inside .llm/ (the LLM composes recipes via skills)

Usage:
  llm flow <src> move <dst>
  llm flow <src> copy <dst>
  llm flow <path> create
  llm flow <path> remove

Paths are relative to .llm/. No `..` segments — write the full path from the
.llm/ root. Files must be .md; directories are free.

Safety:
  - `remove` refuses to delete a file literally named `index.md`.
  - `remove` refuses to delete a pillar root (a direct child of .llm/).
  - All paths must resolve inside .llm/.

Examples:
  llm flow plans/JET-1234/delta-draft.md move    archive/JET-1234/delta.md
  llm flow plans/JET-1234/handoff-t1.md   copy    archive/JET-1234/handoff-t1.md
  llm flow exploring/auth-redesign       create
  llm flow exploring/auth-redesign/index.md create
  llm flow plans/JET-1234                remove
EOF
}

# Reject absolute paths and `..` segments. The `..` ban makes "stays inside .llm/"
# a syntactic property — no realpath / canonicalization needed.
_flow_check_path() {
  local p="$1" label="$2"
  [[ -n "$p" ]]      || { red "✗ missing $label"; return 2; }
  [[ "$p" != /* ]]   || { red "✗ $label must be relative to .llm/ (no leading /): $p"; return 1; }
  if printf '%s\n' "$p" | tr '/' '\n' | grep -qFx ..; then
    red "✗ '..' not allowed in $label (use a clean path from .llm/ root): $p"
    return 1
  fi
  return 0
}

cmd_flow() {
  case "${1:-}" in
    help|-h|--help) cmd_flow_help; return 0 ;;
  esac
  if [[ $# -lt 2 ]]; then
    red "✗ usage: llm flow <src> <verb> [<dst>]"
    cmd_flow_help
    return 2
  fi

  local src="$1" verb="$2" dst="${3:-}"

  case "$verb" in
    move|copy)
      [[ -n "$dst" ]] || { red "✗ $verb requires <dst>"; return 2; }
      [[ $# -eq 3 ]]  || { red "✗ too many arguments"; return 2; }
      ;;
    create|remove)
      [[ -z "$dst" ]] || { red "✗ $verb takes no <dst>"; return 2; }
      ;;
    *)
      red "✗ unknown verb: $verb (expected: move | copy | create | remove)"
      return 2
      ;;
  esac

  _flow_check_path "$src" "<src>" || return $?
  [[ -n "$dst" ]] && { _flow_check_path "$dst" "<dst>" || return $?; }

  local llm_abs
  llm_abs=$(cd "$DOT_LLM_DIR" 2>/dev/null && pwd) || {
    red "✗ DOT_LLM_DIR not found: $DOT_LLM_DIR"
    return 1
  }
  local src_abs="$llm_abs/$src" dst_abs=""
  [[ -n "$dst" ]] && dst_abs="$llm_abs/$dst"

  # `create` is the only verb where src may not exist yet. Naming rule for the
  # leaf: ends in `.md` → file; has NO extension → dir; any other extension
  # (e.g. `.txt`, `.yaml`) is refused — flow only handles .md files and dirs.
  if [[ "$verb" == "create" ]]; then
    if [[ -e "$src_abs" ]]; then
      yellow "⚠ already exists (no-op): $src"
      return 0
    fi
    local leaf
    leaf=$(basename "$src")
    if [[ "$leaf" == *.md ]]; then
      mkdir -p "$(dirname "$src_abs")" && : > "$src_abs"
      green "✓ create: $src (file)"
    elif [[ "$leaf" == *.* ]]; then
      red "✗ files must be .md (got '$leaf') — dirs must have no extension"
      return 1
    else
      mkdir -p "$src_abs"
      green "✓ create: $src/ (dir)"
    fi
    return 0
  fi

  [[ -e "$src_abs" ]] || { red "✗ source not found: $src"; return 1; }

  # Files must be .md (dirs are free).
  if [[ -f "$src_abs" ]]; then
    [[ "$src" == *.md ]] || { red "✗ files must be .md: $src"; return 1; }
    [[ -z "$dst" || "$dst" == *.md ]] || { red "✗ destination must also be .md: $dst"; return 1; }
  fi

  case "$verb" in
    remove)
      local base parent
      base=$(basename "$src_abs")
      parent=$(dirname "$src_abs")
      [[ "$base" == "index.md" ]] && {
        red "✗ cannot remove an index.md (system-critical for the entity)"
        return 1
      }
      if [[ "$parent" == "$llm_abs" && -d "$src_abs" ]]; then
        red "✗ cannot remove a pillar root: $src/"
        return 1
      fi
      rm -rf "$src_abs"
      green "✓ remove: $src"
      ;;
    move)
      [[ -e "$dst_abs" ]] && { red "✗ destination already exists: $dst"; return 1; }
      mkdir -p "$(dirname "$dst_abs")"
      mv "$src_abs" "$dst_abs"
      green "✓ move: $src → $dst"
      ;;
    copy)
      [[ -e "$dst_abs" ]] && { red "✗ destination already exists: $dst"; return 1; }
      mkdir -p "$(dirname "$dst_abs")"
      cp -R "$src_abs" "$dst_abs"
      green "✓ copy: $src → $dst"
      ;;
  esac
}
