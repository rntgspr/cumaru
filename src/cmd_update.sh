# cmd_update.sh — update an installed .cumaru/ tree from the framework source.
#
# Framework-owned Markdown is rebuilt from source. Existing marker bodies are
# captured and restored at matching markers; --keep-prose opts out of canonical
# prose replacement. Adopter-created entities without a source counterpart are
# left untouched.
#
# "Both-sides" files only: every file shipped in the framework starter that
# also exists locally is updated; a starter file absent locally is created;
# adopter-created entities (intake items, plans/<PLAN-ID>/, specs/<area>/…)
# have no source counterpart and are left untouched.
#
# Skills and slash commands:
#   Updated deterministically — sources in the Cumaru checkout replace the
#   installed copies wholesale (no adopter customisation is expected here;
#   these are framework-owned artifacts). Deprecated commands (present
#   locally but absent from the source) are listed for review but NOT removed.
#
# Version drift is gated: local schema and root versions must agree, downgrade
# is refused, and a higher source major is dry-run only until migrated.
#
# Expects from the entry-point: SCRIPT_DIR, CUMARU_DIR, AGENTS_DIR, SCHEMA, QUIET,
# SKILLS_SRC, and the _framework_install_skills /
# _framework_copy_commands / _framework_deprecated_skills /
# _framework_deprecated_commands helpers (defined in cmd_install.sh).

# --- frontmatter helpers (markdown files only) -----------------------------

_update_has_fm() {
  awk '/^---$/ { c++ } END { exit !(c >= 2) }' "$1"
}

_update_fm_keys() {
  awk '
    /^---$/ { c++; if (c == 2) exit; next }
    c == 1 && /^[A-Za-z][A-Za-z0-9_-]*:/ { k = $0; sub(/:.*/, "", k); print k }
  ' "$1"
}

_update_fm_region() {
  awk '/^---$/ { c++; print; if (c == 2) exit; next } c == 1 { print }' "$1"
}

_update_body_after_fm() {
  awk 'p { print; next } /^---$/ { c++; if (c == 2) p = 1 }' "$1"
}

# --- tag helpers -----------------------------------------------------------

# v4 — every tag body is a [Link, Description] table.
_update_tag_is_empty() {
  local body; body=$(fm_block_extract "$1" "$2")
  [[ -z "${body//[[:space:]]/}" ]]
}

_update_tag_is_table() {
  fm_block_extract "$1" "$2" | grep -qE '^[[:space:]]*\|'
}

# --- expected-content builder ----------------------------------------------

_update_build_expected() {
  local src="$1" tgt="$2" keep_prose="$3" has_fm="$4"
  # Framework-owned files are replaced wholesale. Only marker bodies are
  # adopter-owned: capture them from the local file and rehydrate them at the
  # source markers, or at the top when the source no longer has that marker.
  _update_inject_blocks "$src" "$tgt"
}

_update_needs_attention() {
  local src="$1" tgt="$2" keep_prose="$3" has_fm="$4"
  [[ -f "$tgt" ]] || return 0
  local expected; expected=$(mktemp)
  _update_build_expected "$src" "$tgt" "$keep_prose" "$has_fm" > "$expected"
  if ! cmp -s "$expected" "$tgt"; then rm -f "$expected"; return 0; fi
  rm -f "$expected"
  if [[ "$has_fm" == "1" ]] && \
     ! diff -q <(_update_fm_keys "$src" | sort -u) <(_update_fm_keys "$tgt" | sort -u) >/dev/null 2>&1; then
    return 0
  fi
  local name
  while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    fm_block_list "$src" | grep -qxF "$name" || return 0
  done < <(fm_block_list "$tgt")
  return 1
}

# --- schema contract comparison (strip adopter-owned regions) --------------

