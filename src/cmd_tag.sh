# cmd_tag.sh — read/write/audit <!-- cumaru:NAME --> (or legacy <!-- llm:NAME -->) marker blocks in .md files.
#
# Forms:
#   cumaru tag                                 list tags declared for the root index.md (.cumaru/index.md)
#   cumaru tag all [--body|--rows]             list every tag in every .cumaru/*.md
#   cumaru tag <file>                          list the file's actual tags + the schema's expected; flag diffs
#   cumaru tag [<file>] get <tag>              print the body of <tag>; <file> defaults to root index.md
#   cumaru tag [<file>] set <tag> [<content>]  replace the body; content is positional or stdin
#   cumaru tag get [<file>] <tag>              equivalent verb-first form
#   cumaru tag set [<file>] <tag> [<content>]  equivalent verb-first form
#
# Schema-awareness (v4):
#   The schema-declared tag list for a given file is resolved from:
#     - root index.md  → keys of `root.tags`
#     - <pillar>/index.md → keys of `root.entities.<pillar>.tags`
#     - meta.tags entries whose `host_file:` matches the .md file literally.
#   Wildcard meta tags (`host_file: "*"`) are allowed anywhere but are not
#   expected in every file during audits.
#
# Body shape (v4):
#   Every tag body is a markdown table with TWO columns: Link | Description.
#   The shape is hardcoded — schemas no longer declare per-tag columns.
#   `set` accepts any body content; row-shape audits live in `cumaru doctor`.
#
# Strictness:
#   `get` and `set` REFUSE if <tag> is not declared in the schema for <file>.
#
# Expects from entry-point: CUMARU_DIR, SCHEMA. Reuses fm_* from common.sh.

# Allow any depth of colon-joined segments: a tag NAME is the path through the
# schema's node tree, so deep names like `plans:plan:handoff:files` are valid
# (the `*` — not `?` — is what permits more than one colon segment).
_TAG_NAME_RE='^[a-z][a-z0-9_-]*(:[a-z][a-z0-9_*-]*)*$'

