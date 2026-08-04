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
  End
End
