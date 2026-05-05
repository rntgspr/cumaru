# cmd_specs.sh — operations on the specs/ pillar.
#
# Subcommands:
#   bootstrap [--path <dir>] [--apply]
#       Light pass: discover top-level areas under <scan_path> and write a
#       persistent specs/<area>/bootstrap.md per area with discovery output
#       and instructions for an LLM to draft specs/<area>/index.md and
#       populate "## Topics" worth deepening later.
#
#   deep <area> [--topic <slug>] [--apply]
#       Deep pass: append "## Discovery (deep pass <ISO>) — <scope>" to an
#       existing bootstrap.md. <scope> is `all topics` (default) or
#       `topic: <slug>` (with --topic). LLM uses the appended section to
#       refine specs/<area>/index.md.
#
#   consolidate <area> [--apply]
#       Compact a spec area by absorbing its archive deltas into the body.
#       Writes a persistent specs/<area>/history.md.
#
# Expects from the entry-point: DOT_LLM_DIR, SCRIPT_DIR.

cmd_specs_help() {
  cat <<'EOF'
llm specs — operations on the specs/ pillar

Usage:
  llm specs <subcommand> ...

Subcommands:
  bootstrap [--path <dir>] [--apply]
                       light pass: discover areas, write persistent
                       specs/<area>/bootstrap.md per area for an LLM to
                       draft specs/<area>/index.md and list topics.

  deep <area> [--topic <slug>] [--apply]
                       deep pass: append a new ## Discovery section to
                       an existing bootstrap.md (all topics, or one).

  consolidate <area> [--apply]
                       compact a spec area by absorbing its archive
                       deltas; writes a persistent history.md.

  help                 this message.

Examples:
  llm specs bootstrap                      dry-run: detect areas, no writes
  llm specs bootstrap --apply              create specs/<area>/bootstrap.md per area
  llm specs deep auth                      dry-run deep pass for area "auth"
  llm specs deep auth --apply              append deep section, all topics
  llm specs deep auth --topic mfa-flow --apply
EOF
}

