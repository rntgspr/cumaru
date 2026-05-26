# cmd_tag.sh — read/write/audit <!-- llm:NAME --> marker blocks (v3 schema-aware).
#
# Forms:
#   llm tag                                 list tags declared for the root index.md (.llm/index.md)
#   llm tag <file>                          list the file's actual tags + the schema's expected; flag diffs
#   llm tag [<file>] get <tag>              print the body of <tag> in <file>; <file> defaults to root index.md
#   llm tag [<file>] set <tag> [<content>]  replace the body of <tag>; content is positional or stdin
#
# Schema-awareness (v3):
#   The schema-declared tag list for a given file is resolved from:
#     - root index.md  → keys of `root.tags`
#     - <pillar>/index.md → keys of `root.entities.<pillar>.tags`
#     - schema.yaml or any file → entries under `meta.tags` whose `host_file:`
#       matches the file path literally, or `*` (catch-all, anywhere).
#   Deeper-nested entity tags (e.g. handoff's `files` block) match via the
#   `host_file: "*"` catch-all in meta.tags.
#
# Strictness:
#   `get` and `set` REFUSE if <tag> is not declared in the schema for <file>.
#   This is stricter than the previous (warn-only) behaviour — every tag op is
#   validated against the contract.
#
# Expects from entry-point: DOT_LLM_DIR, SCHEMA. Reuses fm_* from common.sh.

_TAG_NAME_RE='^[a-z][a-z0-9_-]*(:[a-z][a-z0-9_*-]*)?$'

cmd_tag_help() {
  cat <<'EOF'
llm tag — read/write/audit <!-- llm:NAME --> marker blocks (v3 schema-aware)

Usage:
  llm tag                                  list tags declared for the root index.md
  llm tag <file>                           list the file's actual tags + schema's expected; flag diffs
  llm tag [<file>] get <tag>               print the body of <tag>
  llm tag [<file>] set <tag> [<content>]   replace the body; content positional or stdin

<file> defaults to the root index.md (.llm/index.md).
Tag name format: [a-z][a-z0-9_-]*(:[a-z][a-z0-9_*-]*)?  (the `llm:` prefix in
the file is implicit — pass `specs` or `llm:specs`, both resolve to the same).

Schema validation:
  - `get` / `set` refuse if <tag> is not declared in the schema for <file>.
  - `list` views show schema's expectation alongside what's in the file.

Exit codes:
  0  success
  1  file/tag absent, validation failure, or write failure
  2  usage error or invalid tag name
EOF
}

# ── path → schema-declared tag list ─────────────────────────────────────────

# Path of $1 relative to DOT_LLM_DIR. Falls back to the original path when it
# cannot be made relative (file outside the tree, or root unresolved).
_tag_relpath() {
  local file="$1" abs_file abs_root
  abs_file=$(cd "$(dirname "$file")" 2>/dev/null && pwd)/$(basename "$file") || { printf '%s\n' "$file"; return; }
  abs_root=$(cd "$DOT_LLM_DIR" 2>/dev/null && pwd) || { printf '%s\n' "$file"; return; }
  if [[ "$abs_file" == "$abs_root/"* ]]; then
    printf '%s\n' "${abs_file#"$abs_root"/}"
  else
    printf '%s\n' "$file"
  fi
}

