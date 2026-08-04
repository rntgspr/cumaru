# cmd_map.sh - read-only level-two Markdown heading projection for .cumaru/.

# Print the public command help without requiring an installed project.
cmd_map_help() {
  cat <<'EOF'
cumaru map - list level-two Markdown headings inside .cumaru/

Usage:
  cumaru map [<directory-or-md>] [--rows]
             [--pillars <name[,name...]>] [--domain <name>]

Paths are relative to .cumaru/. Omit the target to recursively inspect the
whole tree. A Markdown file target maps that exact file. Directories map every
non-hidden Markdown descendant. Absolute paths, `..` segments, hidden paths,
non-Markdown file targets, symlinks, and control-character paths are rejected.
Recursive traversal reports every unsafe descendant, emits rows from safe
files, and returns a runtime error.

Output:
  (default)  path:line:## heading, compatible with rg -n style output
  --rows     path<TAB>line<TAB>heading TSV

Filters:
  --pillars  restrict results to comma-separated schema-declared pillars
  --domain   require the installed config domain to match <name>

Requirements:
  ripgrep (`rg`) on PATH

Diagnostics go to stderr. This command never modifies the project.

Exit codes:
  0  success
  1  runtime or path validation error
  2  usage error
EOF
}

# Record one map traversal defect without interrupting the remaining walk.
_map_diag() {
  local path="$1" message="$2"
  printf 'cumaru map: %s: %s\n' "$(_tree_quote_path "$path")" "$message" >&2
  _MAP_ERRORS=$((_MAP_ERRORS + 1))
}

# Inspect one directory scope without following links and retain only safe
# regular Markdown files for the later ripgrep invocation.
_map_collect_scope() {
  local root="$1" scope="$2" files="$3" walk="$4" find_errors="$5"
  local path rel canonical base

  if ! find "$scope" \
    \( ! -path "$scope" -a -name '.*' \) -prune -o \
    \( ! -path "$scope" -print0 \) > "$walk" 2> "$find_errors"; then
    _map_diag "${scope#"$root"/}" "could not completely inspect directory"
  fi

  while IFS= read -r -d '' path; do
    rel="${path#"$root"/}"

    if [[ -L "$path" ]]; then
      _map_diag "$rel" "symlinks are not supported"
      _tree_path_has_control "$rel" && _map_diag "$rel" "path contains a control character"
      continue
    fi
    if _tree_path_has_control "$rel"; then
      _map_diag "$rel" "path contains a control character"
      continue
    fi

    if [[ -d "$path" ]]; then
      if _tree_has_symlink_component "$root" "$path" ||
         ! canonical=$(_tree_canonicalize "$root" "$path" dir); then
        _map_diag "$rel/" "directory does not resolve safely inside .cumaru/"
      fi
      continue
    fi

    base=$(basename "$path")
    [[ -f "$path" && "$base" == *.md ]] || continue
    if _tree_has_symlink_component "$root" "$path" ||
       ! canonical=$(_tree_canonicalize "$root" "$path" file); then
      _map_diag "$rel" "file does not resolve safely inside .cumaru/"
      continue
    fi
    printf '%s\n' "$rel" >> "$files"
  done < "$walk"
}

