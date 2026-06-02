# cmd_doctor.sh — run health checks on a .cumaru/ tree.
#
# `cumaru doctor` runs all checks: schema conformance plus tree-wide
# structural checks. Each check emits one of:
#   [✓] label                     — pass
#   [⚠] label   detail            — soft issue (warning; never fails)
#   [✗] label   detail            — hard issue (error; exit 1 at end)
#
# Composition (v4 — pillar-agnostic; structural checks use the schema):
#   1. Schema conformance — universal markdown, index.md, pillar index, entity
#      frontmatter, EARS, framework-version match. Walks root.entities from
#      schema.yaml; no hardcoded pillar names.
#   2. Orphan check — walks raiz + pilares (from root.entities), shows every
#      markdown-table tag found, lists orphans both ways. LLM reconciles.
#   3. Stale work-marker files (any *.delete-me.md anywhere under .cumaru/).
#   4. Unrefined RAW blocks (any Markdown file containing <!-- BEGIN RAW).
#   5. File references — links inside [Link, Description] tag bodies exist on
#      disk (`reference` rows resolve from the project root; breaking the
#      source-file rule reports as invalid).
#   6. External tools available (curl, jq, git).
#   7. Agent hook — CUMARU-HOOK block in AGENTS.md / CLAUDE.md present and
#      matching canonical prose; warns if missing or drifted.
#
# Workflow-specific checks (tasks-done-without-handoff, orphan delta-drafts
# after archive) **moved out of doctor in v4** — workflow integrity is
# LLM-driven; doctor stays mechanical and pillar-agnostic.
#
# Expects from the entry-point: CUMARU_DIR, SCHEMA, QUIET. Reuses fm_*
# helpers from common.sh.

