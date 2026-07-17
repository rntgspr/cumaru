# cmd_tree.sh - filesystem-backed navigation for .cumaru/.
#
# The filesystem supplies structural candidates. Markdown frontmatter supplies
# summaries. This command never follows symlinks and never reads Markdown
# bodies: every summary query uses mikefarah/yq's front-matter extraction mode.

cmd_tree_help() {
  cat <<'EOF'
cumaru tree - list filesystem candidates and their summaries

Usage:
  cumaru tree [<directory-or-md>] [--deep] [--rows]
              [--pillars <name[,name...]>] [--domain <name>]

Paths are relative to .cumaru/. Omit the target to inspect the root. A Markdown
file target is normalized to its parent directory. Absolute paths, `..`
segments, hidden paths, and non-Markdown file targets are rejected.

Modes:
  (default)  list direct non-hidden Markdown files and indexed directories
  --deep     recursively inspect all non-hidden descendants; report every
             missing index, invalid summary, unsafe path, and symlink after
             emitting all valid candidates
  --rows     emit path<TAB>summary TSV instead of a Markdown table

Filters:
  --pillars  restrict root navigation to comma-separated schema-declared
             pillars; an explicit target must be inside a selected pillar
  --domain   require the installed schema domain to match <name>

Filters compose with --deep and --rows. They validate the installed domain
contract; they do not switch to another domain source.

Directories are emitted with a trailing slash. All output paths are relative
to .cumaru/. Diagnostics go to stderr.

Requirements:
  mikefarah/yq with --front-matter=extract support

Exit codes:
  0  success
  1  runtime or tree validation error
  2  usage error
EOF
}

_tree_path_has_control() {
  # Reject control characters before a path can reach Markdown or TSV output.
  local value="$1" cleaned
  cleaned=$(LC_ALL=C printf '%s' "$value" | LC_ALL=C tr -d '\000-\037\177')
  [[ "$cleaned" != "$value" ]]
}

_tree_quote_path() {
  printf '%q' "$1"
}

_tree_diag() {
  local path="$1" message="$2" shown
  shown=$(_tree_quote_path "$path")
  printf 'cumaru tree: %s: %s\n' "$shown" "$message" >> "$_TREE_DIAG_FILE"
  _TREE_ERRORS=$((_TREE_ERRORS + 1))
}

_tree_check_yq() {
  local version probe
  if ! command -v yq >/dev/null 2>&1; then
    printf 'cumaru tree: mikefarah/yq is required but was not found on PATH\n' >&2
    return 1
  fi
  version=$(yq --version 2>&1) || {
    printf 'cumaru tree: cannot execute yq: %s\n' "$version" >&2
    return 1
  }
  case "$version" in
    *mikefarah/yq*) ;;
    *)
      printf 'cumaru tree: incompatible yq; install mikefarah/yq with frontmatter support\n' >&2
      return 1
      ;;
  esac
  probe=$(yq -n -r '"é" as $s | [($s | tag), ($s | split("") | length)] | @tsv' 2>/dev/null) || {
    printf 'cumaru tree: incompatible mikefarah/yq; required operators are unavailable\n' >&2
    return 1
  }
  if [[ "$probe" != $'!!str\t1' ]]; then
    printf 'cumaru tree: incompatible mikefarah/yq; Unicode string validation is unavailable\n' >&2
    return 1
  fi
  return 0
}

# True when any component below root is a symlink. The root itself is checked
# separately before it is canonicalized.
_tree_has_symlink_component() {
  local root="$1" path="$2" rel probe segment rest
  [[ "$path" == "$root" || "$path" == "$root/"* ]] || return 0
  [[ "$path" != "$root" ]] || return 1
  rel="${path#"$root"/}"
  probe="$root"
  rest="$rel"
  while :; do
    segment="${rest%%/*}"
    if [[ -n "$segment" && "$segment" != "." ]]; then
      probe="$probe/$segment"
      [[ -L "$probe" ]] && return 0
    fi
    [[ "$rest" == */* ]] || break
    rest="${rest#*/}"
  done
  return 1
}

# Print the canonical path for an existing regular file or directory, provided
# it remains under root. Symlink checks are deliberately done by the caller
# immediately before this function.
_tree_canonicalize() {
  local root="$1" path="$2" kind="$3" canonical parent
  case "$kind" in
    file)
      [[ -f "$path" ]] || return 1
      parent=$(cd "$(dirname "$path")" 2>/dev/null && pwd -P) || return 1
      canonical="$parent/$(basename "$path")"
      ;;
    dir)
      [[ -d "$path" ]] || return 1
      canonical=$(cd "$path" 2>/dev/null && pwd -P) || return 1
      ;;
    *) return 1 ;;
  esac
  if [[ "$canonical" != "$root" && "$canonical" != "$root/"* ]]; then
    return 1
  fi
  printf '%s\n' "$canonical"
}

