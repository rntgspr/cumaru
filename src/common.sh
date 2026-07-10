# common.sh — shared helpers sourced by every cmd_*.sh module.
#
# Provides:
#   - colored output: red, yellow, green, say (gated by QUIET)
#   - frontmatter helpers for YAML-ish keys: fm_scalar, fm_list, fm_h1
#   - marker-block helpers for `<!-- cumaru:NAME -->` regions
#     (fm_block_list, fm_block_extract, fm_block_replace)
#
# The framework tree has one fixed project-relative location. Change it here
# only if every cumaru project managed by this checkout must use another name.
CUMARU_DIR=".cumaru"
SCHEMA="$CUMARU_DIR/schema.yaml"
# Agent-agnostic install target — replaces .claude/ and .codex/.
# Holds skills, commands, hooks, instruction file, and hook config.
AGENTS_DIR=".agents"
#
# Marker convention:
#   `<!-- cumaru:NAME -->` or (legacy) `<!-- llm:NAME -->` ... `<!-- /cumaru:NAME -->`
#   where NAME is any string matching `[a-z0-9_:-]+`. Single-token names
#   (`intake`, `plans`, `components`, `root`) are the canonical form. Two-token
#   names (`files:touched`, etc.) remain valid for pattern-based tags
#   declared in schema.yaml under `tags:`.
# The parser accepts `cumaru:` prefix for marker blocks
# trees are not broken during migration.

# --- color helpers ---