cmd_tag_help() {
  cat <<'EOF'
cumaru tag — read/write/audit <!-- cumaru:NAME --> (or legacy <!-- llm:NAME -->) marker blocks in .md files

Usage:
  cumaru tag                                  list tags declared for the root index.md
  cumaru tag all [--body|--rows]              list every tag in every .cumaru/*.md
  cumaru tag <file>                           list the file's actual tags + schema's expected; flag diffs
  cumaru tag [<file>] get <tag>               print the body of <tag>
  cumaru tag [<file>] set <tag> [<content>]   replace the body; content positional or stdin
  cumaru tag get [<file>] <tag>               equivalent verb-first form
  cumaru tag set [<file>] <tag> [<content>]   equivalent verb-first form

<file> must end in .md and is relative to .cumaru/ unless absolute.
When omitted, <file> defaults to the root index.md (.cumaru/index.md).
Tag name format: [a-z][a-z0-9_-]*(:[a-z][a-z0-9_*-]*)*  (colon-joined node path,
any depth; the `cumaru:` `cumaru:` prefix in the file is
implicit — pass `specs` or `cumaru:specs`, both resolve to the same).

Schema validation:
  - `get` / `set` refuse if <tag> is not declared in the schema for <file>.
  - `list` views show schema's expectation alongside what's in the file.

Exit codes:
  0  success
  1  file/tag absent, validation failure, or write failure
  2  usage error or invalid tag name
EOF
}

# ── form: all ─────────────────────────────────────────────────────────────

_tag_all() {
  local mode="list"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --body) mode="body"; shift ;;
      --rows) mode="rows"; shift ;;
      -h|--help|help)
        cat <<'EOF'
cumaru tag all — list every <!-- cumaru:NAME --> (or legacy <!-- llm:NAME -->) block under .cumaru/

Usage:
  cumaru tag all             group all tags by file
  cumaru tag all --body      print every block with its body
  cumaru tag all --rows      print [Link, Description] rows as TSV:
                           file<TAB>tag<TAB>link<TAB>description<TAB>target<TAB>status

Status values for --rows: ok, missing, external, anchor, template, empty,
invalid (a `reference` row breaking the source-file rule — see cumaru coverage --help).
EOF
        return 0 ;;
      *)
        red "unknown flag for tag all: $1"
        return 2 ;;
    esac
  done

  [[ -d "$CUMARU_DIR" ]] || { red "✗ $CUMARU_DIR not found — run 'cumaru install' first"; return 1; }

  case "$mode" in
    rows)
      fm_tag_table_rows "$CUMARU_DIR"
      ;;
    body)
      local file tag body
      while IFS=$'\t' read -r file tag; do
        [[ -n "$file" && -n "$tag" ]] || continue
        printf 'File: %s\nTag: %s\n\n' "$file" "$tag"
        printf '<!-- cumaru:%s -->\n' "$tag"
        body=$(fm_block_extract "$CUMARU_DIR/$file" "$tag")
        [[ -n "$body" ]] && printf '%s\n' "$body"
        printf '<!-- /cumaru:%s -->\n\n' "$tag"
      done < <(fm_block_walk "$CUMARU_DIR")
      ;;
    list)
      local current="" file tag count=0
      while IFS=$'\t' read -r file tag; do
        [[ -n "$file" && -n "$tag" ]] || continue
        if [[ "$file" != "$current" ]]; then
          [[ -n "$current" ]] && printf '\n'
          printf 'File: %s\n' "$file"
          current="$file"
        fi
        printf '  • %s\n' "$tag"
        count=$((count + 1))
      done < <(fm_block_walk "$CUMARU_DIR")
      [[ $count -eq 0 ]] && yellow "No <!-- cumaru:NAME --> blocks found under $CUMARU_DIR/"
      ;;
  esac
}

# ── path → schema-declared tag list ─────────────────────────────────────────

# Path of $1 relative to CUMARU_DIR. Requires the file to exist within the
# tree; fails with an error message if resolution fails or file is outside tree.
_tag_relpath() {
  local file="$1" abs_file abs_root
  
  # Resolve absolute path of the file
  abs_file=$(cd "$(dirname -- "$file")" 2>/dev/null && pwd)/$(basename -- "$file")
  if [[ -z "$abs_file" ]]; then
    red "✗ Cannot resolve path: $file" >&2
    return 1
  fi
  
  # Resolve absolute path of CUMARU_DIR
  abs_root=$(cd "$CUMARU_DIR" 2>/dev/null && pwd)
  if [[ -z "$abs_root" ]]; then
    red "✗ Cannot resolve CUMARU_DIR: $CUMARU_DIR" >&2
    return 1
  fi
  
  # Make relative if under tree; fail if outside tree
  if [[ "$abs_file" == "$abs_root/"* ]]; then
    printf '%s\n' "${abs_file#"$abs_root"/}"
  else
    red "✗ File not in tree: $file (expected under $abs_root)" >&2
    return 1
  fi
}

# Resolve the file argument — empty means root index.md. Explicit file paths
# must be markdown files.
_tag_resolve_file() {
  local arg="${1:-}"
  if [[ -z "$arg" ]]; then
    printf '%s\n' "$CUMARU_DIR/index.md"
  elif [[ "$arg" != *.md ]]; then
    red "✗ file paths passed to 'cumaru tag' must end in .md: $arg" >&2
    return 2
  elif [[ "$arg" == /* ]]; then
    printf '%s\n' "$arg"
  elif [[ -f "$arg" ]]; then
    printf '%s\n' "$arg"
  else
    # Treat as relative to CUMARU_DIR
    printf '%s\n' "$CUMARU_DIR/$arg"
  fi
}

# Emit the keys of `root.tags` in the schema (one per line).
_tag_schema_root_keys() {
  [[ -f "$SCHEMA" ]] || return 0
  awk '
    /^root:/                       { state="root"; next }
    state=="root" && /^[^ ]/       { state="" }
    state=="root" && /^  tags:[[:space:]]*$/ { state="rtags"; next }
    state=="rtags" && /^    [a-z"]/ {
      k=$0; sub(/^    /, "", k); sub(/:.*$/, "", k); gsub(/"/, "", k)
      print k
      next
    }
    state=="rtags" && /^  [a-z]/   { state="root" }
  ' "$SCHEMA"
}

# Emit the keys of `root.entities.<pillar>.tags` (one per line).
_tag_schema_pillar_keys() {
  local pillar="$1"
  [[ -f "$SCHEMA" ]] || return 0
  awk -v p="$pillar" '
    /^root:/                                       { st="root"; next }
    st=="root" && /^[^ ]/                          { st="" }
    st=="root" && /^  entities:[[:space:]]*$/      { st="ents"; next }
    st=="ents" && /^  [^ ]/                        { st="root" }
    st=="ents" && $0 ~ "^    " p ":[[:space:]]*$"  { st="pil"; next }
    st=="pil"  && /^    [a-z]/                     { st="ents" }
    st=="pil"  && /^      tags:[[:space:]]*$/      { st="ptags"; next }
    st=="ptags" && /^      [a-z]/                  { st="pil" }
    st=="ptags" && /^        [a-z"]/ {
      k=$0; sub(/^        /, "", k); sub(/:.*$/, "", k); gsub(/"/, "", k)
      print k
      next
    }
  ' "$SCHEMA"
}

# Emit each top-level meta.tags entry as "<name>\t<host_file>".
# Handles both inline and block forms:
#   inline: components: {host_file: "domain.md", ...}
#   block:  components:
#             host_file: "domain.md"
_tag_schema_meta_table() {
  [[ -f "$SCHEMA" ]] || return 0
  awk '
    /^meta:/                              { st="meta"; pending_name=""; next }
    st=="meta" && /^[^ ]/                 { st=""; next }
    st=="meta" && /^  tags:[[:space:]]*$/ { st="mtags"; next }
    st=="mtags" && /^  [^ ]/              { st="meta" }

    # 4-space: top-level meta.tags entry. Reset any in-progress block form.
    # Names may carry colon segments (pattern tags like `files:touched`), so
    # the name match allows `:` and extraction cuts at the key separator (the
    # colon followed by whitespace), not at the first colon.
    st=="mtags" && /^    [a-z"]/ {
      pending_name=""
      line=$0; sub(/^    /, "", line); gsub(/"/, "", line)
      # Inline object: name: {host_file: X, ...}
      if (match(line, /^[a-z][a-z0-9_:*-]*:[[:space:]]*\{/)) {
        name=line; sub(/:[[:space:]]*\{.*$/, "", name)
        host=""
        if (match(line, /host_file:[[:space:]]*[^,}]+/)) {
          host=substr(line, RSTART+10, RLENGTH-10)
          sub(/^[[:space:]]*/, "", host); sub(/[[:space:]]*$/, "", host)
        }
        print name "\t" host
        next
      }
      # Block form: name: with no inline value — children follow at deeper indent.
      if (match(line, /^[a-z][a-z0-9_:*-]*:[[:space:]]*$/)) {
        pending_name=line; sub(/:[[:space:]]*$/, "", pending_name)
        next
      }
    }
    # 6-space: child key of a block-form entry — capture host_file when present.
    st=="mtags" && pending_name != "" && /^      / && /host_file:[[:space:]]/ {
      host=$0; sub(/^[[:space:]]*host_file:[[:space:]]*/, "", host)
      sub(/[[:space:]]+$/, "", host)
      print pending_name "\t" host
      pending_name=""
      next
    }
  ' "$SCHEMA"
}