_tree_summary() {
  local file="$1" rel="$2" yaml_tag checks trimmed has_controls count summary
  if ! yaml_tag=$(yq --front-matter=extract -r '.summary | tag' "$file" 2>/dev/null); then
    _tree_diag "$rel" "cannot read YAML frontmatter"
    return 1
  fi
  if [[ "$yaml_tag" != "!!str" ]]; then
    _tree_diag "$rel" "summary must be a YAML string"
    return 1
  fi
  if ! checks=$(yq --front-matter=extract -r \
    '.summary as $s | [($s == ($s | trim)), ($s | test("[[:cntrl:]]")), ($s | split("") | length)] | @tsv' \
    "$file" 2>/dev/null); then
    _tree_diag "$rel" "cannot validate summary"
    return 1
  fi
  IFS=$'\t' read -r trimmed has_controls count <<< "$checks"
  if [[ "$trimmed" != "true" ]]; then
    _tree_diag "$rel" "summary must be trimmed"
    return 1
  fi
  if [[ "$has_controls" != "false" ]]; then
    _tree_diag "$rel" "summary must not contain C0 or DEL control characters"
    return 1
  fi
  if [[ ! "$count" =~ ^[0-9]+$ || "$count" -lt 32 || "$count" -gt 256 ]]; then
    _tree_diag "$rel" "summary must contain 32 to 256 Unicode code points"
    return 1
  fi
  if ! summary=$(yq --front-matter=extract -r '.summary' "$file" 2>/dev/null); then
    _tree_diag "$rel" "cannot read summary"
    return 1
  fi
  _TREE_SUMMARY="$summary"
  return 0
}

_tree_add_candidate() {
  local root="$1" records="$2" output_path="$3" source="$4" source_rel="$5"
  local candidate canonical

  if _tree_path_has_control "$output_path"; then
    _tree_diag "$output_path" "candidate path contains a control character"
    return 1
  fi

  if [[ "$output_path" == */ ]]; then
    candidate="$root/${output_path%/}"
    if _tree_has_symlink_component "$root" "$candidate" ||
       ! canonical=$(_tree_canonicalize "$root" "$candidate" dir); then
      _tree_diag "$output_path" "directory does not resolve safely inside .cumaru/"
      return 1
    fi
  fi

  if _tree_has_symlink_component "$root" "$source"; then
    _tree_diag "$source_rel" "symlinks are not supported"
    return 1
  fi
  if ! canonical=$(_tree_canonicalize "$root" "$source" file); then
    _tree_diag "$source_rel" "file does not resolve safely inside .cumaru/"
    return 1
  fi
  _tree_summary "$canonical" "$source_rel" || return 1
  printf '%s\t%s\n' "$output_path" "$_TREE_SUMMARY" >> "$records"
  return 0
}

_tree_find_shallow() {
  local target="$1" walk="$2" find_errors="$3"
  find "$target" -mindepth 1 -maxdepth 1 -print0 > "$walk" 2> "$find_errors"
}

_tree_find_deep() {
  local target="$1" walk="$2" find_errors="$3"
  # Do not prune a hidden target root such as .cumaru itself. Hidden
  # descendants are pruned before find can inspect their children.
  find "$target" \
    \( ! -path "$target" -a -name '.*' \) -prune -o \
    \( ! -path "$target" -print0 \) > "$walk" 2> "$find_errors"
}

