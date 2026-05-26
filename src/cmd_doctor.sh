# cmd_doctor.sh — run health checks on a .llm/ tree.
#
# `llm doctor` runs all checks: schema conformance plus tree-wide
# structural checks. Each check emits one of:
#   [✓] label                     — pass
#   [⚠] label   detail            — soft issue (warning; never fails)
#   [✗] label   detail            — hard issue (error; exit 1 at end)
#
# Composition (v3 — every check is pillar-agnostic, schema-driven):
#   1. Schema conformance — universal markdown, index.md, pillar index, entity
#      frontmatter, EARS, framework-version match. Walks root.entities from
#      schema.yaml; no hardcoded pillar names.
#   2. Orphan check — walks raiz + pilares (from root.entities), shows every
#      markdown-table tag found, lists orphans both ways. LLM reconciles.
#   3. Stale work-marker files (any *.delete-me.md anywhere under .llm/).
#   4. File references — paths inside path-list tag bodies exist on disk.
#   5. External tools available (curl, jq, git, rsync).
#
# Workflow-specific checks (tasks-done-without-handoff, orphan delta-drafts
# after archive) **moved out of doctor in v3** — workflow integrity is
# LLM-driven; doctor stays mechanical and pillar-agnostic.
#
# Expects from the entry-point: DOT_LLM_DIR, SCHEMA, QUIET. Reuses fm_*
# helpers from common.sh.

cmd_doctor_help() {
  cat <<'EOF'
llm doctor — run health checks on the .llm/ tree

Usage:
  llm doctor [--quiet]

Options:
  --quiet   suppress [✓] pass lines; warnings, errors, and the summary still print.

Checks (v3 — every check is pillar-agnostic, schema-driven):
  [1] Schema conformance — sub-passes:
        [0] H1 + human_revised on every .md (rules.markdown)
        [1] index.md universal frontmatter (generated, apps; apps values valid)
        [2] Pillar index.md (generated-at + pillar extras like intake.tracker)
        [3] Entity frontmatter (schema-driven walk of root.entities)
        [4] EARS warning on AC / Requirements sections
        Cross — framework-version in .llm/index.md ≡ version in schema.yaml.
  [2] Orphan check — walks raiz + pilares (from root.entities), shows each
      markdown-table tag, reports both directions:
        ✗ row points at a missing file/dir
        ⚠ file/dir on disk not claimed by any row (pilares only)
      The LLM reconciles per the orphan-row guidance in the llm-doctor skill.
  [3] Stale work-marker files — any `*.delete-me.md` anywhere under .llm/.
  [4] File references — paths inside path-list tag bodies resolve on disk.
  [5] External tools available (curl, jq, git, rsync).

  Workflow-specific checks (tasks-done-without-handoff, orphan delta-drafts)
  moved to flavor-specific recipe skills (e.g. llm-archive for sdlc) — doctor stays mechanical.

  EARS pattern: WHEN .+ THE SYSTEM SHALL .+ — non-conforming bullets emit
  warnings, not errors. Cross-file checks (path resolution, depends-on,
  deltas references) are listed in schema.yaml under cross_file_checks.deferred
  and not yet enforced.

Exit codes:
  0   all checks pass (warnings allowed)
  1   at least one error
  2   usage error (unknown flag)

Examples:
  llm                                       equivalent to llm doctor (default)
  llm doctor --quiet                      hide pass lines; show warnings + errors
  DOT_LLM_DIR=path/to/.llm llm doctor     non-default tree
EOF
}

# --- output helpers (orchestrator level) ---

_doctor_ok=0
_doctor_warn=0
_doctor_err=0

_doctor_pass() {
  [[ "${QUIET:-0}" == "1" ]] || printf '\033[32m[✓]\033[0m %s\n' "$1"
  _doctor_ok=$((_doctor_ok + 1))
}

_doctor_warn_emit() {
  printf '\033[33m[⚠]\033[0m %s\n' "$1"
  if [[ -n "${2:-}" ]]; then
    printf '%s\n' "$2" | sed 's/^/    /'
  fi
  _doctor_warn=$((_doctor_warn + 1))
}

