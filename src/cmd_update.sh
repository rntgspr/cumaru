# cmd_update.sh — update an installed .llm/ tree from the framework source.
#
# Three regions per file (v3 model):
#   1. frontmatter  — adopter VALUES are kept verbatim; key drift is reported so
#                     the LLM can reconcile against schema.yaml.
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
# also exists locally is updated; a starter file absent locally is created;
# adopter-created entities (intake/<KEY>/, plans/<PLAN-ID>/, specs/<area>/…)
# have no source counterpart and are left untouched.
#
# Skills and slash commands:
#   Updated deterministically — sources in the dot-llm checkout replace the
#   installed copies wholesale (no adopter customisation is expected here;
#   skills/commands are framework-owned artifacts). Deprecated items (present
#   locally but absent from the source) are listed for review but NOT removed.
#
# Version gate: if the source `version:` differs from the local
# `framework-version:`, this is a MIGRATION, not an update. The command refuses
# and points to the llm-cli skill's migration procedure.
#
# Expects from the entry-point: SCRIPT_DIR, DOT_LLM_DIR, SCHEMA, QUIET,
# SKILLS_SRC, COMMANDS_SRC, and the _framework_copy_skills /
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

_update_tag_header() {
  fm_block_extract "$1" "$2" | awk 'NF && /^[[:space:]]*\|/ { print; exit }'
}

_update_tag_is_table() {
  [[ -n "$(_update_tag_header "$1" "$2")" ]]
}

