# cmd_sync.sh — steady-state sync of a project's .llm/ tree with the latest
# framework definition (same framework-version on both sides).
#
# v3 model — three regions per file, no `sync:` config:
#   1. frontmatter  — adopter VALUES are kept verbatim; the script only reports
#                     key drift (keys the source has that local lacks, and vice
#                     versa) so the LLM can reconcile against schema.yaml.
#   2. tag bodies   — `<!-- llm:NAME -->` blocks: local body is preserved; a
#                     marker present in source but absent locally is added empty.
#                     Table tags get a column-header diff; string tags are
#                     flagged for an LLM semantic check. Bodies are never
#                     rewritten mechanically.
#   3. prose        — everything else: taken FROM SOURCE by default (framework
#                     rules land here). `--keep-prose` keeps the adopter's prose
#                     with a per-file warning that the tree may diverge.
#
# "Both-sides" files only: every file shipped in the framework starter that
# also exists locally is synced; a starter file absent locally is created;
# adopter-created entities (intake/<KEY>/, plans/<PLAN-ID>/, specs/<area>/…)
# have no source counterpart and are left untouched.
#
# Version gate: if the source `version:` differs from the local
# `framework-version:`, this is a MIGRATION, not a sync. The command refuses to
# run and points to the llm-cli skill's v2 → v3 migration procedure.
#
# Updating the `llm` script / src/*.sh is NOT this command's job — those live
# outside .llm/ and are maintained by pulling the dot-llm checkout.
#
# Expects from the entry-point: SCRIPT_DIR, DOT_LLM_DIR, SCHEMA, QUIET.

# --- frontmatter helpers (markdown files only) -----------------------------

# True (0) if $1 has a frontmatter fence pair.
_sync_has_fm() {
  awk '/^---$/ { c++ } END { exit !(c >= 2) }' "$1"
}

# Top-level frontmatter keys of $1, one per line (order preserved).
_sync_fm_keys() {
  awk '
    /^---$/ { c++; if (c == 2) exit; next }
    c == 1 && /^[A-Za-z][A-Za-z0-9_-]*:/ { k = $0; sub(/:.*/, "", k); print k }
  ' "$1"
}

# Print the frontmatter region of $1 (the two fences inclusive).
_sync_fm_region() {
  awk '/^---$/ { c++; print; if (c == 2) exit; next } c == 1 { print }' "$1"
}

# Print everything in $1 AFTER the frontmatter region.
_sync_body_after_fm() {
  awk 'p { print; next } /^---$/ { c++; if (c == 2) p = 1 }' "$1"
}

# --- tag helpers -----------------------------------------------------------

# First markdown table header line ("| a | b |") inside tag $2 of file $1.
# Empty if the body has no table.
_sync_tag_header() {
  fm_block_extract "$1" "$2" | awk 'NF && /^[[:space:]]*\|/ { print; exit }'
}

# True (0) if tag $2 of file $1 has a table body.
_sync_tag_is_table() {
  [[ -n "$(_sync_tag_header "$1" "$2")" ]]
}

# --- expected-content builder ----------------------------------------------