# Run ripgrep only over prevalidated files. Ripgrep sorts C-locale paths while
# preserving numeric source order inside each file.
_map_with_rg() {
  local root="$1" target="$2" kind="$3" rows="$4"
  local temp files walk find_errors matches status=0 scope candidate canonical
  local scopes=() safe_files=()

  temp=$(mktemp -d "${TMPDIR:-/tmp}/cumaru-map.XXXXXX") || {
    printf 'cumaru map: cannot create temporary traversal state\n' >&2
    return 1
  }
  files="$temp/files"
  walk="$temp/walk"
  find_errors="$temp/find-errors"
  matches="$temp/matches"
  : > "$files"
  _MAP_ERRORS=0

  if [[ "$kind" == "file" ]]; then
    printf '%s\n' "$target" >> "$files"
  else
    if [[ -n "${_TREE_PILLARS:-}" && "$target" == "." ]]; then
      IFS=',' read -r -a scopes <<< "$_TREE_PILLARS"
    else
      scopes=("$target")
    fi

    for scope in "${scopes[@]}"; do
      candidate="$root"
      [[ "$scope" == "." ]] || candidate="$root/$scope"
      canonical=$(_tree_canonicalize "$root" "$candidate" dir) || {
        _map_diag "$scope" "directory does not resolve safely inside .cumaru/"
        continue
      }
      _map_collect_scope "$root" "$canonical" "$files" "$walk" "$find_errors"
    done
  fi

  while IFS= read -r candidate; do
    safe_files+=("$candidate")
  done < "$files"

  if [[ ${#safe_files[@]} -gt 0 ]]; then
    (
      cd "$root" || exit 1
      LC_ALL=C rg --sort path --with-filename --no-heading --line-number \
        '^## ' -- "${safe_files[@]}"
    ) > "$matches"
    status=$?
    [[ $status -eq 1 ]] && status=0

    if [[ "$rows" == "1" ]]; then
      sed -E $'s@^(.+):([0-9]+):## (.*)$@\\1\t\\2\t\\3@' "$matches"
    else
      cat "$matches"
    fi
  fi

  [[ $_MAP_ERRORS -eq 0 ]] || status=1
  rm -rf "$temp"
  return "$status"
}

# Parse, validate, and map the requested regular Markdown scope without writes.
cmd_map() {
  local target="" rows=0 requested_pillars="" requested_domain="" arg
  while [[ $# -gt 0 ]]; do
    arg="$1"
    case "$arg" in
      -h|--help|help) cmd_map_help; return 0 ;;
      --rows) rows=1 ;;
      --pillars)
        shift
        [[ $# -gt 0 && "${1:-}" != -* ]] || { printf 'cumaru map: --pillars requires a value\n' >&2; return 2; }
        requested_pillars="$1"
        ;;
      --pillars=*)
        requested_pillars="${arg#*=}"
        [[ -n "$requested_pillars" ]] || { printf 'cumaru map: --pillars requires a value\n' >&2; return 2; }
        ;;
      --domain)
        shift
        [[ $# -gt 0 && "${1:-}" != -* ]] || { printf 'cumaru map: --domain requires a value\n' >&2; return 2; }
        requested_domain="$1"
        ;;
      --domain=*)
        requested_domain="${arg#*=}"
        [[ -n "$requested_domain" ]] || { printf 'cumaru map: --domain requires a value\n' >&2; return 2; }
        ;;
      -*) printf 'cumaru map: unknown option: %s\n' "$arg" >&2; cmd_map_help >&2; return 2 ;;
      *)
        [[ -z "$target" ]] || { printf 'cumaru map: expected at most one target\n' >&2; cmd_map_help >&2; return 2; }
        target="$arg"
        ;;
    esac
    shift
  done

  [[ -n "$target" ]] || target="."
  while [[ "$target" != "/" && "$target" == */ ]]; do target="${target%/}"; done
  [[ -n "$target" ]] || target="."
  _tree_validate_target_syntax "$target" || return 1

  command -v rg >/dev/null 2>&1 || {
    printf 'cumaru map: ripgrep (rg) is required\n' >&2
    return 1
  }

  [[ ! -L "$CUMARU_DIR" && -d "$CUMARU_DIR" ]] || { printf 'cumaru map: .cumaru/ not found or is a symlink\n' >&2; return 1; }
  local _TREE_PILLARS=""
  if [[ -n "$requested_domain" || -n "$requested_pillars" ]]; then
    _tree_check_yq || return 1
    _tree_validate_filters "$CONFIG" "$requested_domain" "$requested_pillars" || return 1
  fi
  if [[ "$target" != "." && -n "$_TREE_PILLARS" ]] && ! _tree_path_matches_pillars "$target"; then
    printf 'cumaru map: target is outside the selected pillars: %s\n' "$(_tree_quote_path "$target")" >&2
    return 1
  fi

  local root candidate canonical kind
  root=$(cd "$CUMARU_DIR" 2>/dev/null && pwd -P) || { printf 'cumaru map: cannot resolve .cumaru/\n' >&2; return 1; }
  candidate="$root"
  [[ "$target" == "." ]] || candidate="$root/$target"
  _tree_has_symlink_component "$root" "$candidate" && { printf 'cumaru map: target contains a symlink: %s\n' "$(_tree_quote_path "$target")" >&2; return 1; }

  if [[ -d "$candidate" ]]; then
    kind=dir
  elif [[ -f "$candidate" && "$target" == *.md ]]; then
    kind=file
  elif [[ -f "$candidate" ]]; then
    printf 'cumaru map: file target must end in .md: %s\n' "$(_tree_quote_path "$target")" >&2
    return 1
  else
    printf 'cumaru map: target not found or unsupported: %s\n' "$(_tree_quote_path "$target")" >&2
    return 1
  fi
  canonical=$(_tree_canonicalize "$root" "$candidate" "$kind") || { printf 'cumaru map: target does not resolve safely inside .cumaru/: %s\n' "$(_tree_quote_path "$target")" >&2; return 1; }

  _map_with_rg "$root" "$target" "$kind" "$rows"
}