red()    { printf '\033[31m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
green()  { printf '\033[32m%s\033[0m\n' "$*"; }
say()    { [[ "${QUIET:-0}" == "1" ]] || printf '%s\n' "$*"; }

# --- frontmatter scalar/list helpers ---

# Extract the scalar value of a top-level frontmatter key from $1. Empty if missing.
fm_scalar() {
  local file="$1" key="$2"
  awk -v key="$key" '
    /^---$/ { c++; if (c == 2) exit; next }
    c == 1 && $0 ~ "^"key":" {
      sub("^"key":[[:space:]]*", "")
      sub(/[[:space:]]+$/, "")
      print
      exit
    }
  ' "$file"
}

# Extract a YAML list under a top-level frontmatter key from $1. One item per line.
fm_list() {
  local file="$1" key="$2"
  awk -v key="$key" '
    /^---$/                                    { c++; if (c == 2) exit; next }
    c == 1 && $0 ~ "^"key":[[:space:]]*$"      { in_list = 1; next }
    in_list && /^[[:space:]]+-[[:space:]]+/ {
      sub(/^[[:space:]]+-[[:space:]]+/, "")
      sub(/[[:space:]]+#.*/, "")
      sub(/[[:space:]]+$/, "")
      print
      next
    }
    in_list && /^[a-zA-Z]/                     { exit }
  ' "$file"
}

# First H1 line in $1, with the leading `# ` stripped.
fm_h1() {
  awk '/^# / { sub(/^# /, ""); print; exit }' "$1"
}

# --- marker-block helpers ---

# Marker recognition is anchored to the **whole line** (with tolerance for
# leading whitespace and YAML/JS comment prefixes like `# ` or `// `). This
# prevents textual mentions of a marker inside prose (e.g. inline code in a
# rule explanation) from being treated as real boundaries.

# List every marker NAME present in $1 (one per line, sorted unique). NAME is
# whatever sits between `<!-- cumaru:` and ` -->`; may contain `:` for
# two-token tags (e.g. `files:touched`).
fm_block_list() {
  local file="$1"
  awk '
    {
      line = $0
      sub(/^[[:space:]]*(#|\/\/)?[[:space:]]*/, "", line)
      sub(/[[:space:]]+$/, "", line)
    }
    line ~ /^<!-- cumaru:[a-z0-9_:-]+ -->$/ {
      m = line
      sub(/^<!-- cumaru:/, "", m)
      sub(/ -->$/, "", m)
      print m
    }
  ' "$file" | sort -u
}

# Print the body between `<!-- cumaru:NAME -->` and `<!-- /cumaru:NAME -->`
# in $1.
# Args: file, name.
fm_block_extract() {
  local file="$1" name="$2"
  local open="<!-- cumaru:${name} -->"
  local endmark="<!-- /cumaru:${name} -->"
  awk -v open="$open" -v endmark="$endmark" '
    function marker_line(s,    t) {
      t = s
      sub(/^[[:space:]]*(#|\/\/)?[[:space:]]*/, "", t)
      sub(/[[:space:]]+$/, "", t)
      return t
    }
    marker_line($0) == open    { capture=1; next }
    marker_line($0) == endmark { capture=0 }
    capture
  ' "$file"
}

# Replace the body of a `<!-- cumaru:NAME -->` block in $1 with content read
# from stdin. Markers are preserved. Returns non-zero (file left unchanged) if
# the open OR the close marker is absent.
# Args: file, name.
fm_block_replace() {
  local file="$1" name="$2"
  # Stream stdin to a temp file. Passing multi-line content via `awk -v
  # new_content="$value"` is unsafe — BSD awk (macOS default) rejects real
  # newlines in `-v` assignments with "awk: newline in string", which
  # silently breaks any multi-line block replacement.
  local content_file
  content_file=$(mktemp)
  cat > "$content_file"
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
  ' "$file"; then
    rm -f "$content_file"
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
  ' "$file" > "$tmp" && mv "$tmp" "$file"
  local rc=$?
  rm -f "$content_file"
  return $rc
}

# Walk all real marker blocks under a tree. Emits:
#   <file>\t<tag>
# with file paths relative to the tree root.
fm_block_walk() {
  local root="${1:-$CUMARU_DIR}"
  [[ -d "$root" ]] || return 0

  find "$root" -type f -name '*.md' -print0 | sort -z | while IFS= read -r -d '' file; do
    fm_block_list "$file" | while IFS= read -r tag; do
      [[ -n "$tag" ]] && printf '%s\t%s\n' "${file#"$root"/}" "$tag"
    done
  done
}

# Emit schema-declared tag specs as:
#   <tag>\t<type>\t<columns_csv>\t<host_file>
#
# v5 tag body model:
#   default                    => standard Link, Description table
#   [SHA, KEY, Description]    => custom deterministic table columns
#   prose | mixed | other      => non-default bodies (preserved, not path-resolved)
#
# Compatibility: an empty mapping (`tag: {}`) is read as `default` so older
# installed trees can still be inspected while they migrate to v5.
fm_schema_tag_specs() {
  local root="${1:-$CUMARU_DIR}" schema="$root/schema.yaml"
  [[ -f "$schema" ]] || return 0
  command -v ruby >/dev/null 2>&1 || return 0
  ruby -ryaml -e '
    def spec_for(value)
      host = ""
      spec = value
      if value.is_a?(Hash)
        host = (value["host_file"] || "").to_s
        spec = value["type"] || value["body"] || value["shape"]
        spec = "default" if spec.nil? && (value.keys - ["host_file"]).empty?
      end

      case spec
      when nil
        ["default", "Link,Description", host]
      when String
        type = spec.empty? ? "default" : spec
        cols = type == "default" ? "Link,Description" : ""
        [type, cols, host]
      when Array
        ["table", spec.map(&:to_s).join(","), host]
      when Hash
        ["default", "Link,Description", host]
      else
        ["other", "", host]
      end
    end

    def emit_tags(tags)
      (tags || {}).each do |name, value|
        type, cols, host = spec_for(value)
        puts [name, type, cols, host].join("\t")
      end
    end

    def walk(node)
      return unless node.is_a?(Hash)
      emit_tags(node["tags"])
      (node["entities"] || {}).each_value { |child| walk(child) }
    end

    data = YAML.load_file(ARGV[0]) || {}
    walk(data["root"] || {})
    emit_tags((data["meta"] || {})["tags"])
  ' "$schema"
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

# Emit every [Link, Description] row in every cumaru marker block under a tree:
#   <file>\t<tag>\t<link>\t<description>\t<target>\t<status>
# The parser intentionally follows the v4 table shape and keeps validation
# separate: malformed rows are omitted here and surfaced by doctor-specific
# checks.
fm_tag_table_rows() {
  local root="${1:-$CUMARU_DIR}"
  [[ -d "$root" ]] || return 0

  find "$root" -type f -name '*.md' -print0 | sort -z | while IFS= read -r -d '' file; do
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
      fm_schema_tag_is_default "$root" "$tag" || continue
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

  find "$root" -type f -name '*.md' -print0 | sort -z | while IFS= read -r -d '' file; do
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
    # remain visible via --tables without becoming a path-resolution warning.
    if [[ "$actual" == "$expected" ]]; then
      continue
    fi
    if [[ "$c1" =~ ^[A-Za-z][A-Za-z0-9_-]*$ && "$actual_count" -ge 2 && "$actual_count" -ne "$expected_count" ]]; then
      printf '%s\t%s\t%s\t%s\n' "$file" "$tag" "$expected" "$actual"
    fi
  done
}

# Print the canonical CUMARU-HOOK block for AGENTS.md / CLAUDE.md.
# Args: rel_index (path from project root to .cumaru/index.md), created (0|1).
# When created==1, the BEGIN marker says "created" instead of the default.
_cumaru_hook_block() {
  local rel_index="$1" created="${2:-0}"
  local begin="<!-- BEGIN CUMARU-HOOK -->"
  [[ "$created" == "1" ]] && begin="<!-- BEGIN CUMARU-HOOK created -->"
  cat <<EOF
$begin
## \`.cumaru/\` framework

This project uses the \`.cumaru/\` framework — a spec-driven, agent-friendly knowledge structure. Whenever you start a session in this repository, **read \`$rel_index\` first**. It carries the schema, the pillars declared for this project, the loading rule for what enters context, and any role definitions present under \`$rel_index\`'s siblings.

@$rel_index
<!-- END CUMARU-HOOK -->
EOF
}
