# common.sh — shared helpers sourced by every cmd_*.sh module.
#
# Provides:
#   - colored output: red, yellow, green, say (gated by QUIET)
#   - frontmatter helpers for YAML-ish keys: fm_scalar, fm_list, fm_h1
#   - marker-block helpers for `<!-- llm:NAME -->` regions
#     (fm_block_list, fm_block_extract, fm_block_replace)
#
# Marker convention:
#   `<!-- llm:NAME -->` ... `<!-- /llm:NAME -->` where NAME is any string
#   matching `[a-z0-9_:-]+`. Single-token names (`intake`, `plans`,
#   `components`, `root`) are the canonical form for new tags. Two-token
#   names (`files:touched`, etc.) remain valid for pattern-based tags
#   declared in schema.yaml under `tags:`.

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
# whatever sits between `<!-- llm:` and ` -->`; may contain `:` for two-token
# tags (e.g. `files:touched`).
fm_block_list() {
  local file="$1"
  awk '
    {
      line = $0
      sub(/^[[:space:]]*(#|\/\/)?[[:space:]]*/, "", line)
      sub(/[[:space:]]+$/, "", line)
    }
    line ~ /^<!-- llm:[a-z0-9_:-]+ -->$/ {
      m = line
      sub(/^<!-- llm:/, "", m)
      sub(/ -->$/, "", m)
      print m
    }
  ' "$file" | sort -u
}

# Print the body between `<!-- llm:NAME -->` and `<!-- /llm:NAME -->` in $1.
# Args: file, name.
fm_block_extract() {
  local file="$1" name="$2"
  local open="<!-- llm:${name} -->"
  local endmark="<!-- /llm:${name} -->"
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

# Replace the body of a `<!-- llm:NAME -->` block in $1 with content read
# from stdin. Markers are preserved. Returns non-zero if the open marker is
# absent (file left unchanged).
# Args: file, name.
fm_block_replace() {
  local file="$1" name="$2"
  # Stream stdin to a temp file. Passing multi-line content via `awk -v
  # new_content="$value"` is unsafe — BSD awk (macOS default) rejects real
  # newlines in `-v` assignments with "awk: newline in string", which
  # silently breaks any regen producing >1 row.
  local content_file
  content_file=$(mktemp)
  cat > "$content_file"
  local open="<!-- llm:${name} -->"
  local endmark="<!-- /llm:${name} -->"
  # Open marker must exist as its own line (not just a substring in prose).
  if ! awk -v marker="$open" '
    { t = $0; sub(/^[[:space:]]*(#|\/\/)?[[:space:]]*/, "", t); sub(/[[:space:]]+$/, "", t) }
    t == marker { found = 1; exit }
    END { exit !found }
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