# Emit expected tag NAMES for <file>. Combines:
#   - root.tags keys when file is the root index
#   - root.entities.<pillar>.tags keys when file is a pillar's index.md
#   - meta.tags entries whose host_file matches the .md file (literal)
_tag_schema_expected_tags_for_file() {
  local file="$1"
  local rel
  rel=$(_tag_relpath "$file")

  # 1) Root index.md
  if [[ "$rel" == "index.md" ]]; then
    _tag_schema_root_keys
  fi

  # 2) Pillar's index.md → root.entities.<pillar>.tags
  if [[ "$rel" == */index.md && "$rel" != index.md ]]; then
    # Only top-level pillar (one segment + /index.md), not deeper
    local seg="${rel%/index.md}"
    if [[ "$seg" != */* ]]; then
      _tag_schema_pillar_keys "$seg"
    fi
  fi

  # 3) meta.tags entries with matching .md host_file
  local mname mhost basename_rel
  basename_rel=$(basename "$rel")
  while IFS=$'\t' read -r mname mhost; do
    [[ -z "$mname" ]] && continue
    case "$mhost" in
      "")        ;;   # no host_file → skip
      "$rel")    [[ "$mhost" == *.md ]] && printf '%s\n' "$mname" ;;
      "$basename_rel") [[ "$mhost" == *.md ]] && printf '%s\n' "$mname" ;;
    esac
  done < <(_tag_schema_meta_table)
  return 0
}

_tag_schema_wildcard_tags() {
  local mname mhost
  while IFS=$'\t' read -r mname mhost; do
    [[ -z "$mname" ]] && continue
    [[ "$mhost" == '*' ]] && printf '%s\n' "$mname"
  done < <(_tag_schema_meta_table)
  return 0
}

_tag_schema_allowed_tags_for_file() {
  _tag_schema_expected_tags_for_file "$1"
  _tag_schema_wildcard_tags
  return 0
}

# True (0) if <tag> is declared in the schema for <file>.
# Captures output before grep (no pipe) — `grep -q` matches early and closes
# stdin, which sends SIGPIPE to the producer; `set -o pipefail` would then
# turn the pipe's exit into 141 (false negative).
_tag_in_schema_for_file() {
  local file="$1" tag="$2"
  local tags
  tags=$(_tag_schema_allowed_tags_for_file "$file")
  grep -qxF "$tag" <<< "$tags"
}

# ── form: list-only (cumaru tag, cumaru tag <file>) ─────────────────────────────

_tag_list() {
  local file="$1"
  [[ -f "$file" ]] || { red "✗ file not found: $file"; return 1; }

  local rel
  rel=$(_tag_relpath "$file")
  printf 'File: %s\n\n' "$rel"

  # Schema-declared
  local schema_list
  schema_list=$(_tag_schema_expected_tags_for_file "$file" | sort -u)
  local allowed_list
  allowed_list=$(_tag_schema_allowed_tags_for_file "$file" | sort -u)

  if [[ -z "$schema_list" ]]; then
    yellow "Schema: no tags declared for this file."
  else
    printf 'Schema declares:\n'
    while IFS= read -r t; do
      [[ -n "$t" ]] && printf '  • %s\n' "$t"
    done <<< "$schema_list"
  fi

  # Actual
  local actual_list
  actual_list=$(fm_block_list "$file" | sort -u)

  printf '\n'
  if [[ -z "$actual_list" ]]; then
    yellow "File: no <!-- cumaru:NAME --> (or <!-- llm:NAME -->) blocks present."
  else
    printf 'File contains:\n'
    while IFS= read -r t; do
      [[ -n "$t" ]] && printf '  • %s\n' "$t"
    done <<< "$actual_list"
  fi

  # Diff
  local only_schema only_file
  only_schema=$(comm -23 <(printf '%s\n' "$schema_list") <(printf '%s\n' "$actual_list") | grep -v '^$' || true)
  only_file=$(comm -13 <(printf '%s\n' "$allowed_list") <(printf '%s\n' "$actual_list") | grep -v '^$' || true)

  if [[ -z "$only_schema" && -z "$only_file" ]]; then
    printf '\n'
    green "✓ aligned — every expected tag is present, no extras."
    return 0
  fi

  printf '\n'
  yellow "Diff:"
  if [[ -n "$only_schema" ]]; then
    while IFS= read -r t; do yellow "  [+] $t — declared in schema, absent in file"; done <<< "$only_schema"
  fi
  if [[ -n "$only_file" ]]; then
    while IFS= read -r t; do red    "  [✗] $t — present in file, NOT declared in schema"; done <<< "$only_file"
  fi
  return 1
}

# ── form: get ─────────────────────────────────────────────────────────────

_tag_do_get() {
  local file="$1" tag="$2"
  if fm_block_list "$file" | grep -qxF "$tag"; then
    local body
    body=$(fm_block_extract "$file" "$tag")
    if [[ -z "${body//[[:space:]]/}" ]]; then
      yellow "cumaru tag get: block '$tag' is present but empty in $(_tag_relpath "$file")" >&2
    fi
    [[ -n "$body" ]] && printf '%s\n' "$body"
    return 0
  fi
  red "✗ block '$tag' not found in $(_tag_relpath "$file") (the schema declares it but it isn't present yet)"
  return 1
}

# ── form: set ─────────────────────────────────────────────────────────────

_tag_do_set() {
  local file="$1" tag="$2" content="${3-}"

  # Content: positional > stdin > error
  local tmp
  tmp=$(mktemp)
  if [[ -n "$content" ]]; then
    printf '%s\n' "$content" > "$tmp"
  elif [[ ! -t 0 ]]; then
    cat > "$tmp"
  else
    red "✗ no content — pass a positional arg or pipe via stdin"
    rm -f "$tmp"
    return 2
  fi

  # Insert empty block if absent, then replace its body.
  if ! fm_block_list "$file" | grep -qxF "$tag"; then
    _tag_insert_empty "$file" "$tag" || { rm -f "$tmp"; return 1; }
  fi
  fm_block_replace "$file" "$tag" < "$tmp"
  local rc=$?
  rm -f "$tmp"
  return $rc
}

# Insert one or more empty marker blocks just after the frontmatter, before
# any prose. (Kept from previous version; needed when set creates a missing tag.)
_tag_insert_empty() {
  local file="$1"; shift
  local tags=("$@")
  [[ ${#tags[@]} -gt 0 ]] || return 0
  local fence_count
  fence_count=$(grep -c '^---$' "$file" 2>/dev/null || true)
  if [[ "${fence_count:-0}" -lt 2 ]]; then
    red "✗ cannot insert block — '$file' has no frontmatter fence"
    return 1
  fi
  local joined="${tags[*]}"
  local tmp
  tmp=$(mktemp)
  awk -v tags="$joined" '
    function print_markers(   n, a, i) {
      n = split(tags, a, " ")
      for (i = 1; i <= n; i++) {
        print "<!-- cumaru:" a[i] " -->"
        print "<!-- /cumaru:" a[i] " -->"
      }
    }
    /^---$/ { c++; print; if (c == 2) armed = 1; next }
    armed && !done {
      armed = 0; done = 1
      if ($0 ~ /^[[:space:]]*$/) {
        print
        print_markers()
        print ""
        next
      }
      print ""
      print_markers()
      print ""
      print
      next
    }
    { print }
  ' "$file" > "$tmp" && mv "$tmp" "$file"
}

# ── verb dispatch (shared for get/set) ────────────────────────────────────

_tag_dispatch_verb() {
  local verb="$1" file="$2" tag="${3:-}" content="${4:-}"

  [[ -n "$tag" ]] || { red "✗ $verb: missing <tag>"; cmd_tag_help; return 2; }

  file=$(_tag_resolve_file "$file")
  local rc=$?
  [[ $rc -eq 0 ]] || return $rc
  [[ -f "$file" ]] || { red "✗ file not found: $file"; return 1; }

  # Strip cumaru: prefix and validate name shape.
  tag="${tag#cumaru:}"
  if [[ ! "$tag" =~ $_TAG_NAME_RE ]]; then
    red "✗ invalid tag name: '$tag'"
    return 2
  fi

  if ! _tag_in_schema_for_file "$file" "$tag"; then
    red "✗ tag '$tag' is not declared in the schema for $(_tag_relpath "$file")"
    yellow "  → run 'cumaru tag $(_tag_relpath "$file")' to see what the schema declares for this file"
    return 1
  fi

  case "$verb" in
    get) _tag_do_get "$file" "$tag" ;;
    set) _tag_do_set "$file" "$tag" "$content" ;;
  esac
}

_tag_arg_is_md_file() {
  [[ "${1:-}" == *.md ]]
}

_tag_arg_looks_like_file() {
  local arg="${1:-}"
  [[ "$arg" == */* || "$arg" == *.* ]]
}