# Strip adopter-owned YAML regions from schema.yaml, outputting only the
# framework contract portion (version, domain, rules, root, meta.tags,
# meta.compatibility). Adapter-owned regions (meta.apps.values,
# meta.specification_dir, meta.coverage) are excluded so that customising
# them doesn't trigger false drift warnings in `cumaru update`.
_schema_extract_contract() {
  awk '
    BEGIN { skip = 0; skip_indent = -1; in_meta = 0 }

    {
      if (skip) {
        match($0, /^[ \t]*/)
        cur_indent = RLENGTH
        if (cur_indent <= skip_indent && /^[ \t]*[a-zA-Z_][a-zA-Z0-9_-]*:/) {
          skip = 0
          print
          next
        }
        next
      }

      if (/^[ \t]*$/) { print; next }

      # Agent selection is installed runtime state, not source schema drift.
      if (/^agent:/) { next }

      # Detect adopter-owned keys (including commented forms) before the
      # generic comment catch-all, so they are stripped from the contract.
      if (in_meta && /^  (# )?apps:/)              { skip = 1; skip_indent = 2; next }
      if (in_meta && /^  (# )?specification_dir:/) { next }
      if (in_meta && /^  (# )?coverage:/)           { skip = 1; skip_indent = 2; next }

      if (/^meta:[ \t]*$/) {
        in_meta = 1
        print
        next
      }

      if (in_meta && /^[a-zA-Z_][a-zA-Z0-9_-]*:/) {
        in_meta = 0
        print
        next
      }

      if (/^[ \t]*#/) { print; next }

      if (/^[a-zA-Z_][a-zA-Z0-9_-]*:/) {
        print
        next
      }

      print
    }
  ' "$1"
}

# Compare two schema.yaml files using only their framework contract portions.
# Returns 0 (match) or 1 (framework contract differs).
_schema_framework_contract_match() {
  cmp -s <(_schema_extract_contract "$1") <(_schema_extract_contract "$2")
}

# --- per-file structured review (dry-run) ----------------------------------

_update_render() {
  local idx="$1" total="$2" f="$3" src="$4" tgt="$5" has_fm="$6" keep_prose="$7" tag_schema_root="${8:-$CUMARU_DIR}"
  echo
  echo "─── [$idx/$total] $f"

  if [[ ! -f "$tgt" ]]; then
    echo "Status: NEW (absent locally) — will be created from the framework source."
    echo
    return 0
  fi

  if [[ "$has_fm" == "1" ]]; then
    local only_src only_local
    only_src=$(comm -23 <(_update_fm_keys "$src" | sort -u) <(_update_fm_keys "$tgt" | sort -u) | paste -sd, -)
    only_local=$(comm -13 <(_update_fm_keys "$src" | sort -u) <(_update_fm_keys "$tgt" | sort -u) | paste -sd, -)
    if [[ -z "$only_src" && -z "$only_local" ]]; then
      echo "Frontmatter: ✓ keys match (values kept as-is)."
    else
      echo "Frontmatter: key drift (values are NEVER overwritten — reconcile against schema.yaml):"
      [[ -n "$only_src"   ]] && echo "    + in source, missing locally: $only_src"
      [[ -n "$only_local" ]] && echo "    - local only, not in source:  $only_local"
    fi
  fi

  local src_tags tgt_tags name tag_type
  src_tags=$(fm_block_list "$src")
  tgt_tags=$(fm_block_list "$tgt")
  if [[ -n "$src_tags$tgt_tags" ]]; then
    echo "Tags (v5 — body type comes from schema; bodies preserved):"
    while IFS= read -r name; do
      [[ -z "$name" ]] && continue
      if grep -qxF "$name" <<< "$tgt_tags"; then
        tag_type=$(fm_schema_tag_type "$tag_schema_root" "$name")
        if _update_tag_is_empty "$tgt" "$name"; then
          echo "    [?] $name — local block is empty; populate according to its schema tag type."
        elif [[ "$tag_type" == "prose" || "$tag_type" == "mixed" || "$tag_type" == "other" ]]; then
          echo "    [=] $name — ${tag_type} body preserved."
        elif _update_tag_is_table "$tgt" "$name"; then
          echo "    [=] $name — body preserved."
        else
          echo "    [Δ] $name — local body is NOT a markdown table; if schema declares a table, reshape it, otherwise keep prose/mixed/other as adopter-owned."
        fi
      else
        echo "    [+] $name — present in source, absent locally → empty block will be added."
      fi
    done <<< "$src_tags"
    while IFS= read -r name; do
      [[ -z "$name" ]] && continue
      grep -qxF "$name" <<< "$src_tags" || echo "    [orphan] $name — local only, not in the framework source (kept verbatim on --apply; decide: keep or remove)."
    done <<< "$tgt_tags"
  fi

  echo
  echo "--- Diff (local → result of --apply: canonical source + preserved marker bodies) ---"
  local merged; merged=$(mktemp)
  _update_build_expected "$src" "$tgt" "$keep_prose" "$has_fm" > "$merged"
  diff -u "$tgt" "$merged" 2>/dev/null || true
  rm -f "$merged"
  echo
}

cmd_update_help() {
  cat <<'EOF'
cumaru update — update an installed .cumaru/ tree + skills + slash commands

Usage:
  cumaru update [<path>] [--from <path|git-url>] [--keep-prose] [--apply]
  cumaru update agent <none|claude|codex|opencode> [--from <path>] [--apply]
  cumaru update skills   [--from <path|git-url>] [--apply]
  cumaru update commands [--from <path|git-url>] [--apply]
  cumaru update schema   [--from <path|git-url>] [--apply]

Arguments:
  <path>         optional path filter, relative to .cumaru/. May be a directory
                 (e.g. `templates`, `specs`) to scope the .cumaru/ update to that
                 subtree, or a single file (e.g. `intake/index.md`). Adopter-
                 owned paths (no framework source counterpart) are rejected.
  skills         update ONLY framework skills for installed agent target(s).
                  Without --apply, prints a dry-run summary. With --apply, replaces
                  skills wholesale. Skips the .cumaru/ file merge and commands.
                  Without --apply, prints a dry-run summary. With --apply, replaces
                  hook files wholesale. Skips the .cumaru/ file merge, skills, and commands.
  commands       update ONLY slash commands for installed agent target(s).
                  Without --apply, prints a dry-run summary. With --apply, replaces
                  commands wholesale. Skips the .cumaru/ file merge and skills.
  schema         review or replace .cumaru/schema.yaml. Never auto-merged by the
                 general `cumaru update` (mixes framework-owned contracts with
                 adopter-owned regions like `meta.apps.values`). Without --apply,
                 prints a raw `diff -u` for the LLM to adjudicate, listing the
                 adopter-owned regions to preserve. With --apply, OVERWRITES the
                 local schema with the source — destructive on purpose.
  agent <name>   preview or apply a switch of the native agent integration.
                 `none` restores the backward-compatible `.agents/` adapter.

Options:
  --from <src>   path to a Cumaru checkout, or a git URL to clone shallowly
                 (default: the checkout this `cumaru` script was sourced from).
  --keep-prose   keep the adopter's prose instead of taking it from the source.
                 Prints a per-file warning when framework prose is skipped.
  --apply        rebuild framework Markdown from canonical source while
                 preserving matching marker bodies, AND
                  replace skills + slash commands from the source.
                  Without it, prints a structured per-file review for the LLM.

Skills and commands (always applied with --apply, never in general dry-run):
  Skills and supported slash commands are framework-owned artifacts installed
  for the schema-selected adapter. --apply replaces them wholesale. Deprecated
  commands are listed but NOT removed — remove them manually after review.

Domain detection:
  The installed domain is read from the `domain:` field in .cumaru/schema.yaml
  (legacy `flavor:` is accepted as a fallback). Falls back to `base` if absent.

Per-file model (v6):
  • Framework-owned Markdown — rebuilt from the canonical domain source.
  • Marker bodies — captured locally and restored at matching source markers.
  • Local-only entities — untouched because they have no source counterpart.
  • Prose — taken from source by default; --keep-prose retains local prose.

Version drift:
  Local schema and root versions must agree. A higher source major may be
  reviewed in dry-run, but --apply is refused until `cumaru migrate v6` runs.
  Downgrades are refused.

Examples:
  cumaru update                          dry-run from the active checkout
  cumaru update --apply                  apply the merge + replace skills/commands
  cumaru update templates --apply        only update templates/
  cumaru update intake/index.md          review just one file
  cumaru update --keep-prose --apply     apply, but keep local prose (warns)
  cumaru update skills                   dry-run: show which skills would change
  cumaru update skills --apply           replace only skills
  cumaru update commands                 dry-run: show which commands would change
  cumaru update commands --apply         replace only slash commands
  cumaru update schema                   diff source schema vs local for LLM review
  cumaru update schema --apply           OVERWRITE local schema (destructive)
  cumaru update agent opencode            preview native OpenCode integration
  cumaru update agent opencode --apply    install it and persist agent: opencode
  cumaru update agent none --apply        restore generic agent: null behavior
EOF
}

# Reconcile the active adapter's native instruction surface.
_update_reconcile_agent_hook() {
  local parent="$1" apply="$2"
  local agent instructions
  agent=$(_agent_current) || {
    red "✗ invalid agent value in $SCHEMA"
    return 1
  }

  if [[ $apply -eq 1 ]]; then
    _agent_refresh_instructions "$parent" "$agent"
    return
  fi

  if [[ "$agent" == "opencode" ]]; then
    if [[ -f "$parent/opencode.json" ]] &&
       jq -e '.instructions | index(".cumaru/index.md") != null' "$parent/opencode.json" >/dev/null 2>&1; then
      say "  OpenCode instructions: configured (ok)"
    else
      say "  OpenCode instructions: absent (will be configured on --apply)"
    fi
    return
  fi

  instructions=$(_agent_instructions_file "$parent" "$agent")
  if [[ -f "$instructions" ]] && grep -q "BEGIN CUMARU-HOOK" "$instructions"; then
    say "  ${instructions#"$parent"/} hook: CUMARU-HOOK (ok)"
  else
    say "  Agent hook: absent in ${instructions#"$parent"/} (will be created on --apply)"
  fi
}

cmd_update() {
  if [[ "${1:-}" == "agent" ]]; then
    shift
    cmd_update_agent "$@"
    return $?
  fi

  local from="" apply=0 keep_prose=0 path_filter=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --from)       from="${2:-}"; shift 2 ;;
      --apply)      apply=1; shift ;;
      --keep-prose) keep_prose=1; shift ;;
      help|-h|--help) cmd_update_help; return 0 ;;
      -*)           red "unknown flag: $1"; cmd_update_help; return 2 ;;
      *)
        if [[ -z "$path_filter" ]]; then path_filter="${1%/}"
        else red "unexpected arg: $1"; cmd_update_help; return 2; fi
        shift ;;
    esac
  done

  # Resolve domain from the installed schema.yaml. `flavor:` is a legacy field
  # from pre-domain installs; keep it as a read-only fallback so update can
  # migrate those trees instead of incorrectly selecting base.
  local domain
  domain=$(awk '/^domain:[[:space:]]/ {print $2; exit}' "$SCHEMA" 2>/dev/null || true)
  [[ -n "$domain" ]] || domain=$(awk '/^flavor:[[:space:]]/ {print $2; exit}' "$SCHEMA" 2>/dev/null || true)
  : "${domain:=base}"

  # 1) Resolve source root (the dot-llm checkout).
  local source_root tmpdir=""
  if [[ -z "$from" ]]; then
    if [[ -f "$SCRIPT_DIR/cumaru" && -d "$SCRIPT_DIR/domains" ]]; then
      source_root="$SCRIPT_DIR"
    else
      red "✗ --from required (path to a Cumaru checkout or git URL)"; return 1
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
  # Use RETURN instead of EXIT so the trap fires when this function returns,
  # not when the whole process exits. EXIT traps are global — a second call
  # to cmd_update would overwrite the first trap, leaking the first tmpdir.
  # RETURN traps are scoped to the current function invocation.
  [[ -n "$tmpdir" ]] && trap 'rm -rf "$tmpdir"' RETURN

  if [[ ! -f "$source_root/cumaru" || ! -d "$source_root/domains" ]]; then
    red "✗ source $source_root does not look like a cumaru checkout (need cumaru and domains/)"
    return 1
  fi

  # 2) Resolve source domain.
  local source_domain
  source_domain="$source_root/domains/$( [[ "$domain" == "base" ]] && echo "__base" || echo "$domain" )"
  if [[ ! -d "$source_domain" ]]; then
    red "✗ domain '$domain' not found at $source_domain"
    return 1
  fi
  local source_schema="$source_domain/schema.yaml"

  # 3) Pre-flight: target must be installed.
  if [[ ! -f "$CUMARU_DIR/index.md" || ! -f "$SCHEMA" ]]; then
    red "✗ target $CUMARU_DIR is not an installed framework tree (missing index.md or schema.yaml)"
    return 1
  fi

  # 4) Major-version gate. Steady-state update never crosses a major version.
  local source_version source_index_version target_schema_version target_version source_schema_domain
  source_version=$(yq -r '.version // ""' "$source_schema" 2>/dev/null || true)
  source_index_version=$(yq --front-matter=extract -r '.["framework-version"] // ""' "$source_domain/index.md" 2>/dev/null || true)
  target_schema_version=$(yq -r '.version // ""' "$SCHEMA" 2>/dev/null || true)
  target_version=$(yq --front-matter=extract -r '.["framework-version"] // ""' "$CUMARU_DIR/index.md" 2>/dev/null || true)
  source_schema_domain=$(yq -r '.domain // ""' "$source_schema" 2>/dev/null || true)

  if [[ -z "$target_schema_version" || "$target_schema_version" != "$target_version" ]]; then
    red "✗ local version disagreement: schema is ${target_schema_version:-<unset>}, framework-version is ${target_version:-<unset>}"
    return 1
  fi
  if [[ -z "$source_version" || "$source_version" != "$source_index_version" ]]; then
    red "✗ source version disagreement: schema is ${source_version:-<unset>}, framework-version is ${source_index_version:-<unset>}"
    return 1
  fi
  if [[ "$source_schema_domain" != "$domain" ]]; then
    red "✗ source domain disagreement: selected $domain, schema declares ${source_schema_domain:-<unset>}"
    return 1
  fi

  local source_major="${source_version%%.*}" target_major="${target_version%%.*}" migration_notice=0
  if [[ ! "$source_major" =~ ^[0-9]+$ || ! "$target_major" =~ ^[0-9]+$ ]]; then
    red "✗ cannot determine numeric framework major versions"
    return 1
  fi
  if (( source_major < target_major )); then
    red "✗ refusing framework downgrade: source v$source_version, local v$target_version"
    return 1
  fi
  if (( source_major > target_major )); then
    migration_notice=1
    yellow "⚠ major framework upgrade: source v$source_version, local v$target_version"
    say "  Run: cumaru migrate v$source_major --from $source_root"
    if [[ $apply -eq 1 ]]; then
      red "✗ cannot cross a major version boundary with cumaru update --apply"
      return 1
    fi
  fi

  say "Source: $source_root (framework version ${source_version:-unset})"
  say "Target: $CUMARU_DIR (framework-version ${target_version:-unset})"
  say "Schema reference for reconciliation: $SCHEMA"
  say ""

  # Override SKILLS_SRC (opt-ins source) to point at the resolved source root
  # when --from was given. Skills and commands themselves are always sourced
  # from $source_domain — no override needed because $source_domain
  # already resolved from $source_root.
  local skills_src_effective="${source_root}/skills"
  [[ -d "$SKILLS_SRC" && "$source_root" == "$SCRIPT_DIR" ]] && skills_src_effective="$SKILLS_SRC"

  local parent
  parent=$(dirname "$CUMARU_DIR")

  # 5) Reconcile the active adapter's durable instruction surface first.
  _update_reconcile_agent_hook "$parent" "$apply" || return 1

  # 5a-schema) Dedicated schema target: never mechanical-merged.
  # Dry-run prints the raw `diff -u` for the LLM to adjudicate, listing the
  # adopter-owned regions to preserve while reconciling. `--apply` overwrites
  # the local schema with the source — destructive on purpose, parallel to
  # skills/commands. The expected path is hand-merge with LLM assistance.
  if [[ "$path_filter" == "schema" ]]; then
    say "Source schema: $source_schema"
    say "Target schema: $CUMARU_DIR/schema.yaml"
    say ""
    if _schema_framework_contract_match "$source_schema" "$CUMARU_DIR/schema.yaml"; then
      green "✓ schema.yaml framework contract in sync."
      return 0
    fi
    if [[ $apply -eq 0 ]]; then
      yellow "⚠ schema.yaml diverged from source."
      yellow "  Adopter-owned regions to PRESERVE when reconciling:"
      yellow "    · meta.apps.values        — project components list"
      yellow "    · adopter-added pillars   — top-level keys not in source"
      yellow "    · locally-removed markers — intentional removals"
      say ""
      say "Diff (source → target):"
      diff -u "$source_schema" "$CUMARU_DIR/schema.yaml" 2>/dev/null || true
      say ""
      say "Recommended: hand-merge with LLM assistance, preserving the regions"
      say "above. Re-run with --apply ONLY if you want to OVERWRITE the local"
      say "schema with the source (destructive: loses meta.apps.values and any"
      say "local additions)."
      return 0
    fi
    yellow "⚠ Replacing $CUMARU_DIR/schema.yaml with source — local customisations will be lost."
    local active_agent
    active_agent=$(_agent_current) || active_agent="generic"
    cp "$source_schema" "$CUMARU_DIR/schema.yaml"
    _agent_set "$active_agent"
    green "✓ schema.yaml replaced from source."
    return 0
  fi

  # 5a) Special targets: `skills` and `commands` bypass the .cumaru/ file merge.
  if [[ "$path_filter" == "skills" || "$path_filter" == "commands" ]]; then
    if [[ $apply -eq 0 ]]; then
      if [[ "$path_filter" == "skills" ]]; then
        local active_agent active_skills_dir
        active_agent=$(_agent_current) || return 1
        active_skills_dir=$(_agent_skills_dir "$parent" "$active_agent")
        say "Dry-run — cumaru-* skills that would be installed under ${active_skills_dir#"$parent"/}/:"
        find "$source_domain/skills" -mindepth 1 -maxdepth 1 -type d -name 'cumaru-*' 2>/dev/null \
          | while read -r d; do basename "$d"; done | sort -u | while read -r n; do
          say "  · $n"
        done
        if [[ -d "$CUMARU_DIR/skills" ]]; then
          yellow "  (will remove legacy $CUMARU_DIR/skills — skills no longer live inside .cumaru/)"
        fi
      else
        local active_agent active_commands_dir
        active_agent=$(_agent_current) || return 1
        active_commands_dir=$(_agent_commands_dir "$parent" "$active_agent")
        if [[ -z "$active_commands_dir" ]]; then
          say "Dry-run — '$active_agent' uses native skills and has no project command directory."
          say "Re-run with --apply to confirm the adapter state."
          return 0
        fi
        say "Dry-run — slash commands that would be replaced under ${active_commands_dir#"$parent"/}/:"
        find "$source_domain/commands" -name '*.md' 2>/dev/null | sort | while read -r f; do
          local rel="${f#"$source_domain/commands"/}"
          local slash="${rel%.md}"; slash="/${slash//\//:}"
          say "  · $slash"
        done
      fi
      say "Re-run with --apply to apply."
      return 0
    fi
    if [[ "$path_filter" == "skills" ]]; then
      say "Skills:"
      local _orig_skills_src="$SKILLS_SRC"
      SKILLS_SRC="$skills_src_effective"
      _framework_prune_legacy_cumaru_skills "$CUMARU_DIR"
      _framework_install_skills "$parent" "$source_domain" "1"
      _framework_prune_deprecated_cumaru_skills "$parent" "$source_domain"
      # Remove the one-shot migration skill if it exists — it's a transition
      # tool, not a recurring recipe.
      local active_agent active_skills_dir
      active_agent=$(_agent_current) || return 1
      active_skills_dir=$(_agent_skills_dir "$parent" "$active_agent")
      rm -rf "$active_skills_dir/cumaru-migrate" 2>/dev/null || true
      SKILLS_SRC="$_orig_skills_src"
    else
      say "Slash commands:"
      _framework_copy_commands "$parent" "$source_domain" "1"
      _update_report_deprecated_commands "$parent" "$source_domain"
    fi
    green "✓ Update complete."
    return 0
  fi

  # 5b) Discover both-sides candidates by walking the source framework dir.
  local rels=() rel
  while IFS= read -r rel; do
    rel="${rel#"$source_domain"/}"
    [[ "$rel" == *.bkp.* ]] && continue
    # Never feed the framework's own skills/ or commands/ subtrees into the
    # .cumaru/ file merge — those are framework-owned artifacts installed under
    # agent project dirs, handled by the dedicated helpers
    # below.
    [[ "$rel" == skills/* ]] && continue
    [[ "$rel" == commands/* ]] && continue
    # schema.yaml is also out of the mechanical merge — it mixes framework-owned
    # contracts with adopter-owned regions (meta.apps.values, locally-added
    # pillars, intentionally removed markers). Mechanical replace would silently
    # destroy customisations. Routed to the dedicated `cumaru update schema` path,
    # where the LLM adjudicates the diff against schema-aware preservation rules.
    [[ "$rel" == "schema.yaml" ]] && continue
    if [[ -n "$path_filter" ]]; then
      [[ "$rel" == "$path_filter" || "$rel" == "$path_filter"/* ]] || continue
    fi
    rels+=("$rel")
  done < <(find "$source_domain" -type f \( -name '*.md' -o -name '*.yaml' \) | sort)

  if [[ -n "$path_filter" && ${#rels[@]} -eq 0 ]]; then
    if [[ -e "$CUMARU_DIR/$path_filter" ]]; then
      red "✗ '$path_filter' is adopter-owned — no framework source exists for it, so no update applies."
      yellow "  Only files shipped in the framework starter can be updated."
    else
      red "✗ '$path_filter' matches nothing in the framework source."
    fi
    return 2
  fi

  # 6) Compute the changed set.
  local changed=()
  for rel in "${rels[@]}"; do
    local src="$source_domain/$rel" tgt="$CUMARU_DIR/$rel"
    local has_fm=0; _update_has_fm "$src" && has_fm=1
    _update_needs_attention "$src" "$tgt" "$keep_prose" "$has_fm" && changed+=("$rel")
  done

  local total=${#changed[@]}

  # 7) --apply: mechanical merge of .cumaru/ files + replace skills/commands.
  if [[ $apply -eq 1 ]]; then
    [[ $keep_prose -eq 1 ]] && yellow "⚠ --keep-prose: framework prose updates are NOT applied; the tree may diverge."

    # .cumaru/ file merge.
    if [[ $total -gt 0 ]]; then
      for rel in "${changed[@]}"; do
        local src="$source_domain/$rel" tgt="$CUMARU_DIR/$rel"
        mkdir -p "$(dirname "$tgt")"
        if [[ ! -f "$tgt" ]]; then
          cp "$src" "$tgt"; green "  ✓ created $rel"; continue
        fi
        [[ $keep_prose -eq 1 ]] && yellow "    (kept local prose) $rel"
        local has_fm=0; _update_has_fm "$src" && has_fm=1
        if _update_build_expected "$src" "$tgt" "$keep_prose" "$has_fm" > "$tgt.tmp"; then
          mv "$tgt.tmp" "$tgt" || { rm -f "$tgt.tmp"; red "  ✗ failed to replace $rel (mv error)"; continue; }
        else
          rm -f "$tgt.tmp"
          red "  ✗ failed to build merge for $rel (skipped)"
          continue
        fi
        green "  ✓ merged $rel"
      done
    else
      green "✓ .cumaru/ files already in sync."
    fi

    # Schema drift: never auto-merged. Surface it so the user knows the source
    # contract moved, and point at the dedicated path where the LLM adjudicates.
    if ! _schema_framework_contract_match "$source_schema" "$CUMARU_DIR/schema.yaml"; then
      say ""
      yellow "⚠ schema.yaml framework contract diverged from source — not auto-merged."
      yellow "  Review:  cumaru update schema"
      yellow "  Replace: cumaru update schema --apply   (destructive: loses meta.apps.values)"
    fi

    # Skills: drop any legacy .cumaru/skills/ tree, install cumaru-* directly into
    # the active adapter's skill directory, then prune deprecated artifacts.
    say ""
    say "Skills:"
    local _orig_skills_src="$SKILLS_SRC"
    SKILLS_SRC="$skills_src_effective"
    _framework_prune_legacy_cumaru_skills "$CUMARU_DIR"
    _framework_install_skills "$parent" "$source_domain" "1"
    _framework_prune_deprecated_cumaru_skills "$parent" "$source_domain"
    # Remove the one-shot migration skill if it exists.
    local active_agent active_skills_dir
    active_agent=$(_agent_current) || return 1
    active_skills_dir=$(_agent_skills_dir "$parent" "$active_agent")
    rm -rf "$active_skills_dir/cumaru-migrate" 2>/dev/null || true
    SKILLS_SRC="$_orig_skills_src"

    # Slash commands: replace from the domain source.
    say ""
    say "Slash commands:"
    _framework_copy_commands "$parent" "$source_domain" "1"

    # Deprecated commands.
    _update_report_deprecated_commands "$parent" "$source_domain"

    say ""
    green "✓ Update complete."
    return 0
  fi

  # Schema drift notice (dry-run too — surfaces even when .cumaru/ files are clean).
  local _schema_drift=0
  _schema_framework_contract_match "$source_schema" "$CUMARU_DIR/schema.yaml" || _schema_drift=1

  # 8) Default: structured per-file review (dry-run). Skills/commands not shown
  #    in dry-run — they are always replaced deterministically with --apply.
  if [[ $total -eq 0 ]]; then
    green "✓ .cumaru/ files already in sync${path_filter:+ (path: $path_filter)}."
    if [[ $_schema_drift -eq 1 ]]; then
      yellow "⚠ schema.yaml framework contract diverged from source — not auto-merged."
      yellow "  Review:  cumaru update schema"
      yellow "  Replace: cumaru update schema --apply   (destructive: loses meta.apps.values)"
    fi
    say "  Run with --apply to replace artifacts for the schema-selected agent."
    return 0
  fi

  say "═══════════════════════════════════════════════════════════════════════"
  if [[ $migration_notice -eq 1 ]]; then
    say "Update review (migration: source v${source_version:-unset}, local v${target_version:-unset}) — $total file(s) need attention"
  else
    say "Update review (v$source_version steady state) — $total file(s) need attention"
  fi
  say "═══════════════════════════════════════════════════════════════════════"
  say "Per file: framework frontmatter and prose come from canonical source;"
  say "matching marker bodies are preserved. Review the resulting contract against:"
  say "  $SCHEMA"
  [[ $keep_prose -eq 1 ]] && yellow "⚠ --keep-prose active: prose will be kept local (framework updates skipped)."
  [[ -n "$path_filter" ]] && say "Path filter: $path_filter"

  local idx=0
  for rel in "${changed[@]}"; do
    idx=$((idx + 1))
    local src="$source_domain/$rel" tgt="$CUMARU_DIR/$rel"
    local has_fm=0; _update_has_fm "$src" && has_fm=1
    _update_render "$idx" "$total" "$rel" "$src" "$tgt" "$has_fm" "$keep_prose" "$source_domain"
  done

  say "═══════════════════════════════════════════════════════════════════════"
  say "Summary — $total file(s):"
  for rel in "${changed[@]}"; do
    [[ -f "$CUMARU_DIR/$rel" ]] && say "  [merge] $rel" || say "  [new]   $rel"
  done
  say ""
  if [[ $_schema_drift -eq 1 ]]; then
    yellow "⚠ schema.yaml framework contract diverged from source — not auto-merged."
    yellow "  Review:  cumaru update schema"
    yellow "  Replace: cumaru update schema --apply   (destructive: loses meta.apps.values)"
    say ""
  fi
  say "Skills and supported slash commands will also be replaced for the schema-selected agent on --apply."
  say "Re-run with --apply to merge .cumaru/ files and replace skills/commands."
  return 0
}

# Switch the native agent integration. Dry-run by default; schema is written
# only after all target artifacts have been installed.
cmd_update_agent() {
  local requested="${1:-}" apply=0 from=""
  local CUMARU_AGENT_OVERRIDE=""
  [[ -n "$requested" ]] || {
    red "✗ usage: cumaru update agent <none|claude|codex|opencode> [--apply]"
    return 2
  }
  shift

  local target_agent
  target_agent=$(_agent_normalize "$requested") || {
    red "✗ unknown agent: $requested (expected none, claude, codex, or opencode)"
    return 2
  }

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --apply) apply=1; shift ;;
      --from)
        [[ -n "${2:-}" ]] || { red "✗ --from requires a path"; return 2; }
        from="$2"; shift 2 ;;
      -h|--help|help)
        say "Usage: cumaru update agent <none|claude|codex|opencode> [--from <checkout>] [--apply]"
        return 0 ;;
      *) red "unexpected arg: $1"; return 2 ;;
    esac
  done

  [[ -f "$SCHEMA" && -f "$CUMARU_DIR/index.md" ]] || {
    red "✗ $CUMARU_DIR is not installed"
    return 1
  }

  local source_root="${from:-$SCRIPT_DIR}"
  [[ -d "$source_root/domains" ]] || {
    red "✗ source does not look like a Cumaru checkout: $source_root"
    return 1
  }

  local domain source_domain
  domain=$(yq -r '.domain // "base"' "$SCHEMA" 2>/dev/null || true)
  source_domain="$source_root/domains/$( [[ "$domain" == "base" ]] && printf '%s' "__base" || printf '%s' "$domain" )"
  [[ -d "$source_domain" ]] || {
    red "✗ domain '$domain' not found at $source_domain"
    return 1
  }
  if [[ "$target_agent" == "opencode" ]] && ! command -v jq >/dev/null 2>&1; then
    red "✗ jq is required for the opencode adapter"
    return 1
  fi

  local current_agent parent
  current_agent=$(_agent_current) || {
    red "✗ invalid agent value in $SCHEMA"
    return 1
  }
  parent=$(dirname "$CUMARU_DIR")

  say "Agent adapter: $current_agent → $target_agent"
  _agent_describe "$parent" "$target_agent"
  if [[ $apply -eq 0 ]]; then
    say ""
    say "Dry-run only. Re-run with --apply to switch adapters."
    return 0
  fi

  CUMARU_AGENT_OVERRIDE="$target_agent"
  _agent_refresh_instructions "$parent" "$target_agent" || {
    unset CUMARU_AGENT_OVERRIDE
    red "✗ failed to install target instructions; schema was not changed"
    return 1
  }
  _framework_install_skills "$parent" "$source_domain" "1" || {
    unset CUMARU_AGENT_OVERRIDE
    red "✗ failed to install target skills; schema was not changed"
    return 1
  }
  _framework_prune_deprecated_cumaru_skills "$parent" "$source_domain"
  _framework_copy_commands "$parent" "$source_domain" "1" || {
    unset CUMARU_AGENT_OVERRIDE
    red "✗ failed to install target commands; schema was not changed"
    return 1
  }
  if [[ "$current_agent" != "$target_agent" ]]; then
    _agent_remove_adapter "$parent" "$current_agent" "$target_agent" || {
      unset CUMARU_AGENT_OVERRIDE
      red "✗ target installed, but the old adapter could not be removed; schema was not changed"
      return 1
    }
  fi
  _agent_set "$target_agent" || {
    unset CUMARU_AGENT_OVERRIDE
    red "✗ target artifacts installed, but schema state could not be written"
    return 1
  }
  unset CUMARU_AGENT_OVERRIDE

  green "✓ agent adapter switched to $target_agent"
}

_update_report_deprecated_commands() {
  local parent="$1" source_framework="$2"
  local depr_cmds=()
  while IFS= read -r rel_cmd; do
    [[ -n "$rel_cmd" ]] && depr_cmds+=("$rel_cmd")
  done < <(_framework_deprecated_commands "$parent" "$source_framework")
  [[ ${#depr_cmds[@]} -eq 0 ]] && return 0
  yellow ""
  yellow "  Deprecated commands (locally present, absent from source — review and remove manually):"
  local active_agent commands_dir
  active_agent=$(_agent_current) || return 1
  commands_dir=$(_agent_commands_dir "$parent" "$active_agent")
  local slash cmd_path
  for rel_cmd in "${depr_cmds[@]}"; do
    slash="${rel_cmd%.md}"; slash="/${slash//\//:}"
    cmd_path="$commands_dir/$rel_cmd"
    yellow "    · ${slash} ($cmd_path)"
  done
}

# Build the source file with the target's tag bodies injected. Local-only
# (orphan) blocks have no slot in the source — they are carried over VERBATIM,
# placed right after the frontmatter, per the preservation contract (the
# script never drops tag bodies; the LLM decides keep-or-remove after review).
# Args: src_file, tgt_file
_update_inject_blocks() {
  local src="$1" tgt="$2"
  local tmp; tmp=$(mktemp -d)
  local name src_tags
  src_tags=$(fm_block_list "$src")
  : > "$tmp/__orphans"
  while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    local safe="${name//:/__}"
    fm_block_extract "$tgt" "$name" > "$tmp/$safe"
    if ! grep -qxF "$name" <<< "$src_tags"; then
      { printf '<!-- cumaru:%s -->\n' "$name"
        cat "$tmp/$safe"
        printf '<!-- /cumaru:%s -->\n\n' "$name"; } >> "$tmp/__orphans"
    fi
  done < <(fm_block_list "$tgt")
  awk -v dir="$tmp" '
    function marker_line(s,    t) {
      t = s
      sub(/^[[:space:]]*(#|\/\/)?[[:space:]]*/, "", t)
      sub(/[[:space:]]+$/, "", t)
      return t
    }
    function flush_orphans(   line, path) {
      if (orphans_done) return
      orphans_done = 1
      path = dir "/__orphans"
      while ((getline line < path) > 0) print line
      close(path)
    }
    {
      ml = marker_line($0)
      if (ml ~ /^<!-- cumaru:[a-z0-9_:-]+ -->$/) {
        m = ml
        sub(/^<!-- cumaru:/, "", m); sub(/ -->$/, "", m)
        safe = m; gsub(/:/, "__", safe)
        print
        path = dir "/" safe
        while ((getline line < path) > 0) print line
        close(path)
        skip = 1
        next
      }
      if (ml ~ /^<!-- \/cumaru:[a-z0-9_:-]+ -->$/) { skip = 0 }
      if (!skip) {
        print
        # Right after the closing frontmatter fence + its blank line, slot in
        # any orphan blocks so they keep the conventional top-of-file position.
        if ($0 ~ /^---$/) { fences++ }
        else if (fences == 2 && $0 ~ /^[[:space:]]*$/) flush_orphans()
      }
    }
    END { flush_orphans() }
  ' "$src"
  rm -rf "$tmp"
}