# True when a path relative to .cumaru/ belongs to a selected pillar. An empty
# filter admits every path and preserves the unfiltered behavior.
_tree_path_matches_pillars() {
  local rel="$1" first
  [[ -z "${_TREE_PILLARS:-}" ]] && return 0
  while [[ "$rel" == ./* ]]; do rel="${rel#./}"; done
  rel="${rel%/}"
  first="${rel%%/*}"
  [[ ",$_TREE_PILLARS," == *",$first,"* ]]
}

_tree_walk_shallow() {
  local root="$1" target="$2" records="$3" walk="$4" find_errors="$5"
  local target_index path base rel index canonical index_rel

  target_index="$target/index.md"
  if [[ -L "$target_index" ]]; then
    printf 'cumaru tree: target index is a symlink: %s\n' "$(_tree_quote_path "${target_index#"$root"/}")" >&2
    return 1
  fi
  if [[ ! -f "$target_index" ]] || _tree_has_symlink_component "$root" "$target_index" ||
     ! canonical=$(_tree_canonicalize "$root" "$target_index" file); then
    printf 'cumaru tree: target requires a regular index.md: %s\n' "$(_tree_quote_path "${target_index#"$root"/}")" >&2
    return 1
  fi

  if ! _tree_find_shallow "$target" "$walk" "$find_errors"; then
    _tree_diag "${target#"$root"/}" "could not completely inspect directory"
  fi

  while IFS= read -r -d '' path; do
    base=$(basename "$path")
    [[ "$base" == .* ]] && continue
    rel="${path#"$root"/}"

    _tree_path_matches_pillars "$rel" || continue

    if [[ -L "$path" ]]; then
      _tree_diag "$rel" "symlinks are not supported"
      _tree_path_has_control "$rel" && _tree_diag "$rel" "candidate path contains a control character"
      continue
    fi
    if _tree_path_has_control "$rel"; then
      _tree_diag "$rel" "candidate path contains a control character"
      continue
    fi

    if [[ -d "$path" ]]; then
      if _tree_has_symlink_component "$root" "$path" ||
         ! canonical=$(_tree_canonicalize "$root" "$path" dir); then
        _tree_diag "$rel/" "directory does not resolve safely inside .cumaru/"
        continue
      fi
      index="$canonical/index.md"
      index_rel="$rel/index.md"
      if [[ -L "$index" ]]; then
        _tree_diag "$index_rel" "symlinks are not supported"
      elif [[ -f "$index" ]]; then
        _tree_add_candidate "$root" "$records" "$rel/" "$index" "$index_rel" || true
      fi
    elif [[ -f "$path" && "$base" == *.md && "$base" != "index.md" ]]; then
      _tree_add_candidate "$root" "$records" "$rel" "$path" "$rel" || true
    fi
  done < "$walk"
  return 0
}

_tree_walk_deep() {
  local root="$1" target="$2" records="$3" walk="$4" find_errors="$5"
  local target_index path base rel index canonical index_rel parent parent_rel

  target_index="$target/index.md"
  if [[ ! -L "$target_index" && ! -f "$target_index" ]]; then
    _tree_diag "${target_index#"$root"/}" "directory is missing a regular index.md"
  fi

  if ! _tree_find_deep "$target" "$walk" "$find_errors"; then
    _tree_diag "${target#"$root"/}" "could not completely inspect directory"
  fi

  while IFS= read -r -d '' path; do
    base=$(basename "$path")
    rel="${path#"$root"/}"

    _tree_path_matches_pillars "$rel" || continue

    if [[ -L "$path" ]]; then
      _tree_diag "$rel" "symlinks are not supported"
      _tree_path_has_control "$rel" && _tree_diag "$rel" "candidate path contains a control character"
      continue
    fi
    if _tree_path_has_control "$rel"; then
      _tree_diag "$rel" "candidate path contains a control character"
      continue
    fi

    if [[ -d "$path" ]]; then
      if _tree_has_symlink_component "$root" "$path" ||
         ! canonical=$(_tree_canonicalize "$root" "$path" dir); then
        _tree_diag "$rel/" "directory does not resolve safely inside .cumaru/"
        continue
      fi
      index="$canonical/index.md"
      index_rel="$rel/index.md"
      if [[ ! -L "$index" && ! -f "$index" ]]; then
        _tree_diag "$index_rel" "directory is missing a regular index.md"
      fi
    elif [[ -f "$path" && "$base" == *.md ]]; then
      if [[ "$base" == "index.md" ]]; then
        parent=$(dirname "$path")
        if [[ "$parent" == "$target" ]]; then
          if _tree_has_symlink_component "$root" "$path" ||
             ! canonical=$(_tree_canonicalize "$root" "$path" file); then
            _tree_diag "$rel" "file does not resolve safely inside .cumaru/"
          else
            _tree_summary "$canonical" "$rel" || true
          fi
        else
          parent_rel="${parent#"$root"/}"
          _tree_add_candidate "$root" "$records" "$parent_rel/" "$path" "$rel" || true
        fi
      else
        _tree_add_candidate "$root" "$records" "$rel" "$path" "$rel" || true
      fi
    fi
  done < "$walk"
  return 0
}

_tree_markdown_escape() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//|/\\|}"
  printf '%s' "$value"
}

_tree_emit() {
  local records="$1" rows="$2" path summary escaped_path escaped_summary
  if [[ "$rows" == "1" ]]; then
    LC_ALL=C sort "$records"
    return 0
  fi
  printf '| Path | Summary |\n'
  printf '|---|---|\n'
  LC_ALL=C sort "$records" | while IFS=$'\t' read -r path summary; do
    escaped_path=$(_tree_markdown_escape "$path")
    escaped_summary=$(_tree_markdown_escape "$summary")
    printf '| %s | %s |\n' "$escaped_path" "$escaped_summary"
  done
}

_tree_validate_target_syntax() {
  local target="$1" rest segment
  [[ "$target" != /* ]] || {
    printf 'cumaru tree: target must be relative to .cumaru/: %s\n' "$(_tree_quote_path "$target")" >&2
    return 1
  }
  if _tree_path_has_control "$target"; then
    printf 'cumaru tree: target path contains a control character: %s\n' "$(_tree_quote_path "$target")" >&2
    return 1
  fi
  rest="$target"
  while :; do
    segment="${rest%%/*}"
    if [[ "$segment" == ".." ]]; then
      printf 'cumaru tree: `..` path segments are not allowed: %s\n' "$(_tree_quote_path "$target")" >&2
      return 1
    fi
    if [[ "$segment" == .* && "$segment" != "." ]]; then
      printf 'cumaru tree: hidden target paths are not allowed: %s\n' "$(_tree_quote_path "$target")" >&2
      return 1
    fi
    [[ "$rest" == */* ]] || break
    rest="${rest#*/}"
  done
  return 0
}

