#!/usr/bin/env bash
set -euo pipefail

MAX_FILE_BYTES=7000
MAX_TOTAL_BYTES=30000

read_hook_input() {
  cat
}

json_field() {
  local input="$1" field="$2"
  jq -r --arg field "$field" '.[$field] // empty' <<< "$input" 2>/dev/null || true
}

find_project_root() {
  local dir="$1"
  dir=$(cd "$dir" 2>/dev/null && pwd -P) || return 1

  while [[ "$dir" != "/" ]]; do
    if [[ -d "$dir/.cumaru" ]]; then
      printf '%s\n' "$dir"
      return 0
    fi
    dir=$(dirname "$dir")
  done

  return 1
}

prompt_terms() {
  local prompt="$1"
  printf '%s\n' "$prompt" \
    | tr '[:upper:]' '[:lower:]' \
    | tr -cs '[:alnum:]_-' '\n' \
    | awk '
      length($0) > 2 &&
      $0 !~ /^(about|after|also|and|are|around|com|como|das|dos|for|from|isso|mais|para|por|que|should|the|uma|with|you)$/ {
        print
      }
    ' \
    | sort -u
}

score_row() {
  local searchable="$1" terms_file="$2" score=0 term

  while IFS= read -r term; do
    [[ -n "$term" ]] || continue
    if [[ "$searchable" == *"$term"* ]]; then
      score=$((score + 20))
    fi
  done < "$terms_file"

  printf '%s\n' "$score"
}

select_context_files() {
  local cumaru_dir="$1" terms_file="$2" candidates_file="$3"
  local rel file tag link description target status searchable score

  for rel in index.md domain.md schema.yaml; do
    file="$cumaru_dir/$rel"
    [[ -f "$file" ]] && printf '1000\t%s\tcanonical root context\n' "$file" >> "$candidates_file"
  done

  command -v cumaru >/dev/null 2>&1 || return 0

  while IFS=$'\t' read -r file tag link description target status; do
    [[ "$status" == "ok" ]] || continue
    [[ -n "$target" && -f "$cumaru_dir/$target" ]] || continue

    searchable=$(printf '%s %s %s %s\n' "$tag" "$file" "$link" "$description" | tr '[:upper:]' '[:lower:]')
    score=$(score_row "$searchable" "$terms_file")
    [[ "$score" -gt 0 ]] || continue

    printf '%s\t%s\tmatched tag %s in %s\n' "$score" "$cumaru_dir/$target" "$tag" "$file" >> "$candidates_file"
  done < <(cd "$(dirname "$cumaru_dir")" && cumaru tag all --rows 2>/dev/null)
}

append_file_section() {
  local output_file="$1" rel="$2" reason="$3" file="$4"
  {
    printf '## .cumaru/%s\n\n' "$rel"
    printf 'Reason: %s\n\n' "$reason"
    head -c "$MAX_FILE_BYTES" "$file"
    if [[ $(wc -c < "$file") -gt "$MAX_FILE_BYTES" ]]; then
      printf '\n\n[truncated]\n'
    fi
    printf '\n\n'
  } >> "$output_file"
}

build_context() {
  local project_root="$1" cumaru_dir="$2" terms_file="$3"
  local candidates_file output_file selected_file
  candidates_file=$(mktemp)
  output_file=$(mktemp)
  selected_file=$(mktemp)

  select_context_files "$cumaru_dir" "$terms_file" "$candidates_file"

  sort -rn "$candidates_file" \
    | awk -F '\t' '!seen[$2]++ { print }' \
    > "$selected_file"

  {
    printf '# dot-llm Context Refresh\n\n'
    printf 'Project root: %s\n\n' "$project_root"
    printf 'Load this as supplemental context for the current prompt. It is built deterministically from canonical cumaru tag bodies: root context is always included; linked files from tag tables are included only when their Link or Description matches the prompt subject.\n\n'
  } > "$output_file"

  local score file reason rel current_bytes section_tmp
  while IFS=$'\t' read -r score file reason; do
    [[ -f "$file" ]] || continue
    rel="${file#"$cumaru_dir"/}"
    section_tmp=$(mktemp)
    append_file_section "$section_tmp" "$rel" "$reason" "$file"

    current_bytes=$(wc -c < "$output_file")
    if [[ $((current_bytes + $(wc -c < "$section_tmp"))) -gt "$MAX_TOTAL_BYTES" ]]; then
      printf '\n[context budget exhausted]\n' >> "$output_file"
      rm -f "$section_tmp"
      break
    fi

    cat "$section_tmp" >> "$output_file"
    rm -f "$section_tmp"
  done < "$selected_file"

  cat "$output_file"
  rm -f "$candidates_file" "$output_file" "$selected_file"
}

emit_context() {
  local target="$1" context="$2"

  jq -n --arg context "$context" '{
    continue: true,
    suppressOutput: true,
    hookSpecificOutput: {
      hookEventName: "UserPromptSubmit",
      additionalContext: $context
    }
  }'
}

main() {
  command -v jq >/dev/null 2>&1 || exit 0

  local input cwd prompt target project_root cumaru_dir terms_file context
  input=$(read_hook_input)
  cwd=$(json_field "$input" "cwd")
  prompt=$(json_field "$input" "user_prompt")
  [[ -n "$prompt" ]] || prompt=$(json_field "$input" "prompt")
  [[ -n "$cwd" ]] || cwd="${CUMARU_PROJECT_DIR:-${DOT_LLM_PROJECT_DIR:-$PWD}}"
  target="${CUMARU_HOOK_TARGET:-${DOT_LLM_HOOK_TARGET:-claude}}"

  for arg in "$@"; do
    case "$arg" in
      --target=*) target="${arg#--target=}" ;;
    esac
  done

  project_root=$(find_project_root "$cwd" 2>/dev/null || true)
  [[ -n "$project_root" ]] || exit 0
  cumaru_dir="$project_root/.cumaru"

  terms_file=$(mktemp)
  prompt_terms "$prompt" > "$terms_file"
  context=$(build_context "$project_root" "$cumaru_dir" "$terms_file")
  rm -f "$terms_file"

  emit_context "$target" "$context"
}

main "$@"
