# cmd_reconcile.sh — reconcile each pillar's shallow index table with disk.
#
# Discovers pillars by walking `root.entities` in schema.yaml; for each pillar
# reads the column list of its array tag (e.g. `intake: [Key, Type, Title,
# Status, Relates]`), walks the pillar dir for entities, builds the expected
# table from each entity's frontmatter via convention, and diffs against the
# actual table in the pillar's index.md.
#
# Default: structured per-pillar diff for an LLM to adjudicate.
# --apply : mechanically rewrite the table body to the expected content.
#
# Column → frontmatter convention:
#   Key, Idea     basename of the entity dir / slug
#   Path          path of the entity dir relative to the pillar dir (recursive)
#   Title         the H1 of the entity's index.md (stripped of `# `)
#   Tasks         count of t*.md files in the entity dir
#   *             lowercase(column_name), hyphens preserved; if the
#                 frontmatter value is a list, items joined with ", "
#
# Specs are walked recursively — every dir under specs/ with an index.md is
# a row. Other pillars are depth-1 (immediate children of the pillar dir).
#
# Expects from entry-point: DOT_LLM_DIR, SCHEMA, QUIET.

# --- schema readers --------------------------------------------------------

# Emit the pillar keys (one per line) under `root.entities:` in $SCHEMA.
_reconcile_pillars() {
  awk '
    /^root:/                        { state = "root"; next }
    state == "root" && /^  entities:/ { state = "ents"; next }
    state == "ents" && /^[^ ]/      { state = "" }
    state == "ents" && /^  [^ ]/    { state = "root" }
    state == "ents" && /^    [a-z][a-z0-9_-]*:[[:space:]]*$/ {
      k = $0; sub(/^    /, "", k); sub(/:[[:space:]]*$/, "", k); print k
    }
  ' "$SCHEMA"
}

# Emit the column list for `root.entities.<pillar>.tags.<pillar>:` as a
# comma-joined string (e.g. "Key, Type, Title, Status, Relates"). Empty if
# the pillar has no matching array tag.
_reconcile_pillar_cols() {
  local p="$1"
  awk -v p="$p" '
    /^root:/                                       { st = "root"; next }
    st == "root" && /^  entities:/                 { st = "ents"; next }
    st == "ents" && /^[^ ]/                        { st = "" }
    st == "ents" && /^  [^ ]/                      { st = "root" }
    st == "ents" && $0 ~ "^    " p ":[[:space:]]*$" { st = "pil"; next }
    st == "pil"  && /^    [a-z]/                   { st = "ents" }
    st == "pil"  && /^      tags:[[:space:]]*$/    { st = "tags"; next }
    st == "tags" && /^      [a-z]/                 { st = "pil" }
    st == "tags" && $0 ~ "^        " p ":[[:space:]]*\\[" {
      line = $0
      sub(/^[[:space:]]*[a-z][a-z0-9_-]*:[[:space:]]*\[/, "", line)
      sub(/\][[:space:]]*$/, "", line)
      print line; exit
    }
  ' "$SCHEMA"
}

# --- table building --------------------------------------------------------

# Compute the value for one (entity_dir, column_name) pair, using the
# convention documented at the top of this file.
# Args: entity_dir pillar_dir column_name
_reconcile_cell() {
  local edir="$1" pdir="$2" col="$3"
  local idx="$edir/index.md"
  case "$col" in
    Key|Idea)  basename "$edir" ;;
    Path)      local rel="${edir#"$pdir"/}"; printf '%s' "${rel%/}" ;;
    Title)     [[ -f "$idx" ]] && fm_h1 "$idx" || printf '' ;;
    Tasks)
      local n=0
      shopt -s nullglob
      for _ in "$edir"/t*.md; do n=$((n + 1)); done
      shopt -u nullglob
      printf '%d' "$n"
      ;;
    *)
      [[ -f "$idx" ]] || { printf ''; return; }
      local fmkey
      fmkey=$(printf '%s' "$col" | tr '[:upper:]' '[:lower:]')
      local val
      val=$(fm_scalar "$idx" "$fmkey")
      if [[ -n "$val" ]]; then
        # Strip surrounding `[ ... ]` if present (inline YAML list scalar).
        val="${val#[}"; val="${val%]}"
        printf '%s' "$val"
        return
      fi
      # Try as a block list.
      fm_list "$idx" "$fmkey" | paste -sd, - | sed 's/,/, /g'
      ;;
  esac
}

