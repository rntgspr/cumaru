Include tests/spec/update/support/update_helpers.sh

Describe 'cumaru update content and configuration ownership'
  setup() {
    update_tmp_create
    PROJECT="$UPDATE_TMP/project"
    install_base "$PROJECT" >/dev/null
    CANONICAL_SUMMARY=$(yq --front-matter=extract -r '.summary' "$UPDATE_ROOT/domains/__base/domain.md")
  }
  cleanup() { update_tmp_remove; }
  BeforeEach 'setup'
  AfterEach 'cleanup'

  It 'rejects the removed --keep-prose flag with usage status and diagnostic'
    When call run_cumaru "$PROJECT" update domain.md --from "$UPDATE_ROOT" --keep-prose
    The status should equal 2
    The output should include 'unknown flag: --keep-prose'
  End

  It 'replaces canonical frontmatter and prose while preserving adopter tag bodies'
    yq --front-matter=process -i '.summary = "Local adopter summary that canonical framework updates must replace."' "$PROJECT/.cumaru/domain.md"
    printf '\nLocal outside-tag prose used by the update ownership regression.\n' >> "$PROJECT/.cumaru/domain.md"
    printf '%s\n' 'Adopter-owned root context.' | run_cumaru "$PROJECT" tag set domain.md root >/dev/null
    git -C "$PROJECT" init >/dev/null 2>&1 || return 1
    git -C "$PROJECT" add . >/dev/null 2>&1 || return 1
    git -C "$PROJECT" -c user.name=Cumaru -c user.email=cumaru@example.invalid commit -m 'local baseline' >/dev/null 2>&1 || return 1
    When call run_cumaru "$PROJECT" update domain.md --from "$UPDATE_ROOT" --apply
    The status should equal 0
    The output should be present
    The value "$(yq --front-matter=extract -r '.summary' "$PROJECT/.cumaru/domain.md")" should equal "$CANONICAL_SUMMARY"
    The contents of file "$PROJECT/.cumaru/domain.md" should not include 'Local outside-tag prose used by the update ownership regression.'
    The value "$(run_cumaru "$PROJECT" tag get domain.md root)" should equal 'Adopter-owned root context.'
  End

  It 'stops invalid installed config before staging or mutation'
    yq -i '.unexpected = true' "$PROJECT/.cumaru/config.yaml"
    cp "$PROJECT/.cumaru/config.yaml" "$UPDATE_TMP/before.yaml"
    When call run_cumaru "$PROJECT" update --from "$UPDATE_ROOT" --apply
    The status should equal 1
    The output should include 'installed config is invalid under the current Cumaru configuration contract'
    The stderr should be present
    The value "$(cmp -s "$PROJECT/.cumaru/config.yaml" "$UPDATE_TMP/before.yaml"; printf '%s' $?)" should equal 0
    The value "$(no_transaction_debris "$PROJECT"; printf '%s' $?)" should equal 0
  End

  It 'reports config drift without mutating or creating a persistent backup'
    yq -i '.meta.apps.values = ["custom", "meta"] | .root.obsolete = true' "$PROJECT/.cumaru/config.yaml"
    cp "$PROJECT/.cumaru/config.yaml" "$UPDATE_TMP/before.yaml"
    run_cumaru "$PROJECT" update config --from "$UPDATE_ROOT" >/dev/null || return 1
    [ ! -e "$PROJECT/.cumaru/config.yaml.backup" ] || return 1
    cmp -s "$UPDATE_TMP/before.yaml" "$PROJECT/.cumaru/config.yaml" || return 1
    When call run_cumaru "$PROJECT" update config --from "$UPDATE_ROOT" --apply
    The status should equal 2
    The output should include 'config reconciliation is agent-led'
    The value "$(cmp -s "$PROJECT/.cumaru/config.yaml" "$UPDATE_TMP/before.yaml"; printf '%s' $?)" should equal 0
    The path "$PROJECT/.cumaru/config.yaml.backup" should not be exist
    The path "$PROJECT/.cumaru/.state" should not be exist
  End

  It 'blocks an invalid local value without changing config'
    yq -i '.rules.markdown.required_heading = 42' "$PROJECT/.cumaru/config.yaml"
    cp "$PROJECT/.cumaru/config.yaml" "$UPDATE_TMP/config"
    When call run_cumaru "$PROJECT" update config --from "$UPDATE_ROOT"
    The status should equal 1
    The output should be present
    The stderr should be present
    The value "$(cmp -s "$PROJECT/.cumaru/config.yaml" "$UPDATE_TMP/config"; printf '%s' $?)" should equal 0
    The path "$PROJECT/.cumaru/config.yaml.backup" should not be exist
    The value "$(no_transaction_debris "$PROJECT"; printf '%s' $?)" should equal 0
  End
End
