# cmd_validate.sh — validate a .llm/ tree against the schema.
#
# Expects from the entry-point:
#   DOT_LLM_DIR  — root of the tree to validate (e.g. ./.llm)
#   SCHEMA   — path to schema.yaml inside that tree
#   errors, warnings — counters (must be initialised to 0 before this runs)
#   QUIET    — 0|1 (used by say() in common.sh)
#
# Tier 1 + 2 checks (the schema is canon; the bash mirrors it).
# Cross-file checks (path resolution, depends-on, deltas references) are
# listed in schema.yaml under cross_file_checks_deferred and not yet enforced.

cmd_validate() {
  # Pre-flight: schema must exist
  if [[ ! -f "$SCHEMA" ]]; then
    red "✗ schema not found at $SCHEMA"
    exit 1
  fi

  # Read valid apps from schema (single source of truth)
  local VALID_APPS=()
  while IFS= read -r line; do
    VALID_APPS+=("$line")
  done < <(awk '
    /^apps:[[:space:]]*$/                           { state="apps"; next }
    state=="apps"   && /^[[:space:]]+values:[[:space:]]*$/ { state="values"; next }
    state=="values" && /^[[:space:]]+-[[:space:]]+/ {
      sub(/^[[:space:]]+-[[:space:]]+/, "")
      sub(/[[:space:]]+#.*/, "")
      sub(/[[:space:]]+$/, "")
      if (length($0) > 0) print
      next
    }
    state=="values" && /^[a-zA-Z]/                  { exit }
  ' "$SCHEMA")

  if [[ ${#VALID_APPS[@]} -eq 0 ]]; then
    red "✗ failed to parse apps.values from $SCHEMA"
    exit 1
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

  # check helpers
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

  check_ears() {
    local file="$1" section_marker="$2"
    local found
    found=$(awk -v marker="$section_marker" -v f="$file" '
      $0 ~ marker {section=1; next}
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

  # H1 check helper — every markdown must have at least one H1
  check_h1() {
    local file="$1"
    if ! grep -qE '^# ' "$file"; then
      red "  ✗ $file: missing H1 heading"
      errors=$((errors + 1))
    fi
  }

  say "Validating $DOT_LLM_DIR/ ..."

  # [0] Every .md has an H1
  say ""
  say "[0] H1 heading on every markdown"
  while IFS= read -r f; do
    check_h1 "$f"
  done < <(find "$DOT_LLM_DIR" -name '*.md' -type f 2>/dev/null | sort)

  # [1] Universal: every index.md
  say ""
  say "[1] index.md universal frontmatter"
  while IFS= read -r f; do
    check_required "$f" "index" generated apps
    check_apps_value "$f"
  done < <(find "$DOT_LLM_DIR" -name index.md -type f 2>/dev/null | sort)

  # [2] Plans + tasks
  say ""
  say "[2] Plans and tasks"
  for d in "$DOT_LLM_DIR"/plans/*/; do
    [[ -d "$d" ]] || continue
    pi="$d/index.md"
    if [[ -f "$pi" ]]; then
      check_required "$pi" "plan" generated apps status summary scope
      check_apps_value "$pi"
      check_ears "$pi" '## Acceptance Criteria'
    fi
    for tf in "$d"/t*.md; do
      [[ -f "$tf" ]] || continue
      base=$(basename "$tf")
      [[ "$base" == handoff-* ]] && continue
      check_required "$tf" "task" plan task depends-on concerns files status apps
      check_apps_value "$tf"
    done
  done

  # [3] Spec areas + concerns
  say ""
  say "[3] Spec areas and concerns"
  for d in "$DOT_LLM_DIR"/specs/*/; do
    [[ -d "$d" ]] || continue
    ai="$d/index.md"
    if [[ -f "$ai" ]]; then
      check_required "$ai" "spec area" generated name summary depends-on apps deltas
      check_apps_value "$ai"
      check_ears "$ai" '## Requirements'
    fi
    for cf in "$d"/*.md; do
      [[ -f "$cf" ]] || continue
      base=$(basename "$cf")
      [[ "$base" == "index.md" ]] && continue
      # history.md is the transient working file produced by `llm specs
      # consolidate` and deleted by the LLM once the spec is rewritten.
      # Skip it during validation so a partial consolidation does not block
      # validation of the rest of the tree.
      [[ "$base" == "history.md" ]] && continue
      # bootstrap.md is the persistent discovery log produced by `llm specs
      # bootstrap` and grown by `llm specs deep`. Skip during validation.
      [[ "$base" == "bootstrap.md" ]] && continue
      check_required "$cf" "spec concern" generated apps
      check_apps_value "$cf"
    done
  done

  # [4] Archive
  say ""
  say "[4] Archive"
  for d in "$DOT_LLM_DIR"/archive/*/; do
    [[ -d "$d" ]] || continue
    ai="$d/index.md"
    [[ -f "$ai" ]] || continue
    check_required "$ai" "archive" generated status summary apps
    check_apps_value "$ai"
  done

  # [5] Exploring
  say ""
  say "[5] Exploring"
  for d in "$DOT_LLM_DIR"/exploring/*/; do
    [[ -d "$d" ]] || continue
    ei="$d/index.md"
    [[ -f "$ei" ]] || continue
    check_required "$ei" "exploring idea" generated status apps summary
    check_apps_value "$ei"
  done

  # Summary
  say ""
  if [[ $errors -eq 0 && $warnings -eq 0 ]]; then
    green "✓ All checks passed (0 errors, 0 warnings)"
  elif [[ $errors -eq 0 ]]; then
    yellow "⚠ $warnings warnings (no errors)"
  else
    red "✗ $errors errors, $warnings warnings"
    return 1
  fi
}
