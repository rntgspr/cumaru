# cmd_update.sh — update an installed .cumaru/ tree from the framework source.
#
# Framework-owned Markdown is rebuilt from source. Existing tag bodies are
# captured and restored at matching markers. All content outside tags is
# canonical. Adopter-created entities without a source counterpart are untouched.
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
# Version drift is gated: local config and root versions must agree, every
# downgrade is refused, and a higher integer boundary is dry-run only.
#
# Expects from the entry-point: SCRIPT_DIR, CUMARU_DIR, AGENTS_DIR, CONFIG, QUIET,
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
  local src="$1" tgt="$2"
  # Framework-owned files are replaced wholesale. Only tag bodies are
  # adopter-owned: capture them from the local file and rehydrate them at the
  # source markers, or at the top when the source no longer has that marker.
  _update_inject_blocks "$src" "$tgt"
}

_update_needs_attention() {
  local src="$1" tgt="$2" has_fm="$3"
  [[ -f "$tgt" ]] || return 0
  local expected; expected=$(mktemp)
  if ! _update_build_expected "$src" "$tgt" > "$expected"; then
    rm -f "$expected"
    return 2
  fi
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

# Managed project surfaces committed by one logical update transaction. Whole
# adapter directories are snapshotted so adopter-owned siblings survive exactly.
_update_transaction_paths() {
  printf '%s\n' \
    .cumaru .agents .claude .codex .opencode \
    AGENTS.md CLAUDE.md opencode.json
}

_update_transaction_copy_path() {
  local root="$1" rel="$2" dest="$3"
  [[ -e "$root/$rel" || -L "$root/$rel" ]] || return 0
  mkdir -p "$dest/$(dirname "$rel")" || return 1
  cp -R "$root/$rel" "$dest/$rel"
}

_update_transaction_restore() {
  local parent="$1" backup="$2" rel rc=0
  while IFS= read -r rel; do
    rm -rf "$parent/$rel" || rc=1
    if [[ -e "$backup/$rel" || -L "$backup/$rel" ]]; then
      mkdir -p "$parent/$(dirname "$rel")" || { rc=1; continue; }
      cp -R "$backup/$rel" "$parent/$rel" || rc=1
    fi
  done < <(_update_transaction_paths)
  return $rc
}

_update_transaction_fault() {
  local phase="$1"
  [[ "${CUMARU_TEST_FAIL_PHASE:-}" != "$phase" ]] || {
    red "✗ injected update failure at phase: $phase"
    return 97
  }
}

# Execute an apply against a staged project, validate it, then publish every
# managed surface with exact rollback on any handled commit failure.
_update_transaction_apply() {
  local source_root="$1" path_filter="$2" agent_request="${3:-}"
  local parent lock txn staged backup output rel rc=0
  source_root=$(cd "$source_root" && pwd -P) || return 1
  parent=$(cd "$(dirname "$CUMARU_DIR")" && pwd -P) || return 1
  lock="$parent/.cumaru-update.lock"
  if ! mkdir "$lock" 2>/dev/null; then
    red "✗ another Cumaru update transaction is active: $lock"
    return 1
  fi
  txn=$(mktemp -d "$parent/.cumaru-update.XXXXXX") || { rmdir "$lock"; return 1; }
  staged="$txn/project"; backup="$txn/backup"; output="$txn/stage.out"
  mkdir -p "$staged" "$backup" || { rm -rf "$txn"; rmdir "$lock"; return 1; }

  while IFS= read -r rel; do
    _update_transaction_copy_path "$parent" "$rel" "$staged" || rc=1
    _update_transaction_copy_path "$parent" "$rel" "$backup" || rc=1
  done < <(_update_transaction_paths)
  if [[ $rc -ne 0 ]]; then
    red "✗ failed to snapshot update surfaces"
    rm -rf "$txn"; rmdir "$lock"; return 1
  fi
  _update_transaction_fault after-stage || { rm -rf "$txn"; rmdir "$lock"; return 97; }

  if [[ -n "$agent_request" ]]; then
    (cd "$staged" && CUMARU_TRANSACTION_STAGE=1 bash "$SCRIPT_DIR/cumaru" update agent "$agent_request" --from "$source_root" --apply) > "$output" 2>&1 || rc=$?
  fi
  if [[ $rc -eq 0 && -z "$agent_request" ]]; then
    local args=(update)
    [[ -n "$path_filter" ]] && args+=("$path_filter")
    args+=(--from "$source_root")
    args+=(--apply)
    (cd "$staged" && CUMARU_TRANSACTION_STAGE=1 bash "$SCRIPT_DIR/cumaru" "${args[@]}") >> "$output" 2>&1 || rc=$?
  fi
  if [[ $rc -eq 0 ]]; then
    (cd "$staged" && bash "$SCRIPT_DIR/cumaru" doctor --quiet) >> "$output" 2>&1 || rc=$?
  fi
  if [[ $rc -ne 0 ]]; then
    cat "$output" >&2
    red "✗ staged update failed; live project unchanged"
    rm -rf "$txn"; rmdir "$lock"; return $rc
  fi
  _update_transaction_fault after-validation || { rm -rf "$txn"; rmdir "$lock"; return 97; }

  rm -rf "$parent/.cumaru"
  cp -R "$staged/.cumaru" "$parent/.cumaru" || rc=1
  _update_transaction_fault after-tree-commit || rc=$?

  if [[ $rc -eq 0 ]]; then
    while IFS= read -r rel; do
      [[ "$rel" == ".cumaru" ]] && continue
      rm -rf "$parent/$rel" || { rc=1; break; }
      if [[ -e "$staged/$rel" || -L "$staged/$rel" ]]; then
        mkdir -p "$parent/$(dirname "$rel")" || { rc=1; break; }
        cp -R "$staged/$rel" "$parent/$rel" || { rc=1; break; }
      fi
    done < <(_update_transaction_paths)
  fi
  [[ $rc -ne 0 ]] || _update_transaction_fault after-adapter-commit || rc=$?

  if [[ $rc -ne 0 ]]; then
    red "✗ update commit failed; restoring live project"
    if ! _update_transaction_restore "$parent" "$backup"; then
      red "✗ rollback incomplete; recovery snapshot retained at $backup"
      rmdir "$lock" 2>/dev/null || true
      return 1
    fi
    rm -rf "$txn"; rmdir "$lock"
    return $rc
  fi

  cat "$output"
  rm -rf "$txn"; rmdir "$lock"
  green "✓ Transaction committed."
  return 0
}

# --- per-file structured review (dry-run) ----------------------------------

_update_render() {
  local idx="$1" total="$2" f="$3" src="$4" tgt="$5" has_fm="$6" tag_schema_root="${7:-$CUMARU_DIR}"
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
      echo "Frontmatter: ✓ keys match (canonical source values will be used)."
    else
      echo "Frontmatter: key drift (canonical source keys and values will be used):"
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
        echo "    [+] $name — present in source, absent locally → canonical scaffold will be added."
      fi
    done <<< "$src_tags"
    while IFS= read -r name; do
      [[ -z "$name" ]] && continue
      grep -qxF "$name" <<< "$src_tags" || echo "    [orphan] $name — local only, not in the framework source (kept verbatim on --apply; decide: keep or remove)."
    done <<< "$tgt_tags"
  fi

  echo
  echo "--- Diff (local → result of --apply: canonical source + preserved tag bodies) ---"
  local merged; merged=$(mktemp)
  _update_build_expected "$src" "$tgt" > "$merged"
  diff -u "$tgt" "$merged" 2>/dev/null || true
  rm -f "$merged"
  echo
}

cmd_update_help() {
  cat <<'EOF'
  cumaru update — update an installed .cumaru/ tree and explicit agent artifacts

Usage:
  cumaru update [<path>] [--from <path|git-url>] [--apply]
  cumaru update agent [<none|claude|codex|opencode>] [--apply|--clear]
  cumaru update skills [<none|claude|codex|opencode>] [--apply|--clear]
  cumaru update commands [<none|claude|codex|opencode>] [--apply|--clear]
  cumaru update config   [--from <path|git-url>]

Arguments:
  <path>         optional path filter, relative to .cumaru/. May be a directory
                 (e.g. `templates`, `specs`) to scope the .cumaru/ update to that
                 subtree, or a single file (e.g. `intake/index.md`). Adopter-
                 owned paths (no framework source counterpart) are rejected.
  skills         update ONLY framework skills for installed agent target(s).
                  Without --apply, prints a dry-run summary. With --apply, replaces
                  skills wholesale. Skips the .cumaru/ file merge and commands.
  commands       update ONLY slash commands for installed agent target(s).
                  Without --apply, prints a dry-run summary. With --apply, replaces
                  commands wholesale. Skips the .cumaru/ file merge and skills.
  config         report schema and domain-default drift for agent-led config
                 reconciliation. It never writes config.yaml.
  agent <name>   preview or transactionally apply a native agent switch.
                 `none` restores the backward-compatible `.agents/` adapter.

Options:
  --from <src>   path to a Cumaru checkout, or a git URL to clone shallowly
                 (default: the checkout this `cumaru` script was sourced from).
  --apply        rebuild framework Markdown from canonical source while
                   preserving matching tag bodies, and replace skills + slash
                   commands from one staged, validated transaction. config.yaml
                   is adopter-owned and must be changed deliberately by an agent.
                  Without it, prints a structured per-file review for the LLM.

Agent artifacts:
  Skills and supported slash commands are framework-owned artifacts addressed
  by an explicit adapter. --apply installs them; --clear removes only Cumaru
  files and never removes adapter directories.

Domain detection:
  The installed domain is read from the validated `domain:` field in
  .cumaru/config.yaml. Missing or invalid state blocks update.

Per-file model (v7):
  • Framework-owned Markdown — rebuilt from the canonical domain source.
  • Frontmatter — always taken from the canonical domain source.
  • Marker bodies — captured locally and restored at matching source markers.
  • Local-only entities — untouched because they have no source counterpart.
  • Outside-marker prose — always taken from the canonical domain source.

Version drift:
  Local config and root versions must agree. Versions are integer migration
  boundaries. A higher source value may be reviewed in dry-run, but --apply is
  refused until migration runs. Every lower source value is refused.

Examples:
  cumaru update                          dry-run from the active checkout
  cumaru update --apply                  apply the .cumaru/ merge
  cumaru update templates --apply        only update templates/
  cumaru update intake/index.md          review just one file
  cumaru update skills claude --apply    install only Claude skills
  cumaru update commands claude --apply  install only Claude slash commands
  cumaru update config                   report config drift for agent review
  cumaru update agent opencode --apply    install the complete OpenCode set
  cumaru update agent claude --clear      remove Claude-owned Cumaru files
  cumaru update agent --clear             remove every Cumaru adapter artifact

Exit codes:
  0   success
  1   validation, runtime, or transaction failure
  2   usage error
EOF
}

cmd_update() {
  if [[ "${1:-}" == "skills" || "${1:-}" == "commands" ]]; then
    local artifact_kind="$1"
    shift
    cmd_update_artifacts "$artifact_kind" "$@"
    return $?
  fi
  if [[ "${1:-}" == "agent" ]]; then
    shift
    cmd_update_agent "$@"
    return $?
  fi

  local from="" apply=0 path_filter=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --from)       from="${2:-}"; shift 2 ;;
      --apply)      apply=1; shift ;;
      help|-h|--help) cmd_update_help; return 0 ;;
      -*)           red "unknown flag: $1"; cmd_update_help; return 2 ;;
      *)
        if [[ -z "$path_filter" ]]; then path_filter="${1%/}"
        else red "unexpected arg: $1"; cmd_update_help; return 2; fi
        shift ;;
    esac
  done

  # Validate local state before source resolution or network access.
  if [[ ! -f "$CUMARU_DIR/index.md" || ! -f "$CONFIG" ]]; then
    red "✗ target $CUMARU_DIR is not an installed framework tree (missing index.md or config.yaml)"
    return 1
  fi
  if [[ "$path_filter" == "config" ]]; then
    _schema_require_runtime || return $?
    _schema_json "$CONFIG" >/dev/null || { red "✗ cannot parse config: $CONFIG"; return 1; }
  elif ! schema_validate_installed "$CONFIG" "$CUMARU_DIR/index.md"; then
    if [[ -z "$path_filter" ]]; then
      yellow "⚠ installed config is invalid under the current Cumaru configuration contract."
      yellow "→ Update stopped before source resolution or any project change."
    fi
    return 1
  fi
  local domain
  domain=$(schema_get_domain "$CONFIG") || return 1

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
  local source_schema="$source_domain/config.yaml"
  schema_validate_domain "$source_domain" "$domain" || return $?

  # 4) Integer version gate. Every different value is a migration boundary.
  local source_version source_index_version target_schema_version target_version source_schema_domain
  source_version=$(yq -r '.version // ""' "$source_schema" 2>/dev/null || true)
  source_index_version=$(yq --front-matter=extract -r '.["framework-version"] // ""' "$source_domain/index.md" 2>/dev/null || true)
  target_schema_version=$(yq -r '.version // ""' "$CONFIG" 2>/dev/null || true)
  target_version=$(yq --front-matter=extract -r '.["framework-version"] // ""' "$CUMARU_DIR/index.md" 2>/dev/null || true)
  source_schema_domain=$(yq -r '.domain // ""' "$source_schema" 2>/dev/null || true)

  if [[ -z "$target_schema_version" || "$target_schema_version" != "$target_version" ]]; then
    red "✗ local version disagreement: config is ${target_schema_version:-<unset>}, framework-version is ${target_version:-<unset>}"
    return 1
  fi
  if [[ -z "$source_version" || "$source_version" != "$source_index_version" ]]; then
    red "✗ source version disagreement: config is ${source_version:-<unset>}, framework-version is ${source_index_version:-<unset>}"
    return 1
  fi
  if [[ "$source_schema_domain" != "$domain" ]]; then
    red "✗ source domain disagreement: selected $domain, config declares ${source_schema_domain:-<unset>}"
    return 1
  fi

  local migration_notice=0
  if [[ ! "$source_version" =~ ^[0-9]+$ || ! "$target_version" =~ ^[0-9]+$ ]]; then
    red "✗ cannot determine integer framework versions"
    return 1
  fi
  if (( source_version < target_version )); then
    red "✗ refusing framework downgrade: source v$source_version, local v$target_version"
    return 1
  fi
  if (( source_version > target_version )); then
    migration_notice=1
    yellow "⚠ framework migration boundary: source v$source_version, local v$target_version"
    say "  Run: cumaru migrate --from $source_root"
    if [[ $apply -eq 1 ]]; then
      red "✗ cannot cross an integer version boundary with cumaru update --apply"
      return 1
    fi
  fi

  say "Source: $source_root (framework version ${source_version:-unset})"
  say "Target: $CUMARU_DIR (framework-version ${target_version:-unset})"
  say "Configuration reference for reconciliation: $CONFIG"
  say ""

  # Override SKILLS_SRC (opt-ins source) to point at the resolved source root
  # when --from was given. Skills and commands themselves are always sourced
  # from $source_domain — no override needed because $source_domain
  # already resolved from $source_root.
  local skills_src_effective="${source_root}/skills"
  [[ -d "$SKILLS_SRC" && "$source_root" == "$SCRIPT_DIR" ]] && skills_src_effective="$SKILLS_SRC"

  local parent
  parent=$(dirname "$CUMARU_DIR")

  # Configuration reconciliation is a read-only report. The agent, not the
  # CLI, adjudicates adopter-owned choices and edits config.yaml deliberately.
  if [[ "$path_filter" == "config" ]]; then
    local plan_dir plan_file merged_file removed
    plan_dir=$(mktemp -d); plan_file="$plan_dir/plan.json"; merged_file="$plan_dir/config.yaml"
    config_reconcile_plan "$source_schema" "$CONFIG" "$plan_file" || { rm -rf "$plan_dir"; return 1; }
    jq '.value' "$plan_file" | yq -P > "$merged_file" || {
      rm -rf "$plan_dir"; return 1;
    }
    schema_validate_file "$merged_file" "$domain" || {
      rm -rf "$plan_dir"; return 1;
    }
    removed=$(jq -r '.removed[] | "  \(.path): \(.reason)"' "$plan_file")
    if [[ -n "$removed" ]]; then
      yellow "Properties removed as incompatible with the global model:"
      printf '%s\n' "$removed"
    fi
    say "Configuration drift (local → candidate for agent review):"
    diff -u "$CONFIG" "$merged_file" 2>/dev/null || true
    rm -rf "$plan_dir"
    say "Schema: $CUMARU_SCHEMA_METAMODEL"
    say "Source defaults: $source_schema"
    say "→ Review the candidate and edit $CONFIG deliberately; Cumaru will not apply it."
    if [[ $apply -eq 1 ]]; then
      red "✗ config reconciliation is agent-led; --apply is not supported for config"
      return 2
    fi
    return 0
  fi

  if [[ $apply -eq 1 && "${CUMARU_TRANSACTION_STAGE:-0}" != "1" ]]; then
    _update_transaction_apply "$source_root" "$path_filter"
    return $?
  fi

  # 5) Discover both-sides candidates by walking the source framework dir.
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
    # migration.md is delivered by `cumaru migrate` straight from the CLI
    # checkout and is deliberately never copied into an adopter tree — it is a
    # rolling document replaced on every upgrade, not installed state.
    [[ "$rel" == "migration.md" ]] && continue
    # config.yaml is reconciled only by the dedicated config target.
    [[ "$rel" == "config.yaml" ]] && continue
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
    if _update_needs_attention "$src" "$tgt" "$has_fm"; then
      changed+=("$rel")
    elif [[ $? -eq 2 ]]; then
      red "✗ cannot build expected content for $rel"
      return 1
    fi
  done

  local total=${#changed[@]}

  # 7) --apply: merge .cumaru/ files. Adapter artifacts are explicit targets.
  if [[ $apply -eq 1 ]]; then
    # .cumaru/ file merge.
    if [[ $total -gt 0 ]]; then
      for rel in "${changed[@]}"; do
        local src="$source_domain/$rel" tgt="$CUMARU_DIR/$rel"
        mkdir -p "$(dirname "$tgt")"
        if [[ ! -f "$tgt" ]]; then
          cp "$src" "$tgt"; green "  ✓ created $rel"; continue
        fi
        local has_fm=0; _update_has_fm "$src" && has_fm=1
        if _update_build_expected "$src" "$tgt" > "$tgt.tmp"; then
          mv "$tgt.tmp" "$tgt" || { rm -f "$tgt.tmp"; red "  ✗ failed to replace $rel (mv error)"; continue; }
        else
          rm -f "$tgt.tmp"
          red "  ✗ failed to build merge for $rel"
          return 1
        fi
        green "  ✓ merged $rel"
      done
    else
      green "✓ .cumaru/ files already in sync."
    fi

    if [[ -n "$path_filter" ]]; then
      green "✓ Scoped update complete."
      return 0
    fi

    say ""
    green "✓ Update complete."
    return 0
  fi

  # 8) Default: structured per-file review (dry-run). Skills/commands not shown
  #    in dry-run — they are always replaced deterministically with --apply.
  if [[ $total -eq 0 ]]; then
    green "✓ .cumaru/ files already in sync${path_filter:+ (path: $path_filter)}."
    [[ -z "$path_filter" ]] && say "  Configuration reconciliation is agent-led; inspect it with: cumaru update config"
    say "  Use 'cumaru update skills <agent>' or 'cumaru update commands <agent>' for adapter artifacts."
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
  say "matching tag bodies are preserved. Review the resulting contract against:"
  say "  $CONFIG"
  [[ -n "$path_filter" ]] && say "Path filter: $path_filter"

  local idx=0
  for rel in "${changed[@]}"; do
    idx=$((idx + 1))
    local src="$source_domain/$rel" tgt="$CUMARU_DIR/$rel"
    local has_fm=0; _update_has_fm "$src" && has_fm=1
    _update_render "$idx" "$total" "$rel" "$src" "$tgt" "$has_fm" "$source_domain"
  done

  say "═══════════════════════════════════════════════════════════════════════"
  say "Summary — $total file(s):"
  for rel in "${changed[@]}"; do
    [[ -f "$CUMARU_DIR/$rel" ]] && say "  [merge] $rel" || say "  [new]   $rel"
  done
  say ""
  if [[ -z "$path_filter" ]]; then
    say "Adapter artifacts are explicit: cumaru update skills|commands <agent> [--apply]."
    say "Configuration reconciliation is agent-led: cumaru update config."
  else
    say "A scoped --apply changes only the selected .cumaru/ path."
  fi
  say "Re-run with --apply to merge .cumaru/ files."
  return 0
}