# Walk a pillar dir and emit one entity dir path per line (sorted).
# specs is recursive (any subdir with an index.md); others are depth-1.
# Args: pillar pillar_dir
_reconcile_entities() {
  local p="$1" pdir="$2"
  [[ -d "$pdir" ]] || return 0
  if [[ "$p" == "specs" ]]; then
    find "$pdir" -mindepth 1 -type d | while read -r d; do
      [[ -f "$d/index.md" ]] && printf '%s\n' "$d"
    done | sort
  else
    find "$pdir" -mindepth 1 -maxdepth 1 -type d | sort
  fi
}

# Build the expected table body (header + separator + rows, or a "_No entries
# yet._" line). One row per entity, columns in schema order.
# Args: pillar pillar_dir columns_csv
_reconcile_build_table() {
  local p="$1" pdir="$2" cols_csv="$3"
  local cols=() col
  IFS=',' read -ra cols <<< "$cols_csv"
  for i in "${!cols[@]}"; do
    cols[$i]="$(printf '%s' "${cols[$i]}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  done

  # Header + separator.
  local header="|" sep="|"
  for col in "${cols[@]}"; do
    header+=" $col |"
    sep+="---|"
  done
  printf '%s\n%s\n' "$header" "$sep"

  # Rows.
  local edir row val any=0
  while IFS= read -r edir; do
    [[ -z "$edir" ]] && continue
    any=1
    row="|"
    for col in "${cols[@]}"; do
      val=$(_reconcile_cell "$edir" "$pdir" "$col")
      row+=" ${val:--} |"
    done
    printf '%s\n' "$row"
  done < <(_reconcile_entities "$p" "$pdir")

  [[ $any -eq 0 ]] && printf '\n_No entries yet._\n'
}

# Extract the actual table body from the pillar's index.md tag block.
# Args: pillar
_reconcile_actual_table() {
  local p="$1"
  local idx="$DOT_LLM_DIR/$p/index.md"
  [[ -f "$idx" ]] || return 0
  fm_block_extract "$idx" "$p"
}

# Quiet check used by doctor. Exit codes:
#   0  every pillar aligned
#   1  at least one pillar drifted
#   2  schema unreadable, or has no `root.entities` (likely a pre-v3 tree)
# Prints nothing.
_reconcile_check_quiet() {
  [[ -f "$SCHEMA" ]] || return 2
  local p cols_csv idx expected actual e_trim a_trim seen=0
  while IFS= read -r p; do
    [[ -z "$p" ]] && continue
    seen=1
    cols_csv=$(_reconcile_pillar_cols "$p")
    [[ -z "$cols_csv" ]] && continue
    idx="$DOT_LLM_DIR/$p/index.md"
    [[ -f "$idx" ]] || return 1
    expected=$(_reconcile_build_table "$p" "$DOT_LLM_DIR/$p" "$cols_csv")
    actual=$(_reconcile_actual_table "$p")
    e_trim=$(printf '%s\n' "$expected" | awk 'NF{p=1} p')
    a_trim=$(printf '%s\n' "$actual"   | awk 'NF{p=1} p')
    [[ "$e_trim" == "$a_trim" ]] || return 1
  done < <(_reconcile_pillars)
  [[ $seen -eq 1 ]] || return 2
  return 0
}

# --- main ------------------------------------------------------------------