# Resolve the file argument — empty means root index.md.
_tag_resolve_file() {
  local arg="${1:-}"
  if [[ -z "$arg" ]]; then
    printf '%s\n' "$DOT_LLM_DIR/index.md"
  elif [[ "$arg" == /* ]]; then
    printf '%s\n' "$arg"
  elif [[ -f "$arg" ]]; then
    printf '%s\n' "$arg"
  else
    # Treat as relative to DOT_LLM_DIR
    printf '%s\n' "$DOT_LLM_DIR/$arg"
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
# Nested forms (e.g. meta.tags.framework.apps.values) yield the dotted-colon
# composite name (`framework:apps:values`).
_tag_schema_meta_table() {
  [[ -f "$SCHEMA" ]] || return 0
  awk '
    function flush_pending(   k) {
      # If we left the meta.tags region with a pending key that we never matched
      # a host_file for, drop it silently — its host is unknown.
    }
    /^meta:/                          { st="meta"; depth_stack=""; next }
    st=="meta" && /^[^ ]/             { st=""; next }
    st=="meta" && /^  tags:[[:space:]]*$/ { st="mtags"; path=""; next }
    st=="mtags" && /^  [^ ]/          { st="meta" }

    # 4-space indent: top-level meta.tags entry
    st=="mtags" && /^    [a-z"]/ {
      line=$0; sub(/^    /, "", line); gsub(/"/, "", line)
      # Two forms: inline object `name: {host_file: X, ...}` or block (followed by deeper lines)
      if (match(line, /^[a-z][a-z0-9_-]*:[[:space:]]*\{/)) {
        # inline object: extract name and host_file
        name=line; sub(/:.*$/, "", name)
        host=""
        if (match(line, /host_file:[[:space:]]*[^,}]+/)) {
          host=substr(line, RSTART+10, RLENGTH-10)
          sub(/^[[:space:]]*/, "", host); sub(/[[:space:]]*$/, "", host)
        }
        print name "\t" host
        next
      }
      # block form: this is a branch (key:) — track the branch path
      if (match(line, /^[a-z][a-z0-9_-]*:[[:space:]]*$/)) {
        path=line; sub(/:.*$/, "", path)
        depth=4
        next
      }
    }
    # Deeper levels under a tracked branch
    st=="mtags" && /^      / && path != "" {
      # 6-space indent: sub-branch or leaf
      line=$0
      indent=0
      while (substr(line, indent+1, 1) == " ") indent++
      content=substr(line, indent+1)
      if (match(content, /^[a-z][a-z0-9_-]*:[[:space:]]*\{/)) {
        name=content; sub(/:.*$/, "", name)
        host=""
        if (match(content, /host_file:[[:space:]]*[^,}]+/)) {
          host=substr(content, RSTART+10, RLENGTH-10)
          sub(/^[[:space:]]*/, "", host); sub(/[[:space:]]*$/, "", host)
        }
        # Compose dotted-colon name from the path stack
        composite=path
        # walk back from current depth: simplified — just join with ":"
        sub(/^.*/, "", composite)
        composite=path
        # Track only one level of nesting for now (path is the parent branch)
        # Actual composite = path + ":" + name
        print path ":" name "\t" host
        next
      }
      if (match(content, /^[a-z][a-z0-9_-]*:[[:space:]]*$/)) {
        # deeper branch: extend path
        sub_name=content; sub(/:.*$/, "", sub_name)
        path=path ":" sub_name
        next
      }
    }
  ' "$SCHEMA"
}

# Emit the schema-declared tag NAMES for <file>. Combines:
#   - root.tags keys when file is the root index
#   - root.entities.<pillar>.tags keys when file is a pillar's index.md
#   - meta.tags entries whose host_file matches the file (literal) or `*`
_tag_schema_tags_for_file() {
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

  # 3) meta.tags entries with matching host_file
  local mname mhost basename_rel
  basename_rel=$(basename "$rel")
  while IFS=$'\t' read -r mname mhost; do
    [[ -z "$mname" ]] && continue
    case "$mhost" in
      "")        ;;   # no host_file → skip
      '*')       printf '%s\n' "$mname" ;;       # catch-all
      "$rel")    printf '%s\n' "$mname" ;;       # literal file path
      "$basename_rel") printf '%s\n' "$mname" ;; # literal basename
    esac
  done < <(_tag_schema_meta_table)
  # Explicit success — `while read … done < <(…)` returns 1 on EOF, and with
  # `set -o pipefail` (active in the entry script) the downstream `grep` in
  # callers gets the read's 1 instead of grep's own exit. Force 0 here.
  return 0
}