# Validate the optional domain guard and pillar list against the installed v6
# schema, then expose a normalized comma-separated pillar filter.
_tree_validate_filters() {
  local schema="$1" requested_domain="$2" requested_pillars="$3"
  local installed_domain value pillar declared normalized=""
  [[ -f "$schema" && ! -L "$schema" ]] || {
    printf 'cumaru tree: filters require a regular .cumaru/schema.yaml\n' >&2
    return 1
  }

  installed_domain=$(yq -r '.domain // "base"' "$schema" 2>/dev/null) || {
    printf 'cumaru tree: cannot read domain from .cumaru/schema.yaml\n' >&2
    return 1
  }
  if [[ -n "$requested_domain" && "$requested_domain" != "$installed_domain" ]]; then
    printf 'cumaru tree: installed domain is %s, not %s\n' \
      "$(_tree_quote_path "$installed_domain")" "$(_tree_quote_path "$requested_domain")" >&2
    return 1
  fi

  [[ -n "$requested_pillars" ]] || {
    _TREE_PILLARS=""
    return 0
  }
  IFS=',' read -r -a value <<< "$requested_pillars"
  for pillar in "${value[@]}"; do
    if [[ -z "$pillar" || ! "$pillar" =~ ^[A-Za-z0-9_-]+$ ]]; then
      printf 'cumaru tree: invalid pillar filter: %s\n' "$(_tree_quote_path "$requested_pillars")" >&2
      return 1
    fi
    declared=$(yq -r ".root.entities | has(\"$pillar\")" "$schema" 2>/dev/null) || declared="false"
    if [[ "$declared" != "true" ]]; then
      printf 'cumaru tree: unknown pillar for domain %s: %s\n' \
        "$(_tree_quote_path "$installed_domain")" "$(_tree_quote_path "$pillar")" >&2
      return 1
    fi
    [[ ",$normalized," == *",$pillar,"* ]] || normalized="${normalized:+$normalized,}$pillar"
  done
  _TREE_PILLARS="$normalized"
}

