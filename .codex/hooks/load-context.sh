#!/usr/bin/env bash

set -euo pipefail

repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
memory_index="$repo_root/.memory/index.md"

# Emit one Markdown file with a project-relative delimiter.
emit_markdown() {
  local file="$1"
  local relative_path="${file#"$repo_root"/}"

  printf '\n--- BEGIN %s ---\n\n' "$relative_path"
  cat "$file"
  printf '\n\n--- END %s ---\n' "$relative_path"
}

if [[ -f "$memory_index" && ! -L "$memory_index" ]]; then
  emit_markdown "$memory_index"
fi

{
  [[ ! -d "$repo_root/.memory" ]] || find "$repo_root/.memory" -type f -name '*.md' -print
  [[ ! -d "$repo_root/docs" ]] || find "$repo_root/docs" -type f -name '*.md' -print
} | LC_ALL=C sort | while IFS= read -r file; do
  [[ "$file" == "$memory_index" ]] && continue

  emit_markdown "$file"
done
