# cmd_migrate_v6.sh - transactional migration from framework v5 to v6.

# Print v5-to-v6 adapter usage without requiring a project tree.
cmd_migrate_v6_help() {
  cat <<'EOF'
cumaru migrate v6 — transactionally migrate a framework v5 tree to v6

Usage:
  cumaru migrate v6 [--from <source>] [--apply]

Options:
  --from <source>  Cumaru checkout containing domains/<installed-domain>/
                   (default: the active CLI checkout)
  --apply          perform the migration; without it, print a dry-run summary

The adapter derives missing summaries, removes only manifest-declared
structural markers, moves supported archive history into the durable domain
ledger, refreshes framework-owned agent artifacts, and swaps the staged tree
transactionally. Unsupported or ambiguous local content stops before swap.
EOF
}

_migrate_v6_remove_block() {
  local file="$1" tag="$2" tmp
  tmp=$(mktemp)
  awk -v open="<!-- cumaru:$tag -->" -v close_marker="<!-- /cumaru:$tag -->" '
    index($0, open) { skip=1; next }
    index($0, close_marker) { skip=0; next }
    !skip { print }
  ' "$file" > "$tmp" && mv "$tmp" "$file"
}

_migrate_v6_summary_from_row() {
  local file="$1" parent base
  parent="$(dirname "$file")/index.md"; base="$(basename "$file")"
  [[ -f "$parent" ]] || return 1
  awk -v base="$base" '
    index($0, "(" base ")") { n=split($0,a,"|"); if(n>=3){gsub(/^[[:space:]]+|[[:space:]]+$/, "", a[3]); print a[3]; exit} }
  ' "$parent"
}

_migrate_v6_set_summary() {
  local file="$1" summary="$2"
  SUMMARY="$summary" yq -i --front-matter=process '.summary = strenv(SUMMARY)' "$file"
}

# Renames the former namespaced touched-file marker inside the staged v5 tree.
_migrate_v6_normalize_touched_markers() {
  local tree="$1" file tmp

  while IFS= read -r -d '' file; do
    grep -qF 'cumaru:files:touched' "$file" || continue
    tmp=$(mktemp)
    sed 's/cumaru:files:touched/cumaru:touched/g' "$file" > "$tmp" && mv "$tmp" "$file"
  done < <(find "$tree" -type f -name '*.md' -print0)
}

# Flattens legacy SDLC intake directories only when no auxiliary files would be
# discarded. Directories with attachments require LLM adjudication instead.
_migrate_v6_flatten_sdlc_intake() {
  local tree="$1" dir name target entries
  [[ -d "$tree/intake" ]] || return 0

  while IFS= read -r -d '' dir; do
    name=$(basename "$dir")
    target="$tree/intake/$name.md"
    entries=$(find "$dir" -mindepth 1 -maxdepth 1 -print | LC_ALL=C sort)
    if [[ "$entries" != "$dir/index.md" ]]; then
      red "✗ intake/$name requires LLM reconciliation before flattening (directory contains auxiliary files)"
      return 1
    fi
    if [[ -e "$target" ]]; then
      red "✗ intake/$name is ambiguous: both directory and file layouts exist"
      return 1
    fi
  done < <(find "$tree/intake" -mindepth 1 -maxdepth 1 -type d -print0)

  while IFS= read -r -d '' dir; do
    name=$(basename "$dir")
    mv "$dir/index.md" "$tree/intake/$name.md" && rmdir "$dir"
  done < <(find "$tree/intake" -mindepth 1 -maxdepth 1 -type d -print0)
}

# Moves absorbed archive evidence into the durable ledger declared by a manifest row.
_migrate_v6_move_ledger() {
  local file="$1" tag="$2" ledger="$3" tree="$4" target target_tag rows
  [[ "$ledger" != "-" ]] || return 0
  target="$tree/${ledger%%:*}"; target_tag="${ledger##*:}"
  [[ -f "$target" ]] || return 0
  rows=$(awk -v open="<!-- cumaru:$tag -->" -v close_marker="<!-- /cumaru:$tag -->" '
    index($0, open) { on=1; next }; index($0, close_marker) { on=0 }
    on && /\]\([^)]*\)/ { n=split($0,a,"|"); key=a[2]; desc=a[3]; gsub(/.*\[/,"",key); gsub(/\].*/,"",key); if(match(desc,/Absorbed-in:[[:space:]]*[A-Za-z0-9]+/)){ sha=substr(desc,RSTART,RLENGTH); sub(/.*:[[:space:]]*/,"",sha); gsub(/^[[:space:]]+|[[:space:]]+$/, "",desc); printf "| %s | %s | %s |\n",sha,key,desc } }
  ' "$file")
  [[ -n "$rows" ]] || return 0
  if ! fm_block_list "$target" | grep -Fxq "$target_tag"; then
    printf '\n<!-- cumaru:%s -->\n| SHA | KEY | Description |\n|---|---|---|\n<!-- /cumaru:%s -->\n' "$target_tag" "$target_tag" >> "$target"
  fi
  awk -v open="<!-- cumaru:$target_tag -->" -v close_marker="<!-- /cumaru:$target_tag -->" -v rows="$rows" '
    index($0, close_marker) { print rows }; { print }
  ' "$target" > "$target.tmp" && mv "$target.tmp" "$target"
}

_migrate_v6_recover() {
  local journal=".cumaru-migrate.interrupted"
  [[ -d "$journal" ]] || return 0
  [[ -d "$journal/backup-tree" ]] || return 0
  [[ ! -e .cumaru ]] && mv "$journal/backup-tree" .cumaru
  [[ -d "$journal/backup-agents" && ! -e .agents ]] && mv "$journal/backup-agents" .agents
  rm -rf "$journal"
  say "✓ interrupted migration rolled back"
}