# Refresh one explicitly named agent artifact surface. No config value is read
# or written: the command line is the sole routing input.
cmd_update_artifacts() {
  local kind="$1" requested="${2:-}" apply=0 clear=0 from=""
  shift
  if [[ "${1:-}" != --* && -n "${1:-}" ]]; then requested="$1"; shift; else requested=""; fi
  local agent
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --apply) apply=1; shift ;;
      --clear) clear=1; shift ;;
      --from) from="${2:-}"; [[ -n "$from" ]] || return 2; shift 2 ;;
      *) red "unexpected arg: $1"; return 2 ;;
    esac
  done
  if [[ -z "$requested" && $clear -eq 0 ]]; then
    red "✗ cumaru update $kind --apply requires an explicit agent"
    return 2
  fi
  if [[ -n "$requested" ]]; then
    agent=$(_agent_normalize "$requested") || { red "✗ unknown agent: $requested"; return 2; }
  fi
  [[ -f "$CONFIG" && -f "$CUMARU_DIR/index.md" ]] || { red "✗ $CUMARU_DIR is not installed"; return 1; }
  schema_validate_installed "$CONFIG" "$CUMARU_DIR/index.md" || return $?
  local parent
  parent=$(dirname "$CUMARU_DIR")
  if [[ $clear -eq 1 ]]; then
    if [[ -z "$requested" ]]; then
      for agent in generic claude codex opencode; do _agent_remove_adapter "$parent" "$agent" "" || return 1; done
      _agent_remove_skills_at "$parent/.agents/skills"
    elif [[ "$kind" == skills ]]; then
      _agent_remove_skills_at "$(_agent_skills_dir "$parent" "$agent")"
    else
      local commands_dir
      commands_dir=$(_agent_commands_dir "$parent" "$agent")
      if [[ -n "$commands_dir" && -d "$commands_dir/cumaru" ]]; then
        local command_file
        while IFS= read -r -d '' command_file; do rm -f "$command_file" || return 1; done < <(find "$commands_dir/cumaru" -type f -name '*.md' -print0)
      fi
    fi
    green "✓ Cleared Cumaru $kind artifacts${requested:+ for $agent}."
    return 0
  fi
  if [[ "$kind" == "commands" && "$agent" == "codex" ]]; then
    red "✗ codex does not support a project slash-command directory; use native skills"
    return 1
  fi
  local source_root="${from:-$SCRIPT_DIR}" domain source_domain
  domain=$(schema_get_domain "$CONFIG") || return 1
  source_domain="$source_root/domains/$( [[ "$domain" == base ]] && printf '%s' __base || printf '%s' "$domain" )"
  [[ -d "$source_domain" ]] || { red "✗ source domain not found: $source_domain"; return 1; }
  _agent_describe "$parent" "$agent"
  if [[ $apply -eq 0 ]]; then
    say "Dry-run only. Re-run with --apply to replace Cumaru $kind for $agent."
    return 0
  fi
  local CUMARU_AGENT_OVERRIDE="$agent"
  if [[ "$kind" == skills ]]; then
    _framework_install_skills "$parent" "$source_domain" 1 || return 1
    _framework_prune_deprecated_cumaru_skills "$parent" "$source_domain"
  else
    _framework_copy_commands "$parent" "$source_domain" 1 || return 1
  fi
  green "✓ Updated $kind for $agent."
}

