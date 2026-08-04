Include tests/spec/spec_helper.sh

Describe 'domain kernel synchronization script'
  setup() {
    SYNC_TMP=$(mktemp -d "${TMPDIR:-/tmp}/cumaru-sync.XXXXXX")
    mkdir -p "$SYNC_TMP/repo/scripts"
    cp "$REPO_ROOT/scripts/sync-domain-kernel.sh" "$SYNC_TMP/repo/scripts/"
    cp -R "$REPO_ROOT/domains" "$SYNC_TMP/repo/domains"
    SYNC_SCRIPT="$SYNC_TMP/repo/scripts/sync-domain-kernel.sh"
  }

  cleanup() { rm -rf "$SYNC_TMP"; }

  # Exercise every documented help route without invoking destructive upgrade.
  safe_help_routes() {
    for command in install uninstall doctor tag coverage tree map update fs migrate; do
      bash "$REPO_ROOT/cumaru" "$command" --help >/dev/null 2>&1 || return 1
    done
    bash "$REPO_ROOT/cumaru" help >/dev/null 2>&1 || return 1
    bash "$REPO_ROOT/cumaru" help domains >/dev/null 2>&1
  }

  BeforeEach 'setup'
  AfterEach 'cleanup'

  It 'checks synchronized domain mirrors without a flag'
    When call bash "$SYNC_SCRIPT"
    The status should be success
    The output should include 'Universal domain artifacts are synchronized.'
    The stderr should equal ''
  End

  It 'reports a divergent mirror without modifying it'
    target="$SYNC_TMP/repo/domains/sdlc-full/index.md"
    printf '\ndrift\n' >>"$target"
    before=$(cksum "$target")
    When call bash "$SYNC_SCRIPT" --check
    The status should be failure
    The output should include 'divergent: domains/sdlc-full/index.md'
    The value "$(cksum "$target")" should equal "$before"
  End

  It 'restores mirrors and preserves domain-owned artifacts'
    mirror="$SYNC_TMP/repo/domains/sdlc-full/skills/cumaru-update/SKILL.md"
    owned_skill="$SYNC_TMP/repo/domains/sdlc-full/skills/cumaru-install/SKILL.md"
    owned_index="$SYNC_TMP/repo/domains/sdlc-full/disciplines/index.md"
    printf '\ndrift\n' >>"$mirror"
    skill_before=$(cksum "$owned_skill")
    index_before=$(cksum "$owned_index")
    When call bash "$SYNC_SCRIPT" --apply
    The status should be success
    The output should include 'synced: domains/sdlc-full/skills/cumaru-update/SKILL.md'
    The value "$(cmp -s "$SYNC_TMP/repo/domains/__base/skills/cumaru-update/SKILL.md" "$mirror"; printf '%s' $?)" should equal 0
    The value "$(cksum "$owned_skill")" should equal "$skill_before"
    The value "$(cksum "$owned_index")" should equal "$index_before"
    The path "$SYNC_TMP/repo/domains/design-as-code/disciplines/code-comments.md" should not be exist
  End

  It 'keeps the kernel CLI map complete and safely discoverable'
    kernel="$REPO_ROOT/domains/__base/index.md"
    dispatcher=$(sed -n '/^case "$sub" in/,/^esac/p' "$REPO_ROOT/cumaru" |
      sed -nE 's/^  ([a-z][a-z-]*)\)$/\1/p' | LC_ALL=C sort)
    expected=$(printf '%s\n' coverage doctor fs install map migrate tag tree uninstall update upgrade)

    The value "$dispatcher" should equal "$expected"
    for command in $dispatcher; do
      The contents of file "$kernel" should include "| \`cumaru $command\` |"
    done
    The contents of file "$kernel" should include '| `cumaru help` |'
    The contents of file "$kernel" should include '| `cumaru help domains` |'
    The contents of file "$kernel" should include '`cumaru upgrade` | Destructively replace'
    The contents of file "$kernel" should include 'Never invoke it for discovery.'
    The contents of file "$kernel" should not include '`cumaru upgrade --help`'
    The contents of file "$kernel" should not include '| `cumaru domains` |'
    The contents of file "$kernel" should not include '| `cumaru intake` |'
    The contents of file "$kernel" should include '`cumaru-intake`, when shipped'
  End

  It 'uses working non-destructive help routes for kernel entries'
    When call safe_help_routes
    The status should be success
    The stdout should equal ''
    The stderr should equal ''
  End
End