cmd_doctor_help() {
  cat <<'EOF'
cumaru doctor — run health checks on the .cumaru/ tree

Usage:
  cumaru doctor [--quiet]

Options:
  --quiet   suppress [✓] pass lines; warnings, errors, and the summary still print.

Checks (v4 — pillar-agnostic; structural checks use the schema):
  [1] Schema conformance — sub-passes:
        [0] H1 + human_revised on every .md (rules.markdown)
        [1] index.md universal frontmatter (generated, apps; apps values valid)
        [2] Pillar index.md (generated-at + pillar extras like intake.tracker)
        [3] Entity frontmatter (schema-driven walk of root.entities)
        [4] Pattern rules (EARS, GWT, …) — schema-driven from rules.*
        Cross — framework-version in .cumaru/index.md ≡ version in schema.yaml.
  [2] Orphan check — walks raiz + pilares (from root.entities), shows each
      markdown-table tag, reports both directions:
        ✗ row points at a missing file/dir
        ⚠ file/dir on disk not claimed by any row (pilares only)
      The LLM reconciles per the orphan-row guidance in the cumaru-doctor skill.
  [3] Stale work-marker files — any `*.delete-me.md` anywhere under .cumaru/.
  [4] Unrefined RAW blocks — any Markdown file containing `<!-- BEGIN RAW`.
  [5] File references — links inside [Link, Description] tag bodies resolve on
      disk. `reference` rows resolve from the project root and must target
      repository source files; rule-breaking rows report as invalid.
  [6] External tools available (curl, jq, git).
  [7] Agent hook — CUMARU-HOOK block in AGENTS.md / CLAUDE.md present and
      matching the canonical prose (warning if missing or drifted).

  Workflow-specific checks (tasks-done-without-handoff, orphan delta-drafts)
  moved to domain-specific recipe skills (e.g. cumaru-archive for sdlc) — doctor stays mechanical.

  Pattern rules are schema-driven: each rules.<name> declaring a `pattern:` +
  `applies_to:` (e.g. ears, gherkin) is scanned. Bullets under the named
  section that don't match emit that rule's severity (warning unless the rule
  declares severity: error). The section marker is the quoted substring of each
  applies_to entry. Cross-file checks (path resolution, depends-on, deltas
  references) are listed in schema.yaml under cross_file_checks.deferred.

Exit codes:
  0   all checks pass (warnings allowed)
  1   at least one error
  2   usage error (unknown flag)

Examples:
  cumaru                                       equivalent to cumaru doctor (default)
  cumaru doctor --quiet                      hide pass lines; show warnings + errors
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

# --- schema conformance check (v4, fully schema-driven) ----------------------
#
# Walks `root.entities` recursively (via the helpers above) and validates
# every entity's frontmatter against the spec declared in schema.yaml. NO
# hardcoded pillar names anywhere — adding a new pillar to the schema is
# enough; this check picks it up automatically. The previous v2 version had
# hand-rolled sub-passes for plans / specs / archive / exploring; v4 collapses
# them into the schema walk.

# Read meta.apps.values (v4 location). Each line = one valid app key.
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

# Read every pattern rule under `rules:` — any rule that declares both a
# `pattern:` and an `applies_to:` list (e.g. `ears`, `gherkin`). Emits one
# TAB-separated record per (rule × applies_to entry):
#   <severity>\t<pattern>\t<section-marker>
# The section marker is the quoted substring of each applies_to entry
# (`- intake tickets — "## Acceptance Criteria (EARS)"` → `## Acceptance
# Criteria (EARS)`); entries without quotes fall back to the trimmed bullet.
# This is what makes EARS/GWT/any future rule fully schema-driven — the doctor
# carries no hardcoded section names or regexes.
_doctor_pattern_rules() {
  [[ -f "$SCHEMA" ]] || return 0
  awk '
    /^rules:[[:space:]]*$/                              { st="rules"; next }
    st=="rules" && /^[^ ]/                              { st="" }
    st=="rules" && /^  [a-zA-Z][a-zA-Z0-9_-]*:[[:space:]]*$/ {
      sev=""; pat=""; inap=0; next
    }
    st=="rules" && /^    severity:[[:space:]]/ {
      sev=$0; sub(/^    severity:[[:space:]]*/, "", sev); sub(/[[:space:]]+$/, "", sev); next
    }
    st=="rules" && /^    pattern:[[:space:]]/ {
      pat=$0; sub(/^    pattern:[[:space:]]*/, "", pat)
      if (match(pat, /"[^"]*"/)) {
        pat=substr(pat, RSTART+1, RLENGTH-2)             # quoted value — ignores any trailing # comment
      } else {
        sub(/[[:space:]]*#.*/, "", pat); sub(/[[:space:]]+$/, "", pat)  # bare value — strip comment + trailing space
      }
      next
    }
    st=="rules" && /^    applies_to:[[:space:]]*$/      { inap=1; next }
    st=="rules" && inap && /^      -[[:space:]]/ {
      m=$0
      if (match(m, /"[^"]*"/)) { mk=substr(m, RSTART+1, RLENGTH-2) }
      else { mk=m; sub(/^      -[[:space:]]*/, "", mk); sub(/[[:space:]]+$/, "", mk) }
      if (pat != "" && mk != "") print sev "\t" pat "\t" mk
      next
    }
    st=="rules" && /^    [a-zA-Z]/                      { inap=0 }
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
  # Quote the dir (it may contain spaces) but leave $glob unquoted so it still
  # expands; an unquoted $CUMARU_DIR would word-split a path with spaces and
  # silently match nothing, making this sub-pass check zero files.
  for f in "$CUMARU_DIR"/$glob; do
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

  # Read valid apps from schema (v4: meta.apps.values)
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
  local front_door="$CUMARU_DIR/index.md"
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

  # Generic pattern-rule check (schema-driven). Replaces the hardcoded EARS
  # scan: the section marker, the regex, and the severity all arrive from the
  # schema's rules.* (see _doctor_pattern_rules). A bullet under the named
  # section that does NOT match the pattern emits `sev` (warning unless the
  # rule declares severity: error). The marker is matched as a LITERAL prefix
  # (index == 1), so prose that merely cites the heading inside backticks
  # (`## Requirements (EARS)`) never toggles the scanner — only a real heading
  # at column 1 does.
  check_pattern() {
    local file="$1" sev="$2" pat="$3" marker="$4"
    local found
    found=$(awk -v marker="$marker" -v pat="$pat" -v f="$file" '
      index($0, marker) == 1 { section=1; next }
      /^## / { section=0 }
      section && /^- / && $0 !~ pat {
        print f ":" NR ": " $0
      }
    ' "$file")
    [[ -z "$found" ]] && return 0
    local line
    while IFS= read -r line; do
      if [[ "$sev" == "error" ]]; then
        red "  ✗ pattern ($marker): $line"
        errors=$((errors + 1))
      else
        yellow "  ⚠ pattern ($marker): $line"
        warnings=$((warnings + 1))
      fi
    done <<< "$found"
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

  say "Running diagnostic checks on $CUMARU_DIR/ ..."

  # [0] H1 + human_revised on every .md (rules.markdown)
  say ""
  say "[0] Universal markdown (H1, human_revised)"
  while IFS= read -r f; do
    check_h1 "$f"
    check_human_revised "$f"
  done < <(find "$CUMARU_DIR" -name '*.md' -type f 2>/dev/null | sort)

  # [1] index.md universal frontmatter (rules.index_md: generated, apps)
  say ""
  say "[1] index.md universal frontmatter (generated, apps)"
  while IFS= read -r f; do
    check_required "$f" "index" generated apps
    check_apps_value "$f"
  done < <(find "$CUMARU_DIR" -name index.md -type f 2>/dev/null | sort)

  # [2] Pillar index.md — rules.pillar_index (generated-at) + pillar's own extras.
  say ""
  say "[2] Pillar index.md (generated-at + pillar extras)"
  local pillar pextras
  while IFS=$'\t' read -r pillar pextras; do
    [[ -z "$pillar" ]] && continue
    local pidx="$CUMARU_DIR/$pillar/index.md"
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

  # [4] Pattern rules (schema-driven) — EARS, GWT, and any future rules.<name>
  # carrying a `pattern:` + `applies_to:`. Each (severity, pattern, marker) is
  # read once from the schema; every .md is scanned against every rule. No
  # section name or regex is hardcoded here anymore.
  say ""
  say "[4] Pattern rules (schema-driven: EARS, GWT, …)"
  # sort -u dedups identical (severity, pattern, marker) triples — several
  # applies_to entries can share one marker (e.g. "intake tickets" and
  # "slug-based plans" both map to "## Acceptance Criteria (EARS)"); without
  # this each shared-marker bullet would be flagged once per entry.
  local _pat_rules=() _pr _sev _pat _marker
  while IFS= read -r _pr; do
    [[ -n "$_pr" ]] && _pat_rules+=("$_pr")
  done < <(_doctor_pattern_rules | sort -u)
  while IFS= read -r f; do
    for _pr in "${_pat_rules[@]+"${_pat_rules[@]}"}"; do
      IFS=$'\t' read -r _sev _pat _marker <<< "$_pr"
      check_pattern "$f" "$_sev" "$_pat" "$_marker"
    done
  done < <(find "$CUMARU_DIR" -name '*.md' -type f 2>/dev/null | sort)

  # Schema-pass returns based on local error count; orchestrator owns the overall summary.
  # Clean up inner helpers — bash functions defined inside a function are NOT
  # scoped to it; they persist in the global namespace after return. Remove them
  # explicitly so they don't shadow unrelated code in future callers.
  unset -f fm has_key check_required check_apps_value \
            check_required_from_csv check_pattern check_h1 check_human_revised

  # Emit the warning tally on a sentinel line so the orchestrator — which runs
  # this function in a captured subshell — can surface pattern warnings (EARS /
  # GWT) even when there are zero errors. The orchestrator strips this line.
  printf 'WARNCOUNT:%s\n' "$warnings"

  if [[ $errors -gt 0 ]]; then
    return 1
  fi
  return 0
}

# --- orchestrator-level checks (each emits exactly one [✓]/[⚠]/[✗] line) ---

_doctor_check_schema_pass() {
  local out exit_code warn_count
  # Subshell so the schema pass's local errors/warnings counters don't leak.
  out=$(QUIET=1 errors=0 warnings=0 _doctor_check_schema 2>&1)
  exit_code=$?

  # Pull the warning tally out of the sentinel line, then strip it from the
  # detail. With QUIET=1 the captured `out` holds only the red/yellow problem
  # lines (the [0]..[4] headers are suppressed), so when there are no errors it
  # is exactly the pattern-rule (EARS/GWT) warnings.
  warn_count=$(printf '%s\n' "$out" | sed -n 's/^WARNCOUNT:\([0-9][0-9]*\)$/\1/p' | tail -1)
  [[ -z "$warn_count" ]] && warn_count=0
  out=$(printf '%s\n' "$out" | grep -v '^WARNCOUNT:')

  if [[ $exit_code -ne 0 ]]; then
    # Errors present — the detail already includes any warning lines too.
    _doctor_fail "Schema conformance" "$out"
  elif [[ "$warn_count" -gt 0 ]]; then
    # No errors, but pattern rules flagged bullets — surface them in the summary
    # instead of swallowing them (the old behaviour discarded `out` on pass).
    _doctor_warn_emit "Schema conformance: ${warn_count} pattern warning(s) (EARS/GWT)" "$out"
  else
    _doctor_pass "Schema conformance (frontmatter, patterns, version)"
  fi
}

# --- orphan check (raiz + pilares) -----------------------------------------
# Walks every `index.md` declared in the schema (raiz + each pillar key under
# root.entities), shows every markdown-table tag found, and lists orphans in
# both directions:
#   ✗ row points at a missing file/dir
#   ⚠ file/dir on disk not claimed by any row (pilares only — raiz's tables
#       hold project-general entities, so reverse scope is too broad there).
# Bash is mechanical (discover + report); the LLM reconciles per the cumaru-doctor
# skill. Pillar set is schema-driven — never hardcoded, framework-agnostic.

# Pillar keys from schema's root.entities. Empty if pre-v4 or unreadable.
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
# Raiz index / domain.md → project root (e.g. components table points at
# project dirs). Pillar index → its own dir (e.g. plans table points at
# plans/AAA-XXXX/).
_doctor_orphan_anchor() {
  local idx="$1"
  if [[ "$idx" == "$CUMARU_DIR/index.md" || "$idx" == "$CUMARU_DIR/domain.md" ]]; then
    (cd "$(dirname "$CUMARU_DIR")" && pwd)
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
      "→ Likely a pre-v4 tree; apply the migration first (consult the project's migration docs)."
    return
  fi

  # Indexes to walk: raiz + domain.md (hosts the components table) + each
  # pilar declared by the schema.
  local indexes=("$CUMARU_DIR/index.md" "$CUMARU_DIR/domain.md")
  for p in "${pillars[@]}"; do
    indexes+=("$CUMARU_DIR/$p/index.md")
  done

  local total_rows=0 total_files=0 total_missing=0
  local report=()
  local idx anchor rel name body header

  for idx in "${indexes[@]}"; do
    rel="${idx#"$CUMARU_DIR"/}"
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

      # v4: every tag body is a [Link, Description] table. For the archive
      # pillar specifically, the ephemeral-directory model (pruned after Phase
      # 4) means a row whose Link points at a missing dir is EXPECTED — that's
      # the post-prune steady state. We tolerate it on archive/index.md only
      # and let the row description carry the commit reference.
      local archive_tolerate=0
      [[ "$name" == "archive" ]] && archive_tolerate=1

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
        elif [[ $archive_tolerate -eq 1 ]]; then
          # Archive row pointing at a pruned dir is expected; not an orphan.
          label=$(_doctor_row_paths "$row" | head -1)
          [[ -z "$label" ]] && label=$(printf '%s\n' "$row" | awk -F'|' '{print $2}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
          report+=("    ✓ ${label:-?} (archived — directory pruned)")
        else
          label=$(_doctor_row_paths "$row" | head -1)
          if [[ -z "$label" ]]; then
            label=$(printf '%s\n' "$row" | awk -F'|' '{print $2}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
          fi
          report+=("    ✗ ${label:-?} — orphan row (no file/dir on disk)")
          total_rows=$((total_rows + 1))
        fi
      done <<< "$body"

      # Reverse direction: pilares only (raiz/domain anchor is project-wide,
      # too broad).
      if [[ "$idx" != "$CUMARU_DIR/index.md" && "$idx" != "$CUMARU_DIR/domain.md" ]]; then
        local pdir base c cl reverse_found
        pdir="$(dirname "$idx")"
        while IFS= read -r c; do
          base=$(basename "$c")
          [[ "$base" == "index.md" ]] && continue
          [[ "$base" =~ ^\. ]] && continue
          reverse_found=0
          for cl in "${claimed[@]+"${claimed[@]}"}"; do
            # Three forms a claimed path can take for the same entry:
            #   "AAA-1234"            → ${cl%/}  matches base directly
            #   "AAA-1234/"           → ${cl%/} = "AAA-1234" matches base
            #   "AAA-1234/index.md"   → ${cl%%/*} = "AAA-1234" matches base
            # Without the third check a link to `path/index.md` would cause
            # the directory to be falsely reported as an orphan file.
            if [[ "$base" == "${cl%/}" || "${base%/}" == "${cl%/}" || "$base" == "${cl%%/*}" ]]; then
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

# Generic stale-marker detector — any `*.delete-me.md` anywhere under .cumaru/
# is a work-file the LLM was supposed to delete after finishing a recipe.
# Pillar-agnostic; replaces the v2 archive-specific check.
_doctor_check_stale_markers() {
  local files rels
  files=$(find "$CUMARU_DIR" -name '*.delete-me.md' -type f 2>/dev/null)
  if [[ -z "$files" ]]; then
    _doctor_pass "No stale work-marker files (*.delete-me.md)"
  else
    # Strip the .cumaru/ prefix per-line via parameter expansion (the quoted
    # prefix is matched literally) — a sed `s|$CUMARU_DIR/|` would break if the
    # install path contained `|`, `&`, `\`, or a glob char.
    rels=$(printf '%s\n' "$files" | while IFS= read -r _df; do
      [[ -n "$_df" ]] && printf '%s\n' "${_df#"$CUMARU_DIR"/}"
    done)
    _doctor_warn_emit "Stale work-marker file(s) lingering:" \
      "$rels"$'\n'"→ Complete the recipe step that owns each marker and delete the file (likely the LLM forgot to remove it)."
  fi
}

# A RAW block is an explicit handoff marker: the source content still needs
# LLM refinement. Detect by marker shape across the tree, without hardcoding a
# pillar or entity type.
_doctor_check_raw_blocks() {
  local files rels
  files=$(find "$CUMARU_DIR" -name '*.md' -type f -exec grep -lF '<!-- BEGIN RAW' {} + 2>/dev/null)
  if [[ -z "$files" ]]; then
    _doctor_pass "No unrefined RAW blocks"
  else
    rels=$(printf '%s\n' "$files" | while IFS= read -r _rf; do
      [[ -n "$_rf" ]] && printf '%s\n' "${_rf#"$CUMARU_DIR"/}"
    done)
    _doctor_warn_emit "Unrefined RAW block(s) found:" \
      "$rels"$'\n'"→ Refine each item and delete its BEGIN/END RAW block."
  fi
}

# Workflow-specific checks (tasks-done-without-handoff, orphan delta-drafts
# after archive) **moved out of doctor in v4**. Doctor stays schema-driven and
# pillar-agnostic; workflow integrity is the LLM's responsibility per the
# recipe skills (e.g. cumaru-archive for sdlc, which owns the archive recipe).

# v4: every tag body is a [Link, Description] table. Validate that each link's
# target path resolves on disk. The orphan check (above) already covers links
# anchored at pillar/raiz indexes; this check is the catch-all for every other
# .md that hosts a tag — `templates/index.md`, sub-area indexes, handoffs, etc.
# Detection is by BODY SHAPE (lines containing `[name](path)`), not by marker
# name. Files already audited by the orphan check are skipped to avoid double-
# counting. The anchor for resolving each link is the file's own directory
# (relative links inside a .md resolve next to the .md), not the project root —
# EXCEPT `reference` rows, which resolve from the project root and must target
# repository source files (the coverage rule); rows breaking it are `invalid`.
_doctor_check_file_refs() {
  local missing=() invalid=() file tag link desc target status
  while IFS=$'\t' read -r file tag link desc target status; do
    case "$status" in
      missing) missing+=("${file} [${tag}]: ${target}") ;;
      invalid) invalid+=("${file} [${tag}]: ${target}") ;;
    esac
  done < <(fm_tag_table_rows "$CUMARU_DIR")

  if [[ ${#missing[@]} -eq 0 && ${#invalid[@]} -eq 0 ]]; then
    _doctor_pass "File references resolve on disk"
  else
    local detail=""
    if [[ ${#missing[@]} -gt 0 ]]; then
      detail+=$(printf '  • %s\n' "${missing[@]}")
    fi
    if [[ ${#invalid[@]} -gt 0 ]]; then
      [[ -n "$detail" ]] && detail+=$'\n'
      detail+=$(printf '  • %s — invalid reference (must be a repository source file, project-root-relative)\n' "${invalid[@]}")
    fi
    _doctor_warn_emit "File references not found or invalid ($((${#missing[@]} + ${#invalid[@]}))):" "$detail"
  fi
}

_doctor_check_external_tools() {
  local missing=()
  local tool
  for tool in curl jq git; do
    command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
  done
  if [[ ${#missing[@]} -eq 0 ]]; then
    _doctor_pass "External tools available (curl, jq, git)"
  else
    _doctor_warn_emit "Missing external tools: ${missing[*]}" "→ Some commands won't work (intake needs curl+jq; update from a git URL needs git)"
  fi
}

# Check the CUMARU-HOOK block in the adopter's AGENTS.md / CLAUDE.md.
# Warns if the block is missing or its prose diverges from the canonical —
# the LLM decides whether to accept the drift or reconcile via cumaru update.
_doctor_check_agent_hook() {
  local parent
  parent="$(dirname "$CUMARU_DIR")"

  # Locate the agents instruction file.
  local agents_file=""
  if [[ -f "$parent/$AGENTS_DIR/AGENTS.md" ]]; then
    agents_file="$parent/$AGENTS_DIR/AGENTS.md"
  elif [[ -f "$parent/CLAUDE.md" ]]; then
    agents_file="$parent/CLAUDE.md"
  fi

  if [[ -z "$agents_file" ]]; then
    _doctor_warn_emit "No AGENTS.md or CLAUDE.md found — CUMARU-HOOK not present" \
      "→ Run 'cumaru install' or 'cumaru update --apply' to wire the agent hook."
    return
  fi

  # Does the hook block exist at all?
  if ! grep -qF "BEGIN CUMARU-HOOK" "$agents_file"; then
    _doctor_warn_emit "CUMARU-HOOK not found in $(basename "$agents_file")" \
      "→ Run 'cumaru update --apply' to create it."
    return
  fi

  # Extract existing hook block between BEGIN and END markers.
  local existing_hook
  existing_hook=$(awk '
    /<!-- BEGIN CUMARU-HOOK/ { h=1; print; next }
    h && /<!-- END CUMARU-HOOK -->/ { print; h=0; next }
    h { print }
  ' "$agents_file")

  # Generate the canonical block. rel_index is always .cumaru/index.md. A freshly
  # created instruction file intentionally uses the "created" marker so
  # uninstall can decide whether the whole file may be removed.
  local canonical_hook
  if grep -qF "<!-- BEGIN CUMARU-HOOK created -->" "$agents_file"; then
    canonical_hook=$(_cumaru_hook_block "$CUMARU_DIR/index.md" "1")
  else
    canonical_hook=$(_cumaru_hook_block "$CUMARU_DIR/index.md" "0")
  fi

  if [[ "$existing_hook" != "$canonical_hook" ]]; then
    local diff_output
    diff_output=$(diff <(echo "$canonical_hook") <(echo "$existing_hook") 2>/dev/null || true)
    _doctor_warn_emit "CUMARU-HOOK block in $(basename "$agents_file") differs from canonical" \
      "$diff_output"
  else
    _doctor_pass "CUMARU-HOOK block matches canonical"
  fi
}

# --- driver ---

cmd_doctor() {
  if [[ ! -d "$CUMARU_DIR" ]]; then
    red "✗ $CUMARU_DIR not found — run 'cumaru install' first"
    return 1
  fi

  echo "Running diagnostic checks on $CUMARU_DIR/ ..."
  echo

  # Reset orchestrator counters (subcommand may be called more than once in a process)
  _doctor_ok=0
  _doctor_warn=0
  _doctor_err=0

  _doctor_check_schema_pass
  _doctor_check_orphans
  _doctor_check_stale_markers
  _doctor_check_raw_blocks
  _doctor_check_file_refs
  _doctor_check_external_tools
  _doctor_check_agent_hook

  echo
  printf 'Summary: %d error(s), %d warning(s), %d ok\n' "$_doctor_err" "$_doctor_warn" "$_doctor_ok"

  if [[ $_doctor_err -gt 0 ]]; then
    return 1
  fi
  return 0
}
