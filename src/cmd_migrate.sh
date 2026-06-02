# cmd_migrate.sh — migrate a project tree from `llm` (legacy) to `cumaru`.
#
# Renames .llm/ → .cumaru/, rewrites <!-- llm: --> markers to <!-- cumaru: -->,
# updates .agents/ skill/command dirs, and updates hook references.
# Idempotent: safe to run on an already-migrated tree (detects .cumaru/ first).
#
# Expects from entry-point: CUMARU_DIR, AGENTS_DIR, SCRIPT_DIR, QUIET.

cmd_migrate_help() {
  cat <<'EOF'
cumaru migrate — migrate a project tree from llm (legacy) to cumaru

Usage:
  cumaru migrate [--apply]

Without --apply, shows a dry-run plan of what would change.
With --apply, performs the migration.

What it does:
  1. Renames .llm/ → .cumaru/ (if .llm/ exists and .cumaru/ does not)
  2. Rewrites <!-- llm: --> → <!-- cumaru: --> in all .md files under .cumaru/
  3. Updates @.llm/index.md → @.cumaru/index.md in .agents/AGENTS.md hook block
  4. Renames .agents/commands/llm/ → .agents/commands/cumaru/
  5. Renames .agents/skills/llm-*/ → .agents/skills/cumaru-*/
EOF
}

cmd_migrate() {
  local apply=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help|help)  cmd_migrate_help; return 0 ;;
      --apply)         apply=1; shift ;;
      -*)              red "unknown flag: $1"; cmd_migrate_help; return 2 ;;
      *)               red "unexpected arg: $1"; cmd_migrate_help; return 2 ;;
    esac
  done

  local legacy_dir=".llm"
  local proj_parent changes=0

  # Check if already migrated
  if [[ -d "$CUMARU_DIR" && ! -d "$legacy_dir" ]]; then
    say "✓ Already migrated — .cumaru/ exists and .llm/ is gone."
    [[ -d "$CUMARU_DIR/index.md" ]] || yellow "⚠ .cumaru/ exists but missing index.md (was this a cumaru install?)"
    return 0
  fi

  if [[ ! -d "$legacy_dir" ]]; then
    red "✗ No .llm/ directory found in this project — nothing to migrate."
    return 1
  fi

  proj_parent=$(dirname "$(cd "$legacy_dir" 2>/dev/null && pwd -P)") || proj_parent=""

  say "Migration plan for ${proj_parent:-.}:"

  # 1) Rename .llm/ → .cumaru/
  if [[ -d "$legacy_dir" && ! -d "$CUMARU_DIR" ]]; then
    say "  [mv] $legacy_dir/ → $CUMARU_DIR/"
    changes=$((changes + 1))
  elif [[ -d "$CUMARU_DIR" ]]; then
    say "  [ok] $CUMARU_DIR/ already exists"
  fi

  # 2) Rewrite markers under .cumaru/
  local target_dir="${CUMARU_DIR}"
  if [[ -d "$target_dir" ]]; then
    local md_count=0
    while IFS= read -r -d '' f; do
      if grep -q '<!-- llm:' "$f" 2>/dev/null; then
        md_count=$((md_count + 1))
      fi
    done < <(find "$target_dir" -name '*.md' -type f -print0 2>/dev/null)
    if [[ $md_count -gt 0 ]]; then
      say "  [rewrite] $md_count .md file(s) with <!-- llm: --> markers → <!-- cumaru: -->"
      changes=$((changes + 1))
    else
      say "  [ok] no <!-- llm: --> markers found under $target_dir/"
    fi
  fi

  # 3) AGENTS.md hook reference
  local hook_file=".agents/AGENTS.md"
  if [[ -f "$hook_file" ]] && grep -q '\.llm/' "$hook_file" 2>/dev/null; then
    say "  [edit] $hook_file — update .llm/ → .cumaru/ in hook block"
    changes=$((changes + 1))
  elif [[ -f "$hook_file" ]]; then
    say "  [ok] $hook_file — no .llm/ reference found"
  fi

  # 4) commands/llm/ → commands/cumaru/
  if [[ -d ".agents/commands/llm" && ! -d ".agents/commands/cumaru" ]]; then
    say "  [mv] .agents/commands/llm/ → .agents/commands/cumaru/"
    changes=$((changes + 1))
  elif [[ -d ".agents/commands/cumaru" ]]; then
    say "  [ok] .agents/commands/cumaru/ already exists"
  fi

  # 5) skills/llm-*/ → skills/cumaru-*/
  local llm_skills=0
  for d in .agents/skills/llm-*/; do
    [[ -d "$d" ]] && llm_skills=$((llm_skills + 1))
  done
  if [[ $llm_skills -gt 0 ]]; then
    say "  [mv] $llm_skills skill dir(s): llm-* → cumaru-*"
    changes=$((changes + 1))
  else
    say "  [ok] no llm-* skill dirs under .agents/skills/"
  fi

  if [[ $apply -eq 0 ]]; then
    say ""
    say "To apply these $changes change(s), run:  cumaru migrate --apply"
    return 0
  fi

  # --- APPLY ---
  say "Applying migration..."

  # 1) Rename .llm/ → .cumaru/
  if [[ -d "$legacy_dir" && ! -d "$CUMARU_DIR" ]]; then
    mv "$legacy_dir" "$CUMARU_DIR" && green "  ✓ $legacy_dir/ → $CUMARU_DIR/"
  fi

  # 2) Rewrite markers
  if [[ -d "$target_dir" ]]; then
    local rewritten=0
    while IFS= read -r -d '' f; do
      if grep -q '<!-- llm:' "$f" 2>/dev/null; then
        sed -i '' 's/<!-- llm:/<!-- cumaru:/g' "$f"
        sed -i '' 's/<!-- \/llm:/<!-- \/cumaru:/g' "$f"
        rewritten=$((rewritten + 1))
      fi
    done < <(find "$target_dir" -name '*.md' -type f -print0 2>/dev/null)
    green "  ✓ Rewrote <!-- llm: --> markers in $rewritten file(s)"
  fi

  # 3) AGENTS.md hook
  if [[ -f "$hook_file" ]] && grep -q '\.llm/' "$hook_file" 2>/dev/null; then
    sed -i '' 's/\.llm\//.cumaru\//g' "$hook_file"
    sed -i '' 's/@\.llm\//@.cumaru\//g' "$hook_file"
    green "  ✓ Updated $hook_file references"
  fi

  # 4) commands/llm/ → commands/cumaru/
  if [[ -d ".agents/commands/llm" && ! -d ".agents/commands/cumaru" ]]; then
    mv ".agents/commands/llm" ".agents/commands/cumaru" && green "  ✓ .agents/commands/llm/ → commands/cumaru/"
  elif [[ -d ".agents/commands/llm" && -d ".agents/commands/cumaru" ]]; then
    rm -rf ".agents/commands/llm"
    green "  ✓ Removed redundant .agents/commands/llm/ (cumaru/ already exists)"
  fi

  # 5) skills/llm-*/ → skills/cumaru-*/
  for d in .agents/skills/llm-*/; do
    [[ -d "$d" ]] || continue
    local base="${d%/}"
    base="${base##*/}"
    local newname="cumaru-${base#llm-}"
    mv "${d%/}" ".agents/skills/$newname"
    green "  ✓ $base → $newname"
  done

  green "Migration complete. Run 'cumaru doctor' to verify."
}