cmd_specs_consolidate_help() {
  cat <<'EOF'
llm specs consolidate — compact a spec area by absorbing its archive deltas

Usage:
  llm specs consolidate <area> [--apply]

Default is dry-run: prints what would happen (target file, delta count, plan
IDs) without writing anything. Pass --apply to create the work file.

Behavior (with --apply):
  1. Reads .llm/specs/<area>/index.md and its frontmatter \`deltas:\` list.
  2. Loads each archive/<PLAN-ID>/delta.md referenced by that list.
  3. Writes .llm/specs/<area>/history.md containing:
       - The current spec body
       - Each delta in chronological order (oldest first)
       - Step-by-step instructions for an LLM to rewrite the spec
  4. The LLM (you, in the same chat) opens the work file, rewrites
     specs/<area>/index.md compactly, and replaces the long \`deltas:\`
     list with \`consolidated-at: <ISO date>\` in the frontmatter. The
     work file (\`history.md\`) is persistent — leave it on disk unless
     the user explicitly asks to delete it.

  Archive entries are NOT touched — history is preserved on disk; only the
  spec frontmatter's reference shape changes (long list → single date).

Why:
  Over time, a spec area accumulates many \`deltas:\` and absorbed history.
  Consolidation keeps the loaded context lean: the LLM reads one compact
  spec instead of the body plus a chain of historical deltas.
EOF
}

# Subcommand: consolidate
cmd_specs_consolidate() {
  local area=""
  local apply=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --apply)        apply=1; shift ;;
      -h|--help|help) cmd_specs_consolidate_help; return 0 ;;
      -*)             red "unknown flag: $1"; cmd_specs_consolidate_help; return 2 ;;
      *)
        if [[ -z "$area" ]]; then area="$1"
        else red "unexpected arg: $1"; return 2
        fi
        shift
        ;;
    esac
  done

  if [[ -z "$area" ]]; then
    cmd_specs_consolidate_help
    return 2
  fi

  # Normalize the area path (strip leading/trailing slashes).
  area="${area#/}"
  area="${area%/}"

  if [[ ! -d "$DOT_LLM_DIR" ]]; then
    red "✗ $DOT_LLM_DIR not found — run 'llm install' first"
    return 1
  fi

  local area_dir="$DOT_LLM_DIR/specs/$area"
  local area_index="$area_dir/index.md"

  if [[ ! -f "$area_index" ]]; then
    red "✗ spec area not found: $area_index"
    return 1
  fi

  local work_file="$area_dir/history.md"
  if [[ -f "$work_file" ]]; then
    red "✗ work file already exists: $work_file"
    yellow "  Finish the previous consolidation first, or remove the file."
    return 1
  fi

  # Extract the deltas: list from the area's frontmatter.
  local deltas
  deltas=$(awk '
    /^---$/                                          { c++; if (c == 2) exit; next }
    c == 1 && /^deltas:/                             { in_list = 1; next }
    in_list && /^[[:space:]]+-[[:space:]]+/ {
      sub(/^[[:space:]]+-[[:space:]]+/, "")
      sub(/[[:space:]]+#.*/, "")
      sub(/[[:space:]]+$/, "")
      print
      next
    }
    in_list && /^[a-zA-Z]/                           { exit }
  ' "$area_index")

  local now
  now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Count deltas and report what would happen (dry-run vs apply).
  local delta_count=0
  if [[ -n "$deltas" ]]; then
    delta_count=$(echo "$deltas" | grep -c .)
  fi

  if [[ $apply -eq 0 ]]; then
    say "Dry-run for specs/$area:"
    say "  Spec body:    $area_index"
    say "  Would write:  $work_file"
    say "  Deltas to absorb (from frontmatter \`deltas:\`): $delta_count"
    if [[ -n "$deltas" ]]; then
      local plan_id
      while IFS= read -r plan_id; do
        [[ -z "$plan_id" ]] && continue
        say "    - $plan_id"
      done <<< "$deltas"
    fi
    say ""
    say "Pass --apply to write the consolidation work file."
    return 0
  fi

  # Build the work file.
  {
    echo "# Consolidation work — specs/$area"
    echo ""
    echo "<!-- BEGIN CONSOLIDATE-INSTRUCTIONS"
    echo "INSTRUCTION FOR LLM:"
    echo "Below are (1) the current spec body for \`specs/$area/\`, then (2) the"
    echo "archive deltas that built it, in chronological order. Your job:"
    echo ""
    echo "  1. Rewrite \`$area_index\` so the body absorbs the deltas and reads"
    echo "     as a single coherent specification of the CURRENT state."
    echo "  2. Keep every surviving Requirement; merge or rephrase where deltas"
    echo "     modified the same Requirement; drop Removed Requirements (they"
    echo "     are no longer part of the system)."
    echo "  3. In the frontmatter:"
    echo "       - replace the long \`deltas:\` list with the single field"
    echo "         \`consolidated-at: $now\`;"
    echo "       - keep \`generated\`, \`name\`, \`summary\`, \`depends-on\`, \`apps\`."
    echo "  4. Be compact. The spec body should be the smallest version that"
    echo "     still captures every surviving requirement, decision, and"
    echo "     reference. Compactness is the point — every line you can drop"
    echo "     without losing meaning is shrinking the LLM's loaded context."
    echo "  5. DO NOT touch \`archive/\` — history is preserved on disk."
    echo "  6. DO NOT delete sections of the spec body that came from outside"
    echo "     the deltas (Overview, Decisions, Files) unless they are also"
    echo "     obsolete in the consolidated state."
    echo "  7. DO NOT delete this file — \`history.md\` is the area's persistent"
    echo "     chronological history. Leave it on disk after the rewrite."
    echo "     Only delete it if the user explicitly asks."
    echo "END CONSOLIDATE-INSTRUCTIONS -->"
    echo ""
    echo "## (1) Current spec body"
    echo ""
    cat "$area_index"
    echo ""
    echo "## (2) Archive deltas (chronological, oldest first)"
    echo ""
    if [[ -z "$deltas" ]]; then
      echo "_No deltas listed in the spec frontmatter — nothing to absorb._"
      echo ""
      echo "If the spec is already consolidated, the only update needed is"
      echo "switching the frontmatter from \`deltas:\` (absent) to \`consolidated-at: $now\`."
    else
      local plan_id delta_file
      while IFS= read -r plan_id; do
        [[ -z "$plan_id" ]] && continue
        delta_file="$DOT_LLM_DIR/archive/$plan_id/delta.md"
        echo ""
        echo "### $plan_id"
        echo ""
        if [[ -f "$delta_file" ]]; then
          cat "$delta_file"
        else
          echo "_(missing on disk: $delta_file — proceed without this delta or report to the user)_"
        fi
        echo ""
      done <<< "$deltas"
    fi
  } > "$work_file"

  green "✓ created $work_file"
  say "  → Open the file; it carries step-by-step instructions for an LLM"
  say "    to rewrite $area_index compactly and then delete the work file."
}

# ============================================================================
# Bootstrap and deep — discovery passes that scaffold spec areas from code.
# ============================================================================

cmd_specs_bootstrap_help() {
  cat <<'EOF'
llm specs bootstrap — light pass discovery for spec areas

Usage:
  llm specs bootstrap [--path <dir>] [--apply]

Default is dry-run: detect scan path, list candidate areas with file counts
and cross-area imports. Pass --apply to write specs/<area>/bootstrap.md
per area (skips areas that already have bootstrap.md).

Auto-detects scan path from common conventions: src/, app/, lib/, packages/.
Override with --path <dir> if your code lives elsewhere.
EOF
}

cmd_specs_deep_help() {
  cat <<'EOF'
llm specs deep — deep pass discovery for one spec area

Usage:
  llm specs deep <area> [--topic <slug>] [--apply]

Requires specs/<area>/bootstrap.md to already exist (run 'llm specs bootstrap'
first). Default is dry-run.

With --apply: appends a new "## Discovery (deep pass <ISO>) — <scope>"
section to the existing bootstrap.md. <scope> is "all topics" (default)
or "topic: <slug>" (with --topic). The LLM uses the appended section to
refine specs/<area>/index.md.
EOF
}

# Resolve the scan path: explicit --path, else auto-detect.
_specs_resolve_scan_path() {
  local explicit="$1"
  if [[ -n "$explicit" ]]; then
    [[ -d "$explicit" ]] && { printf '%s\n' "$explicit"; return 0; }
    return 1
  fi
  local candidate
  for candidate in src app lib; do
    [[ -d "$candidate" ]] && { printf '%s\n' "$candidate"; return 0; }
  done
  return 1
}

# List source files under a directory (TS/JS/Python/Go/Rust/Ruby), excluding
# tests, node_modules, dist, build, coverage. Prints one file per line.
_specs_list_files() {
  local dir="$1"
  find "$dir" -type f \
    \( -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' \
    -o -name '*.py' -o -name '*.go' -o -name '*.rs' -o -name '*.rb' \) \
    2>/dev/null \
    | grep -vE '\.(test|spec)\.[a-z]+$' \
    | grep -vE '/(node_modules|dist|build|coverage|__pycache__|\.next|\.cache)/'
}

# Total LOC across files passed via stdin.
_specs_total_loc() {
  local files
  files=$(cat)
  [[ -z "$files" ]] && { echo 0; return; }
  echo "$files" | tr '\n' '\0' | xargs -0 wc -l 2>/dev/null | tail -1 | awk '{print $1+0}'
}

# Top external imports (TS/JS) across files passed via stdin.
# Outputs lines like "  3 react".
_specs_external_imports() {
  local files
  files=$(cat)
  [[ -z "$files" ]] && return
  echo "$files" | tr '\n' '\0' | xargs -0 grep -hE "^(import|from) " 2>/dev/null \
    | awk '
      {
        if (match($0, /from[[:space:]]+["\047][^"\047]+["\047]/)) {
          s = substr($0, RSTART, RLENGTH)
          sub(/^from[[:space:]]+["\047]/, "", s)
          sub(/["\047]$/, "", s)
          if (s !~ /^[\.@\/]/) print s
        }
      }
    ' \
    | sort | uniq -c | sort -rn | head -10
}

# Cross-area imports: count files referencing other top-level areas.
# Args: dir, area, all_areas (space-separated).
# Outputs lines like "auth 3" (other_area  file_count).
_specs_cross_area_imports() {
  local dir="$1" area="$2" all_areas="$3"
  local other hits
  for other in $all_areas; do
    [[ "$other" == "$area" ]] && continue
    hits=$(grep -rlE "from[[:space:]]+[\"'](\\.\\./|\\.\\./.+/|@[^\"']*/)$other(/|[\"'])" "$dir" 2>/dev/null | wc -l | tr -d ' ')
    [[ "$hits" -gt 0 ]] && echo "$other $hits"
  done
}

# TODO/FIXME comments (first 5).
_specs_todos() {
  local dir="$1"
  grep -rnE "(TODO|FIXME)" "$dir" 2>/dev/null \
    | grep -vE '/(node_modules|dist|build|coverage)/' \
    | head -5
}

# Print one summary line for an area.
# Args: scan_path, area, all_areas.
_specs_print_area_summary() {
  local scan_path="$1" area="$2" all_areas="$3"
  local dir="$scan_path/$area"
  local files n_files loc cross
  files=$(_specs_list_files "$dir")
  n_files=$(printf '%s\n' "$files" | grep -c . 2>/dev/null || echo 0)
  loc=$(printf '%s\n' "$files" | _specs_total_loc)
  cross=$(_specs_cross_area_imports "$dir" "$area" "$all_areas" | awk '{print $1}' | tr '\n' ',' | sed 's/,$//; s/,/, /g')
  printf "  %-24s  %5s files  %7s LOC" "$area" "$n_files" "$loc"
  [[ -n "$cross" ]] && printf "  cross: %s" "$cross"
  echo
}

# Render a bootstrap.md for an area to stdout.
# Args: area, scan_path/area, all_areas.
_specs_render_bootstrap() {
  local area="$1" dir="$2" all_areas="$3"
  local files n_files loc external cross todos now
  files=$(_specs_list_files "$dir")
  n_files=$(printf '%s\n' "$files" | grep -c . 2>/dev/null || echo 0)
  loc=$(printf '%s\n' "$files" | _specs_total_loc)
  external=$(printf '%s\n' "$files" | _specs_external_imports)
  cross=$(_specs_cross_area_imports "$dir" "$area" "$all_areas")
  todos=$(_specs_todos "$dir")
  now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Frontmatter + H1 + instructions block (literal, no expansion).
  cat <<EOF
---
human_revised: false
generated: false
---

# Bootstrap — $area

EOF
  cat <<'EOF'
<!-- BEGIN BOOTSTRAP-INSTRUCTIONS
INSTRUCTION FOR LLM:

This file is the persistent discovery log for this spec area. It is created
by `llm specs bootstrap` (light pass) and grown by future
`llm specs deep <area>` invocations. Leave it on disk after editing.

# Light pass — your job

  1. Read the entry-point files listed under `## Files` (start with
     `index.*`, `main.*`, `app.*`, or similar). Goal: breadth, not depth.
  2. Write `specs/<area>/index.md` following `templates/spec.md`:
     - frontmatter: `name`, `summary`, `depends-on:` (use the cross-area
       imports below), `apps:` (from `schema.yaml` `apps.values`),
       `deltas: []`.
     - `## Overview` — 1-3 paragraphs.
     - `## Requirements (EARS)` — observable behaviors as
       `WHEN <trigger> THE SYSTEM SHALL <response>`. Light produces broad
       criteria; deep refines.
     - `## Decisions` — non-obvious choices visible in the code, or
       `(none surfaced)`.
     - `## Files` — markdown list with one-line role per file.
  3. Populate `## Topics` below — each item names an investigation worth
     deepening later. Kebab-case slug, one short rationale.
  4. Leave THIS file on disk.

