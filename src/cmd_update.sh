# cmd_update.sh — update an installed .cumaru/ tree from the framework source.
#
# Three regions per file (v4 model):
#   1. frontmatter  — adopter VALUES are kept verbatim; key drift is reported so
#                     the LLM can reconcile against schema.yaml.
#   2. tag bodies   — `<!-- cumaru:NAME -->` blocks: local body is preserved; a
#                     marker present in source but absent locally is added empty.
#                     Every body is a [Link, Description] table (hardcoded shape);
#                     bodies are never rewritten mechanically.
#   3. prose        — everything else: taken FROM SOURCE by default (framework
#                     rules land here). `--keep-prose` keeps the adopter's prose
#                     with a per-file warning that the tree may diverge.
#
# "Both-sides" files only: every file shipped in the framework starter that
# also exists locally is updated; a starter file absent locally is created;
# adopter-created entities (intake/<KEY>/, plans/<PLAN-ID>/, specs/<area>/…)
# have no source counterpart and are left untouched.
#
# Skills, hooks, and slash commands:
#   Updated deterministically — sources in the dot-llm checkout replace the
#   installed copies wholesale (no adopter customisation is expected here;
#   these are framework-owned artifacts). Deprecated commands/hooks (present
#   locally but absent from the source) are listed for review but NOT removed.
#
# Version drift: if the source `version:` differs from the local
# `framework-version:`, this is a MIGRATION. Dry-run surfaces that fact; --apply
# still applies the requested update so migration work is not blocked.
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

  if [[ "$keep_prose" == "1" ]]; then
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

  local injected; injected=$(mktemp)
  _update_inject_blocks "$src" "$tgt" > "$injected"
  if [[ "$has_fm" == "1" ]] && _update_has_fm "$tgt"; then
    _update_fm_region "$tgt"
    _update_body_after_fm "$injected"
  else
    cat "$injected"
  fi
  rm -f "$injected"
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
  local idx="$1" total="$2" f="$3" src="$4" tgt="$5" has_fm="$6" keep_prose="$7"
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

  local src_tags tgt_tags name
  src_tags=$(fm_block_list "$src")
  tgt_tags=$(fm_block_list "$tgt")
  if [[ -n "$src_tags$tgt_tags" ]]; then
    echo "Tags (v4 — every body is a [Link, Description] table; rows preserved):"
    while IFS= read -r name; do
      [[ -z "$name" ]] && continue
      if grep -qxF "$name" <<< "$tgt_tags"; then
        if _update_tag_is_empty "$tgt" "$name"; then
          echo "    [?] $name — local block is empty; add [Link, Description] rows."
        elif _update_tag_is_table "$tgt" "$name"; then
          echo "    [=] $name — body preserved."
        else
          echo "    [Δ] $name — local body is NOT a markdown table; v4 expects [Link, Description]. Reshape to the canonical table form."
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
  echo "--- Diff (local → result of --apply: prose from source, bodies + frontmatter kept) ---"
  local merged; merged=$(mktemp)
  _update_build_expected "$src" "$tgt" "$keep_prose" "$has_fm" > "$merged"
  diff -u "$tgt" "$merged" 2>/dev/null || true
  rm -f "$merged"
  echo
}