cmd_reconcile_help() {
  cat <<'EOF'
llm reconcile — align each pillar's shallow index table with disk

Usage:
  llm reconcile [<pillar>] [--apply]

Arguments:
  <pillar>     optional: limit to one pillar (intake, plans, archive, specs,
               exploring, or any node declared under root.entities).

Options:
  --apply      mechanically rewrite the table block to the expected content.
               Without it, prints a structured diff per pillar for an LLM
               to adjudicate.

Behavior:
  Discovers pillars from schema.yaml (root.entities). For each, reads the
  array-tag column list, walks disk for entities, builds the expected table
  via convention (Key/Idea = dir name; Path = relpath; Title = H1; Tasks =
  count of t*.md; otherwise lowercase(column) read from frontmatter, lists
  joined with ", "). specs is walked recursively (subareas included).

  The diff highlights rows added, removed, and changed; --apply replaces the
  tag body in <pillar>/index.md with the expected table. The schema is the
  single source of truth for which pillars exist and which columns they carry.
EOF
}

cmd_reconcile() {
  local apply=0 only=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --apply)        apply=1; shift ;;
      help|-h|--help) cmd_reconcile_help; return 0 ;;
      -*)             red "unknown flag: $1"; cmd_reconcile_help; return 2 ;;
      *)
        if [[ -z "$only" ]]; then only="$1"
        else red "unexpected arg: $1"; cmd_reconcile_help; return 2; fi
        shift ;;
    esac
  done

  [[ -f "$SCHEMA" ]] || { red "✗ schema not found: $SCHEMA"; return 1; }

  local pillars=()
  while IFS= read -r p; do [[ -n "$p" ]] && pillars+=("$p"); done < <(_reconcile_pillars)
  if [[ ${#pillars[@]} -eq 0 ]]; then
    red "✗ no pillars found under root.entities in $SCHEMA"
    yellow "  This looks like a pre-v3 schema. Reconcile requires v3 — see the v2 → v3 migration in the llm-cli skill."
    return 1
  fi

  if [[ -n "$only" ]]; then
    local found=0
    for p in "${pillars[@]}"; do [[ "$p" == "$only" ]] && found=1; done
    [[ $found -eq 1 ]] || { red "✗ unknown pillar: $only (known: ${pillars[*]})"; return 2; }
    pillars=("$only")
  fi

  local any_drift=0 p
  for p in "${pillars[@]}"; do
    local cols_csv
    cols_csv=$(_reconcile_pillar_cols "$p")
    if [[ -z "$cols_csv" ]]; then
      say "─── $p — no array tag declared in schema (skipping)."
      continue
    fi

    local idx="$DOT_LLM_DIR/$p/index.md"
    if [[ ! -f "$idx" ]]; then
      yellow "─── $p — pillar index.md missing ($idx)"
      any_drift=1
      continue
    fi

    local expected actual
    expected=$(_reconcile_build_table "$p" "$DOT_LLM_DIR/$p" "$cols_csv")
    actual=$(_reconcile_actual_table "$p")

    # Trim leading/trailing blank lines from both for a fair compare.
    local e_trim a_trim
    e_trim=$(printf '%s\n' "$expected" | awk 'NF{p=1} p')
    a_trim=$(printf '%s\n' "$actual"   | awk 'NF{p=1} p')

    if [[ "$e_trim" == "$a_trim" ]]; then
      green "─── $p — ✓ in sync (columns: $cols_csv)"
      continue
    fi

    any_drift=1
    yellow "─── $p — drift (columns: $cols_csv)"
    if [[ $apply -eq 1 ]]; then
      printf '%s\n' "$expected" | fm_block_replace "$idx" "$p"
      green "    ✓ rewrote $p/index.md tag body"
    else
      echo "    --- Diff (actual → expected) ---"
      diff -u <(printf '%s\n' "$actual") <(printf '%s\n' "$expected") 2>/dev/null | sed 's/^/    /'
    fi
  done

  if [[ $any_drift -eq 0 ]]; then
    green ""
    green "✓ All indexes aligned with disk."
    return 0
  fi
  if [[ $apply -eq 0 ]]; then
    say ""
    say "Re-run with --apply to rewrite the drifted tables, or edit them by hand."
  fi
  return 0
}