# Deep pass — your job (when invoked later)

  1. Read this file end-to-end (light + prior deep passes).
  2. Iterate every topic under `## Topics` (default), or focus on the
     one passed via `--topic <slug>`.
  3. Append `## Discovery (deep pass <ISO>) — <scope>` at the END.
     Do NOT edit prior sections.
  4. Refine `specs/<area>/index.md` with what you learned.

END BOOTSTRAP-INSTRUCTIONS -->

EOF

  # Discovery section (with var expansion).
  cat <<EOF
## Discovery (light pass $now)

- **Path:** \`$dir/\`
- **Files:** $n_files ($loc LOC)
EOF

  if [[ -n "$external" ]]; then
    echo "- **Top-level imports** (external packages used):"
    echo "$external" | awk '{count=$1; pkg=$2; printf "  - `%s` (%d file%s)\n", pkg, count, (count==1?"":"s")}'
  fi

  if [[ -n "$cross" ]]; then
    echo "- **Cross-area imports** (candidates for \`depends-on:\`):"
    echo "$cross" | awk '{printf "  - `%s` (%d file%s)\n", $1, $2, ($2==1?"":"s")}'
  fi

  if [[ -n "$todos" ]]; then
    echo "- **TODO/FIXME found** (first 5):"
    echo "$todos" | awk -F: '{
      path=$1; line=$2;
      rest="";
      for(i=3;i<=NF;i++) rest = rest ":" $i;
      sub(/^:/, "", rest);
      sub(/^[[:space:]]+/, "", rest);
      printf "  - `%s:%s` — %s\n", path, line, rest
    }'
  fi

  echo
  echo "## Files"
  echo
  echo "_The CLI lists the files below; you describe each after the light read._"
  echo
  if [[ -n "$files" ]]; then
    echo "$files" | head -30 | sed 's|^|- `|; s|$|` — _(LLM: one-line description)_|'
    local total_count
    total_count=$(echo "$files" | grep -c .)
    if [[ "$total_count" -gt 30 ]]; then
      echo
      echo "_(... and $((total_count - 30)) more files; deep pass lists all)_"
    fi
  fi

  cat <<'EOF'

## Topics

_LLM populates this section during the light pass — one bullet per
investigation worth deepening later._

- **<topic-slug>** — _(rationale: what's unclear / complex / under-specified)_

<!-- Future deep passes append below. Each pass starts a new
     `## Discovery (deep pass <ISO>) — <scope>` section and never edits
     prior sections. -->
