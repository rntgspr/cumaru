# cmd_sync.sh — sync a project's .llm/ tree with the latest
# framework definition.
#
# Two categories of files (declared in schema.yaml under `sync:`):
#   A. framework_files — replaced wholesale.
#   B. marked_files    — replaced wholesale OUTSIDE `<!-- llm:NAME -->`
#                        blocks; the body of every such block in the target is
#                        preserved. Tags are auto-detected per file.
# Anything not listed is project-owned and never touched.
#
# Updates to the `llm` script itself and the src/*.sh modules are NOT this
# command's responsibility — they live outside .llm/. To update them, pull
# the dot-llm checkout (typically `git -C <dot-llm-checkout> pull`); a
# global symlink (~/.local/bin/llm → checkout) propagates automatically.
#
# Expects from the entry-point: SCRIPT_DIR, DOT_LLM_DIR, SCHEMA, QUIET.

# Build the source file with the target's `<!-- llm:*:* -->` blocks injected.
# Writes to stdout. Tag bodies absent in the target produce empty content.
# Args: src_file, tgt_file
inject_blocks() {
  local src="$1" tgt="$2"
  local tmp
  tmp=$(mktemp -d)
  local name
  while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    local safe="${name//:/__}"
    fm_block_extract "$tgt" "$name" > "$tmp/$safe"
  done < <(fm_block_list "$tgt")
  awk -v dir="$tmp" '
    function marker_line(s,    t) {
      t = s
      sub(/^[[:space:]]*(#|\/\/)?[[:space:]]*/, "", t)
      sub(/[[:space:]]+$/, "", t)
      return t
    }
    {
      ml = marker_line($0)
      if (ml ~ /^<!-- llm:[a-z0-9_:-]+ -->$/) {
        m = ml
        sub(/^<!-- llm:/, "", m); sub(/ -->$/, "", m)
        safe = m; gsub(/:/, "__", safe)
        print
        path = dir "/" safe
        while ((getline line < path) > 0) print line
        close(path)
        skip = 1
        next
      }
      if (ml ~ /^<!-- \/llm:[a-z0-9_:-]+ -->$/) { skip = 0 }
      if (!skip) print
    }
  ' "$src"
  rm -rf "$tmp"
}

# Parse a flat list under sync.<key>: in $1 (yaml). Prints one item per line.
parse_yaml_list() {
  local file="$1" key="$2"
  awk -v key="$key" '
    /^sync:[[:space:]]*$/                                    { in_sync=1; next }
    in_sync && $0 ~ "^[[:space:]]+" key ":[[:space:]]*$"     { in_list=1; next }
    in_list && /^[[:space:]]+-[[:space:]]+/ {
      sub(/^[[:space:]]+-[[:space:]]+/, "")
      sub(/[[:space:]]+#.*/, "")
      sub(/[[:space:]]+$/, "")
      print
      next
    }
    in_list && /^[[:space:]]+[a-zA-Z]/                        { in_list=0 }
    in_list && /^[^[:space:]]/                                { exit }
  ' "$file"
}

cmd_sync_help() {
  cat <<'EOF'
llm sync — update .llm/ from the framework source

Usage:
  llm sync [<filter>] [--from <path|git-url>] [--apply]

Arguments:
  <filter>       optional single dir name to limit the sync to:
                 intake | plans | archive | specs | exploring |
                 roles | templates | reviews

Options:
  --from <src>   path to a dot-llm checkout, or a git URL to clone shallowly
                 (default: the directory containing this llm script, if it
                 looks like a dot-llm checkout)
  --apply        auto-apply default strategies for every changed file
                 (replace for category A, merge for category B)

Behavior:

  Default (no --apply): rich dry-run for an LLM to consume. For each file
  that differs, prints:
    - category (A framework_files, or B marked_files)
    - default strategy
    - the four available strategies (replace / merge / keep / llm-decide)
    - the full unified diff (local → source)

  The LLM reads this output, applies the heuristic below per file, and
  edits the affected file(s) using its standard tools — or runs the same
  command with --apply to take the defaults.

  Heuristic:
    • Content inside `<!-- llm:NAME -->` blocks → KEEP LOCAL.
    • Prose / headers / Rules / structure outside markers → take FROM FRAMEWORK.
    • Outside-marker prose with project-specific content → ANALYZE: keep
      what is project-local, integrate framework changes around it.

  --apply path: applies the default per file (no analysis).

Categories (declared in the source schema's sync: section):
  [A] framework_files — replaced wholesale
  [B] marked_files    — replaced outside `<!-- llm:NAME -->` blocks
  Anything not listed is project-owned and never touched.

This command does NOT update the llm script itself or src/*.sh — those live
outside .llm/ and are maintained by pulling the dot-llm checkout (the
llm-cli skill describes how).

After applying, bump framework-version in .llm/index.md to match the source
schema's version. The validator enforces equality on the next run.

Examples:
  llm sync                                  dry-run from the active checkout
  llm sync --apply                          apply defaults (replace A; merge B)
  llm sync templates --apply                only sync templates/
  llm sync --from /path/to/dot-llm          sync from a custom local checkout
  llm sync --from git@github.com:rntgspr/dot-llm.git --apply
                                            sync from a git URL (shallow clone)
EOF
}

cmd_sync() {
  local from=""
  local apply=0
  local filter=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --from)  from="${2:-}"; shift 2 ;;
      --apply) apply=1; shift ;;
      help|-h|--help) cmd_sync_help; return 0 ;;
      -*)      red "unknown flag: $1"; cmd_sync_help; return 2 ;;
      *)
        if [[ -z "$filter" ]]; then filter="$1"
        else red "unexpected arg: $1"; cmd_sync_help; return 2
        fi
        shift
        ;;
    esac
  done

  # Validate filter (must be a known top-level dir of the framework starter)
  if [[ -n "$filter" ]]; then
    case "$filter" in
      intake|plans|archive|specs|exploring|roles|templates|reviews) ;;
      *)
        red "✗ unknown filter: $filter"
        yellow "  Valid filters: intake, plans, archive, specs, exploring, roles, templates, reviews"
        return 2
        ;;
    esac
  fi

  # 1) Resolve source
  local source_root tmpdir=""
  if [[ -z "$from" ]]; then
    if [[ -f "$SCRIPT_DIR/llm" && -d "$SCRIPT_DIR/dot-llm-framework" ]]; then
      source_root="$SCRIPT_DIR"
    else
      red "✗ --from required (path to a dot-llm checkout or git URL)"
      return 1
    fi
  elif [[ "$from" =~ ^(git@|https?://|ssh://) ]] || [[ "$from" =~ \.git$ ]]; then
    tmpdir=$(mktemp -d)
    say "Cloning $from into $tmpdir ..."
    if ! git clone --depth 1 "$from" "$tmpdir" >/dev/null 2>&1; then
      red "✗ git clone failed: $from"
      rm -rf "$tmpdir"
      return 1
    fi
    source_root="$tmpdir"
  elif [[ -d "$from" ]]; then
    source_root="$from"
  else
    red "✗ source not found: $from"
    return 1
  fi
  [[ -n "$tmpdir" ]] && trap 'rm -rf "$tmpdir"' EXIT

  if [[ ! -f "$source_root/llm" || ! -d "$source_root/dot-llm-framework" ]]; then
    red "✗ source $source_root does not look like a dot-llm checkout (need llm and dot-llm-framework/)"
    return 1
  fi

  local source_framework="$source_root/dot-llm-framework"
  local source_schema="$source_framework/schema.yaml"

  # 2) Pre-flight: target must be installed
  if [[ ! -f "$DOT_LLM_DIR/index.md" || ! -f "$SCHEMA" ]]; then
    red "✗ target $DOT_LLM_DIR is not an installed framework tree (missing index.md or schema.yaml)"
    return 1
  fi

  # 3) Versions
  local source_version target_version
  source_version=$(awk '/^version:[[:space:]]/ {print $2; exit}' "$source_schema")
  target_version=$(awk '/^---$/{c++; if(c==2) exit; next} c==1 && /^framework-version:[[:space:]]/ {print $2; exit}' "$DOT_LLM_DIR/index.md")

  say "Source: $source_root (framework version $source_version)"
  say "Target: $DOT_LLM_DIR (framework-version ${target_version:-unset})"
  say ""

  # 4) Parse sync config from the source schema
  local framework_files=()
  while IFS= read -r f; do [[ -n "$f" ]] && framework_files+=("$f"); done < <(parse_yaml_list "$source_schema" framework_files)

  local marked_files=()
  while IFS= read -r f; do [[ -n "$f" ]] && marked_files+=("$f"); done < <(parse_yaml_list "$source_schema" marked_files)

  # 5) Compute changes (with optional filter)
  local changes_a=() changes_b=()

  local f src tgt
  for f in "${framework_files[@]}"; do
    [[ -n "$filter" && "$f" != "$filter"/* && "$f" != "$filter".* ]] && continue
    src="$source_framework/$f"; tgt="$DOT_LLM_DIR/$f"
    [[ ! -f "$src" ]] && { yellow "  ⚠ source missing: $f (skip)"; continue; }
    if [[ ! -f "$tgt" ]] || ! cmp -s "$src" "$tgt"; then
      changes_a+=("$f")
    fi
  done

  local expected_tmp tags_csv
  for f in "${marked_files[@]}"; do
    [[ -n "$filter" && "$f" != "$filter"/* && "$f" != "$filter".* ]] && continue
    src="$source_framework/$f"; tgt="$DOT_LLM_DIR/$f"
    [[ ! -f "$src" ]] && { yellow "  ⚠ source missing: $f (skip)"; continue; }
    if [[ ! -f "$tgt" ]]; then
      changes_b+=("$f|")
      continue
    fi
    expected_tmp=$(mktemp)
    inject_blocks "$src" "$tgt" > "$expected_tmp"
    if ! cmp -s "$expected_tmp" "$tgt"; then
      tags_csv=$(fm_block_list "$tgt" | awk '{ printf "%s%s", (NR>1?",":""), $0 }')
      changes_b+=("$f|$tags_csv")
    fi
    rm -f "$expected_tmp"
  done

  local total=$(( ${#changes_a[@]} + ${#changes_b[@]} ))
  if [[ $total -eq 0 ]]; then
    if [[ -n "$filter" ]]; then
      green "✓ Already in sync (filter: $filter)."
    else
      green "✓ Already in sync."
    fi
    return 0
  fi

  # 6) Apply path (--apply): auto-strategy and exit.
  if [[ $apply -eq 1 ]]; then
    say "[A] Framework files (replace wholesale): ${#changes_a[@]}"
    say "[B] Marked files (replace outside llm:* blocks): ${#changes_b[@]}"
    if [[ "$source_version" != "$target_version" ]]; then
      yellow "  Note: framework-version differs (source=$source_version, target=${target_version:-unset})."
      yellow "  After applying, bump framework-version in $DOT_LLM_DIR/index.md to $source_version."
    fi
    say ""
    if [[ ${#changes_a[@]} -gt 0 ]]; then
      for f in "${changes_a[@]}"; do
        mkdir -p "$(dirname "$DOT_LLM_DIR/$f")"
        cp "$source_framework/$f" "$DOT_LLM_DIR/$f"
        green "  ✓ replaced $f"
      done
    fi
    if [[ ${#changes_b[@]} -gt 0 ]]; then
      local entry tags
      for entry in "${changes_b[@]}"; do
        f="${entry%%|*}"; tags="${entry##*|}"
        src="$source_framework/$f"; tgt="$DOT_LLM_DIR/$f"
        mkdir -p "$(dirname "$tgt")"
        if [[ ! -f "$tgt" ]]; then
          cp "$src" "$tgt"
          green "  ✓ created $f"
        else
          inject_blocks "$src" "$tgt" > "$tgt.tmp" && mv "$tgt.tmp" "$tgt"
          green "  ✓ updated $f (preserved: ${tags:-no markers})"
        fi
      done
    fi
    green ""
    green "✓ Sync complete."
    return 0
  fi

  # 7) Default (no --apply): rich dry-run for an LLM to review file-by-file.
  say "═══════════════════════════════════════════════════════════════════════"
  say "Sync review for an LLM"
  say "═══════════════════════════════════════════════════════════════════════"
  say ""
  say "Heuristic — apply per file:"
  say "  • Content inside \`<!-- llm:NAME -->\` blocks → KEEP LOCAL."
  say "  • Prose / headers / Rules / structure outside markers → take FROM FRAMEWORK."
  say "  • Outside-marker prose that contains project-specific content → ANALYZE: keep"
  say "    what is project-local, integrate framework changes around it."
  say ""
  if [[ "$source_version" != "$target_version" ]]; then
    yellow "Note: framework-version differs (source=$source_version, target=${target_version:-unset})."
    yellow "After applying, bump framework-version in $DOT_LLM_DIR/index.md to $source_version."
    say ""
  fi
  say "$total file(s) need review."
  if [[ -n "$filter" ]]; then
    say "Filter: $filter"
  fi
  say ""

  local idx=0
  if [[ ${#changes_a[@]} -gt 0 ]]; then
    for f in "${changes_a[@]}"; do
      idx=$((idx + 1))
      _sync_render_review "$idx" "$total" "$f" "A" "" \
        "$source_framework/$f" "$DOT_LLM_DIR/$f"
    done
  fi
  if [[ ${#changes_b[@]} -gt 0 ]]; then
    local entry tags
    for entry in "${changes_b[@]}"; do
      f="${entry%%|*}"; tags="${entry##*|}"
      idx=$((idx + 1))
      _sync_render_review "$idx" "$total" "$f" "B" "$tags" \
        "$source_framework/$f" "$DOT_LLM_DIR/$f"
    done
  fi

  # Final summary — machine-readable for an LLM to synthesize a one-liner.
  say "═══════════════════════════════════════════════════════════════════════"
  say "Summary"
  say "═══════════════════════════════════════════════════════════════════════"
  say "Total files needing review: $total"
  say "  Category A (replace wholesale):  ${#changes_a[@]}"
  say "  Category B (preserve markers):   ${#changes_b[@]}"
  if [[ "$source_version" != "$target_version" ]]; then
    say "  Framework-version drift: target=${target_version:-unset} → source=$source_version"
  fi
  say ""
  say "Files:"
  if [[ ${#changes_a[@]} -gt 0 ]]; then
    for f in "${changes_a[@]}"; do
      say "  [A] $f"
    done
  fi
  if [[ ${#changes_b[@]} -gt 0 ]]; then
    local entry tags
    for entry in "${changes_b[@]}"; do
      f="${entry%%|*}"; tags="${entry##*|}"
      say "  [B] $f${tags:+ (markers: $tags)}"
    done
  fi
  say ""
  say "═══════════════════════════════════════════════════════════════════════"
  say "Pass --apply to auto-apply default strategies, or edit individual files"
  say "based on the heuristic above."
  return 0
}

# Render a per-file review block for the rich dry-run.
# Args: idx, total, path, category (A|B), tags_csv (B only), src_path, tgt_path.
_sync_render_review() {
  local idx="$1" total="$2" f="$3" cat="$4" tags="$5" src="$6" tgt="$7"

  echo
  echo "─── [$idx/$total] $f"
  if [[ "$cat" == "A" ]]; then
    echo "Category: A (framework_files — replace wholesale by default)"
    echo "Default:  replace"
    echo "Options:"
    echo "    replace      overwrite local with framework version"
    echo "    keep         do nothing (you decided to diverge)"
    echo "    llm-decide   read both, produce a semantic merge"
  else
    echo "Category: B (marked_files — preserve <!-- llm:NAME --> blocks)"
    echo "Markers:  ${tags:-none in target}"
    echo "Default:  merge (preserve markers, replace prose around them)"
    echo "Options:"
    echo "    replace      overwrite local entirely (loses anything outside markers AND inside)"
    echo "    merge        apply default strategy"
    echo "    keep         do nothing"
    echo "    llm-decide   read both, produce a semantic merge"
  fi
  echo
  if [[ ! -f "$tgt" ]]; then
    echo "(local file does not exist — \`merge\` and \`replace\` both create it from source)"
    echo
    return 0
  fi
  echo "--- Diff (local → source) ---"
  diff -u "$tgt" "$src" 2>/dev/null || true
  echo
}
