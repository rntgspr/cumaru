#!/usr/bin/env bash
# Repository-local context loader for agents working on Cumaru itself.
#
# Modes:
#   session (default) - emit the mandatory startup set defined in
#                       .memory/index.md, validated as a whole first.
#   prompt            - emit a bounded per-prompt digest of discipline rules
#                       and canonical paths, to reinforce recall every turn.
#
# Both modes fail atomically: on a missing file or budget overflow they print
# a diagnostic and none of the selected bodies. Output is never truncated.

set -euo pipefail

repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
memory="$repo_root/.memory"
mode="${1:-session}"
session_budget=32768
prompt_budget=2048

# Print a diagnostic to stdout so the agent sees why context is missing.
fail() {
  printf 'cumaru context loader: %s; no context emitted. Read .memory/index.md manually.\n' "$1"
  exit 0
}

# Resolve the mandatory set in canonical order: index, advisor mode, disciplines.
# Discovery runs in the parent shell so any failure aborts before emission.
[[ -d "$memory/disciplines" && ! -L "$memory/disciplines" ]] || fail "missing directory .memory/disciplines"

disciplines=$(find "$memory/disciplines" -maxdepth 1 -type f -name '*.md' -print) || fail "cannot enumerate .memory/disciplines"
[[ -n "$disciplines" ]] || fail "no discipline files in .memory/disciplines"

files=("$memory/index.md" "$memory/advisor_mode.md")
while IFS= read -r file; do
  files+=("$file")
done <<< "$(printf '%s\n' "$disciplines" | LC_ALL=C sort)"

for file in "${files[@]}"; do
  [[ -f "$file" && ! -L "$file" ]] || fail "missing mandatory file ${file#"$repo_root"/}"
done

# Session mode: validate the full byte budget, then emit every body.
if [[ "$mode" == "session" ]]; then
  total=$(cat "${files[@]}" | wc -c | tr -d ' ')
  (( total <= session_budget )) || fail "mandatory set is $total bytes, over the $session_budget-byte budget"

  printf 'Cumaru repository startup set: %d files, %d bytes.\n' "${#files[@]}" "$total"

  for file in "${files[@]}"; do
    printf '\n--- BEGIN %s ---\n\n' "${file#"$repo_root"/}"
    cat "$file"
    printf '\n--- END %s ---\n' "${file#"$repo_root"/}"
  done

  exit 0
fi

[[ "$mode" == "prompt" ]] || fail "unknown mode '$mode'"

# Prompt mode: build the digest from discipline frontmatter descriptions.
digest='Cumaru disciplines (active every turn; reread the file before acting on its topic):'

for file in "${files[@]:2}"; do
  # Read only a closed leading frontmatter block; prose is never scanned.
  description=$(awk '
    NR == 1 { if ($0 != "---") exit 1; next }
    $0 == "---" { closed = 1; exit }
    /^description:/ && !found { sub(/^description:[ ]*/, ""); value = $0; found = 1 }
    END { if (!closed || !found) exit 1; print value }
  ' "$file") || fail "discipline ${file#"$repo_root"/} has no frontmatter description"
  [[ "$description" =~ ^\"[^\"]+\"$ ]] || fail "discipline ${file#"$repo_root"/} description must be a quoted one-line scalar"
  description="${description:1:${#description}-2}"
  digest+=$'\n'"- $description (${file#"$repo_root"/})"
done

digest+=$'\n''Canonical sources: load the relevant spec from .memory/index.md before changing its surface; never rely on memory of it.'

size=$(printf '%s\n' "$digest" | wc -c | tr -d ' ')
(( size <= prompt_budget )) || fail "prompt digest is $size bytes, over the $prompt_budget-byte budget"

printf '%s\n' "$digest"