cmd_update_help() {
  cat <<'EOF'
cumaru update — update an installed .cumaru/ tree + skills + hooks + slash commands

Usage:
  cumaru update [<path>] [--from <path|git-url>] [--keep-prose] [--apply]
  cumaru update skills   [--from <path|git-url>] [--apply]
  cumaru update hooks    [--from <path|git-url>] [--apply]
  cumaru update commands [--from <path|git-url>] [--apply]
  cumaru update schema   [--from <path|git-url>] [--apply]

Arguments:
  <path>         optional path filter, relative to .cumaru/. May be a directory
                 (e.g. `templates`, `specs`) to scope the .cumaru/ update to that
                 subtree, or a single file (e.g. `intake/index.md`). Adopter-
                 owned paths (no framework source counterpart) are rejected.
  skills         update ONLY framework skills for installed agent target(s).
                  Without --apply, prints a dry-run summary. With --apply, replaces
                  skills wholesale. Skips the .cumaru/ file merge, hooks, and commands.
  hooks          update ONLY framework hooks inside .agents/hooks/.
                  Without --apply, prints a dry-run summary. With --apply, replaces
                  hook files wholesale. Skips the .cumaru/ file merge, skills, and commands.
  commands       update ONLY slash commands for installed agent target(s).
                  Without --apply, prints a dry-run summary. With --apply, replaces
                  commands wholesale. Skips the .cumaru/ file merge, skills, and hooks.
  schema         review or replace .cumaru/schema.yaml. Never auto-merged by the
                 general `cumaru update` (mixes framework-owned contracts with
                 adopter-owned regions like `meta.apps.values`). Without --apply,
                 prints a raw `diff -u` for the LLM to adjudicate, listing the
                 adopter-owned regions to preserve. With --apply, OVERWRITES the
                 local schema with the source — destructive on purpose.

Options:
  --from <src>   path to a dot-llm checkout, or a git URL to clone shallowly
                 (default: the checkout this `cumaru` script was sourced from).
  --keep-prose   keep the adopter's prose instead of taking it from the source.
                 Prints a per-file warning when framework prose is skipped.
  --apply        apply the merge mechanically (preserve frontmatter values and
                 tag bodies, take prose from source, add missing markers) AND
                  replace skills + hooks + slash commands from the source.
                  Without it, prints a structured per-file review for the LLM.

Skills, hooks, and commands (always applied with --apply, never in general dry-run):
  Skills and slash commands are framework-owned artifacts installed under
  .agents/. Hooks also live under .agents/hooks/. --apply replaces them
  wholesale from the source checkout. Deprecated commands/hooks (locally
  present, absent from source) are listed but NOT removed — remove them
  manually after review.

Domain detection:
  The installed domain is read from the `domain:` field in .cumaru/schema.yaml
  (written there at install time). Falls back to `base` if absent.

Per-file model (v4):
  • Frontmatter — adopter values are kept verbatim; only key drift is reported.
  • Tag bodies  — local body preserved; a marker missing locally is added empty.
                  v4: every body is a [Link, Description] table — local bodies
                  that don't match the table shape are flagged for reshape.
                  Bodies are never rewritten mechanically.
  • Prose       — taken FROM SOURCE by default (--keep-prose to retain local).

Version drift:
  If the source `version:` differs from the local `framework-version:`, this is
  a MIGRATION. Dry-run surfaces the migration procedure; --apply still applies
  the requested update.

Examples:
  cumaru update                          dry-run from the active checkout
  cumaru update --apply                  apply the merge + replace skills/hooks/commands
  cumaru update templates --apply        only update templates/
  cumaru update intake/index.md          review just one file
  cumaru update --keep-prose --apply     apply, but keep local prose (warns)
  cumaru update skills                   dry-run: show which skills would change
  cumaru update skills --apply           replace only skills
  cumaru update hooks                    dry-run: show which hooks would change
  cumaru update hooks --apply            replace only hooks
  cumaru update commands                 dry-run: show which commands would change
  cumaru update commands --apply         replace only slash commands
  cumaru update schema                   diff source schema vs local for LLM review
  cumaru update schema --apply           OVERWRITE local schema (destructive)
EOF
}