# Install or clear one complete native adapter footprint without config state.
cmd_update_agent() {
  local requested="${1:-}" clear=0 apply=0
  [[ "$requested" == --* ]] && requested=""
  [[ -n "$requested" ]] && shift
  for arg in "$@"; do
    [[ "$arg" == --clear ]] && clear=1
    [[ "$arg" == --apply ]] && apply=1
  done
  if [[ -z "$requested" && $clear -eq 0 ]]; then red "✗ cumaru update agent --apply requires an explicit agent"; return 2; fi
  local parent; parent=$(dirname "$CUMARU_DIR")
  if [[ $clear -eq 1 ]]; then
    if [[ -z "$requested" ]]; then
      for a in generic claude codex opencode; do _agent_remove_adapter "$parent" "$a" "" || return 1; done
      _agent_remove_skills_at "$parent/.agents/skills"
    else local a; a=$(_agent_normalize "$requested") || return 2; _agent_remove_adapter "$parent" "$a" "" || return 1; fi
    green "✓ Cleared Cumaru agent artifacts${requested:+ for $requested}."; return 0
  fi
  if [[ $apply -eq 0 ]]; then
    say "Dry-run only. Re-run with --apply to install complete artifacts for $requested."
    return 0
  fi
  if [[ "${CUMARU_TRANSACTION_STAGE:-0}" != "1" ]]; then
    _update_transaction_apply "$SCRIPT_DIR" "" "$requested"
    return $?
  fi
  cmd_update_artifacts skills "$requested" --apply || return $?
  [[ "$requested" == codex ]] || cmd_update_artifacts commands "$requested" --apply || return $?
  local a; a=$(_agent_normalize "$requested") || return 2
  _agent_refresh_instructions "$parent" "$a" || return 1
  green "✓ Updated complete agent artifacts for $a."
}

# Build the source file with the target's tag bodies injected. Local-only
# (orphan) tags have no slot in the source — they are carried over,
# placed right after the frontmatter, per the preservation contract (the
# script never drops tag bodies; the LLM decides keep-or-remove after review).
# Args: src_file, tgt_file
_update_inject_blocks() {
  fm_block_merge "$1" "$2"
}
