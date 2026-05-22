# cmd_tag.sh — read, write, and audit <!-- llm:NAME --> marker blocks.
#
# Forms:
#   tag                       list the tags declared in schema.yaml (active set)
#   tag <file>                audit a file's blocks against the schema:
#                               - tags present but undeclared → error, review
#                               - tags expected (by host_file) but absent →
#                                 add empty blocks + ask for review
#   tag get <file> <tag>      print a block body; if the tag is declared in
#                             schema but absent, warn and create an empty block.
#                             If absent and undeclared, exit 1.
#   tag set <file> <tag>      replace a block body (content from stdin); creates
#                             the block if absent (warns if undeclared).
#
# Tag name rules (see schema.yaml > tags:):
#   Valid: [a-z][a-z0-9_-]*(:[a-z][a-z0-9_*-]*)?
#   Two-token names like `files:touched` or `custom:apps-values` are valid.
#   The `llm:` namespace prefix seen in the file (<!-- llm:NAME -->) is NOT
#   part of the tag NAME — it is stripped automatically when the user passes it.
#
# Expects from entry-point: DOT_LLM_DIR, SCHEMA. Reuses fm_* from common.sh.

_TAG_NAME_RE='^[a-z][a-z0-9_-]*(:[a-z][a-z0-9_*-]*)?$'

cmd_tag_help() {
  cat <<'EOF'
llm tag — read, write, and audit <!-- llm:NAME --> marker blocks

Usage:
  llm tag                       list the tags declared in schema.yaml
  llm tag <file>                audit a file's blocks against the schema
  llm tag get <file> <tag>      print the block body
  llm tag set <file> <tag>      replace the block body (content from stdin)

Tag name format:
  [a-z][a-z0-9_-]*(:[a-z][a-z0-9_*-]*)?
  Examples: plans, specs, files:touched, custom:apps-values
  The `llm:` namespace prefix is stripped automatically — both `specs` and
  `llm:specs` are accepted and resolve to the same tag.

Audit (llm tag <file>):
  [✓] tag present and known to the schema
  [+] tag expected here (host_file matches) but missing → empty block added
  [✗] tag present but NOT declared in schema.yaml → review (remove or declare)

Get/Set behaviour:
  get  tag declared in schema, absent from file → warn + create empty + print empty
  get  tag NOT declared, absent from file        → error, exit 1
  set  tag absent from file                      → create at canonical position
  set  tag NOT declared in schema                → warn (undeclared) + create anyway

Exit codes:
  0  success / clean audit
  1  audit found issues, tag absent+undeclared (get), file not found, write failure
  2  usage / invalid tag name
EOF
}

# Emit the schema's declared tags, one per line, US-separated (0x1f):
#   <key><US><host_file><US><placement><US><format>
# A non-whitespace separator is required: `IFS=$'\t' read` collapses empty
# fields between tabs (pattern tags like `files:*` have no host_file), which
# would shift columns. The US control char (0x1f) never appears in tag data.
# Only 2-space-indented keys under `tags:` are tag names; 4-space lines are
# their fields. Quotes are stripped BEFORE the trailing YAML colon so that
# `"files:*":` yields `files:*` (a naive sub(/:.*/,"") would drop the `*`).
_TAG_SEP=$'\037'
_tag_schema_table() {
  [[ -f "$SCHEMA" ]] || return 1
  awk '
    function val(s) {
      sub(/^    [a-z_]+:[[:space:]]*/, "", s)
      sub(/[[:space:]]*$/, "", s)
      return s
    }
    function emit() {
      if (key != "") print key SEP host SEP place SEP fmt
      key = ""
    }
    BEGIN { SEP = sprintf("%c", 31); intags = 0; key = ""; host = ""; place = ""; fmt = "" }
    /^tags:/                       { intags = 1; next }
    intags && /^[^ ]/              { emit(); intags = 0; next }
    intags && /^  [a-z"*]/ {
      emit()
      key = $0
      sub(/^  /, "", key)
      sub(/:[[:space:]]*$/, "", key)
      gsub(/"/, "", key)
      host = ""; place = ""; fmt = ""
      next
    }
    intags && /^    host_file:/    { host  = val($0) }
    intags && /^    placement:/    { place = val($0) }
    intags && /^    format:/       { fmt   = val($0) }
    END { emit() }
  ' "$SCHEMA"
}

# True if <tag> matches any schema key. Pattern keys (e.g. `files:*`) glob-match.
_tag_schema_declared() {
  local tag="$1" key host place fmt
  while IFS="$_TAG_SEP" read -r key host place fmt; do
    [[ -z "$key" ]] && continue
    # shellcheck disable=SC2254
    case "$tag" in
      $key) return 0 ;;
    esac
  done < <(_tag_schema_table)
  return 1
}