# Reconcile the hook block in AGENTS.md and/or CLAUDE.md. On --apply,
# replaces a legacy DOT-LLM-HOOK marker with CUMARU-HOOK, or adds it
# if absent. Idempotent.
_update_reconcile_agent_hook() {
  local parent="$1" apply="$2"
  local rel_index="$CUMARU_DIR/index.md"
  local candidates=( "$parent/$AGENTS_DIR/AGENTS.md" "$parent/CLAUDE.md" )
  local any=0

  for instructions in "${candidates[@]}"; do
    local name; name=$(basename "$instructions")
    [[ ! -f "$instructions" ]] && continue

    if grep -q "BEGIN CUMARU-HOOK" "$instructions"; then
      say "  $name hook: CUMARU-HOOK (ok)"
      any=1
      continue
    fi

    if grep -q "BEGIN DOT-LLM-HOOK" "$instructions"; then
      if [[ $apply -eq 1 ]]; then
        _update_replace_legacy_hook "$instructions" "$rel_index"
        green "  ✓ $name: replaced DOT-LLM-HOOK → CUMARU-HOOK"
      else
        yellow "  ⚠ $name: uses legacy DOT-LLM-HOOK (will be updated on --apply)"
      fi
      any=1
      continue
    fi
  done

  if [[ $any -eq 0 ]]; then
    if [[ $apply -eq 1 ]]; then
      _install_wire_agent_hook "$parent"
    else
      say "  Agent hook: absent in AGENTS.md / CLAUDE.md (will be created on --apply)"
    fi
  fi
}

# Replace a legacy DOT-LLM-HOOK block in AGENTS.md with the current
# CUMARU-HOOK block. Uses awk to find and strip the old block, then
# appends the new block.
_update_replace_legacy_hook() {
  local file="$1" rel_index="$2"
  local tmp; tmp=$(mktemp)
  awk '
    { lines[NR] = $0 }
    END {
      b = 0; e = 0
      for (i = 1; i <= NR; i++) {
        if (lines[i] ~ /BEGIN (CUMARU|DOT-LLM)-HOOK/) b = i
        if (lines[i] ~ /END (CUMARU|DOT-LLM)-HOOK/)   e = i
      }
      if (b == 0 || e == 0) { for (i = 1; i <= NR; i++) print lines[i]; exit }
      drop = (b > 1 && lines[b-1] ~ /^[[:space:]]*$/) ? b - 1 : 0
      for (i = 1; i <= NR; i++) {
        if (i >= b && i <= e) continue
        if (i == drop)        continue
        print lines[i]
      }
      print ""
    }
  ' "$file" > "$tmp"
  _cumaru_hook_block "$rel_index" "0" >> "$tmp"
  mv "$tmp" "$file"
}

