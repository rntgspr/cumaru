# cmd_doctor_checks.sh - navigation-first health checks.

# Materialize the installed-tree and tag-schema data once. The config has
# already passed schema_validate_installed before this module is called.
_doctor_cache_init() {
  local path
  FM_INVENTORY_ROOT="$CUMARU_DIR"
  FM_INVENTORY_MARKDOWN=()
  _doctor_inventory_dirs=()
  while IFS= read -r -d '' path; do
    if [[ -d "$path" ]]; then
      _doctor_inventory_dirs+=("$path")
    else
      FM_INVENTORY_MARKDOWN+=("$path")
    fi
  done < <(find "$CUMARU_DIR" \( -type d -o -type f -name '*.md' \) -print0 | LC_ALL=C sort -z)

  FM_SCHEMA_TAG_SPECS_ROOT=""
  FM_SCHEMA_TAG_SPECS=$(fm_schema_tag_specs "$CUMARU_DIR") || return 1
  FM_SCHEMA_TAG_SPECS_ROOT="$CUMARU_DIR"
}

# Validate the v9 direct tree using the shared resolver. The resolver owns
# selector precedence, path overrides, glob expansion, containment, and the
# effective global contract; doctor only inspects each resolved Markdown host.
_doctor_check_v9_contract() {
  local output status logical rel ownership frontmatter tags rules file field tag heading
  local issues=() value

  output=$(config_tree_resolve "$CONFIG" "$CUMARU_DIR" 2>&1)
  status=$?
  if [[ $status -ne 0 ]]; then
    _doctor_fail "Configured v9 tree is invalid" "$output"
    return 1
  fi

  while IFS=$'\t' read -r logical rel ownership frontmatter tags rules; do
    [[ -n "$rel" ]] || continue
    file="$CUMARU_DIR/$rel"

    while IFS= read -r field; do
      [[ -n "$field" ]] || continue
      if ! FIELD="$field" yq --front-matter=extract -e 'has(strenv(FIELD))' "$file" >/dev/null 2>&1; then
        issues+=("$rel: missing required frontmatter field '$field'")
      fi
    done < <(jq -r 'to_entries[] | select(.value.optional != true) | .key' <<< "$frontmatter")

    if jq -e 'has("targets")' <<< "$frontmatter" >/dev/null; then
    if ! yq --front-matter=extract -e '(.targets | type == "!!seq") and ([.targets[] | tag == "!!str"] | contains([false]) | not)' "$file" >/dev/null 2>&1; then
        issues+=("$rel: targets must be an array of domain target names")
      else
        while IFS= read -r value; do
          [[ -n "$value" ]] || continue
          if ! VALUE="$value" yq -e '.meta.targets.values | contains([strenv(VALUE)])' "$CONFIG" >/dev/null 2>&1; then
            issues+=("$rel: targets value '$value' is not declared by meta.targets.values")
          fi
        done < <(yq --front-matter=extract -r '.targets[]' "$file")
      fi
    fi

    heading=$(jq -r '.markdown.required_heading // ""' <<< "$rules")
    if [[ "$heading" == "h1" ]] && ! grep -qE '^# ' "$file"; then
      issues+=("$rel: missing required H1 heading")
    fi

    if ! fm_block_validate "$file" "$rel" >/dev/null 2>&1; then
      issues+=("$rel: malformed semantic tag structure")
      continue
    fi
    while IFS= read -r tag; do
      [[ -n "$tag" ]] || continue
      if ! fm_block_list "$file" | grep -Fxq "$tag"; then
        issues+=("$rel: missing required tag '$tag'")
      fi
    done < <(jq -r '.[]?' <<< "$tags")
  done <<< "$output"

  if [[ ${#issues[@]} -eq 0 ]]; then
    _doctor_pass "Configured v9 tree contracts conform"
  else
    _doctor_fail "Configured v9 tree contracts are invalid" "$(printf '%s\n' "${issues[@]}")"
    return 1
  fi
}

# Validates directory indexes, Markdown summaries, and discipline strictness.
_doctor_check_navigation() {
  local issues=() dir rel index file checks trimmed controls length issue
  for dir in "${_doctor_inventory_dirs[@]+"${_doctor_inventory_dirs[@]}"}"; do
    rel="${dir#"$CUMARU_DIR"/}"
    [[ "$dir" == "$CUMARU_DIR" ]] && rel="."
    [[ "$rel" == .* || "$rel" == */.* ]] && continue
    index="$dir/index.md"
    [[ -f "$index" && ! -L "$index" ]] || issues+=("non-hidden directory lacks a real index.md: ${rel%/}/ — inspect with cumaru tree --deep")
  done

  for file in "${FM_INVENTORY_MARKDOWN[@]+"${FM_INVENTORY_MARKDOWN[@]}"}"; do
    rel="${file#"$CUMARU_DIR"/}"
    checks=$(yq --front-matter=extract -r '
      .summary | select(tag == "!!str") |
      [(. == (. | trim)), test("[[:cntrl:]]"), (split("") | length)] | @tsv
    ' "$file" 2>/dev/null || true)
    if [[ -z "$checks" ]]; then
      issues+=("$rel: summary must be a YAML string")
      continue
    fi
    IFS=$'\t' read -r trimmed controls length <<< "$checks"
    [[ "$trimmed" == "true" ]] || issues+=("$rel: summary has leading or trailing whitespace")
    [[ "$controls" == "false" ]] || issues+=("$rel: summary contains a control character")
    if [[ "$length" =~ ^[0-9]+$ ]]; then
      (( length >= 32 )) || issues+=("$rel: summary is shorter than 32 Unicode code points")
      (( length <= 512 )) || issues+=("$rel: summary is longer than 512 Unicode code points")
    else
      issues+=("$rel: summary must contain 32 to 512 Unicode code points")
    fi
  done

  while IFS= read -r issue; do
    [[ -n "$issue" ]] && issues+=("$issue")
  done < <(discipline_metadata_issues "$CUMARU_DIR")

  if [[ ${#issues[@]} -eq 0 ]]; then
    _doctor_pass "Navigation indexes, summaries, and discipline metadata conform to the latest"
  else
    _doctor_fail "Navigation indexes, summaries, or discipline metadata are invalid" "$(printf '%s\n' "${issues[@]}")"
  fi
}

# Rejects malformed tag structures before reviewing balanced opaque bodies.
_doctor_check_markers() {
  local malformed=() unknown=() nested=() host rel tag known detail item declared_tags diagnostic
  declared_tags=$(fm_schema_tag_specs "$CUMARU_DIR" | cut -f1 | sort -u)
  while IFS= read -r host; do
    [[ -n "$host" ]] || continue
    rel="${host#"$CUMARU_DIR"/}"
    if ! diagnostic=$(fm_block_validate "$host" "$rel" 2>&1); then
      malformed+=("$diagnostic")
      continue
    fi

    if fm_block_has_nested "$host" "$rel"; then
      nested+=("$rel: balanced nested tags are valid but need adopter review")
    fi
    while IFS= read -r tag; do
      [[ -n "$tag" ]] || continue
      known=0
      grep -Fxq "$tag" <<< "$declared_tags" && known=1
      if [[ $known -eq 0 ]]; then
        unknown+=("$rel [$tag]: body kept opaque and not path-resolved")
      fi
    done < <(fm_block_list "$host")
  done < <(_fm_inventory_markdown_files "$CUMARU_DIR")

  if [[ ${#malformed[@]} -gt 0 ]]; then
    _doctor_fail "Malformed semantic tags found" "$(printf '%s\n' "${malformed[@]}")"
  elif [[ ${#unknown[@]} -gt 0 || ${#nested[@]} -gt 0 ]]; then
    detail=""
    if [[ ${#unknown[@]} -gt 0 ]]; then
      for item in "${unknown[@]}"; do
        detail="${detail}${detail:+$'\n'}${item}"
      done
    fi
    if [[ ${#nested[@]} -gt 0 ]]; then
      for item in "${nested[@]}"; do
        detail="${detail}${detail:+$'\n'}${item}"
      done
    fi
    _doctor_warn_emit "Marker blocks need review" "$detail"
  else
    _doctor_pass "Marker contracts contain no retired structural inventories"
  fi
}

# Extracts the target path from a Markdown link cell.
_doctor_link_target() {
  local link="$1" target
  target="${link#*(}"
  if [[ "$target" != "$link" ]]; then
    target="${target%)*}"
  fi
  printf '%s\n' "$target"
}

# Validates retained project-file tag rows under their current root semantics.
_doctor_check_file_refs() {
  local problems=() file tag link desc ignored target project candidate
  project=$(dirname "$CUMARU_DIR")
  while IFS=$'\t' read -r file tag link desc ignored ignored; do
    case "$tag" in files|touched|reference) ;; *) continue ;; esac
    target=$(_doctor_link_target "$link")
    [[ "$target" == *"<"* || "$target" == *">"* ]] && continue
    if [[ "$target" == /* || "$target" == *".."* || "$target" == .cumaru/* ]]; then
      problems+=("$file [$tag]: $target - invalid path, file type, containment, or final symlink target")
      continue
    fi
    candidate="$project/$target"
    if [[ "$tag" == "touched" && ! -e "$candidate" && "$desc" == *removed* ]]; then
      continue
    fi
    if [[ ! -e "$candidate" || ( "$tag" == "reference" && ( -d "$candidate" || -L "$candidate" ) ) ]]; then
      problems+=("$file [$tag]: $target - invalid path, file type, containment, or final symlink target")
    fi
  done < <(fm_tag_table_rows "$CUMARU_DIR")

  if [[ ${#problems[@]} -eq 0 ]]; then
    _doctor_pass "Retained project file references are valid"
  else
    _doctor_warn_emit "Retained project file references need review" "$(printf '%s\n' "${problems[@]}")"
  fi
}

# Runs the nine navigation-first checks while preserving the existing output format.
cmd_doctor_checks() {
  _doctor_ok=0; _doctor_warn=0; _doctor_err=0
  if config_tree_is_v9 "$CONFIG"; then
    if ! _doctor_check_v9_contract; then
      printf '\nSummary: %d error(s), %d warning(s), %d ok\n' "$_doctor_err" "$_doctor_warn" "$_doctor_ok"
      return 1
    fi
  fi
  _doctor_cache_init || return 1
  _doctor_check_navigation
  _doctor_check_markers
  _doctor_check_stale_markers
  _doctor_check_raw_blocks
  _doctor_check_file_refs
  _doctor_check_external_tools
  _doctor_check_agent_hook
  _doctor_check_retired_agent_config
  _doctor_check_config_drift
  printf '\nSummary: %d error(s), %d warning(s), %d ok\n' "$_doctor_err" "$_doctor_warn" "$_doctor_ok"
  (( _doctor_err == 0 ))
}
