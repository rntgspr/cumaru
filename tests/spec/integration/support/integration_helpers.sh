INTEGRATION_ROOT=${SHELLSPEC_PROJECT_ROOT:-$(pwd)}

integration_tmp_create() {
  INTEGRATION_TMP=$(mktemp -d "${TMPDIR:-/tmp}/cumaru-shellspec.XXXXXX")
  export INTEGRATION_ROOT INTEGRATION_TMP
}

integration_tmp_remove() {
  rm -rf "$INTEGRATION_TMP"
}

snapshot_mode() {
  local path="$1" mode
  if mode=$(stat -f '%Lp' "$path" 2>/dev/null); then
    printf '%s\n' "$mode"
  else
    stat -c '%a' "$path"
  fi
}

snapshot_managed_surfaces() {
  local project="$1" snapshot="$2" rel path type mode target
  rm -rf "$snapshot"
  mkdir -p "$snapshot"
  for rel in .cumaru .agents .claude .codex .opencode AGENTS.md CLAUDE.md opencode.json; do
    [ -e "$project/$rel" ] || [ -L "$project/$rel" ] || continue
    mkdir -p "$snapshot/$(dirname "$rel")"
    cp -R "$project/$rel" "$snapshot/$rel"
  done
  : >"$snapshot/.metadata"
  while IFS= read -r path; do
    rel=${path#"$snapshot"/}
    [ "$rel" = .metadata ] && continue
    if [ -L "$path" ]; then
      type=link; mode=-; target=$(readlink "$path")
    elif [ -d "$path" ]; then
      type=dir; mode=$(snapshot_mode "$path"); target=-
    else
      type=file; mode=$(snapshot_mode "$path"); target=-
    fi
    printf '%s\t%s\t%s\t%s\n' "$type" "$mode" "$rel" "$target" >>"$snapshot/.metadata"
  done < <(find "$snapshot" -mindepth 1 -print | LC_ALL=C sort)
}

managed_surfaces_equal() {
  local project="$1" expected="$2" actual="$INTEGRATION_TMP/actual-snapshot"
  snapshot_managed_surfaces "$project" "$actual"
  diff -r "$expected" "$actual" >/dev/null
}

capture_integration() {
  local stdout="$INTEGRATION_TMP/stdout" stderr="$INTEGRATION_TMP/stderr"
  "$@" >"$stdout" 2>"$stderr"
  CAPTURE_STATUS=$?
  CAPTURE_STDOUT=$(<"$stdout")
  CAPTURE_STDERR=$(<"$stderr")
}

run_in_project() {
  local project="$1"
  shift
  (cd "$project" && "$@")
}

git_clean_baseline() {
  local project="$1" message="${2:-baseline}"
  git -C "$project" rev-parse --is-inside-work-tree >/dev/null 2>&1 || git -C "$project" init >/dev/null 2>&1 || return
  git -C "$project" add -A >/dev/null 2>&1 || return
  git -C "$project" diff --cached --quiet >/dev/null 2>&1 && return 0
  git -C "$project" -c user.name=Cumaru -c user.email=cumaru@example.invalid commit -m "$message" >/dev/null 2>&1
}

install_adapter_fixture() {
  local adapter="$1" project
  project="$INTEGRATION_TMP/$adapter"
  shift
  mkdir -p "$project"
  run_in_project "$project" "$INTEGRATION_ROOT/cumaru" install agent "$adapter" --domain base "$@"
}

json_hook_count() {
  local config="$1" command="$2"
  jq --arg cmd "$command" \
    '[(.hooks.SessionStart // [])[] | (.hooks // [])[] | select(.command == $cmd)] | length' \
    "$config"
}

file_contains() {
  grep -qF "$2" "$1"
}

files_equal() {
  cmp -s "$1" "$2"
}
