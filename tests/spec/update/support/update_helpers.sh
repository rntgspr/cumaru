UPDATE_ROOT=${SHELLSPEC_PROJECT_ROOT:-$(pwd)}

update_tmp_create() {
  UPDATE_TMP=$(mktemp -d "${TMPDIR:-/tmp}/cumaru-shellspec-update.XXXXXX")
}

update_tmp_remove() {
  rm -rf "$UPDATE_TMP"
}

run_cumaru() {
  local project="$1"; shift
  (cd "$project" && bash "$UPDATE_ROOT/cumaru" "$@")
}

run_cumaru_combined() {
  run_cumaru "$@" 2>&1
}

install_base() {
  local project="$1"
  mkdir -p "$project"
  run_cumaru "$project" install --domain base
}

make_update_source() {
  local source="$1" marker="${2:-Transactional}"
  mkdir -p "$source/domains"
  : > "$source/cumaru"
  cp -R "$UPDATE_ROOT/domains/__base" "$source/domains/__base"
  printf '\n%s framework prose marker.\n' "$marker" >> "$source/domains/__base/domain.md"
  printf '\n%s skill marker.\n' "$marker" >> "$source/domains/__base/skills/cumaru-doctor/SKILL.md"
  printf '\n%s command marker.\n' "$marker" >> "$source/domains/__base/commands/cumaru/doctor.md"
  yq -i ".meta.apps.values = [\"${marker}-source\"]" "$source/domains/__base/config.yaml"
}

make_plain_source() {
  local source="$1"
  mkdir -p "$source/domains"
  : > "$source/cumaru"
  cp -R "$UPDATE_ROOT/domains/__base" "$source/domains/__base"
}

make_update_project() {
  local project="$1"
  install_base "$project" >/dev/null || return
  mkdir -p "$project/.agents/adopter-fixture"
  printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$project/.agents/adopter-fixture/tool.sh"
  chmod 755 "$project/.agents/adopter-fixture/tool.sh"
  ln -s tool.sh "$project/.agents/adopter-fixture/tool-link"
}

snapshot_mode() {
  stat -f '%Lp' "$1" 2>/dev/null || stat -c '%a' "$1"
}

write_metadata_manifest() {
  local snapshot="$1" output="$2" path rel type mode target
  : > "$output"
  while IFS= read -r path; do
    rel=${path#"$snapshot"/}
    if [ -L "$path" ]; then type=link; mode=-; target=$(readlink "$path")
    elif [ -d "$path" ]; then type=dir; mode=$(snapshot_mode "$path"); target=-
    elif [ -f "$path" ]; then type=file; mode=$(snapshot_mode "$path"); target=-
    else type=other; mode=$(snapshot_mode "$path"); target=-
    fi
    printf '%s\t%s\t%s\t%s\n' "$type" "$mode" "$rel" "$target" >> "$output"
  done < <(find "$snapshot" -mindepth 1 -print | LC_ALL=C sort)
}

snapshot_live() {
  local project="$1" snapshot="$2" rel manifest
  rm -rf "$snapshot"; mkdir -p "$snapshot"
  for rel in .cumaru .agents .claude .codex .opencode AGENTS.md CLAUDE.md opencode.json; do
    [ -e "$project/$rel" ] || [ -L "$project/$rel" ] || continue
    mkdir -p "$snapshot/$(dirname "$rel")"
    cp -R "$project/$rel" "$snapshot/$rel"
  done
  manifest="$snapshot.metadata"
  write_metadata_manifest "$snapshot" "$manifest"
  mv "$manifest" "$snapshot/.metadata"
}

snapshots_match() {
  local project="$1" expected="$2" actual="$UPDATE_TMP/current.$RANDOM"
  snapshot_live "$project" "$actual"
  diff -r "$expected" "$actual"
}

no_transaction_debris() {
  local project="$1"
  [ ! -e "$project/.cumaru-update.lock" ] && ! compgen -G "$project/.cumaru-update.*" >/dev/null
}