# True (0) if <tag> is declared in the schema for <file>.
# Captures output before grep (no pipe) — `grep -q` matches early and closes
# stdin, which sends SIGPIPE to the producer; `set -o pipefail` would then
# turn the pipe's exit into 141 (false negative).
_tag_in_schema_for_file() {
  local file="$1" tag="$2"
  local tags
  tags=$(_tag_schema_tags_for_file "$file")
  grep -qxF "$tag" <<< "$tags"
}

# ── form: list-only (llm tag, llm tag <file>) ─────────────────────────────

_tag_list() {
  local file="$1"
  [[ -f "$file" ]] || { red "✗ file not found: $file"; return 1; }

  local rel
  rel=$(_tag_relpath "$file")
  printf 'File: %s\n\n' "$rel"

  # Schema-declared
  local schema_list
  schema_list=$(_tag_schema_tags_for_file "$file" | sort -u)

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
    yellow "File: no <!-- llm:NAME --> blocks present."
  else
    printf 'File contains:\n'
    while IFS= read -r t; do
      [[ -n "$t" ]] && printf '  • %s\n' "$t"
    done <<< "$actual_list"
  fi

  # Diff
  local only_schema only_file
  only_schema=$(comm -23 <(printf '%s\n' "$schema_list") <(printf '%s\n' "$actual_list") | grep -v '^$' || true)
  only_file=$(comm -13 <(printf '%s\n' "$schema_list") <(printf '%s\n' "$actual_list") | grep -v '^$' || true)

  if [[ -z "$only_schema" && -z "$only_file" ]]; then
    printf '\n'
    green "✓ aligned — every declared tag is present, no extras."
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
      yellow "llm tag get: block '$tag' is present but empty in $(_tag_relpath "$file")" >&2
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
        print "<!-- llm:" a[i] " -->"
        print "<!-- /llm:" a[i] " -->"
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
  [[ -f "$file" ]] || { red "✗ file not found: $file"; return 1; }

  # Strip llm: prefix and validate name shape.
  tag="${tag#llm:}"
  if [[ ! "$tag" =~ $_TAG_NAME_RE ]]; then
    red "✗ invalid tag name: '$tag'"
    return 2
  fi

  if ! _tag_in_schema_for_file "$file" "$tag"; then
    red "✗ tag '$tag' is not declared in the schema for $(_tag_relpath "$file")"
    yellow "  → run 'llm tag $(_tag_relpath "$file")' to see what the schema declares for this file"
    return 1
  fi

  case "$verb" in
    get) _tag_do_get "$file" "$tag" ;;
    set) _tag_do_set "$file" "$tag" "$content" ;;
  esac
}

# ── main ──────────────────────────────────────────────────────────────────

cmd_tag() {
  case "${1:-}" in
    help|-h|--help) cmd_tag_help; return 0 ;;
    "")
      # No args → list root's tags from schema (and what's in the root index.md).
      _tag_list "$(_tag_resolve_file "")"
      return $?
      ;;
    get|set)
      # First arg is a verb → file defaults to root index.md.
      local verb="$1"; shift
      _tag_dispatch_verb "$verb" "" "${1:-}" "${2:-}"
      return $?
      ;;
    *)
      # First arg is a file (or schema-relative path).
      local file="$1"; shift
      if [[ $# -eq 0 ]]; then
        _tag_list "$(_tag_resolve_file "$file")"
        return $?
      fi
      case "$1" in
        get|set)
          local verb="$1"; shift
          _tag_dispatch_verb "$verb" "$file" "${1:-}" "${2:-}"
          return $?
          ;;
        *)
          red "✗ unexpected arg: $1"
          cmd_tag_help
          return 2
          ;;
      esac
      ;;
  esac
}