_doctor_fail() {
  printf '\033[31m[✗]\033[0m %s\n' "$1"
  if [[ -n "${2:-}" ]]; then
    printf '%s\n' "$2" | sed 's/^/    /'
  fi
  _doctor_err=$((_doctor_err + 1))
}

# --- schema conformance check (v3, fully schema-driven) ----------------------
#
# Walks `root.entities` recursively (via the helpers above) and validates
# every entity's frontmatter against the spec declared in schema.yaml. NO
# hardcoded pillar names anywhere — adding a new pillar to the schema is
# enough; this check picks it up automatically. The previous v2 version had
# hand-rolled sub-passes for plans / specs / archive / exploring; v3 collapses
# them into the schema walk.

# Read meta.apps.values (v3 location). Each line = one valid app key.
_doctor_apps_values() {
  awk '
    /^meta:[[:space:]]*$/                                   { state="meta"; next }
    state=="meta"   && /^[^ ]/                              { state="" }
    state=="meta"   && /^  apps:[[:space:]]*$/              { state="apps"; next }
    state=="apps"   && /^  [^ ]/                            { state="meta" }
    state=="apps"   && /^    values:[[:space:]]*$/          { state="values"; next }
    state=="values" && /^    [a-z]/                         { state="apps" }
    state=="values" && /^      -[[:space:]]+/ {
      v=$0; sub(/^[[:space:]]+-[[:space:]]+/, "", v); sub(/[[:space:]]+#.*/, "", v); sub(/[[:space:]]+$/, "", v)
      if (length(v) > 0) print v
    }
  ' "$SCHEMA"
}

# Given an entity path pattern (e.g. `plans/<PLAN-ID>` or `plans/<PLAN-ID>/t<N>.md`),
# expand placeholders into shell globs and emit each matching file on disk:
#   <KEY> / <PLAN-ID> / <slug> / <area> / <concern>  →  *
#   <N>                                              →  [0-9]*
# Patterns without a `.md` suffix point at a directory whose entity-file is
# `index.md`, so we glob for that.
_doctor_disk_files_for_path() {
  local pat="$1" glob
  [[ "$pat" == *.md ]] || pat="$pat/index.md"
  glob="$pat"
  glob="${glob//<N>/[0-9]*}"
  glob=$(printf '%s' "$glob" | sed -E 's/<[a-zA-Z][a-zA-Z0-9_-]*>/*/g')
  shopt -s nullglob
  local f
  for f in $DOT_LLM_DIR/$glob; do
    [[ -f "$f" ]] && printf '%s\n' "$f"
  done
  shopt -u nullglob
}

# Run frontmatter / EARS / version checks against the schema. Verbose by
# default (the [0]..[5] sub-passes); silenced by the orchestrator via QUIET.
# Bumps the local `errors` and `warnings` counters; returns non-zero if any
# error landed.
_doctor_check_schema() {
  # Pre-flight: schema must exist
  if [[ ! -f "$SCHEMA" ]]; then
    red "✗ schema not found at $SCHEMA"
    return 1
  fi

  # Read valid apps from schema (v3: meta.apps.values)
  local VALID_APPS=()
  while IFS= read -r line; do
    VALID_APPS+=("$line")
  done < <(_doctor_apps_values)

  if [[ ${#VALID_APPS[@]} -eq 0 ]]; then
    red "✗ failed to parse meta.apps.values from $SCHEMA"
    return 1
  fi

  # Framework-version check
  local schema_version
  schema_version=$(awk '/^version:[[:space:]]/ {print $2; exit}' "$SCHEMA")
  local front_door="$DOT_LLM_DIR/index.md"
  if [[ -f "$front_door" ]]; then
    local fd_version
    fd_version=$(awk '/^---$/{c++; if(c==2) exit; next} c==1 && /^framework-version:[[:space:]]/ {print $2; exit}' "$front_door")
    if [[ -z "$fd_version" ]]; then
      red "✗ $front_door missing framework-version: in frontmatter (schema is at version $schema_version)"
      errors=$((errors + 1))
    elif [[ "$fd_version" != "$schema_version" ]]; then
      red "✗ framework-version mismatch: $front_door declares $fd_version, schema is $schema_version"
      errors=$((errors + 1))
    fi
  fi

  # frontmatter helpers
  fm() { awk '/^---$/{c++; if(c==2) exit; next} c>=1' "$1"; }
  has_key() { fm "$1" | grep -qE "^${2}:" 2>/dev/null; }

  check_required() {
    local file="$1" label="$2"; shift 2
    local missing=()
    local f
    for f in "$@"; do
      has_key "$file" "$f" || missing+=("$f")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
      local joined
      joined=$(IFS=,; echo "${missing[*]}")
      red "  ✗ $file ($label): missing $joined"
      errors=$((errors + ${#missing[@]}))
    fi
  }

  check_apps_value() {
    local file="$1"
    local line
    line=$(fm "$file" | grep -E '^apps:' | head -1 || true)
    [[ -z "$line" ]] && return 0
    local raw
    raw=$(echo "$line" | sed -E 's/^apps:[[:space:]]*\[(.*)\][[:space:]]*$/\1/' | tr -d ' ' | tr ',' '\n')
    local v ok valid
    for v in $raw; do
      [[ -z "$v" ]] && continue
      valid=0
      for ok in "${VALID_APPS[@]}"; do
        [[ "$v" == "$ok" ]] && valid=1 && break
      done
      if [[ $valid -eq 0 ]]; then
        local valid_list
        valid_list=$(IFS=,; echo "${VALID_APPS[*]}")
        red "  ✗ $file: apps value '$v' not in {${valid_list//,/, }}"
        errors=$((errors + 1))
      fi
    done
  }

  # Validate every required (suffix `!`) field listed in <fm_csv> on <file>.
  check_required_from_csv() {
    local file="$1" label="$2" csv="$3"
    local field req missing=()
    for field in $(printf '%s' "$csv" | tr ',' ' '); do
      [[ -z "$field" ]] && continue
      [[ "$field" == *'!' ]] || continue   # only required
      req="${field%!}"
      has_key "$file" "$req" || missing+=("$req")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
      local joined
      joined=$(IFS=,; echo "${missing[*]}")
      red "  ✗ $file ($label): missing $joined"
      errors=$((errors + ${#missing[@]}))
    fi
  }

  check_ears() {
    local file="$1" section_marker="$2"
    local found
    # Anchor marker to start-of-line so prose that *cites* the section name
    # (e.g. inside backticks: `## Requirements (EARS)`) doesn't trigger the
    # section toggle. Only an actual heading at column 1 turns the scanner on.
    found=$(awk -v marker="$section_marker" -v f="$file" '
      $0 ~ "^"marker {section=1; next}
      /^## / {section=0}
      section && /^- / && !/WHEN .+ THE SYSTEM SHALL .+/ {
        print f ":" NR ": " $0
      }
    ' "$file")
    if [[ -n "$found" ]]; then
      while IFS= read -r line; do
        yellow "  ⚠ EARS form: $line"
        warnings=$((warnings + 1))
      done <<< "$found"
    fi
  }

  check_h1() {
    local file="$1"
    if ! grep -qE '^# ' "$file"; then
      red "  ✗ $file: missing H1 heading"
      errors=$((errors + 1))
    fi
  }

  check_human_revised() {
    local file="$1"
    has_key "$file" "human_revised" || {
      red "  ✗ $file: missing human_revised (required by rules.markdown)"
      errors=$((errors + 1))
    }
  }

  say "Running diagnostic checks on $DOT_LLM_DIR/ ..."

  # [0] H1 + human_revised on every .md (rules.markdown)
  say ""
  say "[0] Universal markdown (H1, human_revised)"
  while IFS= read -r f; do
    check_h1 "$f"
    check_human_revised "$f"
  done < <(find "$DOT_LLM_DIR" -name '*.md' -type f 2>/dev/null | sort)

  # [1] index.md universal frontmatter (rules.index_md: generated, apps)
  say ""
  say "[1] index.md universal frontmatter (generated, apps)"
  while IFS= read -r f; do
    check_required "$f" "index" generated apps
    check_apps_value "$f"
  done < <(find "$DOT_LLM_DIR" -name index.md -type f 2>/dev/null | sort)

  # [2] Pillar index.md — rules.pillar_index (generated-at) + pillar's own extras.
  say ""
  say "[2] Pillar index.md (generated-at + pillar extras)"
  local pillar pextras
  while IFS=$'\t' read -r pillar pextras; do
    [[ -z "$pillar" ]] && continue
    local pidx="$DOT_LLM_DIR/$pillar/index.md"
    [[ -f "$pidx" ]] || continue
    check_required "$pidx" "$pillar pillar index" generated-at
    [[ -n "$pextras" ]] && check_required_from_csv "$pidx" "$pillar pillar" "$pextras"
  done < <(_doctor_schema_pillar_extras)

  # [3] Entity frontmatter — walk root.entities recursively (no pillar names hardcoded).
  say ""
  say "[3] Entity frontmatter (schema-driven walk of root.entities)"
  local path_pattern fm_csv
  while IFS=$'\t' read -r path_pattern fm_csv; do
    [[ -z "$path_pattern" || -z "$fm_csv" ]] && continue
    while IFS= read -r f; do
      check_required_from_csv "$f" "$path_pattern" "$fm_csv"
      check_apps_value "$f"
    done < <(_doctor_disk_files_for_path "$path_pattern")
  done < <(_doctor_schema_entities)

  # [4] EARS warnings on AC / Requirements sections (any .md that has them).
  say ""
  say "[4] EARS pattern (warning-only)"
  while IFS= read -r f; do
    check_ears "$f" '## Acceptance Criteria'
    check_ears "$f" '## Requirements'
  done < <(find "$DOT_LLM_DIR" -name '*.md' -type f 2>/dev/null | sort)

  # Schema-pass returns based on local error count; orchestrator owns the overall summary.
  if [[ $errors -gt 0 ]]; then
    return 1
  fi
  return 0
}

# --- orchestrator-level checks (each emits exactly one [✓]/[⚠]/[✗] line) ---

_doctor_check_schema_pass() {
  local out exit_code
  # Subshell so the schema pass's local errors/warnings counters don't leak.
  out=$(QUIET=1 errors=0 warnings=0 _doctor_check_schema 2>&1)
  exit_code=$?
  if [[ $exit_code -eq 0 ]]; then
    _doctor_pass "Schema conformance (frontmatter, EARS, version)"
  else
    # Preserve newlines — _doctor_fail indents multi-line details with sed.
    _doctor_fail "Schema conformance" "$out"
  fi
}

# --- orphan check (raiz + pilares) -----------------------------------------
# Walks every `index.md` declared in the schema (raiz + each pillar key under
# root.entities), shows every markdown-table tag found, and lists orphans in
# both directions:
#   ✗ row points at a missing file/dir
#   ⚠ file/dir on disk not claimed by any row (pilares only — raiz's tables
#       hold project-general entities, so reverse scope is too broad there).
# Bash is mechanical (discover + report); the LLM reconciles per the llm-doctor
# skill. Pillar set is schema-driven — never hardcoded, framework-agnostic.

# Pillar keys from schema's root.entities. Empty if pre-v3 or unreadable.
_doctor_orphan_pillars() {
  [[ -f "$SCHEMA" ]] || return 0
  awk '
    /^root:/                          { state = "root"; next }
    state == "root" && /^  entities:/ { state = "ents"; next }
    state == "ents" && /^[^ ]/        { state = "" }
    state == "ents" && /^  [^ ]/      { state = "root" }
    state == "ents" && /^    [a-z][a-z0-9_-]*:[[:space:]]*$/ {
      k = $0; sub(/^    /, "", k); sub(/:[[:space:]]*$/, "", k); print k
    }
  ' "$SCHEMA"
}

# Walk root.entities recursively and emit one TAB-separated record per entity:
#   <disk_path_pattern>\t<frontmatter_csv>
# disk_path is the OS path composed from ancestor `path:` declarations (a node
# without `path:` defaults to its key). frontmatter is the inline-list value
# verbatim from schema (with `!` markers preserved).
#
# Implementation note — Ruby instead of awk: this is the only spot in the CLI
# that needs a true recursive YAML walk. Pure-awk would be ~80 lines of stack
# bookkeeping. Ruby's `psych` ships with macOS stdlib (`ruby -ryaml -e …`),
# and the schema is small. The CLI's only Ruby dependency lives in this one
# function; everything else stays bash + awk.
_doctor_schema_entities() {
  [[ -f "$SCHEMA" ]] || return 0
  command -v ruby >/dev/null 2>&1 || {
    yellow "⚠ ruby not found — schema entity walk skipped (install ruby for full schema-conformance checks)" >&2
    return 0
  }
  ruby -ryaml -e '
    d = YAML.load_file(ARGV[0])
    def walk(node, path)
      ents = node["entities"] || {}
      ents.each do |key, edef|
        seg = edef["path"] || key
        new_path = path.empty? ? seg : "#{path}/#{seg}"
        fm = (edef["frontmatter"] || []).join(",")
        puts "#{new_path}\t#{fm}" unless fm.empty?
        walk(edef, new_path)
      end
    end
    walk(d["root"] || {}, "")
  ' "$SCHEMA"
}

# Same as above but limited to pillars (top-level under root.entities) — emits
# `<pillar_key>\t<frontmatter_csv>`, even when the pillar's frontmatter is
# empty (so `intake → tracker!` and `plans → ` both surface).
_doctor_schema_pillar_extras() {
  [[ -f "$SCHEMA" ]] || return 0
  command -v ruby >/dev/null 2>&1 || return 0
  ruby -ryaml -e '
    d = YAML.load_file(ARGV[0])
    (d.dig("root", "entities") || {}).each do |key, edef|
      fm = (edef["frontmatter"] || []).join(",")
      puts "#{key}\t#{fm}"
    end
  ' "$SCHEMA"
}

# Anchor dir for resolving a table's row paths.
# Raiz index → project root (e.g. components table points at project dirs).
# Pillar index → its own dir (e.g. plans table points at plans/JET-XXXX/).
_doctor_orphan_anchor() {
  local idx="$1"
  if [[ "$idx" == "$DOT_LLM_DIR/index.md" ]]; then
    (cd "$(dirname "$DOT_LLM_DIR")" && pwd)
  else
    dirname "$idx"
  fi
}

# Extract candidate paths from one table row. Each markdown link target and
# each backtick-quoted token is a candidate. The orphan check then resolves
# each against the anchor and picks the first that exists.
_doctor_row_paths() {
  printf '%s\n' "$1" | grep -oE '\[[^]]+\]\([^)]+\)' | sed -E 's/.*\(([^)]+)\)/\1/'
  printf '%s\n' "$1" | grep -oE '`[^`]+`'           | sed -E 's/`//g'
}

_doctor_check_orphans() {
  local pillars=() p
  while IFS= read -r p; do [[ -n "$p" ]] && pillars+=("$p"); done < <(_doctor_orphan_pillars)
  if [[ ${#pillars[@]} -eq 0 ]]; then
    _doctor_warn_emit "Orphan check skipped — schema has no pilares declared under root.entities" \
      "→ Likely a pre-v3 tree; apply the migration first (consult the project's migration docs)."
    return
  fi

  # Indexes to walk: raiz + each pilar declared by the schema.
  local indexes=("$DOT_LLM_DIR/index.md")
  for p in "${pillars[@]}"; do
    indexes+=("$DOT_LLM_DIR/$p/index.md")
  done

  local total_rows=0 total_files=0 total_missing=0
  local report=()
  local idx anchor rel name body header

  for idx in "${indexes[@]}"; do
    rel="${idx#$DOT_LLM_DIR/}"
    if [[ ! -f "$idx" ]]; then
      report+=("─── ${rel}")
      report+=("  ✗ missing — expected by schema")
      total_missing=$((total_missing + 1))
      continue
    fi

    anchor=$(_doctor_orphan_anchor "$idx")
    local printed_header=0

    while IFS= read -r name; do
      [[ -z "$name" ]] && continue
      body=$(fm_block_extract "$idx" "$name")
      header=$(printf '%s\n' "$body" | awk 'NF && /^[[:space:]]*\|/ { print; exit }')
      [[ -z "$header" ]] && continue   # not a markdown-table tag

      if [[ $printed_header -eq 0 ]]; then
        report+=("─── ${rel}")
        printed_header=1
      fi
      report+=("  Table: $name")
      report+=("    $header")

      local claimed=() row found cand label
      while IFS= read -r row; do
        [[ -z "$row" ]] && continue
        [[ "$row" =~ ^[[:space:]]*\| ]] || continue
        [[ "$row" == "$header" ]] && continue
        # Separator row: only |, -, :, spaces.
        if printf '%s\n' "$row" | grep -qE '^[[:space:]]*\|[-:[:space:]\|]+$'; then
          continue
        fi

        # Try each candidate path; first that resolves wins.
        found=""
        while IFS= read -r cand; do
          [[ -z "$cand" ]] && continue
          if [[ -e "$anchor/${cand%/}" ]]; then
            found="${cand%/}"
            break
          fi
        done < <(_doctor_row_paths "$row")

        if [[ -n "$found" ]]; then
          report+=("    ✓ $found")
          claimed+=("$found")
        else
          label=$(_doctor_row_paths "$row" | head -1)
          if [[ -z "$label" ]]; then
            label=$(printf '%s\n' "$row" | awk -F'|' '{print $2}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
          fi
          report+=("    ✗ ${label:-?} — orphan row (no file/dir on disk)")
          total_rows=$((total_rows + 1))
        fi
      done <<< "$body"

      # Reverse direction: pilares only (raiz anchor is project-wide, too broad).
      if [[ "$idx" != "$DOT_LLM_DIR/index.md" ]]; then
        local pdir base c cl reverse_found
        pdir="$(dirname "$idx")"
        while IFS= read -r c; do
          base=$(basename "$c")
          [[ "$base" == "index.md" ]] && continue
          [[ "$base" =~ ^\. ]] && continue
          reverse_found=0
          for cl in "${claimed[@]+"${claimed[@]}"}"; do
            if [[ "$base" == "${cl%/}" || "${base%/}" == "${cl%/}" ]]; then
              reverse_found=1
              break
            fi
          done
          if [[ $reverse_found -eq 0 ]]; then
            report+=("    ⚠ $base — orphan file (on disk, not in table)")
            total_files=$((total_files + 1))
          fi
        done < <(find "$pdir" -mindepth 1 -maxdepth 1 \( -type d -o -name '*.md' \) 2>/dev/null | sort)
      fi
    done < <(fm_block_list "$idx")
  done

  if [[ $total_missing -eq 0 && $total_rows -eq 0 && $total_files -eq 0 ]]; then
    _doctor_pass "Pillar tables aligned with disk (no orphans)"
    return
  fi

  local summary=""
  [[ $total_missing -gt 0 ]] && summary+="${total_missing} missing index.md, "
  [[ $total_rows    -gt 0 ]] && summary+="${total_rows} orphan row(s), "
  [[ $total_files   -gt 0 ]] && summary+="${total_files} orphan file(s), "
  summary="${summary%, }"

  _doctor_warn_emit "Orphan check found drift: $summary" "$(printf '%s\n' "${report[@]}")"
}

# Generic stale-marker detector — any `*.delete-me.md` anywhere under .llm/
# is a work-file the LLM was supposed to delete after finishing a recipe.
# Pillar-agnostic; replaces the v2 archive-specific check.
_doctor_check_stale_markers() {
  local files rels
  files=$(find "$DOT_LLM_DIR" -name '*.delete-me.md' -type f 2>/dev/null)
  if [[ -z "$files" ]]; then
    _doctor_pass "No stale work-marker files (*.delete-me.md)"
  else
    rels=$(printf '%s\n' "$files" | sed "s|$DOT_LLM_DIR/||g")
    _doctor_warn_emit "Stale work-marker file(s) lingering:" \
      "$rels"$'\n'"→ Complete the recipe step that owns each marker and delete the file (likely the LLM forgot to remove it)."
  fi
}

# Workflow-specific checks (tasks-done-without-handoff, orphan delta-drafts
# after archive) **moved out of doctor in v3**. Doctor stays schema-driven and
# pillar-agnostic; workflow integrity is the LLM's responsibility per the
# recipe skills (e.g. llm-archive for sdlc, which owns the archive recipe).

# Validate path-list tag bodies: ANY marker block whose body has lines shaped
# like `- \`<path>\`` is treated as a path-list and its paths are checked. The
# detection is by BODY SHAPE, not by marker name — works for v3's nested names
# (e.g. `plans:plan:handoff:files`) without hardcoding.
_doctor_check_file_refs() {
  local repo_root
  repo_root=$(cd "$(dirname "$DOT_LLM_DIR")" && pwd)

  local missing=() f name body path resolved
  while IFS= read -r f; do
    while IFS= read -r name; do
      [[ -z "$name" ]] && continue
      body=$(fm_block_extract "$f" "$name")
      # Only check blocks shaped like a path-list (at least one line of `- \`path\``)
      printf '%s\n' "$body" | grep -qE '^[[:space:]]*-[[:space:]]+`[^`]+`' || continue
      while IFS= read -r path; do
        [[ -z "$path" ]] && continue
        [[ "$path" == *'<'*'>'* ]] && continue   # template placeholder, skip
        resolved="$repo_root/$path"
        [[ -e "$resolved" ]] || missing+=("${f#$DOT_LLM_DIR/} [${name}]: $path")
      done < <(printf '%s\n' "$body" | awk '
        /^[[:space:]]*-[[:space:]]+`[^`]+`/ {
          match($0, /`[^`]+`/)
          print substr($0, RSTART+1, RLENGTH-2)
        }
      ')
    done < <(fm_block_list "$f")
  done < <(find "$DOT_LLM_DIR" -name '*.md' -type f 2>/dev/null | sort)

  if [[ ${#missing[@]} -eq 0 ]]; then
    _doctor_pass "File references resolve on disk"
  else
    local detail
    detail=$(printf '  • %s\n' "${missing[@]}")
    _doctor_warn_emit "File references not found (${#missing[@]}):" "$detail"
  fi
}

_doctor_check_external_tools() {
  local missing=()
  local tool
  for tool in curl jq git rsync; do
    command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
  done
  if [[ ${#missing[@]} -eq 0 ]]; then
    _doctor_pass "External tools available (curl, jq, git, rsync)"
  else
    _doctor_warn_emit "Missing external tools: ${missing[*]}" "→ Some commands won't work (intake needs curl+jq; sync via git URL needs git)"
  fi
}

# --- driver ---

cmd_doctor() {
  if [[ ! -d "$DOT_LLM_DIR" ]]; then
    red "✗ $DOT_LLM_DIR not found — run 'llm install' first"
    return 1
  fi

  echo "Running diagnostic checks on $DOT_LLM_DIR/ ..."
  echo

  # Reset orchestrator counters (subcommand may be called more than once in a process)
  _doctor_ok=0
  _doctor_warn=0
  _doctor_err=0

  _doctor_check_schema_pass
  _doctor_check_orphans
  _doctor_check_stale_markers
  _doctor_check_file_refs
  _doctor_check_external_tools

  echo
  printf 'Summary: %d error(s), %d warning(s), %d ok\n' "$_doctor_err" "$_doctor_warn" "$_doctor_ok"

  if [[ $_doctor_err -gt 0 ]]; then
    return 1
  fi
  return 0
}
