# common.sh — shared helpers sourced by every cmd_*.sh module.
#
# Provides:
#   - colored output: red, yellow, green, say (gated by QUIET)
#   - frontmatter helpers for YAML-ish keys: fm_scalar, fm_list, fm_h1
#   - tag helpers for `<!-- cumaru:NAME -->` regions
#     (fm_block_list, fm_block_extract, fm_block_replace)
#
# The framework tree has one fixed project-relative location. Change it here
# only if every cumaru project managed by this checkout must use another name.
CUMARU_DIR=".cumaru"
CONFIG="$CUMARU_DIR/config.yaml"
# Agent-agnostic install target — replaces .claude/ and .codex/.
# Holds skills, commands, hooks, instruction file, and hook config.
AGENTS_DIR=".agents"
#
# Tag convention:
#   `<!-- cumaru:NAME -->` ... `<!-- /cumaru:NAME -->`, where NAME matches the
#   shared `FM_TAG_NAME_RE`. Single-token names
#   (`touched`, `components`, `root`) are the canonical form. Colon-separated
#   names remain valid when explicitly declared by a schema.
# Runtime parsing accepts only the `cumaru:` prefix.

# --- color helpers ---

red()    { printf '\033[31m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
green()  { printf '\033[32m%s\033[0m\n' "$*"; }
say()    { [[ "${QUIET:-0}" == "1" ]] || printf '%s\n' "$*"; }

# --- v9 configuration tree resolution ---

# Return success when CONFIG uses the direct-tree v9 model. Older installed
# trees keep their legacy consumers during the migration window.
config_tree_is_v9() {
  [[ -f "${1:-$CONFIG}" ]] && [[ "$(yq -r '.version // 0' "${1:-$CONFIG}" 2>/dev/null)" == "9" ]]
}

# Reject an untrusted path segment before it can be combined with .cumaru/.
# Schema validation catches these in normal operation; this remains a runtime
# boundary for every reader and writer that consumes a resolved destination.
_config_tree_safe_relative_path() {
  local path="$1" part rest
  [[ -n "$path" && "$path" != /* ]] || return 1
  rest="$path"
  while :; do
    part="${rest%%/*}"
    [[ -n "$part" && "$part" != "." && "$part" != ".." ]] || return 1
    [[ "$rest" == */* ]] || break
    rest="${rest#*/}"
  done
}

# Return success when an existing component below root is a symlink. Every
# configured destination rejects links, including links that happen to point
# back inside .cumaru/, because mutation safety must not depend on link target.
_config_tree_has_symlink_component() {
  local root="$1" path="$2" rel probe part rest
  [[ "$path" == "$root" || "$path" == "$root/"* ]] || return 1
  rel="${path#"$root"/}"
  probe="$root"
  rest="$rel"
  while [[ -n "$rest" ]]; do
    part="${rest%%/*}"
    probe="$probe/$part"
    [[ -L "$probe" ]] && return 0
    [[ "$rest" == */* ]] || break
    rest="${rest#*/}"
  done
  return 1
}

# Emit the v9 direct-tree declarations as TSV:
# logical selector, physical selector, kind, optional, ownership, effective
# frontmatter, tags, and global rules. Physical selectors remain patterns here;
# expansion happens below against the contained installed tree.
_config_tree_declarations() {
  local config="${1:-$CONFIG}"
  yq -o=json '. ' "$config" 2>/dev/null | jq -r '
    def reserved: ["path", "optional", "framework", "frontmatter", "tags"];
    .rules as $rules |
    def contract($node; $kind; $depth):
      ($rules.markdown.frontmatter // {}) +
      (if $kind == "directory" then ($rules.index_md.frontmatter // {}) else {} end) +
      (if $kind == "directory" and $depth == 1 then ($rules.pillar_index.frontmatter // {}) else {} end) +
      ($node.frontmatter // {});
    def row($node; $logical; $physical; $kind; $depth):
      [($logical | join("/")), ($physical | join("/")), $kind,
       ($node.optional // false | tostring), ($node.framework // false | tostring),
       (contract($node; $kind; $depth) | tojson), ($node.tags // [] | tojson),
       ($rules | tojson)] | @tsv;
    def descend($node; $logical; $physical):
      $node | to_entries[]
      | select(.key as $key | reserved | index($key) | not)
      | .key as $key | .value as $value
      | ($value.path // $key) as $segment
      | ($logical + [$key]) as $next_logical
      | ($physical + [$segment]) as $next_physical
      | (if $key | contains(".") then "file" else "directory" end) as $kind
      | row($value; $next_logical; $next_physical; $kind; ($next_logical | length)),
        descend($value; $next_logical; $next_physical);
    row(.root; ["."]; ["index.md"]; "file"; 0),
    descend(.root; []; [])
  '
}

# Resolve every declared v9 tree entry that exists on disk. Each result is:
# logical entry, physical Markdown path relative to .cumaru/, ownership,
# applicable frontmatter, applicable tags, and global rules. Literal entries
# are required unless optional; globs intentionally match zero or more paths.
# Any escaping path, symlink component, or duplicate destination fails before
# a caller can mutate the target.
config_tree_resolve() {
  local config="${1:-$CONFIG}" root="${2:-$CUMARU_DIR}"
  local root_abs logical selector kind optional ownership frontmatter tags rules
  local target candidate rel matches=() seen_key has_glob prior index declaration
  local seen_paths=() seen_logicals=() seen_ownership=() seen_frontmatter=() seen_tags=() seen_rules=() seen_globs=() declarations=()

  config_tree_is_v9 "$config" || return 0
  [[ -d "$root" && ! -L "$root" ]] || { printf 'cumaru config: .cumaru/ must be a real directory\n' >&2; return 1; }
  root_abs=$(cd "$root" 2>/dev/null && pwd -P) || return 1

  while IFS= read -r declaration; do declarations+=("$declaration"); done < <(_config_tree_declarations "$config")
  for declaration in "${declarations[@]}"; do
    IFS=$'\t' read -r logical selector kind optional ownership frontmatter tags rules <<< "$declaration"
    matches=()
    _config_tree_safe_relative_path "$selector" || {
      printf 'cumaru config: unsafe resolved path for %s: %s\n' "$logical" "$selector" >&2
      return 1
    }
    has_glob=0
    case "$selector" in *[\*\?\[]*) has_glob=1 ;; esac
    if [[ "$has_glob" == "1" ]]; then
      while IFS= read -r candidate; do matches+=("$candidate"); done < <(compgen -G "$root_abs/$selector" || true)
    elif [[ -e "$root_abs/$selector" || -L "$root_abs/$selector" ]]; then
      matches=("$root_abs/$selector")
    else
      matches=()
    fi

    if [[ ${#matches[@]} -eq 0 ]]; then
      [[ "$has_glob" == "1" || "$optional" == "true" ]] && continue
      printf 'cumaru config: required entry is missing: %s\n' "$logical" >&2
      return 1
    fi

    for candidate in "${matches[@]}"; do
      if [[ "$has_glob" == "1" ]]; then
        rel="${candidate#"$root_abs"/}"
        # A directory node owns its index.md; a wildcard child selector never
        # reclassifies that parent index as one of its children.
        [[ "$selector" == */* && "$rel" == "${selector%/*}/index.md" ]] && continue
        for prior in "${declarations[@]}"; do
          IFS=$'\t' read -r _ prior_selector _ <<< "$prior"
          case "$prior_selector" in *[\*\?\[]*) continue ;; esac
          [[ "$prior_selector" == "$rel" ]] && { candidate=""; break; }
        done
        [[ -n "$candidate" ]] || continue
      fi

      # A directory selector can use a wildcard such as "*". Skip matches of
      # the other filesystem kind so a sibling Markdown file does not turn a
      # zero-or-more directory glob into an invalid declaration.
      if [[ "$has_glob" == "1" ]]; then
        [[ "$kind" == "directory" && ! -d "$candidate" ]] && continue
        [[ "$kind" == "file" && ! -f "$candidate" ]] && continue
      fi

      if [[ "$kind" == "directory" ]]; then
        [[ -d "$candidate" && ! -L "$candidate" ]] || { printf 'cumaru config: directory entry is unsafe: %s\n' "$logical" >&2; return 1; }
        target="$candidate/index.md"
      else
        target="$candidate"
      fi
      _config_tree_has_symlink_component "$root_abs" "$target" && { printf 'cumaru config: symlinked destination is unsafe: %s\n' "$logical" >&2; return 1; }
      [[ -f "$target" && ! -L "$target" ]] || { printf 'cumaru config: Markdown entry is unsafe or missing: %s\n' "$logical" >&2; return 1; }
      rel="${target#"$root_abs"/}"
      [[ "$rel" != "$target" && "$rel" != *"/../"* ]] || { printf 'cumaru config: resolved path escapes .cumaru/: %s\n' "$logical" >&2; return 1; }
      # Resolve existing parents physically so an intermediate symlink cannot
      # redirect a read or later write outside the installed tree.
      prior="$(cd "$(dirname "$target")" 2>/dev/null && pwd -P)"
      [[ "$prior" == "$root_abs" || "$prior" == "$root_abs/"* ]] || { printf 'cumaru config: resolved path escapes .cumaru/: %s\n' "$logical" >&2; return 1; }
      seen_key="$rel"
      for index in "${!seen_paths[@]}"; do
        [[ "${seen_paths[$index]}" == "$seen_key" ]] || continue
        if [[ "$has_glob" == "1" && "${seen_globs[$index]}" == "1" && "${seen_ownership[$index]}" == "$ownership" ]]; then
          seen_frontmatter[$index]=$(jq -cn --argjson current "${seen_frontmatter[$index]}" --argjson incoming "$frontmatter" '$current + $incoming') || return 1
          seen_tags[$index]=$(jq -cn --argjson current "${seen_tags[$index]}" --argjson incoming "$tags" '$current + $incoming | unique') || return 1
          candidate=""
          break
        fi
        printf 'cumaru config: destination collision: %s and %s resolve to %s\n' "${seen_logicals[$index]}" "$logical" "$rel" >&2
        return 1
      done
      [[ -n "$candidate" ]] || continue
      seen_paths+=("$seen_key")
      seen_logicals+=("$logical")
      seen_ownership+=("$ownership")
      seen_frontmatter+=("$frontmatter")
      seen_tags+=("$tags")
      seen_rules+=("$rules")
      seen_globs+=("$has_glob")
    done
  done
  for index in "${!seen_paths[@]}"; do
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "${seen_logicals[$index]}" "${seen_paths[$index]}" "${seen_ownership[$index]}" "${seen_frontmatter[$index]}" "${seen_tags[$index]}" "${seen_rules[$index]}"
  done
}

# Emit the top-level logical selectors for v9 filter UIs.
config_tree_root_keys() {
  local config="${1:-$CONFIG}"
  config_tree_is_v9 "$config" || return 0
  yq -o=json '.root' "$config" 2>/dev/null | jq -r 'keys[] | select(. as $key | ["path", "optional", "framework", "frontmatter", "tags"] | index($key) | not)'
}

# Resolve a top-level logical selector to its actual directory path. This is
# used by consumers whose configuration names a pillar rather than a filename.
config_tree_root_directory() {
  local logical="$1" row resolved rel
  while IFS=$'\t' read -r resolved rel _; do
    [[ "$resolved" == "$logical" && "$rel" == */index.md ]] || continue
    printf '%s\n' "${rel%/index.md}"
    return 0
  done < <(config_tree_resolve)
  return 1
}

# --- frontmatter scalar/list helpers ---

# Extract the scalar value of a top-level frontmatter key from $1. Empty if missing.
fm_scalar() {
  local file="$1" key="$2"
  yq --front-matter=extract ".[\"$key\"] // \"\"" "$file"
}

# Extract a YAML list under a top-level frontmatter key from $1. One item per line.
fm_list() {
  local file="$1" key="$2"
  yq --front-matter=extract ".[\"$key\"][] // \"\"" "$file"
}

# First H1 line in $1, with the leading `# ` stripped.
fm_h1() {
  awk '/^# / { sub(/^# /, ""); print; exit }' "$1"
}

# --- tag helpers ---

# Emit the deterministic Markdown inventory when doctor has materialized one;
# fall back to a standalone walk for every other caller.
_fm_inventory_markdown_files() {
  local root="$1" file
  if [[ "${FM_INVENTORY_ROOT:-}" == "$root" ]]; then
    for file in "${FM_INVENTORY_MARKDOWN[@]+"${FM_INVENTORY_MARKDOWN[@]}"}"; do
      printf '%s\n' "$file"
    done
    return 0
  fi
  find "$root" -type f -name '*.md' -print0 | LC_ALL=C sort -z | while IFS= read -r -d '' file; do
    printf '%s\n' "$file"
  done
}

# Marker recognition is anchored to the **whole line** (with tolerance for
# leading whitespace and YAML/JS comment prefixes like `# ` or `// `). This
# prevents textual mentions of a marker inside prose (e.g. inline code in a
# rule explanation) from being treated as real boundaries.

FM_TAG_NAME_RE='^[a-z][a-z0-9_-]*(:[a-z][a-z0-9_*-]*)*$'

# Parse balanced tags with stack semantics. Foreign closing markers inside an
# open tag are body content; a close for a lower stack frame is a crossing.
_fm_block_parse() {
  local file="$1" mode="$2" name="${3:-}" context="${4:-file}"
  awk -v mode="$mode" -v wanted="$name" -v context="$context" -v name_re="$FM_TAG_NAME_RE" '
    function marker_line(s,    t) {
      t=s; sub(/^[[:space:]]*(#|\/\/)?[[:space:]]*/, "", t)
      sub(/[[:space:]]+$/, "", t); return t
    }
    function opening(s,    n) {
      n=s; sub(/^<!-- cumaru:/, "", n); sub(/ -->$/, "", n)
      if (s !~ /^<!-- cumaru:/ || s !~ / -->$/ || n !~ name_re) return ""
      return n
    }
    function closing(s,    n) {
      n=s; sub(/^<!-- \/cumaru:/, "", n); sub(/ -->$/, "", n)
      if (s !~ /^<!-- \/cumaru:/ || s !~ / -->$/ || n !~ name_re) return ""
      return n
    }
    function die(message) { print context " " message > "/dev/stderr"; bad=1; exit 1 }
    {
      ml=marker_line($0); o=opening(ml); c=closing(ml)
      if (o != "") {
        if (capturing) print $0
        depth++; stack[depth]=o
        if (mode == "list") print o
        if (mode == "top-list" && depth == 1) print o
        if (mode == "nested" && depth > 1) nested=1
        if (mode == "extract" && o == wanted && !capturing) {
          if (found++) printf "\n"
          capturing=1; capture_depth=depth
        } else if (mode == "extract-top" && o == wanted && depth == 1 && !capturing) {
          if (found++) printf "\n"
          capturing=1; capture_depth=depth
        }
        next
      }
      if (c != "") {
        if (depth == 0) die("closing tag \"" c "\" has no top-level opening tag")
        if (c == stack[depth]) {
          if (capturing && depth == capture_depth) capturing=0
          else if (capturing) print $0
          delete stack[depth]; depth--; next
        }
        for (i=depth-1; i>=1; i--) if (stack[i] == c)
          die("tags cross: \"" stack[depth] "\" is still open before \"" c "\"")
        if (capturing) print $0
        next
      }
      if (capturing) print $0
    }
    END {
      if (!bad && depth > 0) {
        print context " tag \"" stack[depth] "\" was never closed" > "/dev/stderr"
        exit 1
      }
      if (!bad && mode == "nested" && nested) print "nested"
    }
  ' "$file"
}

fm_block_validate() { _fm_block_parse "$1" validate "" "${2:-file}" >/dev/null; }

# List every balanced tag name, including independently addressable nested tags.
fm_block_list() { _fm_block_parse "$1" list "" "${2:-file}" | sort -u; }

_fm_block_top_list() { _fm_block_parse "$1" top-list "" "${2:-file}"; }

fm_block_has_nested() { [[ "$(_fm_block_parse "$1" nested "" "${2:-file}")" == nested ]]; }

# Print the body between `<!-- cumaru:NAME -->` and `<!-- /cumaru:NAME -->`
# in $1.
# Args: file, name.
fm_block_extract() {
  _fm_block_parse "$1" extract "$2" "${3:-file}"
}

_fm_block_extract_top() { _fm_block_parse "$1" extract-top "$2" "${3:-file}"; }

# Merge canonical prose with adopter-owned top-level tag bodies. Nested tags
# remain part of their top-level body and are still independently queryable.
fm_block_merge() {
  local src="$1" tgt="$2"
  fm_block_validate "$src" source || return 1
  fm_block_validate "$tgt" local || return 1

  local tmp; tmp=$(mktemp -d) || return 1
  local name id=0 src_tags top_tags
  src_tags=$(_fm_block_top_list "$src" source | sort -u)
  top_tags=$(_fm_block_top_list "$tgt" local | sort -u)
  : > "$tmp/manifest"
  : > "$tmp/orphans"
  while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    id=$((id + 1))
    _fm_block_extract_top "$tgt" "$name" local > "$tmp/body.$id" || { rm -rf "$tmp"; return 1; }
    printf '%s\t%s\n' "$name" "$id" >> "$tmp/manifest"
    if ! grep -qxF "$name" <<< "$src_tags"; then
      { printf '<!-- cumaru:%s -->\n' "$name"
        cat "$tmp/body.$id"
        printf '<!-- /cumaru:%s -->\n\n' "$name"; } >> "$tmp/orphans"
    fi
  done <<< "$top_tags"

  awk -v dir="$tmp" -v name_re="$FM_TAG_NAME_RE" '
    function marker_line(s,    t) {
      t=s; sub(/^[[:space:]]*(#|\/\/)?[[:space:]]*/, "", t)
      sub(/[[:space:]]+$/, "", t); return t
    }
    function opening(s,    n) {
      n=s; sub(/^<!-- cumaru:/, "", n); sub(/ -->$/, "", n)
      if (s !~ /^<!-- cumaru:/ || s !~ / -->$/ || n !~ name_re) return ""
      return n
    }
    function closing(s,    n) {
      n=s; sub(/^<!-- \/cumaru:/, "", n); sub(/ -->$/, "", n)
      if (s !~ /^<!-- \/cumaru:/ || s !~ / -->$/ || n !~ name_re) return ""
      return n
    }
    function flush_orphans(   line, path) {
      if (orphans_done) return
      orphans_done=1; path=dir "/orphans"
      while ((getline line < path) > 0) print line
      close(path)
    }
    BEGIN {
      while ((getline row < (dir "/manifest")) > 0) {
        split(row, fields, "\t"); ids[fields[1]]=fields[2]
      }
      close(dir "/manifest")
    }
    {
      if (NR == 1 && $0 !~ /^---$/) flush_orphans()
      ml=marker_line($0); o=opening(ml); c=closing(ml)
      if (!skip && o != "") {
        depth++
        if (depth == 1 && (o in ids) && !used[o]) {
          used[o]=1; active=o; path=dir "/body." ids[o]
          print
          while ((getline line < path) > 0) print line
          close(path); skip=1; next
        } else if (depth == 1 && (o in ids) && used[o]) {
          active=o; remove=1; skip=1; next
        }
      } else if (!skip && c != "") depth--
      else if (skip && o != "") depth++
      else if (skip && c != "") {
        if (depth == 1 && c == active) {
          skip=0; active=""; depth--
          if (remove) { remove=0; next }
          print; next
        }
        depth--
      }
      if (!skip) {
        print
        if ($0 ~ /^---$/) fences++
        else if (fences == 2 && $0 ~ /^[[:space:]]*$/) flush_orphans()
      }
    }
    END { flush_orphans() }
  ' "$src"
  local rc=$?
  rm -rf "$tmp"
  return $rc
}

# Replace the body of a `<!-- cumaru:NAME -->` block in $1 with content read
# from stdin. Markers are preserved. Returns non-zero (file left unchanged) if
# the open OR the close marker is absent.
# Args: file, name.
fm_block_replace() {
  local file="$1" name="$2"
  [[ "$name" =~ $FM_TAG_NAME_RE ]] || return 1
  fm_block_validate "$file" file || return 1
  # Stream stdin to a temp file. Passing multi-line content via `awk -v
  # new_content="$value"` is unsafe — BSD awk (macOS default) rejects real
  # newlines in `-v` assignments with "awk: newline in string", which
  # silently breaks any multi-line block replacement.
  local content_file
  content_file=$(mktemp)
  cat > "$content_file"
  local normalized
  normalized=$(mktemp)
  if ! fm_block_merge "$file" "$file" > "$normalized"; then
    rm -f "$content_file" "$normalized"
    return 1
  fi
  local open="<!-- cumaru:${name} -->"
  local endmark="<!-- /cumaru:${name} -->"
  # BOTH markers must exist as their own lines (not just substrings in prose).
  # Fail closed: if the close marker is missing, the rewrite below would set
  # skip=1 at the open marker and never reset it, dropping the entire tail of
  # the file from the open marker to EOF — silent data loss. Refusing leaves
  # the (malformed) file untouched.
  if ! awk -v open="$open" -v endmark="$endmark" '
    { t = $0; sub(/^[[:space:]]*(#|\/\/)?[[:space:]]*/, "", t); sub(/[[:space:]]+$/, "", t) }
    t == open    { o = 1 }
    t == endmark { c = 1 }
    END { exit !(o && c) }
  ' "$normalized"; then
    rm -f "$content_file" "$normalized"
    return 1
  fi
  local tmp
  tmp=$(mktemp)
  awk -v open="$open" -v endmark="$endmark" -v content_file="$content_file" '
    function marker_line(s,    t) {
      t = s
      sub(/^[[:space:]]*(#|\/\/)?[[:space:]]*/, "", t)
      sub(/[[:space:]]+$/, "", t)
      return t
    }
    marker_line($0) == open {
      print
      while ((getline line < content_file) > 0) print line
      close(content_file)
      skip = 1
      next
    }
    marker_line($0) == endmark {
      skip = 0
      print
      next
    }
    !skip { print }
  ' "$normalized" > "$tmp" && mv "$tmp" "$file"
  local rc=$?
  rm -f "$content_file" "$normalized"
  return $rc
}

# Walk all real tags under a tree. Emits:
#   <file>\t<tag>
# with file paths relative to the tree root.
fm_block_walk() {
  local root="${1:-$CUMARU_DIR}"
  [[ -d "$root" ]] || return 0

  _fm_inventory_markdown_files "$root" | while IFS= read -r file; do
    fm_block_list "$file" | while IFS= read -r tag; do
      [[ -n "$tag" ]] && printf '%s\t%s\n' "${file#"$root"/}" "$tag"
    done
  done
}

# Emit declared tag names from the v9 tree with a neutral compatibility shape.
# Tag bodies are opaque; this helper exists only for legacy callers that need
# an inventory, not a configured body format.
fm_schema_tag_specs() {
  local root schema
  root="${1:-$CUMARU_DIR}"
  schema="$root/config.yaml"
  [[ -f "$schema" ]] || return 0
  if [[ "${FM_SCHEMA_TAG_SPECS_ROOT:-}" == "$root" ]]; then
    printf '%s\n' "${FM_SCHEMA_TAG_SPECS:-}"
    return 0
  fi
  config_tree_is_v9 "$schema" || return 0
  config_tree_resolve "$schema" "$root" | while IFS=$'\t' read -r _ _ _ _ tags _; do
    jq -r '.[]? | "\(.)\tdefault\tLink,Description\t"' <<< "$tags"
  done | LC_ALL=C sort -u
}

fm_schema_tag_type() {
  local root="$1" tag="$2" name type cols host
  while IFS=$'\t' read -r name type cols host; do
    [[ "$name" == "$tag" ]] || continue
    printf '%s\n' "${type:-default}"
    return 0
  done < <(fm_schema_tag_specs "$root")
  printf '%s\n' "default"
}

fm_schema_tag_columns() {
  local root="$1" tag="$2" name type cols host
  while IFS=$'\t' read -r name type cols host; do
    [[ "$name" == "$tag" ]] || continue
    printf '%s\n' "${cols:-Link,Description}"
    return 0
  done < <(fm_schema_tag_specs "$root")
  printf '%s\n' "Link,Description"
}

fm_schema_tag_is_default() {
  [[ "$(fm_schema_tag_type "$1" "$2")" == "default" ]]
}

# Anchor dir for resolving path links in default tag tables.
# Root index / domain.md point at the adopter project root; other hosts resolve
# links next to the host file. `reference` rows use their own source-file rule.
fm_tag_anchor_dir() {
  local root="$1" host="$2"
  if [[ "$host" == "$root/index.md" || "$host" == "$root/domain.md" ]]; then
    (cd "$(dirname "$root")" 2>/dev/null && pwd) || dirname "$host"
  else
    dirname "$host"
  fi
}

# Resolve a tag row link relative to its host file. Emits:
#   <target>\t<status>
# Status values:
#   ok        target exists on disk
#   missing   local target does not exist
#   external  URL/mailto link
#   anchor    in-page anchor
#   template  placeholder/template target
#   empty     no target
#   invalid   a `reference` row that breaks the coverage rule (see below)
#
# The optional 4th arg is the tag NAME hosting the row. The `reference` tag
# carries the universal coverage rule: its target is always a repository
# SOURCE FILE — resolved from the PROJECT ROOT (the parent of .cumaru/), never a
# path inside .cumaru/, never a directory, never a URL or anchor. Rows breaking
# the rule resolve to `invalid`.
fm_tag_resolve_target() {
  local root="$1" host="$2" raw_target="$3" tag="${4:-}"
  local target="${raw_target%%#*}"

  if [[ -z "$raw_target" ]]; then
    printf '\t%s\n' "empty"
    return 0
  fi
  if [[ "$raw_target" == \#* ]]; then
    if [[ "$tag" == "reference" ]]; then
      printf '%s\t%s\n' "$raw_target" "invalid"
    else
      printf '%s\t%s\n' "$raw_target" "anchor"
    fi
    return 0
  fi
  if [[ "$raw_target" =~ ^[a-zA-Z][a-zA-Z0-9+.-]*: ]]; then
    if [[ "$tag" == "reference" ]]; then
      printf '%s\t%s\n' "$raw_target" "invalid"
    else
      printf '%s\t%s\n' "$raw_target" "external"
    fi
    return 0
  fi
  if [[ "$raw_target" == *"<"* || "$raw_target" == *">"* ]]; then
    printf '%s\t%s\n' "$raw_target" "template"
    return 0
  fi

  if [[ "$tag" == "reference" ]]; then
    _fm_resolve_reference_target "$root" "$target"
    return 0
  fi

  local candidate
  if [[ "$target" == /* ]]; then
    candidate="$target"
  else
    candidate="$(fm_tag_anchor_dir "$root" "$host")/$target"
  fi

  if [[ -d "$candidate" && -f "$candidate/index.md" ]]; then
    candidate="$candidate/index.md"
  fi

  if [[ -e "$candidate" ]]; then
    local abs_root abs_candidate
    abs_root=$(cd "$root" 2>/dev/null && pwd -P) || abs_root=""
    if [[ -d "$candidate" ]]; then
      abs_candidate=$(cd "$candidate" 2>/dev/null && pwd -P) || abs_candidate="$candidate"
    else
      abs_candidate=$(cd "$(dirname "$candidate")" 2>/dev/null && pwd -P)/$(basename "$candidate") || abs_candidate="$candidate"
    fi

    if [[ -n "$abs_root" && "$abs_candidate" == "$abs_root/"* ]]; then
      printf '%s\t%s\n' "${abs_candidate#"$abs_root"/}" "ok"
    else
      printf '%s\t%s\n' "$abs_candidate" "ok"
    fi
    return 0
  fi

  printf '%s\t%s\n' "$target" "missing"
}

# Resolve a `reference` row target against the project root. Emits the same
# <target>\t<status> shape as fm_tag_resolve_target. On `ok` the target is
# printed relative to the project root (the path `git ls-files` would show).
_fm_resolve_reference_target() {
  local root="$1" target="$2"
  local abs_root proj candidate abs_candidate

  abs_root=$(cd "$root" 2>/dev/null && pwd -P) || abs_root=""
  if [[ -z "$abs_root" ]]; then
    printf '%s\t%s\n' "$target" "missing"
    return 0
  fi
  proj=$(dirname "$abs_root")

  # Absolute paths escape the repository — not a source file reference.
  if [[ "$target" == /* ]]; then
    printf '%s\t%s\n' "$target" "invalid"
    return 0
  fi

  candidate="$proj/$target"
  if [[ ! -e "$candidate" ]]; then
    printf '%s\t%s\n' "$target" "missing"
    return 0
  fi
  if [[ -d "$candidate" ]]; then
    printf '%s\t%s\n' "$target" "invalid"
    return 0
  fi

  abs_candidate=$(cd "$(dirname "$candidate")" 2>/dev/null && pwd -P)/$(basename "$candidate") || abs_candidate="$candidate"
  if [[ "$abs_candidate" == "$abs_root/"* ]]; then
    printf '%s\t%s\n' "$target" "invalid"
    return 0
  fi
  if [[ "$abs_candidate" != "$proj/"* ]]; then
    printf '%s\t%s\n' "$target" "invalid"
    return 0
  fi

  printf '%s\t%s\n' "${abs_candidate#"$proj"/}" "ok"
}

# Emit every [Link, Description] row in every Cumaru tag under a tree:
#   <file>\t<tag>\t<link>\t<description>\t<target>\t<status>
# The parser intentionally follows the v4 table shape and keeps validation
# separate: malformed rows are omitted here and surfaced by doctor-specific
# checks.
fm_tag_table_rows() {
  local root="${1:-$CUMARU_DIR}"
  [[ -d "$root" ]] || return 0

  _fm_inventory_markdown_files "$root" | while IFS= read -r file; do
    awk -v file="$file" -v root="$root" '
      function trim(s) {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
        return s
      }
      function link_target(cell, raw) {
        raw = cell
        if (match(raw, /\[[^]]+\]\([^)]+\)/)) {
          raw = substr(raw, RSTART, RLENGTH)
          sub(/^.*\]\(/, "", raw)
          sub(/\)$/, "", raw)
        }
        gsub(/`/, "", raw)
        return trim(raw)
      }
      {
        line = $0
        marker = line
        sub(/^[[:space:]]*(#|\/\/)?[[:space:]]*/, "", marker)
        sub(/[[:space:]]+$/, "", marker)
      }
      marker ~ /^<!-- cumaru:[a-z0-9_:-]+ -->$/ {
        tag = marker
        sub(/^<!-- cumaru:/, "", tag)
        sub(/ -->$/, "", tag)
        in_block = 1
        next
      }
      marker ~ /^<!-- \/cumaru:[a-z0-9_:-]+ -->$/ {
        in_block = 0
        next
      }
      in_block && line ~ /^[[:space:]]*\|/ {
        row = line
        if (tolower(row) ~ /^[[:space:]]*\|[[:space:]]*link[[:space:]]*\|[[:space:]]*description[[:space:]]*\|?[[:space:]]*$/) next
        if (row ~ /^[[:space:]]*\|[[:space:]-]+\|[[:space:]-]+\|?[[:space:]]*$/) next

        sub(/^[[:space:]]*\|/, "", row)
        sub(/\|[[:space:]]*$/, "", row)
        n = split(row, cells, /\|/)
        if (n < 2) next

        link = trim(cells[1])
        desc = trim(cells[2])
        for (i = 3; i <= n; i++) desc = desc " | " trim(cells[i])
        target = link_target(link)

        gsub(/\t/, " ", link)
        gsub(/\t/, " ", desc)
        gsub(/\t/, " ", target)
        print file "\t" tag "\t" link "\t" desc "\t" target
      }
    ' "$file" | while IFS=$'\t' read -r host tag link desc target; do
      local resolved status rel_host
      IFS=$'\t' read -r resolved status < <(fm_tag_resolve_target "$root" "$host" "$target" "$tag")
      rel_host="${host#"$root"/}"
      printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$rel_host" "$tag" "$link" "$desc" "$resolved" "$status"
    done
  done
}

# Emit deterministic table rows for every tag declared as `default` or a custom
# array. Output: file<TAB>tag<TAB>columns_csv<TAB>cell1<TAB>cell2...
fm_tag_typed_table_rows() {
  local root="${1:-$CUMARU_DIR}"
  [[ -d "$root" ]] || return 0

  _fm_inventory_markdown_files "$root" | while IFS= read -r file; do
    awk -v file="$file" '
      function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
      {
        line = $0
        marker = line
        sub(/^[[:space:]]*(#|\/\/)?[[:space:]]*/, "", marker)
        sub(/[[:space:]]+$/, "", marker)
      }
      marker ~ /^<!-- cumaru:[a-z0-9_:-]+ -->$/ {
        tag = marker; sub(/^<!-- cumaru:/, "", tag); sub(/ -->$/, "", tag)
        in_block = 1; next
      }
      marker ~ /^<!-- \/cumaru:[a-z0-9_:-]+ -->$/ { in_block = 0; next }
      in_block && line ~ /^[[:space:]]*\|/ {
        row = line
        if (row ~ /^[[:space:]]*\|[-:[:space:]\|]+$/) next
        sub(/^[[:space:]]*\|/, "", row)
        sub(/\|[[:space:]]*$/, "", row)
        n = split(row, cells, /\|/)
        out = file "\t" tag
        for (i = 1; i <= n; i++) {
          cell = trim(cells[i]); gsub(/\t/, " ", cell); out = out "\t" cell
        }
        print out
      }
    ' "$file" | while IFS=$'\t' read -r host tag rest; do
      local type cols rel_host
      type=$(fm_schema_tag_type "$root" "$tag")
      [[ "$type" == "default" || "$type" == "table" ]] || continue
      cols=$(fm_schema_tag_columns "$root" "$tag")
      rel_host="${host#"$root"/}"
      printf '%s\t%s\t%s\t%s\n' "$rel_host" "$tag" "$cols" "$rest"
    done
  done
}

# Emit table-shape issues for deterministic table tags. Output:
#   <file>\t<tag>\t<expected_columns>\t<actual_columns>
fm_tag_table_shape_issues() {
  local root="${1:-$CUMARU_DIR}"
  fm_tag_typed_table_rows "$root" | while IFS=$'\t' read -r file tag expected c1 c2 c3 c4 c5 c6 rest; do
    local header actual expected_count actual_count IFS_SAVE
    header="$c1,$c2"
    [[ -n "${c3:-}" ]] && header+=",$c3"
    [[ -n "${c4:-}" ]] && header+=",$c4"
    [[ -n "${c5:-}" ]] && header+=",$c5"
    [[ -n "${c6:-}" ]] && header+=",$c6"
    [[ -n "${rest:-}" ]] && header+=",$rest"
    actual="$header"
    expected_count=$(awk -F',' '{print NF}' <<< "$expected")
    actual_count=$(awk -F',' '{print NF}' <<< "$actual")
    # Only validate header rows. Data rows vary by content; malformed row counts
    # remain visible via --rows without becoming a path-resolution warning.
    if [[ "$actual" == "$expected" ]]; then
      continue
    fi
    if [[ "$c1" =~ ^[A-Za-z][A-Za-z0-9_-]*$ && "$actual_count" -ge 2 && "$actual_count" -ne "$expected_count" ]]; then
      printf '%s\t%s\t%s\t%s\n' "$file" "$tag" "$expected" "$actual"
    fi
  done
}

# List installed discipline files in deterministic order.
_cumaru_discipline_files() {
  local file
  [[ -d "$CUMARU_DIR/disciplines" ]] || return 0
  file="$CUMARU_DIR/disciplines/index.md"
  [[ -f "$file" && ! -L "$file" ]] && printf '%s\n' "$file"
  for file in "$CUMARU_DIR"/disciplines/*.md; do
    [[ -f "$file" && ! -L "$file" ]] || continue
    [[ "$(basename "$file")" == "index.md" ]] && continue
    printf '%s\n' "$file"
  done | LC_ALL=C sort
}

# Print the canonical CUMARU-HOOK block for a native Markdown instruction file.
# Args: rel_index, created (0|1), adapter.
# When created==1, the BEGIN marker says "created" instead of the default.
_cumaru_hook_block() {
  local rel_index="$1" created="${2:-0}" agent="${3:-generic}"
  local rel_domain file rel_file
  rel_domain="$(dirname "$rel_index")/domain.md"
  local begin="<!-- BEGIN CUMARU-HOOK -->"
  [[ "$created" == "1" ]] && begin="<!-- BEGIN CUMARU-HOOK created -->"
  cat <<EOF
$begin
## \`.cumaru/\` framework

This project uses the \`.cumaru/\` framework — a spec-driven, agent-friendly knowledge structure. At the start of every session in this repository, enter the framework in this order: read \`$rel_index\` (the kernel), \`$rel_domain\` (the domain), \`.cumaru/disciplines/index.md\` (the discipline evaluation contract), and every other installed file under \`.cumaru/disciplines/\`, then run \`cumaru tree .\` to project the root's current candidates and their summaries. Every discipline is loaded. Its \`strictness\` controls required consideration and its \`applies-when\` controls application; a missing strictness is invalid and treated as \`0/10\`. Prune tree candidates by relevance — never prune the execution disciplines.

@$rel_index
@$rel_domain
EOF

  if [[ "$agent" == "claude" ]]; then
    while IFS= read -r file; do
      rel_file="${file#"$(dirname "$CUMARU_DIR")"/}"
      printf '@%s\n' "$rel_file"
    done < <(_cumaru_discipline_files)
  else
    while IFS= read -r file; do
      rel_file="${file#"$(dirname "$CUMARU_DIR")"/}"
      printf '\n<!-- BEGIN CUMARU-DISCIPLINE %s -->\n' "$rel_file"
      printf 'Source: `%s`\n\n' "$rel_file"
      cat "$file"
      printf '\n<!-- END CUMARU-DISCIPLINE %s -->\n' "$rel_file"
    done < <(_cumaru_discipline_files)
  fi

  printf '%s\n' '<!-- END CUMARU-HOOK -->'
}