EOF
}

cmd_specs_bootstrap() {
  local apply=0
  local scan_path_arg=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --apply)        apply=1; shift ;;
      --path)         scan_path_arg="${2:-}"; shift 2 ;;
      -h|--help|help) cmd_specs_bootstrap_help; return 0 ;;
      -*)             red "unknown flag: $1"; cmd_specs_bootstrap_help; return 2 ;;
      *)              red "unexpected arg: $1"; return 2 ;;
    esac
  done

  if [[ ! -d "$DOT_LLM_DIR" ]]; then
    red "✗ $DOT_LLM_DIR not found — run 'llm install' first"
    return 1
  fi

  local scan_path
  scan_path=$(_specs_resolve_scan_path "$scan_path_arg")
  if [[ -z "$scan_path" ]]; then
    red "✗ no source dir found (tried src/, app/, lib/). Use --path <dir>."
    return 1
  fi

  # Collect candidate areas (top-level subdirs).
  local areas=()
  local d name
  while IFS= read -r d; do
    [[ -d "$d" ]] || continue
    name=$(basename "$d")
    case "$name" in
      __tests__|test|tests|node_modules|dist|build|coverage|.next|.cache) continue ;;
      *) areas+=("$name") ;;
    esac
  done < <(find "$scan_path" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)

  if [[ ${#areas[@]} -eq 0 ]]; then
    yellow "⚠ no areas found under $scan_path/"
    return 1
  fi

  echo "Scan path:     $scan_path/"
  echo "Areas found:   ${#areas[@]}"
  echo
  local all_areas="${areas[*]}"
  local area
  for area in "${areas[@]}"; do
    _specs_print_area_summary "$scan_path" "$area" "$all_areas"
  done

  if [[ $apply -eq 0 ]]; then
    echo
    say "Dry-run; pass --apply to write specs/<area>/bootstrap.md per area."
    return 0
  fi

  # Apply — write bootstrap.md per area (skip if already present).
  echo
  local written=0 skipped=0 target
  for area in "${areas[@]}"; do
    target="$DOT_LLM_DIR/specs/$area/bootstrap.md"
    if [[ -f "$target" ]]; then
      say "  · $area: bootstrap.md already exists (skip)"
      skipped=$((skipped + 1))
      continue
    fi
    mkdir -p "$DOT_LLM_DIR/specs/$area"
    _specs_render_bootstrap "$area" "$scan_path/$area" "$all_areas" > "$target"
    green "  + $area: wrote $target"
    written=$((written + 1))
  done
  echo
  green "✓ wrote $written bootstrap.md ($skipped skipped — already present)"
}

cmd_specs_deep() {
  local area=""
  local topic=""
  local apply=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --apply)        apply=1; shift ;;
      --topic)        topic="${2:-}"; shift 2 ;;
      -h|--help|help) cmd_specs_deep_help; return 0 ;;
      -*)             red "unknown flag: $1"; cmd_specs_deep_help; return 2 ;;
      *)
        if [[ -z "$area" ]]; then area="$1"
        else red "unexpected arg: $1"; return 2
        fi
        shift
        ;;
    esac
  done

  if [[ -z "$area" ]]; then
    red "✗ usage: llm specs deep <area> [--topic <slug>] [--apply]"
    return 2
  fi

  area="${area%/}"
  area="${area#/}"

  if [[ ! -d "$DOT_LLM_DIR" ]]; then
    red "✗ $DOT_LLM_DIR not found — run 'llm install' first"
    return 1
  fi

  local target="$DOT_LLM_DIR/specs/$area/bootstrap.md"
  if [[ ! -f "$target" ]]; then
    red "✗ no bootstrap.md at $target"
    yellow "  Run 'llm specs bootstrap --apply' first to create the discovery log."
    return 1
  fi

  # Resolve scan path (no flag override on deep — match what bootstrap detected).
  local scan_path
  scan_path=$(_specs_resolve_scan_path "")
  if [[ -z "$scan_path" || ! -d "$scan_path/$area" ]]; then
    red "✗ source dir not found for area '$area' under any common scan path"
    return 1
  fi
  local area_dir="$scan_path/$area"

  # Read topics from existing bootstrap.md.
  local topics_block
  topics_block=$(awk '/^## Topics/{f=1; next} /^## /{f=0} f' "$target")

  local scope
  if [[ -n "$topic" ]]; then
    if ! echo "$topics_block" | grep -q "\\*\\*$topic\\*\\*"; then
      red "✗ topic '$topic' not listed in $target"
      yellow "  Available topics:"
      echo "$topics_block" | grep -oE '\*\*[a-z0-9-]+\*\*' | tr -d '*' | sed 's/^/    - /' || echo "    (none)"
      return 1
    fi
    scope="topic: $topic"
  else
    scope="all topics"
  fi

  # Deep discovery (full file list, more detail).
  local files n_files loc external
  files=$(_specs_list_files "$area_dir")
  n_files=$(printf '%s\n' "$files" | grep -c . 2>/dev/null || echo 0)
  loc=$(printf '%s\n' "$files" | _specs_total_loc)

  local now
  now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  if [[ $apply -eq 0 ]]; then
    say "Dry-run for deep pass on specs/$area:"
    say "  Scope:        $scope"
    say "  Bootstrap:    $target"
    say "  Source dir:   $area_dir"
    say "  Files:        $n_files ($loc LOC)"
    if [[ -n "$topic" ]]; then
      say "  Topic line:"
      echo "$topics_block" | grep "\\*\\*$topic\\*\\*" | sed 's/^/    /'
    fi
    say ""
    say "Pass --apply to append a new ## Discovery (deep pass <ISO>) — $scope section."
    return 0
  fi

  # Append deep section.
  external=$(printf '%s\n' "$files" | _specs_external_imports)
  {
    echo
    echo "## Discovery (deep pass $now) — $scope"
    echo
    echo "_CLI snapshot. The LLM appends findings below this section._"
    echo
    echo "- **Source dir:** \`$area_dir/\`"
    echo "- **Files:** $n_files ($loc LOC)"
    if [[ -n "$external" ]]; then
      echo "- **External imports:**"
      echo "$external" | awk '{printf "  - `%s` (%d)\n", $2, $1}'
    fi
    echo
    echo "### Files (full list)"
    echo
    if [[ -n "$files" ]]; then
      echo "$files" | sed 's|^|- `|; s|$|`|'
    fi
    echo
    if [[ -n "$topic" ]]; then
      echo "### Topic: $topic"
      echo
      echo "_LLM: write detailed findings for the \`$topic\` investigation here._"
      echo "_Reference specific files and line numbers from the list above._"
    else
      echo "### Topics to address"
      echo
      if [[ -n "$topics_block" ]]; then
        echo "$topics_block" | grep -E "^- \\*\\*"
      fi
      echo
      echo "_LLM: for each topic above, write a \`### Topic: <slug>\` subsection_"
      echo "_with detailed findings._"
    fi
    echo
    echo "### Refinements to apply to \`specs/$area/index.md\`"
    echo
    echo "_LLM: list the changes you'll make to the spec — tightened EARS,"
    echo "new Decisions, refined Files descriptions, possible concern splits._"
  } >> "$target"

  green "✓ appended deep pass section to $target"
  say "  → Scope: $scope"
  say "  → Read $target end-to-end and complete the new section."
  say "  → Refine specs/$area/index.md with what you learn."
}
