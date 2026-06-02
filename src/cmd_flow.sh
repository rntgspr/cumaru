# cmd_flow.sh — safe mechanical file ops inside .cumaru/.
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
#   <src> and <dst> are relative to CUMARU_DIR (the .cumaru/ tree root).
#   `..` segments are NOT allowed — write the clean path from the root.
#
# Guardrails:
#   1. all paths must resolve inside .cumaru/ after resolving symlinked parents.
#   2. files must end in `.md`; directory names must not contain dots.
#   3. `remove` refuses if the target is literally named `index.md`.
#   4. `remove` refuses if the target is a direct child of .cumaru/ (pillar root).
#
# Expects from the entry-point: CUMARU_DIR.

cmd_flow_help() {
  cat <<'EOF'
cumaru flow — safe file ops inside .cumaru/ (the LLM composes recipes via skills)

Usage:
  cumaru flow <src> move <dst>
  cumaru flow <src> copy <dst>
  cumaru flow <path> create
  cumaru flow <path> remove

Paths are relative to .cumaru/. No `..` segments — write the full path from the
.cumaru/ root. Files must be .md; directory names must not contain dots.

Safety:
  - `remove` refuses to delete a file literally named `index.md`.
  - `remove` refuses to delete a pillar root (a direct child of .cumaru/).
  - All paths must resolve inside .cumaru/.

Examples:
  cumaru flow plans/AAA-1234/delta-draft.md move    archive/AAA-1234/delta.md
  cumaru flow plans/AAA-1234/handoff-t1.md   copy    archive/AAA-1234/handoff-t1.md
  cumaru flow exploring/auth-redesign       create
  cumaru flow exploring/auth-redesign/index.md create
  cumaru flow plans/AAA-1234                remove
EOF
}

