# Runs the real binary in a private project with an isolated home and closed source stub.
native_setup() {
  NATIVE_TMP=$(mktemp -d "${TMPDIR:-/tmp}/cumaru-native.XXXXXX")
  PROJECT="$NATIVE_TMP/project"
  FS_PROJECT="$PROJECT"
  mkdir -p "$PROJECT" "$NATIVE_TMP/home" "$NATIVE_TMP/bin"
  export HOME="$NATIVE_TMP/home" CUMARU_TEST_SOURCE="$REPO_ROOT" CUMARU_TEST_REQUESTS="$NATIVE_TMP/requests"
  export PATH="$NATIVE_TMP/bin:$PATH"
  cp "$REPO_ROOT/tests/native/curl-stub.sh" "$NATIVE_TMP/bin/curl"
  chmod +x "$NATIVE_TMP/bin/curl"
  : > "$CUMARU_TEST_REQUESTS"
  {
    printf '{"truncated":false,"tree":['
    separator=''
    while IFS= read -r path; do
      printf '%s{"path":"%s","type":"blob","mode":"100644"}' "$separator" "$path"
      separator=,
    done < <(cd "$REPO_ROOT" && find domains skills models -type f | LC_ALL=C sort)
    printf ']}'
  } > "$NATIVE_TMP/inventory.json"
  export CUMARU_TEST_INVENTORY="$NATIVE_TMP/inventory.json"
}

# Removes only the fixture directory allocated by this example.
native_cleanup() { rm -rf "$NATIVE_TMP"; }

# Invokes a compiled executable, never the retired Bash entry point.
cli() { (cd "$PROJECT" && "$CLI" "$@"); }

# Keeps the legacy fs scenario calling convention while executing the native binary.
cli_in() {
  fixture=$1
  shift
  (cd "$fixture" && "$CLI" "$@")
}

# Records every regular project file and directory without following symlinks.
snapshot() {
  (cd "$PROJECT" && find . -print | LC_ALL=C sort && find . -type f -exec cksum {} \; | LC_ALL=C sort)
}

# Supplies complete fixture preservation evidence for reused legacy fs cases.
fs_snapshot() { snapshot; }

# Copies the legacy fs fixture into the isolated project.
fs_setup() {
  native_setup
  cp -R "$REPO_ROOT/tests/fixtures/fs/.cumaru" "$PROJECT/.cumaru"
}

# Creates navigation metadata matching the legacy tree summary probes.
write_md() {
  mkdir -p "$(dirname "$1")"
  printf '%s\n' '---' 'human_revised: false' "summary: '$2'" '---' '# Fixture' > "$1"
}

# Installs one adapter from the closed source stub, retaining adopter instruction text.
installed_setup() {
  native_setup
  printf '# Adopter instructions\n\nKeep this policy.\n' > "$PROJECT/AGENTS.md"
  cli install agent codex --domain sdlc-light >/dev/null
}

# Verifies confirmed uninstall preserves a non-managed project file.
uninstall_and_read() {
  cli uninstall --yes >/dev/null || return
  test ! -e "$PROJECT/.cumaru" || return 1
  cat "$PROJECT/notes.txt"
}

# Exercises both read-only reconciliation surfaces in one fixture snapshot.
preview_both() { cli update && cli update config; }

# Creates a disposable Git baseline for actual recovery checks.
git_baseline() {
  (cd "$PROJECT" && git init -q && git add . && git -c user.name=Fixture -c user.email=fixture@example.invalid -c commit.gpgsign=false commit -qm 'Fixture baseline')
}

# Requires two adapter refreshes to produce identical managed bytes.
refresh_twice() {
  cli update agent codex --apply || return
  first=$(snapshot)
  cli update agent codex --apply || return
  test "$(snapshot)" = "$first"
}

# Builds the legacy navigation shape without requiring a domain config.
tree_setup() {
  native_setup
  write_md "$PROJECT/.cumaru/index.md" 'Root navigation context for focused tree command tests.'
  write_md "$PROJECT/.cumaru/alpha.md" 'Alpha behavior provides stable selection context.'
  write_md "$PROJECT/.cumaru/zeta.md" 'Zeta behavior provides stable selection context.'
  write_md "$PROJECT/.cumaru/area/index.md" 'Area contracts group related behavior for navigation.'
  write_md "$PROJECT/.cumaru/area/leaf.md" 'Area leaf behavior is available after explicit selection.'
  write_md "$PROJECT/.cumaru/.hidden.md" 'Hidden files are deliberately excluded from navigation.'
  mkdir -p "$PROJECT/.cumaru/unindexed"
}