cmd_tree() {
  local target="" deep=0 rows=0 requested_pillars="" requested_domain="" arg
  while [[ $# -gt 0 ]]; do
    arg="$1"
    case "$arg" in
      -h|--help|help) cmd_tree_help; return 0 ;;
      --deep) deep=1 ;;
      --rows) rows=1 ;;
      --pillars)
        shift
        [[ $# -gt 0 && "${1:-}" != -* ]] || {
          printf 'cumaru tree: --pillars requires a value\n' >&2
          return 2
        }
        requested_pillars="$1"
        ;;
      --pillars=*)
        requested_pillars="${arg#*=}"
        [[ -n "$requested_pillars" ]] || {
          printf 'cumaru tree: --pillars requires a value\n' >&2
          return 2
        }
        ;;
      --domain)
        shift
        [[ $# -gt 0 && "${1:-}" != -* ]] || {
          printf 'cumaru tree: --domain requires a value\n' >&2
          return 2
        }
        requested_domain="$1"
        ;;
      --domain=*)
        requested_domain="${arg#*=}"
        [[ -n "$requested_domain" ]] || {
          printf 'cumaru tree: --domain requires a value\n' >&2
          return 2
        }
        ;;
      -*)
        printf 'cumaru tree: unknown option: %s\n' "$arg" >&2
        cmd_tree_help >&2
        return 2
        ;;
      *)
        if [[ -n "$target" ]]; then
          printf 'cumaru tree: expected at most one target\n' >&2
          cmd_tree_help >&2
          return 2
        fi
        target="$arg"
        ;;
    esac
    shift
  done

  [[ -n "$target" ]] || target="."
  while [[ "$target" != "/" && "$target" == */ ]]; do target="${target%/}"; done
  [[ -n "$target" ]] || target="."
  _tree_validate_target_syntax "$target" || return 1

  if [[ -L "$CUMARU_DIR" ]]; then
    printf 'cumaru tree: .cumaru/ must not be a symlink\n' >&2
    return 1
  fi
  if [[ ! -d "$CUMARU_DIR" ]]; then
    printf 'cumaru tree: .cumaru/ not found; run `cumaru install` first\n' >&2
    return 1
  fi
  _tree_check_yq || return 1
  local _TREE_PILLARS=""
  if [[ -n "$requested_domain" || -n "$requested_pillars" ]]; then
    _tree_validate_filters "$SCHEMA" "$requested_domain" "$requested_pillars" || return 1
  fi

  if [[ "$target" != "." && -n "$_TREE_PILLARS" ]] && ! _tree_path_matches_pillars "$target"; then
    printf 'cumaru tree: target is outside the selected pillars: %s\n' "$(_tree_quote_path "$target")" >&2
    return 1
  fi

  local root candidate canonical target_dir
  root=$(cd "$CUMARU_DIR" 2>/dev/null && pwd -P) || {
    printf 'cumaru tree: cannot resolve .cumaru/\n' >&2
    return 1
  }
  if [[ "$target" == "." ]]; then
    candidate="$root"
  else
    candidate="$root/$target"
  fi
  if _tree_has_symlink_component "$root" "$candidate"; then
    printf 'cumaru tree: target contains a symlink: %s\n' "$(_tree_quote_path "$target")" >&2
    return 1
  fi

  if [[ -d "$candidate" ]]; then
    canonical=$(_tree_canonicalize "$root" "$candidate" dir) || {
      printf 'cumaru tree: target does not resolve safely inside .cumaru/: %s\n' "$(_tree_quote_path "$target")" >&2
      return 1
    }
    target_dir="$canonical"
  elif [[ -f "$candidate" ]]; then
    if [[ "$target" != *.md ]]; then
      printf 'cumaru tree: file target must end in .md: %s\n' "$(_tree_quote_path "$target")" >&2
      return 1
    fi
    canonical=$(_tree_canonicalize "$root" "$candidate" file) || {
      printf 'cumaru tree: target does not resolve safely inside .cumaru/: %s\n' "$(_tree_quote_path "$target")" >&2
      return 1
    }
    target_dir=$(dirname "$canonical")
  elif [[ -L "$candidate" ]]; then
    printf 'cumaru tree: target is a symlink: %s\n' "$(_tree_quote_path "$target")" >&2
    return 1
  elif [[ -e "$candidate" ]]; then
    printf 'cumaru tree: target must be a directory or Markdown file: %s\n' "$(_tree_quote_path "$target")" >&2
    return 1
  else
    printf 'cumaru tree: target not found: %s\n' "$(_tree_quote_path "$target")" >&2
    return 1
  fi

  local tmp_dir records diagnostics walk find_errors
  tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/cumaru-tree.XXXXXX") || {
    printf 'cumaru tree: cannot create temporary workspace\n' >&2
    return 1
  }
  records="$tmp_dir/records"
  diagnostics="$tmp_dir/diagnostics"
  walk="$tmp_dir/walk"
  find_errors="$tmp_dir/find-errors"
  : > "$records"
  : > "$diagnostics"
  : > "$walk"
  : > "$find_errors"

  local _TREE_DIAG_FILE="$diagnostics" _TREE_ERRORS=0 _TREE_SUMMARY="" walk_rc=0
  if [[ "$deep" == "1" ]]; then
    _tree_walk_deep "$root" "$target_dir" "$records" "$walk" "$find_errors" || walk_rc=$?
  else
    _tree_walk_shallow "$root" "$target_dir" "$records" "$walk" "$find_errors" || walk_rc=$?
  fi
  if [[ $walk_rc -ne 0 ]]; then
    rm -rf "$tmp_dir"
    return "$walk_rc"
  fi

  _tree_emit "$records" "$rows"
  if [[ -s "$diagnostics" ]]; then
    LC_ALL=C sort "$diagnostics" >&2
  fi
  local rc=0
  [[ $_TREE_ERRORS -eq 0 ]] || rc=1
  rm -rf "$tmp_dir"
  return "$rc"
}
