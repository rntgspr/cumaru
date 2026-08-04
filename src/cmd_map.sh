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
non-Markdown file targets, and symlinks are rejected.

Output:
  (default)  path:line:## heading, compatible with rg -n style output
  --rows     path<TAB>line<TAB>heading TSV

Filters:
  --pillars  restrict results to comma-separated schema-declared pillars
  --domain   require the installed config domain to match <name>

Diagnostics go to stderr. This command never modifies the project.

Exit codes:
  0  success
  1  runtime or path validation error
  2  usage error
EOF
}

# Emit one tab-separated record for every level-two heading when ripgrep is absent.
_map_file_headings() {
  local file="$1" rel="$2" records="$3"
  awk -v path="$rel" '
    NR == 1 && $0 == "---" { frontmatter = 1; next }
    frontmatter {
      if ($0 == "---" || $0 == "...") frontmatter = 0
      next
    }
    /^```/ || /^~~~/ { fenced = !fenced; next }
    !fenced && /^## / { print path "\t" FNR "\t" substr($0, 4) }
  ' "$file" >> "$records"
}

# Use ripgrep's indexed recursive search for the fast path, preserving its
# literal line-matching semantics and the command's root-relative output.
_map_with_rg() {
  local root="$1" target="$2" rows="$3" scopes=() scope
  if [[ -n "${_TREE_PILLARS:-}" && "$target" == "." ]]; then
    IFS=',' read -r -a scopes <<< "$_TREE_PILLARS"
  else
    scopes=("$target")
  fi
  (
    cd "$root" || exit 1
    LC_ALL=C rg --with-filename --no-heading --line-number --hidden --no-ignore \
      --glob '*.md' --glob '!**/.*' '^## ' "${scopes[@]}" 2>/dev/null || {
        status=$?
        [[ $status -eq 1 ]] && exit 0
        exit "$status"
      }
  ) | LC_ALL=C sort | {
    if [[ "$rows" == "1" ]]; then
      sed -E -e 's@^\./@@' -e $'s@^(.+):([0-9]+):## (.*)$@\\1\t\\2\t\\3@'
    else
      sed -E 's#^\./##'
    fi
  }
}

# Record one recursive-walk defect without contaminating machine-readable stdout.
_map_diag() {
  local path="$1" message="$2"
  printf 'cumaru map: %s: %s\n' "$(_tree_quote_path "$path")" "$message" >> "$_MAP_DIAG_FILE"
  _MAP_ERRORS=$((_MAP_ERRORS + 1))
}

# Render deterministic records in rg-compatible or TSV form.
_map_emit() {
  local records="$1" rows="$2" path line heading
  LC_ALL=C sort -t $'\t' -k1,1 -k2,2n "$records" | while IFS=$'\t' read -r path line heading; do
    if [[ "$rows" == "1" ]]; then
      printf '%s\t%s\t%s\n' "$path" "$line" "$heading"
    else
      printf '%s:%s:## %s\n' "$path" "$line" "$heading"
    fi
  done
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

  local root candidate canonical kind tmp_dir records diagnostics walk find_errors file rel rc=0
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

  if command -v rg >/dev/null 2>&1; then
    _map_with_rg "$root" "$target" "$rows"
    return $?
  fi

  tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/cumaru-map.XXXXXX") || return 1
  records="$tmp_dir/records"; diagnostics="$tmp_dir/diagnostics"; walk="$tmp_dir/walk"; find_errors="$tmp_dir/find-errors"
  : > "$records"
  : > "$diagnostics"
  if [[ "$kind" == dir ]]; then
    _tree_find_deep "$canonical" "$walk" "$find_errors" || { cat "$find_errors" >&2; rm -rf "$tmp_dir"; return 1; }
  else
    printf '%s\0' "$canonical" > "$walk"
  fi

  local _MAP_DIAG_FILE="$diagnostics" _MAP_ERRORS=0
  while IFS= read -r -d '' file; do
    [[ "$file" == *.md ]] || continue
    rel="${file#"$root"/}"
    if [[ -L "$file" ]] || _tree_has_symlink_component "$root" "$file"; then
      _map_diag "$rel" "symlinks are not supported"
      continue
    fi
    if _tree_path_has_control "$rel"; then
      _map_diag "$rel" "path contains a control character"
      continue
    fi
    [[ -f "$file" ]] || continue
    _tree_path_matches_pillars "$rel" || continue
    _map_file_headings "$file" "$rel" "$records"
  done < "$walk"
  _map_emit "$records" "$rows"
  if [[ -s "$diagnostics" ]]; then LC_ALL=C sort "$diagnostics" >&2; fi
  [[ $_MAP_ERRORS -eq 0 ]] || rc=1
  rm -rf "$tmp_dir"
  return "$rc"
}
