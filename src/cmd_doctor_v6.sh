# cmd_doctor_v6.sh - navigation-first health checks for framework version 6.

# Validates every non-hidden directory index and every Markdown summary.
_doctor_v6_check_navigation() {
  local issues=() dir rel index file summary_type checks trimmed controls length
  while IFS= read -r -d '' dir; do
    rel="${dir#"$CUMARU_DIR"/}"
    [[ "$dir" == "$CUMARU_DIR" ]] && rel="."
    [[ "$rel" == .* || "$rel" == */.* ]] && continue
    index="$dir/index.md"
    [[ -f "$index" && ! -L "$index" ]] || issues+=("non-hidden directory lacks a real index.md: ${rel%/}/ — inspect with cumaru tree --deep")
  done < <(find "$CUMARU_DIR" -type d -print0)

  while IFS= read -r -d '' file; do
    rel="${file#"$CUMARU_DIR"/}"
    summary_type=$(yq --front-matter=extract -r '.summary | tag' "$file" 2>/dev/null || true)
    if [[ "$summary_type" != "!!str" ]]; then
      issues+=("$rel: summary must be a YAML string")
      continue
    fi
    checks=$(yq --front-matter=extract -r '.summary as $s | [($s == ($s | trim)), ($s | test("[[:cntrl:]]")), ($s | split("") | length)] | @tsv' "$file" 2>/dev/null || true)
    IFS=$'\t' read -r trimmed controls length <<< "$checks"
    [[ "$trimmed" == "true" ]] || issues+=("$rel: summary has leading or trailing whitespace")
    [[ "$controls" == "false" ]] || issues+=("$rel: summary contains a control character")
    if [[ "$length" =~ ^[0-9]+$ ]]; then
      (( length >= 32 )) || issues+=("$rel: summary is shorter than 32 Unicode code points")
      (( length <= 256 )) || issues+=("$rel: summary is longer than 256 Unicode code points")
    else
      issues+=("$rel: summary must contain 32 to 256 Unicode code points")
    fi
  done < <(find "$CUMARU_DIR" -type f -name '*.md' -print0)

  if [[ ${#issues[@]} -eq 0 ]]; then
    _doctor_pass "Navigation indexes and summaries conform to v6"
  else
    _doctor_fail "Navigation indexes or summaries are invalid" "$(printf '%s\n' "${issues[@]}")"
  fi
}

# Audits opaque markers and fails only source-known retired structural tables.
_doctor_v6_check_markers() {
  local retired=() unknown=() host rel tag manifest_host manifest_tag known
  while IFS=$'\t' read -r manifest_host manifest_tag; do
    [[ -n "$manifest_host" && -n "$manifest_tag" ]] || continue
    if fm_block_list "$CUMARU_DIR/$manifest_host" 2>/dev/null | grep -Fxq "$manifest_tag"; then
      retired+=("$manifest_host [$manifest_tag]: retired structural inventory block remains after migration")
    fi
  done < <(yq -r '.meta.migrations.v6.removable_tags[]? | [.host_file, .tag] | @tsv' "$SCHEMA" 2>/dev/null)

  while IFS= read -r host; do
    [[ -n "$host" ]] || continue
    rel="${host#"$CUMARU_DIR"/}"
    while IFS= read -r tag; do
      [[ -n "$tag" ]] || continue
      known=0
      case "$tag" in components|root|files|touched|reference|absorptions|relations) known=1 ;; esac
      if [[ $known -eq 0 ]]; then
        unknown+=("$rel [$tag]: body kept opaque and not path-resolved")
      fi
    done < <(fm_block_list "$host")
  done < <(find "$CUMARU_DIR" -type f -name '*.md' -print)

  if [[ ${#retired[@]} -gt 0 ]]; then
    _doctor_fail "Retired structural marker blocks found" "$(printf '%s\n' "${retired[@]}")"
  elif [[ ${#unknown[@]} -gt 0 ]]; then
    _doctor_warn_emit "Unknown marker blocks found" "$(printf '%s\n' "${unknown[@]}")"
  else
    _doctor_pass "Marker contracts contain no retired structural inventories"
  fi
}

# Extracts the target path from a Markdown link cell.
_doctor_v6_link_target() {
  local link="$1" target
  target="${link#*(}"
  if [[ "$target" != "$link" ]]; then
    target="${target%)*}"
  fi
  printf '%s\n' "$target"
}

# Validates retained project-file tag rows under their v6 root semantics.
_doctor_v6_check_file_refs() {
  local problems=() file tag link desc ignored target project candidate
  project=$(dirname "$CUMARU_DIR")
  while IFS=$'\t' read -r file tag link desc ignored ignored; do
    case "$tag" in files|touched|reference) ;; *) continue ;; esac
    target=$(_doctor_v6_link_target "$link")
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

# Runs the seven v6 checks while preserving the existing doctor output format.
cmd_doctor_v6() {
  _doctor_ok=0; _doctor_warn=0; _doctor_err=0
  _doctor_v6_check_navigation
  _doctor_v6_check_markers
  _doctor_check_stale_markers
  _doctor_check_raw_blocks
  _doctor_v6_check_file_refs
  _doctor_check_external_tools
  _doctor_check_agent_hook
  printf '\nSummary: %d error(s), %d warning(s), %d ok\n' "$_doctor_err" "$_doctor_warn" "$_doctor_ok"
  (( _doctor_err == 0 ))
}
