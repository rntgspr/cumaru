# cmd_coverage.sh — specification coverage: which repository source files are
# referenced by the durable specification pillar, and which are not.
#
# Forms:
#   cumaru coverage                 full report (refs, covered, uncovered, stale, invalid)
#   cumaru coverage --refs          list every reference row, grouped by spec file
#   cumaru coverage --gaps          list only uncovered source files (one per line)
#   cumaru coverage --rows          machine-readable TSV: bucket<TAB>path<TAB>spec_host<TAB>detail
#   cumaru coverage --strict        exit 1 when any uncovered/stale/invalid entry exists (CI gate)
#
# Model:
#   Spec files under the durable pillar carry `<!-- cumaru:reference -->` blocks —
#   [Link, Description] tables whose rows ALWAYS target repository source
#   files, resolved from the project root (never a path inside .cumaru/, never a
#   directory, never a URL). A source file with at least one reference row is
#   COVERED by the specification; a source file with none is UNCOVERED.
#
# Schema attributes (meta section):
#   specification_dir: <pillar>   which pillar holds the durable specification
#                                 (specs | topology | coverage | ...); default: specs
#   coverage.source: [globs]      which repository files count as coverable
#                                 source. fnmatch-style, `*` crosses `/`
#                                 (so `src/**` and `src/*` are equivalent).
#                                 Empty/absent = every tracked file.
#                                 .cumaru/ and .agents/ are always excluded.
#
# The source file list comes from `git ls-files` (tracked files only), so the
# command requires a git work tree. Read-only: nothing is written.
#
# Expects from entry-point: CUMARU_DIR, SCHEMA. Reuses fm_* from common.sh.

cmd_coverage_help() {
  cat <<'EOF'
cumaru coverage — report spec↔code reference coverage

Usage:
  cumaru coverage [--refs|--gaps|--rows] [--strict]

Modes (mutually exclusive):
  (default)   full report: refs, covered, uncovered, stale, invalid
  --refs      list every reference row, grouped by spec file
  --gaps      list only uncovered source files (one per line, pipeable)
  --rows      machine-readable TSV: bucket<TAB>path<TAB>spec_host<TAB>detail
              (buckets: covered, uncovered, stale, invalid, foreign)

Flags:
  --strict    exit 1 when any uncovered, stale, or invalid entry exists

Model:
  Spec files under the durable pillar (schema `meta.specification_dir`,
  default `specs`) carry <!-- cumaru:reference --> blocks. Every row targets a
  repository source file, resolved from the project root:

    | Link                        | Description                            |
    |-----------------------------|----------------------------------------|
    | [util/logger](src/util/logger.ts) | Util used to log, terminal only  |

  A source file referenced by at least one row is covered. Source files come
  from `git ls-files`, optionally narrowed by the `meta.coverage.source` glob
  array in schema.yaml. .cumaru/ and .agents/ are always excluded.

Buckets:
  covered     source file with at least one reference row
  uncovered   source file with no reference row — no spec covers it
  stale       reference row pointing at a file that no longer exists
  invalid     reference row breaking the source-file rule (path inside .cumaru/,
              a directory, an absolute path, a URL, or an anchor)
  foreign     reference row whose target exists but is outside the source
              scope (untracked or filtered out by coverage.source globs)

Exit codes:
  0  success (report printed; gaps allowed without --strict)
  1  runtime error, or --strict with uncovered/stale/invalid entries
  2  usage error
EOF
}

# Read `meta.specification_dir` from the schema. Empty when absent.
_coverage_spec_dir() {
  [[ -f "$SCHEMA" ]] || return 0
  yq '.meta.specification_dir // ""' "$SCHEMA"
}

# Read the `meta.coverage.source` glob array (block or inline form), one glob
# per line. Empty when absent.
_coverage_source_globs() {
  [[ -f "$SCHEMA" ]] || return 0
  yq '.meta.coverage.source[]' "$SCHEMA"
}