_tag_parse_error_non_md_file() {
  red "✗ file paths passed to 'cumaru tag' must end in .md: $1"
  return 2
}

_tag_dispatch_verb_first() {
  local verb="$1"; shift
  local file="" tag="" content=""

  [[ $# -gt 0 ]] || { red "✗ $verb: missing <tag>"; cmd_tag_help; return 2; }

  if _tag_arg_is_md_file "$1"; then
    file="$1"; shift
    [[ $# -gt 0 ]] || { red "✗ $verb: missing <tag>"; cmd_tag_help; return 2; }
  elif _tag_arg_looks_like_file "$1"; then
    _tag_parse_error_non_md_file "$1"
    return $?
  fi

  tag="$1"; shift
  case "$verb" in
    get)
      [[ $# -eq 0 ]] || { red "✗ get: unexpected extra arg: $1"; cmd_tag_help; return 2; }
      _tag_dispatch_verb get "$file" "$tag"
      ;;
    set)
      if [[ $# -gt 1 ]]; then
        red "✗ set: unexpected extra arg: $2"
        cmd_tag_help
        return 2
      fi
      content="${1-}"
      _tag_dispatch_verb set "$file" "$tag" "$content"
      ;;
  esac
}

_tag_dispatch_file_first() {
  local file="$1"; shift

  if [[ $# -eq 0 ]]; then
    local resolved
    resolved=$(_tag_resolve_file "$file")
    local rc=$?
    [[ $rc -eq 0 ]] || return $rc
    _tag_list "$resolved"
    return $?
  fi

  local verb="$1"; shift
  case "$verb" in
    get)
      [[ $# -gt 0 ]] || { red "✗ get: missing <tag>"; cmd_tag_help; return 2; }
      [[ $# -eq 1 ]] || { red "✗ get: unexpected extra arg: $2"; cmd_tag_help; return 2; }
      _tag_dispatch_verb get "$file" "$1"
      ;;
    set)
      [[ $# -gt 0 ]] || { red "✗ set: missing <tag>"; cmd_tag_help; return 2; }
      if [[ $# -gt 2 ]]; then
        red "✗ set: unexpected extra arg: $3"
        cmd_tag_help
        return 2
      fi
      _tag_dispatch_verb set "$file" "$1" "${2:-}"
      ;;
    *)
      red "✗ expected get or set after file path: $verb"
      cmd_tag_help
      return 2
      ;;
  esac
}

# ── main ──────────────────────────────────────────────────────────────────

cmd_tag() {
  case "${1:-}" in
    help|-h|--help) cmd_tag_help; return 0 ;;
    all)
      shift
      _tag_all "$@"
      return $?
      ;;
    "")
      # No args → list root's tags from schema (and what's in the root index.md).
      _tag_list "$(_tag_resolve_file "")"
      return $?
      ;;
    get|set)
      # First arg is a verb → file defaults to root index.md unless the next
      # arg is an explicit .md file.
      local verb="$1"; shift
      _tag_dispatch_verb_first "$verb" "$@"
      return $?
      ;;
    *)
      if _tag_arg_is_md_file "$1"; then
        local file="$1"; shift
        _tag_dispatch_file_first "$file" "$@"
        return $?
      fi
      if _tag_arg_looks_like_file "$1"; then
        _tag_parse_error_non_md_file "$1"
        return $?
      fi
      red "✗ expected a .md file path or get/set: $1"
      cmd_tag_help
      return 2
      ;;
  esac
}