# Absolute path of $1 without requiring the file to exist (dir must exist).
_tag_abspath() {
  local p="$1" d b
  d="$(cd "$(dirname "$p")" 2>/dev/null && pwd)" || return 1
  b="$(basename "$p")"
  printf '%s/%s\n' "$d" "$b"
}

# Path of $1 relative to DOT_LLM_DIR. Falls back to the original path when it
# cannot be made relative (file outside the tree, or root unresolved).
_tag_relpath() {
  local file="$1" abs_file abs_root
  abs_file="$(_tag_abspath "$file")"     || { printf '%s\n' "$file"; return; }
  abs_root="$(cd "$DOT_LLM_DIR" 2>/dev/null && pwd)" || { printf '%s\n' "$file"; return; }
  if [[ "$abs_file" == "$abs_root/"* ]]; then
    printf '%s\n' "${abs_file#"$abs_root"/}"
  else
    printf '%s\n' "$file"
  fi
}

# Insert one or more empty marker blocks just after the frontmatter, before
# any prose. Args: file tag [tag ...]. All tags are inserted in a single pass
# in the order given, so callers control ordering (no LIFO). A blank line is
# kept/added between the frontmatter and the markers, and one is added after,
# matching the framework's file convention. Markdown-with-frontmatter only.
_tag_insert_empty() {
  local file="$1"; shift
  local tags=("$@")
  [[ ${#tags[@]} -gt 0 ]] || return 0
  local fence_count
  fence_count=$(grep -c '^---$' "$file" 2>/dev/null || true)
  if [[ "${fence_count:-0}" -lt 2 ]]; then
    red "llm tag: cannot insert block — '${file}' has no frontmatter fence" >&2
    return 1
  fi
  local joined="${tags[*]}"   # tag names are space-free (validated)
  local tmp
  tmp=$(mktemp)
  awk -v tags="$joined" '
    function print_markers(   n, a, i) {
      n = split(tags, a, " ")
      for (i = 1; i <= n; i++) {
        print "<!-- llm:" a[i] " -->"
        print "<!-- /llm:" a[i] " -->"
      }
    }
    /^---$/ { c++; print; if (c == 2) armed = 1; next }
    armed && !done {
      armed = 0; done = 1
      if ($0 ~ /^[[:space:]]*$/) {   # existing blank after frontmatter
        print
        print_markers()
        print ""
        next
      }
      print ""                        # no blank present — add one
      print_markers()
      print ""
      print                           # then the current (first prose) line
      next
    }
    { print }
  ' "$file" > "$tmp" && mv "$tmp" "$file"
}

# --- form: llm tag (no args) — list active schema tags ---------------------
_tag_list_schema() {
  if [[ ! -f "$SCHEMA" ]]; then
    red "llm tag: schema not found: $SCHEMA"
    return 1
  fi
  local key host place fmt any=0
  printf 'Active tags declared in %s:\n\n' "$SCHEMA"
  printf '  %-20s %-18s %-18s %s\n' "TAG" "HOST_FILE" "PLACEMENT" "FORMAT"
  while IFS="$_TAG_SEP" read -r key host place fmt; do
    [[ -z "$key" ]] && continue
    any=1
    printf '  %-20s %-18s %-18s %s\n' \
      "$key" "${host:-—}" "${place:-—}" "${fmt:-—}"
  done < <(_tag_schema_table)
  [[ $any -eq 1 ]] || yellow "  (no tags declared)"
  return 0
}

# --- form: llm tag <file> — audit a file's blocks against the schema -------
_tag_audit() {
  local file="$1"
  [[ -f "$file" ]] || { red "llm tag: file not found: $file"; return 1; }
  if [[ ! -f "$SCHEMA" ]]; then
    red "llm tag: schema not found: $SCHEMA"
    return 1
  fi

  local rel actual
  rel="$(_tag_relpath "$file")"
  actual="$(fm_block_list "$file")"   # newline-separated; may be empty

  local present=() unknown=() missing=()
  local t key host place fmt

  # Classify the tags actually present in the file.
  while IFS= read -r t; do
    [[ -z "$t" ]] && continue
    if _tag_schema_declared "$t"; then
      present+=("$t")
    else
      unknown+=("$t")
    fi
  done <<< "$actual"

  # Detect tags the schema expects in THIS file (host_file == rel) but missing.
  while IFS="$_TAG_SEP" read -r key host place fmt; do
    [[ -z "$key" || -z "$host" ]] && continue
    [[ "$host" == "$rel" ]] || continue
    grep -qxF "$key" <<< "$actual" || missing+=("$key")
  done < <(_tag_schema_table)

  printf 'Auditing %s (relative: %s)\n\n' "$file" "$rel"

  if [[ ${#present[@]} -gt 0 ]]; then
    for t in "${present[@]}"; do green "  [✓] ${t}"; done
  fi

  local rc=0

  if [[ ${#missing[@]} -gt 0 ]]; then
    printf '\n'
    yellow "Expected by schema (host_file: ${rel}) but missing — adding empty blocks; please review and fill them:"
    if _tag_insert_empty "$file" "${missing[@]}"; then
      for t in "${missing[@]}"; do yellow "  [+] ${t} — empty block added"; done
    else
      for t in "${missing[@]}"; do red "  [✗] ${t} — could not add (see message above)"; done
    fi
    rc=1
  fi

  if [[ ${#unknown[@]} -gt 0 ]]; then
    printf '\n'
    red "Present in file but NOT declared in schema.yaml — review: remove the block, or declare the tag in schema.yaml > tags:"
    for t in "${unknown[@]}"; do red "  [✗] ${t}"; done
    rc=1
  fi

  if [[ $rc -eq 0 ]]; then
    printf '\n'
    green "Clean — every block is declared and every expected block is present."
  fi
  return $rc
}

# --- forms: llm tag get|set <file> <tag> -----------------------------------
_tag_getset() {
  local sub="$1"; shift
  if [[ $# -gt 2 ]]; then
    red "llm tag $sub: too many arguments (expected <file> <tag>)"; cmd_tag_help; return 2
  fi
  local file="${1:-}" tag="${2:-}"

  [[ -n "$file" ]] || { red "llm tag $sub: missing <file>"; cmd_tag_help; return 2; }
  [[ -n "$tag"  ]] || { red "llm tag $sub: missing <tag>";  cmd_tag_help; return 2; }
  [[ -f "$file" ]] || { red "llm tag $sub: file not found: $file"; return 1; }

  # Strip the `llm:` namespace prefix if the caller included it.
  tag="${tag#llm:}"

  if [[ ! "$tag" =~ $_TAG_NAME_RE ]]; then
    red "llm tag: invalid tag name '${tag}'"
    red "  Valid: [a-z][a-z0-9_-]*(:[a-z][a-z0-9_*-]*)?"
    return 2
  fi

  local declared=0
  _tag_schema_declared "$tag" && declared=1

  case "$sub" in
    get)
      if fm_block_list "$file" | grep -qxF "$tag"; then
        local body
        body=$(fm_block_extract "$file" "$tag")
        # Distinguish "present but empty" from a silent no-op: the body still
        # goes to stdout (empty), but a stderr hint tells a human the block
        # exists and is just unfilled. stdout stays clean for `$(...)` capture.
        if [[ -z "${body//[[:space:]]/}" ]]; then
          yellow "llm tag get: block '${tag}' is present but empty in ${file}" >&2
        fi
        [[ -n "$body" ]] && printf '%s\n' "$body"
        return 0
      fi
      if [[ $declared -eq 1 ]]; then
        yellow "llm tag get: '${tag}' absent from ${file}; declared in schema — creating empty block" >&2
        _tag_insert_empty "$file" "$tag" || return 1
        return 0
      fi
      red "llm tag get: '${tag}' not found in ${file} and not declared in schema.yaml" >&2
      return 1
      ;;
    set)
      if [[ $declared -eq 0 ]]; then
        yellow "llm tag set: '${tag}' is not declared in schema.yaml — creating anyway" >&2
      fi
      if ! fm_block_list "$file" | grep -qxF "$tag"; then
        _tag_insert_empty "$file" "$tag" || return 1
      fi
      fm_block_replace "$file" "$tag"   # reads new content from stdin
      return $?
      ;;
  esac
}

cmd_tag() {
  # No arguments → list the active schema tags.
  if [[ $# -eq 0 ]]; then
    _tag_list_schema
    return $?
  fi

  local first="$1"
  case "$first" in
    help|-h|--help)
      cmd_tag_help
      return 0
      ;;
    get|set)
      _tag_getset "$@"
      return $?
      ;;
    *)
      # A single non-keyword argument → treat it as a file to audit.
      if [[ $# -eq 1 ]]; then
        _tag_audit "$first"
        return $?
      fi
      red "llm tag: unrecognized arguments: $*"
      cmd_tag_help
      return 2
      ;;
  esac
}