# Emit the coverable source files (project-root-relative, sorted): tracked
# files, always excluding .cumaru/ and .agents/, narrowed by globs when present.
# `*` in a glob crosses `/` (bash pattern match, not pathname expansion).
_coverage_source_files() {
  local proj="$1" globs_file="$2"
  local f g matched

  # quotepath=off: keep non-ASCII paths literal (the default C-escapes and
  # quotes them, which would break glob matching and the covered/uncovered diff).
  git -C "$proj" -c core.quotepath=off ls-files | while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    case "$f" in
      .cumaru/*|.agents/*) continue ;;
    esac
    if [[ -s "$globs_file" ]]; then
      matched=0
      while IFS= read -r g; do
        [[ -z "$g" ]] && continue
        # shellcheck disable=SC2053
        if [[ "$f" == $g ]]; then
          matched=1
          break
        fi
      done < "$globs_file"
      [[ $matched -eq 1 ]] || continue
    fi
    printf '%s\n' "$f"
  done | sort -u
}

cmd_coverage() {
  local mode="report" strict=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help|help) cmd_coverage_help; return 0 ;;
      --refs|--gaps|--rows)
        if [[ "$mode" != "report" ]]; then
          red "✗ pick one mode: --refs, --gaps, or --rows"
          return 2
        fi
        mode="${1#--}"
        shift ;;
      --strict) strict=1; shift ;;
      *)
        red "✗ unknown argument: $1"
        cmd_coverage_help
        return 2 ;;
    esac
  done

  [[ -d "$CUMARU_DIR" ]] || { red "✗ $CUMARU_DIR not found — run 'cumaru install' first"; return 1; }
  [[ -f "$SCHEMA" ]] || { red "✗ $SCHEMA not found — not a dot-llm tree?"; return 1; }

  local spec_dir
  spec_dir=$(_coverage_spec_dir)
  [[ -n "$spec_dir" ]] || spec_dir="specs"
  if [[ ! -d "$CUMARU_DIR/$spec_dir" ]]; then
    red "✗ $CUMARU_DIR/$spec_dir/ not found"
    yellow "  → set 'specification_dir:' under 'meta:' in $SCHEMA to the pillar that holds the durable specification (default: specs)"
    return 1
  fi

  local proj
  proj=$(cd "$(dirname "$CUMARU_DIR")" 2>/dev/null && pwd -P)
  if [[ -z "$proj" ]] || ! git -C "$proj" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    red "✗ cumaru coverage needs a git work tree — the source file list comes from 'git ls-files'"
    return 1
  fi

  local globs_file source_file covered_file refs_file stale_file invalid_file foreign_file uncovered_file
  globs_file=$(mktemp); source_file=$(mktemp); covered_file=$(mktemp)
  refs_file=$(mktemp); stale_file=$(mktemp); invalid_file=$(mktemp)
  foreign_file=$(mktemp); uncovered_file=$(mktemp)
  # shellcheck disable=SC2064
  trap "rm -f '$globs_file' '$source_file' '$covered_file' '$refs_file' '$stale_file' '$invalid_file' '$foreign_file' '$uncovered_file'; trap - RETURN" RETURN

  _coverage_source_globs > "$globs_file"
  _coverage_source_files "$proj" "$globs_file" > "$source_file"

  # Split every reference row hosted under the spec pillar into buckets.
  # refs_file:    host<TAB>link<TAB>desc<TAB>target<TAB>status  (all rows, for --refs)
  # covered_file: target paths of ok rows
  local file tag link desc target status outside=0
  while IFS=$'\t' read -r file tag link desc target status; do
    [[ "$tag" == "reference" ]] || continue
    case "$status" in
      template|empty) continue ;;
    esac
    if [[ "$file" != "$spec_dir"/* ]]; then
      outside=$((outside + 1))
      continue
    fi
    printf '%s\t%s\t%s\t%s\t%s\n' "$file" "$link" "$desc" "$target" "$status" >> "$refs_file"
    case "$status" in
      ok)      printf '%s\n' "$target" >> "$covered_file" ;;
      missing) printf '%s\t%s\t%s\n' "$target" "$file" "$link" >> "$stale_file" ;;
      *)       printf '%s\t%s\t%s\n' "$target" "$file" "$link" >> "$invalid_file" ;;
    esac
  done < <(fm_tag_table_rows "$CUMARU_DIR")

  sort -u -o "$covered_file" "$covered_file"

  # covered∈source vs foreign (row ok, target outside the source scope);
  # uncovered = source − covered.
  comm -23 "$source_file" "$covered_file" > "$uncovered_file"
  comm -13 "$source_file" "$covered_file" > "$foreign_file"

  local n_source n_covered_in_source n_uncovered n_stale n_invalid n_foreign n_rows n_hosts
  n_source=$(grep -c . "$source_file" || true)
  n_uncovered=$(grep -c . "$uncovered_file" || true)
  n_covered_in_source=$((n_source - n_uncovered))
  n_stale=$(grep -c . "$stale_file" || true)
  n_invalid=$(grep -c . "$invalid_file" || true)
  n_foreign=$(grep -c . "$foreign_file" || true)
  n_rows=$(grep -c . "$refs_file" || true)
  n_hosts=$(cut -f1 "$refs_file" | sort -u | grep -c . || true)

  case "$mode" in
    rows)
      local path host
      while IFS=$'\t' read -r file link desc target status; do
        [[ "$status" == "ok" ]] || continue
        if grep -qxF "$target" "$source_file"; then
          printf 'covered\t%s\t%s\t%s\n' "$target" "$file" "$desc"
        else
          printf 'foreign\t%s\t%s\t%s\n' "$target" "$file" "$desc"
        fi
      done < "$refs_file"
      while IFS= read -r path; do
        [[ -n "$path" ]] && printf 'uncovered\t%s\t\t\n' "$path"
      done < "$uncovered_file"
      while IFS=$'\t' read -r path host link; do
        [[ -n "$path" ]] && printf 'stale\t%s\t%s\t%s\n' "$path" "$host" "$link"
      done < "$stale_file"
      while IFS=$'\t' read -r path host link; do
        [[ -n "$path" ]] && printf 'invalid\t%s\t%s\t%s\n' "$path" "$host" "$link"
      done < "$invalid_file"
      ;;
    gaps)
      cat "$uncovered_file"
      ;;
    refs)
      if [[ $n_rows -eq 0 ]]; then
        yellow "No reference rows found under $CUMARU_DIR/$spec_dir/"
      else
        local current=""
        while IFS=$'\t' read -r file link desc target status; do
          if [[ "$file" != "$current" ]]; then
            [[ -n "$current" ]] && printf '\n'
            printf 'File: %s\n' "$file"
            current="$file"
          fi
          case "$status" in
            ok) printf '  • %s — %s\n' "$link" "$desc" ;;
            *)  printf '  • %s — %s  [%s]\n' "$link" "$desc" "$status" ;;
          esac
        done < "$refs_file"
      fi
      ;;
    report)
      local pct=0
      [[ $n_source -gt 0 ]] && pct=$(( n_covered_in_source * 100 / n_source ))
      printf 'Specification coverage — %s/%s/ ↔ repository source\n\n' "$CUMARU_DIR" "$spec_dir"
      say "[refs]      $n_rows reference row(s) across $n_hosts spec file(s)"
      say "[covered]   $n_covered_in_source/$n_source source file(s) referenced ($pct%)"
      if [[ $n_uncovered -gt 0 ]]; then
        yellow "[uncovered] $n_uncovered source file(s) without a reference row:"
        while IFS= read -r path; do
          [[ -n "$path" ]] && printf '              • %s\n' "$path"
        done < "$uncovered_file"
      else
        green "[uncovered] none — every source file is referenced by the specification"
      fi
      if [[ $n_stale -gt 0 ]]; then
        red "[stale]     $n_stale reference row(s) point at missing files:"
        while IFS=$'\t' read -r path host link; do
          [[ -n "$path" ]] && printf '              • %s: %s\n' "$host" "$path"
        done < "$stale_file"
      fi
      if [[ $n_invalid -gt 0 ]]; then
        red "[invalid]   $n_invalid reference row(s) break the source-file rule (.cumaru/ path, directory, absolute path, or URL):"
        while IFS=$'\t' read -r path host link; do
          [[ -n "$path" ]] && printf '              • %s: %s\n' "$host" "$path"
        done < "$invalid_file"
      fi
      [[ $n_foreign -gt 0 ]] && yellow "[foreign]   $n_foreign referenced file(s) outside the source scope (untracked or filtered by coverage.source)"
      [[ $outside -gt 0 ]] && yellow "[note]      $outside reference row(s) hosted outside $spec_dir/ ignored"
      printf '\nSummary: %d covered, %d uncovered, %d stale, %d invalid\n' \
        "$n_covered_in_source" "$n_uncovered" "$n_stale" "$n_invalid"
      ;;
  esac

  if [[ $strict -eq 1 && $((n_uncovered + n_stale + n_invalid)) -gt 0 ]]; then
    return 1
  fi
  return 0
}
