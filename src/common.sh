# common.sh — shared helpers, sourced by every subcommand.
#
# Expects the entry-point (./llm) to define: QUIET (0|1).
# Provides:
#   - output helpers (red/yellow/green/say)
#   - frontmatter readers (fm_scalar, fm_list, fm_h1)
#   - block helpers for `<!-- llm:<kind>:<tag> -->` markers
#     (fm_block_list, fm_block_extract, fm_block_replace)

red()    { printf '\033[31m%s\033[0m\n' "$*" >&2; }
yellow() { printf '\033[33m%s\033[0m\n' "$*" >&2; }
green()  { printf '\033[32m%s\033[0m\n' "$*"; }
say()    { [[ $QUIET -eq 0 ]] && green "$*" || true; }

# Read a single scalar value from a file's frontmatter. Returns empty if
# the field is missing or the file has no frontmatter.
# Args: file, key.
fm_scalar() {
  local file="$1" key="$2"
  awk -v k="$key" '
    /^---$/ { c++; if (c == 2) exit; next }
    c == 1 && $0 ~ "^" k ":" {
      sub("^" k ":[[:space:]]*", "")
      sub(/[[:space:]]+#.*/, "")
      sub(/[[:space:]]+$/, "")
      print
      exit
    }
  ' "$file"
}

# Read a yaml list under a key in the frontmatter. Prints one item per line.
# Handles both block-style (key:\n  - a\n  - b) and inline ([a, b]) lists.
# Args: file, key.
fm_list() {
  local file="$1" key="$2"
  awk -v k="$key" '
    /^---$/ { c++; if (c == 2) exit; next }
    c == 1 && $0 ~ "^" k ":[[:space:]]*\\[" {
      # inline form: key: [a, b, c]
      sub("^" k ":[[:space:]]*\\[", "")
      sub(/\][[:space:]]*$/, "")
      gsub(/[[:space:]]/, "")
      n = split($0, parts, ",")
      for (i = 1; i <= n; i++) if (parts[i] != "") print parts[i]
      exit
    }
    c == 1 && $0 ~ "^" k ":[[:space:]]*$" { in_list = 1; next }
    in_list && /^[[:space:]]+-[[:space:]]+/ {
      sub(/^[[:space:]]+-[[:space:]]+/, "")
      sub(/[[:space:]]+#.*/, "")
      sub(/[[:space:]]+$/, "")
      print
      next
    }
    in_list && /^[a-zA-Z]/ { exit }
  ' "$file"
}

# Read the first H1 heading text (without the leading "# ") from a file.
# Args: file.
fm_h1() {
  local file="$1"
  awk '/^# / { sub(/^# /, ""); sub(/[[:space:]]+$/, ""); print; exit }' "$file"
}

# Block markers — uniform shape `<!-- llm:<kind>:<tag> -->` ... `<!-- /llm:<kind>:<tag> -->`.
# Recognised on any line; the parser looks for the substring, so the markers
# may live inside YAML comments (`# <!-- ... -->`) or other host syntax.
#
# Reserved kinds:
#   custom   — project edits preserved across `framework sync`.
#   entries  — regenerable index tables (rewritten by `llm regen index`).
#   files    — lists of repo-relative paths checked by `llm doctor`.

# List every (kind, tag) marker present in $1. Output: "KIND<TAB>TAG", sorted unique.
fm_block_list() {
  local file="$1"
  awk '
    {
      s = $0
      while (match(s, /<!-- llm:[a-z0-9_-]+:[a-z0-9_-]+ -->/)) {
        m = substr(s, RSTART, RLENGTH)
        sub(/^<!-- llm:/, "", m); sub(/ -->$/, "", m)
        n = index(m, ":")
        print substr(m, 1, n-1) "\t" substr(m, n+1)
        s = substr(s, RSTART + RLENGTH)
      }
    }
  ' "$file" | sort -u
}

# Print the body between `<!-- llm:KIND:TAG -->` and `<!-- /llm:KIND:TAG -->` in $1.
# Args: file, kind, tag.
fm_block_extract() {
  local file="$1" kind="$2" tag="$3"
  local open="<!-- llm:${kind}:${tag} -->"
  local close="<!-- /llm:${kind}:${tag} -->"
  awk -v open="$open" -v close="$close" '
    index($0, open)  { capture=1; next }
    index($0, close) { capture=0 }
    capture
  ' "$file"
}

# Replace the body of a `<!-- llm:KIND:TAG -->` block in $1 with content read
# from stdin. Markers are preserved. Returns non-zero if the open marker is
# absent (file left unchanged).
# Args: file, kind, tag.
fm_block_replace() {
  local file="$1" kind="$2" tag="$3"
  local new_content
  new_content=$(cat)
  local open="<!-- llm:${kind}:${tag} -->"
  local close="<!-- /llm:${kind}:${tag} -->"
  if ! grep -qF "$open" "$file"; then
    return 1
  fi
  local tmp
  tmp=$(mktemp)
  awk -v open="$open" -v close="$close" -v new_content="$new_content" '
    index($0, open) {
      print
      if (length(new_content) > 0) print new_content
      skip = 1
      next
    }
    index($0, close) {
      skip = 0
      print
      next
    }
    !skip { print }
  ' "$file" > "$tmp" && mv "$tmp" "$file"
}