_update_tag_kind() {
  local body; body=$(fm_block_extract "$1" "$2")
  if [[ -z "${body//[[:space:]]/}" ]]; then echo empty; return; fi
  if printf '%s\n' "$body" | grep -qE '^[[:space:]]*\|'; then echo table; return; fi
  if printf '%s\n' "$body" | awk '
       /^[[:space:]]*$/                          { next }
       /^[[:space:]]*-[[:space:]]+`[^`]+`/        { seen=1; next }
       { bad=1; exit }
       END { exit !(seen && !bad) }
     '; then echo path-list; return; fi
  local non_blank
  non_blank=$(printf '%s\n' "$body" | grep -cE '^[[:space:]]*[^[:space:]]' || true)
  if [[ "$non_blank" -eq 1 ]] && \
     printf '%s\n' "$body" | grep -qE '^[[:space:]]*-?[0-9]+(\.[0-9]+)?[[:space:]]*$'; then
    echo number; return
  fi
  echo prose
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
    fm_block_list "$tgt" | grep -qxF "$name" || continue
    if _update_tag_is_table "$src" "$name" && \
       [[ "$(_update_tag_header "$src" "$name")" != "$(_update_tag_header "$tgt" "$name")" ]]; then
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
    echo "Tags:"
    while IFS= read -r name; do
      [[ -z "$name" ]] && continue
      if grep -qxF "$name" <<< "$tgt_tags"; then
        local kind; kind=$(_update_tag_kind "$src" "$name")
        case "$kind" in
          table)
            local sh th
            sh=$(_update_tag_header "$src" "$name")
            th=$(_update_tag_header "$tgt" "$name")
            if [[ "$sh" == "$th" ]]; then
              echo "    [=] $name (table) — columns match, rows preserved."
            else
              echo "    [Δ] $name (table) — column header changed; reshape body, keep rows:"
              echo "          source: $sh"
              echo "          local:  ${th:-<no table>}"
            fi
            ;;
          path-list)
            echo "    [=] $name (path-list) — body preserved; verify paths still resolve."
            ;;
          number)
            echo "    [=] $name (number) — scalar preserved."
            ;;
          empty)
            echo "    [?] $name (empty) — source body is empty; verify intent."
            ;;
          *)
            echo "    [?] $name (prose) — body preserved; verify it still matches the schema subject."
            ;;
        esac
      else
        echo "    [+] $name — present in source, absent locally → empty block will be added."
      fi
    done <<< "$src_tags"
    while IFS= read -r name; do
      [[ -z "$name" ]] && continue
      grep -qxF "$name" <<< "$src_tags" || echo "    [orphan] $name — local only, not in the framework source (decide: keep or remove)."
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
llm update — update an installed .llm/ tree + skills + slash commands

Usage:
  llm update [<path>] [--framework <name>] [--from <path|git-url>] [--keep-prose] [--apply]

Arguments:
  <path>         optional path filter, relative to .llm/. May be a directory
                 (e.g. `templates`, `specs`) to scope the .llm/ update to that
                 subtree, or a single file (e.g. `intake/index.md`). Adopter-
                 owned paths (no framework source counterpart) are rejected.

Options:
  --from <src>   path to a dot-llm checkout, or a git URL to clone shallowly
                 (default: the checkout this `llm` script was sourced from).
  --keep-prose   keep the adopter's prose instead of taking it from the source.
                 Prints a per-file warning when framework prose is skipped.
  --apply        apply the merge mechanically (preserve frontmatter values and
                 tag bodies, take prose from source, add missing markers) AND
                 replace skills + slash commands from the source.
                 Without it, prints a structured per-file review for the LLM.

Skills and commands (always applied with --apply, never in dry-run):
  Skills (target/.llm/skills/) and slash commands (parent/.claude/commands/)
  are framework-owned artifacts. --apply replaces them wholesale from the
  source checkout. Deprecated items (locally present, absent from source) are
  listed but NOT removed — remove them manually after review.

Flavor detection:
  The framework flavor is read from the `flavor:` field in .llm/schema.yaml
  (written there at install time). Falls back to `base` if absent.

Per-file model (v3):
  • Frontmatter — adopter values are kept verbatim; only key drift is reported.
  • Tag bodies  — local body preserved; a marker missing locally is added
                  empty. Table tags get a column diff; string tags are flagged
                  for a semantic check. Bodies are never rewritten mechanically.
  • Prose       — taken FROM SOURCE by default (--keep-prose to retain local).

Version gate:
  If the source `version:` differs from the local `framework-version:`, this is
  a MIGRATION, not an update. The command refuses and points to the llm-cli
  skill's migration procedure.

Examples:
  llm update                          dry-run from the active checkout
  llm update --apply                  apply the merge + replace skills/commands
  llm update templates --apply        only update templates/
  llm update intake/index.md          review just one file
  llm update --keep-prose --apply     apply, but keep local prose (warns)
EOF
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

  # Resolve flavor from the installed schema.yaml.
  local flavor
  flavor=$(awk '/^flavor:[[:space:]]/ {print $2; exit}' "$SCHEMA" 2>/dev/null || true)
  : "${flavor:=base}"

  # 1) Resolve source root (the dot-llm checkout).
  local source_root tmpdir=""
  if [[ -z "$from" ]]; then
    if [[ -f "$SCRIPT_DIR/llm" && -d "$SCRIPT_DIR/frameworks" ]]; then
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

  if [[ ! -f "$source_root/llm" || ! -d "$source_root/frameworks" ]]; then
    red "✗ source $source_root does not look like a dot-llm checkout (need llm and frameworks/)"
    return 1
  fi

  # 2) Resolve source flavor.
  local source_framework
  source_framework="$source_root/frameworks/$( [[ "$flavor" == "base" ]] && echo "__base" || echo "$flavor" )"
  if [[ ! -d "$source_framework" ]]; then
    red "✗ framework flavor '$flavor' not found at $source_framework"
    return 1
  fi
  local source_schema="$source_framework/schema.yaml"

  # 3) Pre-flight: target must be installed.
  if [[ ! -f "$DOT_LLM_DIR/index.md" || ! -f "$SCHEMA" ]]; then
    red "✗ target $DOT_LLM_DIR is not an installed framework tree (missing index.md or schema.yaml)"
    return 1
  fi

  # 4) Version gate.
  local source_version target_version
  source_version=$(awk '/^version:[[:space:]]/ {print $2; exit}' "$source_schema")
  target_version=$(awk '/^---$/{c++; if(c==2) exit; next} c==1 && /^framework-version:[[:space:]]/ {print $2; exit}' "$DOT_LLM_DIR/index.md")
  if [[ -n "$source_version" && -n "$target_version" && "$source_version" != "$target_version" ]]; then
    red "✗ version mismatch — this is a MIGRATION, not an update."
    yellow "  source framework version: $source_version"
    yellow "  local framework-version:  $target_version"
    say ""
    say "Steady-state update only runs when both versions match. To upgrade this"
    say "tree, follow the v$target_version → v$source_version migration procedure in the"
    say "llm-cli skill (schema first → folders → frontmatter → tags → bump)."
    return 1
  fi

  say "Source: $source_root (framework version $source_version)"
  say "Target: $DOT_LLM_DIR (framework-version ${target_version:-unset})"
  say "Schema reference for reconciliation: $SCHEMA"
  say ""

  # Override SKILLS_SRC and COMMANDS_SRC to point at the resolved source root
  # when --from was given, so the helpers pick up the right artifacts.
  local skills_src_effective="${source_root}/skills"
  local commands_src_effective="${source_root}/commands"
  [[ -d "$SKILLS_SRC" && "$source_root" == "$SCRIPT_DIR" ]] && skills_src_effective="$SKILLS_SRC"
  [[ -d "$COMMANDS_SRC" && "$source_root" == "$SCRIPT_DIR" ]] && commands_src_effective="$COMMANDS_SRC"

  local parent
  parent=$(dirname "$DOT_LLM_DIR")

  # 5) Discover both-sides candidates by walking the source framework dir.
  local rels=() rel
  while IFS= read -r rel; do
    rel="${rel#"$source_framework"/}"
    [[ "$rel" == *.bkp.* ]] && continue
    # Never feed the framework's own skills/ subtree into the .llm/ file merge —
    # those are handled separately by _framework_copy_skills below.
    [[ "$rel" == skills/* ]] && continue
    if [[ -n "$path_filter" ]]; then
      [[ "$rel" == "$path_filter" || "$rel" == "$path_filter"/* ]] || continue
    fi
    rels+=("$rel")
  done < <(find "$source_framework" -type f \( -name '*.md' -o -name '*.yaml' \) | sort)

  if [[ -n "$path_filter" && ${#rels[@]} -eq 0 ]]; then
    if [[ -e "$DOT_LLM_DIR/$path_filter" ]]; then
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
    local src="$source_framework/$rel" tgt="$DOT_LLM_DIR/$rel"
    local has_fm=0; _update_has_fm "$src" && has_fm=1
    _update_needs_attention "$src" "$tgt" "$keep_prose" "$has_fm" && changed+=("$rel")
  done

  local total=${#changed[@]}

  # 7) --apply: mechanical merge of .llm/ files + replace skills/commands.
  if [[ $apply -eq 1 ]]; then
    [[ $keep_prose -eq 1 ]] && yellow "⚠ --keep-prose: framework prose updates are NOT applied; the tree may diverge."

    # .llm/ file merge.
    if [[ $total -gt 0 ]]; then
      for rel in "${changed[@]}"; do
        local src="$source_framework/$rel" tgt="$DOT_LLM_DIR/$rel"
        mkdir -p "$(dirname "$tgt")"
        if [[ ! -f "$tgt" ]]; then
          cp "$src" "$tgt"; green "  ✓ created $rel"; continue
        fi
        [[ $keep_prose -eq 1 ]] && yellow "    (kept local prose) $rel"
        local has_fm=0; _update_has_fm "$src" && has_fm=1
        _update_build_expected "$src" "$tgt" "$keep_prose" "$has_fm" > "$tgt.tmp" && mv "$tgt.tmp" "$tgt"
        green "  ✓ merged $rel"
      done
    else
      green "✓ .llm/ files already in sync."
    fi

    # Skills: replace universal llm-* from the source checkout.
    say ""
    say "Skills:"
    # Temporarily override SKILLS_SRC for the helper call when --from is set.
    local _orig_skills_src="$SKILLS_SRC"
    SKILLS_SRC="$skills_src_effective"
    _framework_copy_skills "$DOT_LLM_DIR" "1"
    SKILLS_SRC="$_orig_skills_src"

    # Deprecated skills.
    local depr_skills=()
    while IFS= read -r name; do
      [[ -n "$name" ]] && depr_skills+=("$name")
    done < <(SKILLS_SRC="$skills_src_effective" _framework_deprecated_skills "$DOT_LLM_DIR" "$source_framework")
    if [[ ${#depr_skills[@]} -gt 0 ]]; then
      yellow ""
      yellow "  Deprecated skills (locally present, absent from source — review and remove manually):"
      for name in "${depr_skills[@]}"; do
        yellow "    · $name"
      done
    fi

    # Slash commands: replace from the source checkout.
    say ""
    say "Slash commands:"
    local _orig_commands_src="$COMMANDS_SRC"
    COMMANDS_SRC="$commands_src_effective"
    _framework_copy_commands "$parent" "1"

    # Deprecated commands.
    local depr_cmds=()
    while IFS= read -r rel_cmd; do
      [[ -n "$rel_cmd" ]] && depr_cmds+=("$rel_cmd")
    done < <(COMMANDS_SRC="$commands_src_effective" _framework_deprecated_commands "$parent")
    if [[ ${#depr_cmds[@]} -gt 0 ]]; then
      yellow ""
      yellow "  Deprecated commands (locally present, absent from source — review and remove manually):"
      for rel_cmd in "${depr_cmds[@]}"; do
        local slash="${rel_cmd%.md}"; slash="/${slash//\//:}"
        yellow "    · ${slash} ($parent/.claude/commands/$rel_cmd)"
      done
    fi
    COMMANDS_SRC="$_orig_commands_src"

    say ""
    green "✓ Update complete."
    return 0
  fi

  # 8) Default: structured per-file review (dry-run). Skills/commands not shown
  #    in dry-run — they are always replaced deterministically with --apply.
  if [[ $total -eq 0 ]]; then
    green "✓ .llm/ files already in sync${path_filter:+ (path: $path_filter)}."
    say "  Run with --apply to replace skills and slash commands from the source."
    return 0
  fi

  say "═══════════════════════════════════════════════════════════════════════"
  say "Update review (v$source_version steady state) — $total file(s) need attention"
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
    local has_fm=0; _update_has_fm "$src" && has_fm=1
    _update_render "$idx" "$total" "$rel" "$src" "$tgt" "$has_fm" "$keep_prose"
  done

  say "═══════════════════════════════════════════════════════════════════════"
  say "Summary — $total file(s):"
  for rel in "${changed[@]}"; do
    [[ -f "$DOT_LLM_DIR/$rel" ]] && say "  [merge] $rel" || say "  [new]   $rel"
  done
  say ""
  say "Skills and slash commands will also be replaced from the source on --apply."
  say "Re-run with --apply to merge .llm/ files and replace skills/commands."
  return 0
}

# Build the source file with the target's tag bodies injected.
# Args: src_file, tgt_file
_update_inject_blocks() {
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