# Build the merged ("expected") content for one both-sides file and print it
# to stdout. Default: source structure + source prose, with local tag bodies
# injected and the local frontmatter kept. With keep_prose=1: the local file is
# kept as-is, only markers missing locally are appended empty.
# Args: src tgt keep_prose has_fm
_sync_build_expected() {
  local src="$1" tgt="$2" keep_prose="$3" has_fm="$4"

  if [[ "$keep_prose" == "1" ]]; then
    # Keep local prose/frontmatter/bodies; only add markers present in source
    # but absent locally (empty), so new framework tags still appear.
    local out missing=()
    out=$(cat "$tgt")
    local name
    while IFS= read -r name; do
      [[ -z "$name" ]] && continue
      fm_block_list "$tgt" | grep -qxF "$name" || missing+=("$name")
    done < <(fm_block_list "$src")
    if [[ ${#missing[@]} -gt 0 ]]; then
      local tmp; tmp=$(mktemp)
      printf '%s\n' "$out" > "$tmp"
      _tag_insert_empty "$tmp" "${missing[@]}" 2>/dev/null || true
      cat "$tmp"; rm -f "$tmp"
    else
      printf '%s\n' "$out"
    fi
    return 0
  fi

  # Default: source prose + injected local bodies, then swap in local fm.
  local injected; injected=$(mktemp)
  inject_blocks "$src" "$tgt" > "$injected"
  if [[ "$has_fm" == "1" ]] && _sync_has_fm "$tgt"; then
    _sync_fm_region "$tgt"
    _sync_body_after_fm "$injected"
  else
    cat "$injected"
  fi
  rm -f "$injected"
}

# True (0) if a file needs attention: the mechanical merge would change it, OR
# its frontmatter keys drift from source, OR a shared table tag's columns
# differ, OR it carries a marker with no source counterpart. The latter three
# are not fixed by the merge (bodies/frontmatter are preserved) but the LLM
# must still see them — so they count as "needs attention".
# Args: src tgt keep_prose has_fm
_sync_needs_attention() {
  local src="$1" tgt="$2" keep_prose="$3" has_fm="$4"
  [[ -f "$tgt" ]] || return 0
  local expected; expected=$(mktemp)
  _sync_build_expected "$src" "$tgt" "$keep_prose" "$has_fm" > "$expected"
  if ! cmp -s "$expected" "$tgt"; then rm -f "$expected"; return 0; fi
  rm -f "$expected"
  if [[ "$has_fm" == "1" ]] && \
     ! diff -q <(_sync_fm_keys "$src" | sort -u) <(_sync_fm_keys "$tgt" | sort -u) >/dev/null 2>&1; then
    return 0
  fi
  local name
  while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    fm_block_list "$tgt" | grep -qxF "$name" || continue
    if _sync_tag_is_table "$src" "$name" && \
       [[ "$(_sync_tag_header "$src" "$name")" != "$(_sync_tag_header "$tgt" "$name")" ]]; then
      return 0
    fi
  done < <(fm_block_list "$src")
  while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    fm_block_list "$src" | grep -qxF "$name" || return 0
  done < <(fm_block_list "$tgt")
  return 1
}

# --- per-file structured review (dry-run) ----------------------------------

# Args: idx total relpath src tgt has_fm keep_prose
_sync_render() {
  local idx="$1" total="$2" f="$3" src="$4" tgt="$5" has_fm="$6" keep_prose="$7"
  echo
  echo "─── [$idx/$total] $f"

  if [[ ! -f "$tgt" ]]; then
    echo "Status: NEW (absent locally) — will be created from the framework source."
    echo
    return 0
  fi

  # Frontmatter key drift.
  if [[ "$has_fm" == "1" ]]; then
    local only_src only_local
    only_src=$(comm -23 <(_sync_fm_keys "$src" | sort -u) <(_sync_fm_keys "$tgt" | sort -u) | paste -sd, -)
    only_local=$(comm -13 <(_sync_fm_keys "$src" | sort -u) <(_sync_fm_keys "$tgt" | sort -u) | paste -sd, -)
    if [[ -z "$only_src" && -z "$only_local" ]]; then
      echo "Frontmatter: ✓ keys match (values kept as-is)."
    else
      echo "Frontmatter: key drift (values are NEVER overwritten — reconcile against schema.yaml):"
      [[ -n "$only_src"   ]] && echo "    + in source, missing locally: $only_src"
      [[ -n "$only_local" ]] && echo "    - local only, not in source:  $only_local"
    fi
  fi

  # Tag analysis.
  local src_tags tgt_tags name
  src_tags=$(fm_block_list "$src")
  tgt_tags=$(fm_block_list "$tgt")
  if [[ -n "$src_tags$tgt_tags" ]]; then
    echo "Tags:"
    while IFS= read -r name; do
      [[ -z "$name" ]] && continue
      if grep -qxF "$name" <<< "$tgt_tags"; then
        if _sync_tag_is_table "$src" "$name"; then
          local sh th
          sh=$(_sync_tag_header "$src" "$name")
          th=$(_sync_tag_header "$tgt" "$name")
          if [[ "$sh" == "$th" ]]; then
            echo "    [=] $name (table) — columns match, rows preserved."
          else
            echo "    [Δ] $name (table) — column header changed; reshape body, keep rows:"
            echo "          source: $sh"
            echo "          local:  ${th:-<no table>}"
          fi
        else
          echo "    [?] $name (prose) — body preserved; verify it still matches the schema subject."
        fi
      else
        echo "    [+] $name — present in source, absent locally → empty block will be added."
      fi
    done <<< "$src_tags"
    # Orphans: local markers with no source counterpart.
    while IFS= read -r name; do
      [[ -z "$name" ]] && continue
      grep -qxF "$name" <<< "$src_tags" || echo "    [orphan] $name — local only, not in the framework source (decide: keep or remove)."
    done <<< "$tgt_tags"
  fi

  echo
  echo "--- Diff (local → result of --apply: prose from source, bodies + frontmatter kept) ---"
  local merged; merged=$(mktemp)
  _sync_build_expected "$src" "$tgt" "$keep_prose" "$has_fm" > "$merged"
  diff -u "$tgt" "$merged" 2>/dev/null || true
  rm -f "$merged"
  echo
}

cmd_sync_help() {
  cat <<'EOF'
llm sync — steady-state update of .llm/ from the framework source

Usage:
  llm sync [<path>] [--from <path|git-url>] [--keep-prose] [--apply]

Arguments:
  <path>         optional path filter, relative to .llm/. May be a directory
                 (e.g. `templates`, `specs`) to scope the sync to that subtree,
                 or a single file (e.g. `intake/index.md`) to sync just that
                 file. Adopter-owned paths (no framework-source counterpart)
                 are rejected with a clear message.

Options:
  --from <src>   path to a dot-llm checkout, or a git URL to clone shallowly
                 (default: the checkout this `llm` script was sourced from).
  --keep-prose   keep the adopter's prose instead of taking it from the source.
                 Prints a per-file warning: framework rule updates are NOT
                 applied and the tree may diverge from its spec.
  --apply        apply the merge mechanically (preserve frontmatter values and
                 tag bodies, take prose from source, add missing markers).
                 Without it, prints a structured per-file review for the LLM.

Per-file model (v3):
  • Frontmatter — adopter values are kept verbatim; only key drift is reported.
  • Tag bodies  — local body preserved; a marker missing locally is added
                  empty. Table tags get a column diff; string tags are flagged
                  for a semantic check. Bodies are never rewritten mechanically.
  • Prose       — taken FROM SOURCE by default (--keep-prose to retain local).

Only "both-sides" files are touched: framework-shipped files that also exist
locally are synced; a starter file absent locally is created; adopter-created
entities have no source counterpart and are left untouched.

Version gate:
  If the source `version:` differs from the local `framework-version:`, this is
  a MIGRATION, not a sync. The command refuses and points to the llm-cli skill's
  v2 → v3 migration procedure.

After applying anything touching index.md or schema.yaml, bump
framework-version in .llm/index.md to match the source. The validator enforces
equality on the next run.

Examples:
  llm sync                          dry-run from the active checkout
  llm sync --apply                  apply the merge to every changed file
  llm sync templates --apply        only sync templates/
  llm sync intake/index.md          review just one file
  llm sync --keep-prose --apply     apply, but keep local prose (warns)
EOF
}

cmd_sync() {
  local from="" apply=0 keep_prose=0 path_filter=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --from)       from="${2:-}"; shift 2 ;;
      --apply)      apply=1; shift ;;
      --keep-prose) keep_prose=1; shift ;;
      help|-h|--help) cmd_sync_help; return 0 ;;
      -*)           red "unknown flag: $1"; cmd_sync_help; return 2 ;;
      *)
        if [[ -z "$path_filter" ]]; then path_filter="${1%/}"
        else red "unexpected arg: $1"; cmd_sync_help; return 2; fi
        shift ;;
    esac
  done

  # 1) Resolve source
  local source_root tmpdir=""
  if [[ -z "$from" ]]; then
    if [[ -f "$SCRIPT_DIR/llm" && -d "$SCRIPT_DIR/dot-llm-framework" ]]; then
      source_root="$SCRIPT_DIR"
    else
      red "✗ --from required (path to a dot-llm checkout or git URL)"; return 1
    fi
  elif [[ "$from" =~ ^(git@|https?://|ssh://) ]] || [[ "$from" =~ \.git$ ]]; then
    tmpdir=$(mktemp -d)
    say "Cloning $from into $tmpdir ..."
    if ! git clone --depth 1 "$from" "$tmpdir" >/dev/null 2>&1; then
      red "✗ git clone failed: $from"; rm -rf "$tmpdir"; return 1
    fi
    source_root="$tmpdir"
  elif [[ -d "$from" ]]; then
    source_root="$from"
  else
    red "✗ source not found: $from"; return 1
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

  # 3) Version gate — mismatch means migration, not steady-state sync.
  local source_version target_version
  source_version=$(awk '/^version:[[:space:]]/ {print $2; exit}' "$source_schema")
  target_version=$(awk '/^---$/{c++; if(c==2) exit; next} c==1 && /^framework-version:[[:space:]]/ {print $2; exit}' "$DOT_LLM_DIR/index.md")
  if [[ -n "$source_version" && -n "$target_version" && "$source_version" != "$target_version" ]]; then
    red "✗ version mismatch — this is a MIGRATION, not a sync."
    yellow "  source framework version: $source_version"
    yellow "  local framework-version:  $target_version"
    say ""
    say "Steady-state sync only runs when both versions match. To upgrade this"
    say "tree, follow the v$target_version → v$source_version migration procedure in the"
    say "llm-cli skill (schema first → folders → frontmatter → tags → bump)."
    return 1
  fi

  say "Source: $source_root (framework version $source_version)"
  say "Target: $DOT_LLM_DIR (framework-version ${target_version:-unset})"
  say "Schema reference for reconciliation: $SCHEMA"
  say ""

  # 4) Discover both-sides candidates by walking the source framework dir.
  #    A path filter (dir or file) restricts the set.
  local rels=() rel
  while IFS= read -r rel; do
    rel="${rel#"$source_framework"/}"
    [[ "$rel" == "schema.bkp.yaml" ]] && continue
    if [[ -n "$path_filter" ]]; then
      [[ "$rel" == "$path_filter" || "$rel" == "$path_filter"/* ]] || continue
    fi
    rels+=("$rel")
  done < <(find "$source_framework" -type f \( -name '*.md' -o -name '*.yaml' \) | sort)

  # If a path filter was given but matched nothing in the source, the path is
  # adopter-owned (or wrong) — refuse rather than silently no-op.
  if [[ -n "$path_filter" && ${#rels[@]} -eq 0 ]]; then
    if [[ -e "$DOT_LLM_DIR/$path_filter" ]]; then
      red "✗ '$path_filter' is adopter-owned — no framework source exists for it, so no sync applies."
      yellow "  Only files shipped in the framework starter can be synced."
    else
      red "✗ '$path_filter' matches nothing in the framework source."
    fi
    return 2
  fi

  # 5) Compute the changed set (needs-attention per file).
  local changed=()
  for rel in "${rels[@]}"; do
    local src="$source_framework/$rel" tgt="$DOT_LLM_DIR/$rel"
    local has_fm=0; _sync_has_fm "$src" && has_fm=1
    _sync_needs_attention "$src" "$tgt" "$keep_prose" "$has_fm" && changed+=("$rel")
  done

  local total=${#changed[@]}
  if [[ $total -eq 0 ]]; then
    green "✓ Already in sync${path_filter:+ (path: $path_filter)}."
    return 0
  fi

  # 6) --apply: mechanical merge.
  if [[ $apply -eq 1 ]]; then
    [[ $keep_prose -eq 1 ]] && yellow "⚠ --keep-prose: framework prose updates are NOT applied; the tree may diverge from its spec."
    local touched_core=0
    for rel in "${changed[@]}"; do
      local src="$source_framework/$rel" tgt="$DOT_LLM_DIR/$rel"
      mkdir -p "$(dirname "$tgt")"
      if [[ ! -f "$tgt" ]]; then
        cp "$src" "$tgt"; green "  ✓ created $rel"; continue
      fi
      [[ $keep_prose -eq 1 ]] && yellow "    (kept local prose) $rel"
      local has_fm=0; _sync_has_fm "$src" && has_fm=1
      _sync_build_expected "$src" "$tgt" "$keep_prose" "$has_fm" > "$tgt.tmp" && mv "$tgt.tmp" "$tgt"
      green "  ✓ merged $rel"
      [[ "$rel" == "index.md" || "$rel" == "schema.yaml" ]] && touched_core=1
    done
    say ""
    if [[ $touched_core -eq 1 && "$source_version" != "$target_version" ]]; then
      yellow "Bump framework-version in $DOT_LLM_DIR/index.md to $source_version."
    fi
    green "✓ Sync complete ($total file(s))."
    return 0
  fi

  # 7) Default: structured per-file review for the LLM.
  say "═══════════════════════════════════════════════════════════════════════"
  say "Sync review (v$source_version steady state) — $total file(s) need attention"
  say "═══════════════════════════════════════════════════════════════════════"
  say "Per file: frontmatter values are kept; tag bodies are preserved; prose"
  say "comes from source. Reconcile reported key/column drift against:"
  say "  $SCHEMA"
  [[ $keep_prose -eq 1 ]] && yellow "⚠ --keep-prose active: prose will be kept local (framework updates skipped)."
  [[ -n "$path_filter" ]] && say "Path filter: $path_filter"

  local idx=0
  for rel in "${changed[@]}"; do
    idx=$((idx + 1))
    local src="$source_framework/$rel" tgt="$DOT_LLM_DIR/$rel"
    local has_fm=0; _sync_has_fm "$src" && has_fm=1
    _sync_render "$idx" "$total" "$rel" "$src" "$tgt" "$has_fm" "$keep_prose"
  done

  say "═══════════════════════════════════════════════════════════════════════"
  say "Summary — $total file(s):"
  for rel in "${changed[@]}"; do
    [[ -f "$DOT_LLM_DIR/$rel" ]] && say "  [merge] $rel" || say "  [new]   $rel"
  done
  say ""
  say "Re-run with --apply to merge mechanically, or edit files per the review."
  return 0
}

# Build the source file with the target's `<!-- llm:NAME -->` block bodies
# injected. Writes to stdout. Markers absent in the target keep the source's
# (typically empty) body. Args: src_file, tgt_file
inject_blocks() {
  local src="$1" tgt="$2"
  local tmp; tmp=$(mktemp -d)
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