cmd_update() {
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

  # Resolve domain from the installed schema.yaml.
  local domain
  domain=$(awk '/^domain:[[:space:]]/ {print $2; exit}' "$SCHEMA" 2>/dev/null || true)
  : "${domain:=base}"

  # 1) Resolve source root (the dot-llm checkout).
  local source_root tmpdir=""
  if [[ -z "$from" ]]; then
    if [[ -f "$SCRIPT_DIR/cumaru" && -d "$SCRIPT_DIR/frameworks" ]]; then
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
  # Use RETURN instead of EXIT so the trap fires when this function returns,
  # not when the whole process exits. EXIT traps are global — a second call
  # to cmd_update would overwrite the first trap, leaking the first tmpdir.
  # RETURN traps are scoped to the current function invocation.
  [[ -n "$tmpdir" ]] && trap 'rm -rf "$tmpdir"' RETURN

    if [[ ! -f "$source_root/cumaru" || ! -d "$source_root/frameworks" ]]; then
    red "✗ source $source_root does not look like a dot-llm checkout (need cumaru and frameworks/)"
    return 1
  fi

  # 2) Resolve source domain.
  local source_framework
  source_framework="$source_root/frameworks/$( [[ "$domain" == "base" ]] && echo "__base" || echo "$domain" )"
  if [[ ! -d "$source_framework" ]]; then
    red "✗ domain '$domain' not found at $source_framework"
    return 1
  fi
  local source_schema="$source_framework/schema.yaml"

  # 3) Pre-flight: target must be installed.
  if [[ ! -f "$CUMARU_DIR/index.md" || ! -f "$SCHEMA" ]]; then
    red "✗ target $CUMARU_DIR is not an installed framework tree (missing index.md or schema.yaml)"
    return 1
  fi

  # 4) Version drift notice.
  local source_version target_version
  source_version=$(awk '/^version:[[:space:]]/ {print $2; exit}' "$source_schema")
  target_version=$(awk '/^---$/{c++; if(c==2) exit; next} c==1 && /^framework-version:[[:space:]]/ {print $2; exit}' "$CUMARU_DIR/index.md")
  local migration_notice=0
  if [[ -z "$source_version" || -z "$target_version" ]]; then
    migration_notice=1
    yellow "⚠ cannot determine the framework version on both sides — treating this as a migration review."
    yellow "  source framework version: ${source_version:-<unset> ($source_schema)}"
    yellow "  local framework-version:  ${target_version:-<unset> ($CUMARU_DIR/index.md)}"
    say ""
    say "Dry-run continues so the LLM can inspect the update. Re-run with --apply"
    say "to apply the requested update, then reconcile framework-version and any"
    say "migration-specific changes using the cumaru-update skill."
    say ""
  elif [[ "$source_version" != "$target_version" ]]; then
    migration_notice=1
    yellow "⚠ version mismatch — this is a MIGRATION."
    yellow "  source framework version: $source_version"
    yellow "  local framework-version:  $target_version"
    say ""
    say "Dry-run continues so the LLM can inspect the update. Re-run with --apply"
    say "to apply the requested update."
    say ""
    say "Migration guidance: open the cumaru-update skill at"
    say "  .agents/skills/cumaru-update/SKILL.md"
    say "and follow the '## Migration to v${source_version:-the source version} (from any earlier version)' section."
    say "That section is the source of truth for follow-up reconciliation."
    say ""
  fi

  say "Source: $source_root (framework version ${source_version:-unset})"
  say "Target: $CUMARU_DIR (framework-version ${target_version:-unset})"
  say "Schema reference for reconciliation: $SCHEMA"
  say ""

  # Override SKILLS_SRC (opt-ins source) to point at the resolved source root
  # when --from was given. Skills, hooks, and commands themselves are always sourced
  # from $source_framework — no override needed because $source_framework
  # already resolved from $source_root.
  local skills_src_effective="${source_root}/skills"
  [[ -d "$SKILLS_SRC" && "$source_root" == "$SCRIPT_DIR" ]] && skills_src_effective="$SKILLS_SRC"

  local parent
  parent=$(dirname "$CUMARU_DIR")

  # 5) Reconcile the AGENTS.md hook block — first thing because it's the
  #    agent's entry point to the framework. Accepts both CUMARU-HOOK and
  #    the legacy DOT-LLM-HOOK marker for backward compat.
  _update_reconcile_agent_hook "$parent" "$apply"

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
    cp "$source_schema" "$CUMARU_DIR/schema.yaml"
    green "✓ schema.yaml replaced from source."
    return 0
  fi

  # 5a) Special targets: `skills`, `hooks`, and `commands` bypass the .cumaru/ file merge.
  if [[ "$path_filter" == "skills" || "$path_filter" == "hooks" || "$path_filter" == "commands" ]]; then
    if [[ $apply -eq 0 ]]; then
      if [[ "$path_filter" == "skills" ]]; then
        say "Dry-run — cumaru-* skills that would be installed under $AGENTS_DIR/skills/:"
        find "$source_framework/skills" -mindepth 1 -maxdepth 1 -type d -name 'cumaru-*' 2>/dev/null \
          | while read -r d; do basename "$d"; done | sort -u | while read -r n; do
          say "  · $n"
        done
        if [[ -d "$CUMARU_DIR/skills" ]]; then
          yellow "  (will remove legacy $CUMARU_DIR/skills — skills no longer live inside .cumaru/)"
        fi
      elif [[ "$path_filter" == "hooks" ]]; then
        say "Dry-run — hooks that would be replaced in $AGENTS_DIR/hooks/"
        find "$source_framework/hooks" -type f 2>/dev/null | sort | while read -r f; do
          local rel="${f#"$source_framework/hooks"/}"
          say "  · $rel"
        done
        _update_report_deprecated_hooks "$source_framework"
      else
        say "Dry-run — slash commands that would be replaced under $AGENTS_DIR/commands/:"
        find "$source_framework/commands" -name '*.md' 2>/dev/null | sort | while read -r f; do
          local rel="${f#"$source_framework/commands"/}"
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
      _framework_install_skills "$parent" "$source_framework" "1"
      _framework_prune_deprecated_cumaru_skills "$parent" "$source_framework"
      # Remove the one-shot migration skill if it exists — it's a transition
      # tool, not a recurring recipe.
      rm -rf "$AGENTS_DIR/skills/cumaru-migrate" 2>/dev/null || true
      SKILLS_SRC="$_orig_skills_src"
    elif [[ "$path_filter" == "hooks" ]]; then
      say "Hooks:"
      _update_copy_hooks "$source_framework"
      _update_report_deprecated_hooks "$source_framework"
    else
      say "Slash commands:"
      _framework_copy_commands "$parent" "$source_framework" "1"
      _update_report_deprecated_commands "$parent" "$source_framework"
    fi
    green "✓ Update complete."
    return 0
  fi

  # 5b) Discover both-sides candidates by walking the source framework dir.
  local rels=() rel
  while IFS= read -r rel; do
    rel="${rel#"$source_framework"/}"
    [[ "$rel" == *.bkp.* ]] && continue
    # Never feed the framework's own skills/, hooks/, or commands/ subtrees into the
    # .cumaru/ file merge — those are framework-owned artifacts installed under
    # agent project dirs, handled by the dedicated helpers
    # below.
    [[ "$rel" == skills/* ]] && continue
    [[ "$rel" == hooks/* ]] && continue
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
  done < <(find "$source_framework" -type f \( -name '*.md' -o -name '*.yaml' \) | sort)

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
    local src="$source_framework/$rel" tgt="$CUMARU_DIR/$rel"
    local has_fm=0; _update_has_fm "$src" && has_fm=1
    _update_needs_attention "$src" "$tgt" "$keep_prose" "$has_fm" && changed+=("$rel")
  done

  local total=${#changed[@]}

  # 7) --apply: mechanical merge of .cumaru/ files + replace skills/hooks/commands.
  if [[ $apply -eq 1 ]]; then
    [[ $keep_prose -eq 1 ]] && yellow "⚠ --keep-prose: framework prose updates are NOT applied; the tree may diverge."

    # .cumaru/ file merge.
    if [[ $total -gt 0 ]]; then
      for rel in "${changed[@]}"; do
        local src="$source_framework/$rel" tgt="$CUMARU_DIR/$rel"
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
    # .agents/skills/, prune deprecated.
    say ""
    say "Skills:"
    local _orig_skills_src="$SKILLS_SRC"
    SKILLS_SRC="$skills_src_effective"
    _framework_prune_legacy_cumaru_skills "$CUMARU_DIR"
    _framework_install_skills "$parent" "$source_framework" "1"
    _framework_prune_deprecated_cumaru_skills "$parent" "$source_framework"
    # Remove the one-shot migration skill if it exists.
    rm -rf "$AGENTS_DIR/skills/cumaru-migrate" 2>/dev/null || true
    SKILLS_SRC="$_orig_skills_src"

    # Hooks: replace from the domain source into .agents/hooks/.
    say ""
    say "Hooks:"
    _update_copy_hooks "$source_framework"
    _update_report_deprecated_hooks "$source_framework"

    # Slash commands: replace from the domain source.
    say ""
    say "Slash commands:"
    _framework_copy_commands "$parent" "$source_framework" "1"

    # Deprecated commands.
    _update_report_deprecated_commands "$parent" "$source_framework"

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
    say "  Run with --apply to replace skills, hooks, and slash commands from the source under $AGENTS_DIR/."
    return 0
  fi

  say "═══════════════════════════════════════════════════════════════════════"
  if [[ $migration_notice -eq 1 ]]; then
    say "Update review (migration: source v${source_version:-unset}, local v${target_version:-unset}) — $total file(s) need attention"
  else
    say "Update review (v$source_version steady state) — $total file(s) need attention"
  fi
  say "═══════════════════════════════════════════════════════════════════════"
  say "Per file: frontmatter values are kept; tag bodies are preserved (every"
  say "block is a [Link, Description] table); prose comes from source. Reconcile"
  say "reported frontmatter key drift against:"
  say "  $SCHEMA"
  [[ $keep_prose -eq 1 ]] && yellow "⚠ --keep-prose active: prose will be kept local (framework updates skipped)."
  [[ -n "$path_filter" ]] && say "Path filter: $path_filter"

  local idx=0
  for rel in "${changed[@]}"; do
    idx=$((idx + 1))
    local src="$source_framework/$rel" tgt="$CUMARU_DIR/$rel"
    local has_fm=0; _update_has_fm "$src" && has_fm=1
    _update_render "$idx" "$total" "$rel" "$src" "$tgt" "$has_fm" "$keep_prose"
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
  say "Skills, hooks, and slash commands will also be replaced from the source on --apply under $AGENTS_DIR/."
  say "Re-run with --apply to merge .cumaru/ files and replace skills/hooks/commands."
  return 0
}

# Copy framework-owned hook files into .agents/hooks/.
_update_copy_hooks() {
  local source_framework="$1"
  local hooks_src="$source_framework/hooks"
  if [[ ! -d "$hooks_src" ]]; then
    yellow "  · no hooks/ directory in source framework (skip)"
    return 0
  fi

  local hook_files=() hook_file
  while IFS= read -r -d '' hook_file; do
    hook_files+=("$hook_file")
  done < <(find "$hooks_src" -type f -print0)
  [[ ${#hook_files[@]} -eq 0 ]] && { yellow "  · no hook files in source framework (skip)"; return 0; }

  local parent rel dest
  parent=$(dirname "$CUMARU_DIR")
  for hook_file in "${hook_files[@]}"; do
    rel="${hook_file#"$hooks_src"/}"
    dest="$parent/$AGENTS_DIR/hooks/$rel"
    mkdir -p "$(dirname "$dest")"
    cp "$hook_file" "$dest"
    chmod --reference="$hook_file" "$dest" 2>/dev/null || chmod +x "$dest" 2>/dev/null || true
    green "  ↺ $AGENTS_DIR/hooks/$rel"
  done
}

# Report installed hook files that no longer exist in the source framework.
_update_report_deprecated_hooks() {
  local source_framework="$1"
  local hooks_src="$source_framework/hooks"
  local parent
  parent=$(dirname "$CUMARU_DIR")
  local hooks_dir="$parent/$AGENTS_DIR/hooks"
  [[ -d "$hooks_dir" ]] || return 0
  [[ -d "$hooks_src" ]] || return 0

  local any=0 file rel
  while IFS= read -r -d '' file; do
    rel="${file#"$hooks_dir"/}"
    [[ -f "$hooks_src/$rel" ]] && continue
    if [[ $any -eq 0 ]]; then
      yellow ""
      yellow "  Deprecated hooks (locally present, absent from source — review and remove manually):"
      any=1
    fi
    yellow "    · $AGENTS_DIR/hooks/$rel ($file)"
  done < <(find "$hooks_dir" -type f -print0)
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
  local commands_dir="$parent/$AGENTS_DIR/commands"
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