cmd_migrate_v6() {
  local from="" apply=0 arg
  while [[ $# -gt 0 ]]; do
    arg="$1"; case "$arg" in
      --from)
        [[ -n "${2:-}" ]] || { red "--from requires a source"; return 2; }
        from="$2"; shift 2
        ;;
      --apply) apply=1; shift ;;
      -h|--help|help) cmd_migrate_v6_help; return 0 ;;
      *) red "unexpected arg: $arg"; return 2 ;;
    esac
  done
  _migrate_v6_recover
  local input=.cumaru legacy=0
  if [[ ! -d "$input" && -d .llm ]]; then input=.llm; legacy=1; fi
  [[ -d "$input" ]] || { red "✗ no .cumaru/ tree found"; return 1; }
  local domain source framework manifest version
  domain=$(yq -r '.domain // ""' "$input/schema.yaml" 2>/dev/null || true)
  [[ -n "$domain" ]] || { red "✗ unsupported custom/unknown domain"; return 1; }
  source="${from:-$SCRIPT_DIR}"; domain_src="$source/domains/$domain"; [[ "$domain" == base ]] && domain_src="$source/domains/__base"
  manifest="$domain_src/migrations/v5-to-v6.tsv"
  [[ -f "$manifest" ]] || { red "✗ unsupported custom/unknown domain: $domain"; return 1; }
  version=$(yq -r '.version // ""' "$input/schema.yaml" 2>/dev/null || true)
  if [[ "$version" == 6* ]]; then say "✓ v6 migration already complete"; return 0; fi
  local count; count=$(awk -F'\t' '!/^#/ && NF {n++} END{print n+0}' "$manifest")
  say "Migration v5 → v6 ($domain): structural blocks removed: $count"
  say "Summary sources: summary:description → source summary → blocker"
  [[ $apply -eq 1 ]] || return 0
  local stage; stage=$(mktemp -d .cumaru-migrate.stage.XXXXXX) || return 1
  local tree="$stage/tree" agents="$stage/agents" file rel summary src
  cp -R "$input" "$tree"; [[ -d .agents ]] && cp -R .agents "$agents" || mkdir -p "$agents"
  _migrate_v6_normalize_touched_markers "$tree"
  while IFS= read -r -d '' file; do
    summary=$(yq --front-matter=extract -r '.summary // ""' "$file" 2>/dev/null || true)
    [[ "$summary" == "null" ]] && summary=""
    [[ -n "$summary" ]] && continue
    rel="${file#"$tree"/}"; summary=$(_migrate_v6_summary_from_row "$file" 2>/dev/null || true)
    if [[ -z "$summary" && -f "$domain_src/$rel" ]]; then summary=$(yq --front-matter=extract -r '.summary // ""' "$domain_src/$rel" 2>/dev/null || true); [[ "$summary" == "null" ]] && summary=""; fi
    [[ -n "$summary" ]] || { rm -rf "$stage"; red "✗ $rel needs LLM summarization"; return 1; }
    _migrate_v6_set_summary "$file" "$summary"
  done < <(find "$tree" -type f -name '*.md' -print0)
  yq eval-all 'select(fileIndex == 0) * select(fileIndex == 1) | .version = 6 | .rules.markdown.frontmatter |= ((. // []) + ["summary!"] | unique) | del(.meta.tags."files:touched")' "$domain_src/schema.yaml" "$tree/schema.yaml" > "$stage/schema.yaml" && mv "$stage/schema.yaml" "$tree/schema.yaml"
  if [[ "$domain" == "sdlc-full" ]]; then
    _migrate_v6_flatten_sdlc_intake "$tree" || { rm -rf "$stage"; return 1; }
  fi
  yq -i --front-matter=process '.["framework-version"] = 6' "$tree/index.md"
  local action host tag schema_path ledger
  while IFS=$'\t' read -r action host tag schema_path ledger; do
    [[ "$action" == remove && -f "$tree/$host" ]] || continue
    _migrate_v6_move_ledger "$tree/$host" "$tag" "$ledger" "$tree"
    _migrate_v6_remove_block "$tree/$host" "$tag"
  done < <(awk -F'\t' '!/^#/ && NF {printf "%s\t%s\t%s\t%s\t%s\n", $1, $2, $3, $4, $5}' "$manifest")
  rm -rf "$agents/skills"/cumaru-* "$agents/commands/cumaru"
  mkdir -p "$agents/skills" "$agents/commands"
  [[ -d "$domain_src/skills" ]] && cp -R "$domain_src/skills"/cumaru-* "$agents/skills/" 2>/dev/null || true
  [[ -d "$domain_src/commands" ]] && cp -R "$domain_src/commands"/cumaru "$agents/commands/" 2>/dev/null || true
  [[ "${CUMARU_MIGRATE_FAIL_AT:-}" != agents-installed ]] || { rm -rf "$stage"; red "✗ injected failure at agents-installed"; return 1; }
  local journal=.cumaru-migrate.interrupted; mkdir "$journal"; printf 'transaction=started\n' > "$journal/rollback.journal"
  mv "$input" "$journal/backup-tree"; [[ -d .agents ]] && mv .agents "$journal/backup-agents"
  if ! mv "$tree" .cumaru || ! mv "$agents" .agents; then
    rm -rf .cumaru .agents; mv "$journal/backup-tree" .cumaru; [[ -d "$journal/backup-agents" ]] && mv "$journal/backup-agents" .agents; rm -rf "$stage" "$journal"; return 1
  fi
  rm -rf "$stage" "$journal"; [[ $legacy -eq 0 ]] || true
  green "✓ v6 migration complete"
}