# Reject absolute paths and `.` / `..` segments. Canonical containment is
# checked separately after the .cumaru/ root is resolved.
_flow_check_path() {
  local p="$1" label="$2"
  [[ -n "$p" ]]      || { red "✗ missing $label"; return 2; }
  [[ "$p" != /* ]]   || { red "✗ $label must be relative to .cumaru/ (no leading /): $p"; return 1; }
  if printf '%s\n' "$p" | tr '/' '\n' | grep -qE '^\.{1,2}$'; then
    red "✗ '.' / '..' segments not allowed in $label (use a clean path from .cumaru/ root): $p"
    return 1
  fi
  return 0
}

# Resolve a path that may not exist yet by canonicalizing its nearest existing
# ancestor, then re-appending the missing suffix. Direct symlink targets are
# rejected so move/copy/remove semantics cannot vary by platform.
_flow_resolve_inside() {
  local cumaru_abs="$1" rel="$2" label="$3"
  local candidate="$cumaru_abs/$rel"
  local probe="$candidate" suffix="" parent resolved

  if [[ -L "$candidate" ]]; then
    red "✗ symlink targets are not supported in $label: $rel" >&2
    return 1
  fi

  while [[ ! -e "$probe" && ! -L "$probe" ]]; do
    suffix="/$(basename "$probe")$suffix"
    parent=$(dirname "$probe")
    [[ "$parent" != "$probe" ]] || {
      red "✗ cannot resolve $label inside .cumaru/: $rel" >&2
      return 1
    }
    probe="$parent"
  done

  if [[ -d "$probe" ]]; then
    resolved="$(cd "$probe" 2>/dev/null && pwd -P)" || {
      red "✗ cannot resolve $label inside .cumaru/: $rel" >&2
      return 1
    }
  else
    parent="$(cd "$(dirname "$probe")" 2>/dev/null && pwd -P)" || {
      red "✗ cannot resolve $label inside .cumaru/: $rel" >&2
      return 1
    }
    resolved="$parent/$(basename "$probe")"
  fi
  resolved+="$suffix"

  if [[ "$resolved" != "$cumaru_abs"/* ]]; then
    red "✗ $label resolves outside .cumaru/: $rel" >&2
    return 1
  fi
  printf '%s\n' "$resolved"
}

# Validate the syntactic file/directory contract for every path segment.
# File paths end in .md; every segment before the file, or every segment of a
# directory path, is a directory name and therefore cannot contain a dot.
_flow_check_shape() {
  local p="$1" kind="$2" label="$3"
  local dir_path="$p"
  if [[ "$kind" == "file" ]]; then
    [[ "$p" == *.md ]] || { red "✗ $label file must end in .md: $p"; return 1; }
    dir_path=$(dirname "$p")
    [[ "$dir_path" == "." ]] && return 0
  fi

  local segment
  while IFS= read -r segment; do
    [[ "$segment" == *.* ]] || continue
    red "✗ directory names must not contain dots in $label: $segment"
    return 1
  done < <(printf '%s\n' "$dir_path" | tr '/' '\n')
  return 0
}

cmd_flow() {
  case "${1:-}" in
    help|-h|--help) cmd_flow_help; return 0 ;;
  esac
  if [[ $# -lt 2 ]]; then
    red "✗ usage: cumaru flow <src> <verb> [<dst>]"
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

  local cumaru_abs
  cumaru_abs=$(cd "$CUMARU_DIR" 2>/dev/null && pwd -P) || {
    red "✗ .cumaru/ not found — run 'cumaru install' first"
    return 1
  }

  local src_canon dst_canon=""
  src_canon=$(_flow_resolve_inside "$cumaru_abs" "$src" "<src>") || return $?
  if [[ -n "$dst" ]]; then
    dst_canon=$(_flow_resolve_inside "$cumaru_abs" "$dst" "<dst>") || return $?
  fi

  # `create` is the only verb where src may not exist yet. The .md suffix
  # selects file creation; otherwise the path is a directory.
  if [[ "$verb" == "create" ]]; then
    if [[ -e "$src_canon" ]]; then
      yellow "⚠ already exists (no-op): $src"
      return 0
    fi
    if [[ "$src" == *.md ]]; then
      _flow_check_shape "$src" file "<path>" || return $?
      mkdir -p "$(dirname "$src_canon")" && : > "$src_canon"
      green "✓ create: $src (file)"
    else
      _flow_check_shape "$src" dir "<path>" || return $?
      mkdir -p "$src_canon"
      green "✓ create: $src/ (dir)"
    fi
    return 0
  fi

  [[ -e "$src_canon" ]] || { red "✗ source not found: $src"; return 1; }

  # Validate the existing source and the destination shape before mutation.
  if [[ -f "$src_canon" ]]; then
    _flow_check_shape "$src" file "<src>" || return $?
    [[ -z "$dst" ]] || { _flow_check_shape "$dst" file "<dst>" || return $?; }
  elif [[ -d "$src_canon" ]]; then
    _flow_check_shape "$src" dir "<src>" || return $?
    [[ -z "$dst" ]] || { _flow_check_shape "$dst" dir "<dst>" || return $?; }
  fi

  case "$verb" in
    remove)
      local base parent
      base=$(basename "$src_canon")
      parent=$(dirname "$src_canon")
      [[ "$base" == "index.md" ]] && {
        red "✗ cannot remove an index.md (system-critical for the entity)"
        return 1
      }
      if [[ "$parent" == "$cumaru_abs" && -d "$src_canon" ]]; then
        red "✗ cannot remove a pillar root: $src/"
        return 1
      fi
      rm -rf "$src_canon"
      green "✓ remove: $src"
      ;;
    move)
      [[ -e "$dst_canon" ]] && { red "✗ destination already exists: $dst"; return 1; }
      mkdir -p "$(dirname "$dst_canon")"
      mv "$src_canon" "$dst_canon"
      green "✓ move: $src → $dst"
      ;;
    copy)
      [[ -e "$dst_canon" ]] && { red "✗ destination already exists: $dst"; return 1; }
      mkdir -p "$(dirname "$dst_canon")"
      cp -R "$src_canon" "$dst_canon"
      green "✓ copy: $src → $dst"
      ;;
  esac
}
