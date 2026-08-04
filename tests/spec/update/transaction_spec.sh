Include tests/spec/update/support/update_helpers.sh

Describe 'update transaction and recovery'
  setup_transaction() { update_tmp_create; SOURCE="$UPDATE_TMP/source"; make_update_source "$SOURCE" Transactional; }
  cleanup() { update_tmp_remove; }
  BeforeEach 'setup_transaction'
  AfterEach 'cleanup'

  It 'detects executable mode drift in transaction snapshots'
    project="$UPDATE_TMP/project"; make_update_project "$project"; snapshot_live "$project" "$UPDATE_TMP/base"
    chmod 600 "$project/.agents/adopter-fixture/tool.sh"
    snapshot_differs() { ! snapshots_match "$project" "$UPDATE_TMP/base" >/dev/null 2>&1; }
    When call snapshot_differs
    The status should equal 0
  End

  It 'detects symlink target drift in transaction snapshots'
    project="$UPDATE_TMP/project"; make_update_project "$project"; snapshot_live "$project" "$UPDATE_TMP/base"
    rm "$project/.agents/adopter-fixture/tool-link"; ln -s missing.sh "$project/.agents/adopter-fixture/tool-link"
    snapshot_differs() { ! snapshots_match "$project" "$UPDATE_TMP/base" >/dev/null 2>&1; }
    When call snapshot_differs
    The status should equal 0
  End

  injected_phase_is_transactional() {
    local phase="$1" project="$UPDATE_TMP/project-$1" output status=0
    make_update_project "$project" || return
    snapshot_live "$project" "$UPDATE_TMP/base-$phase"
    output=$(cd "$project" && CUMARU_TEST_FAIL_PHASE="$phase" bash "$UPDATE_ROOT/cumaru" update --from "$SOURCE" --apply 2>&1) || status=$?
    [ "$status" -ne 0 ] && [[ "$output" == *"injected update failure at phase: $phase"* ]] || return 1
    snapshots_match "$project" "$UPDATE_TMP/base-$phase" >/dev/null && no_transaction_debris "$project"
  }
  Parameters
    after-stage
    after-validation
    after-tree-commit
    after-adapter-commit
  End
  It 'makes injected phase $1 fatal, restores all surfaces, and removes debris'
    When call injected_phase_is_transactional "$1"
    The status should equal 0
  End

  malformed_case() {
    local side="$1" identical="${2:-false}" project="$UPDATE_TMP/project" source="$SOURCE"
    [ "$identical" = true ] && { source="$UPDATE_TMP/plain"; make_plain_source "$source"; }
    make_update_project "$project"
    malformed=$'\n<!-- cumaru:broken -->\nUnclosed adopter body.\n'
    [ "$side" = local ] && printf '%s' "$malformed" >> "$project/.cumaru/domain.md"
    if [ "$side" = source ]; then source="$UPDATE_TMP/malformed-source"; make_update_source "$source" Transactional; printf '%s' "$malformed" >> "$source/domains/__base/domain.md"; fi
    if [ "$identical" = true ]; then printf '%s' "$malformed" >> "$source/domains/__base/domain.md"; printf '%s' "$malformed" >> "$project/.cumaru/domain.md"; fi
    snapshot_live "$project" "$UPDATE_TMP/base"
    output=$(run_cumaru "$project" update domain.md --from "$source" --apply 2>&1); status=$?
    [ "$status" -eq 1 ] && [[ "$output" == *"$([ "$side" = local ] && [ "$identical" != true ] && printf local || printf source) tag \"broken\" was never closed"* ]] || return 1
    snapshots_match "$project" "$UPDATE_TMP/base" >/dev/null && no_transaction_debris "$project"
  }

  It 'rejects malformed local Markdown through scoped apply without mutation'
    When call malformed_case local
    The status should equal 0
  End
  It 'rejects malformed source Markdown through scoped apply without mutation'
    When call malformed_case source
    The status should equal 0
  End
  It 'validates byte-identical malformed Markdown before declaring a no-op'
    When call malformed_case source true
    The status should equal 0
  End

  It 'accepts a valid scoped no-op without changing managed surfaces'
    project="$UPDATE_TMP/project"; source="$UPDATE_TMP/plain"; make_plain_source "$source"; make_update_project "$project"; snapshot_live "$project" "$UPDATE_TMP/base"
    run_cumaru "$project" update domain.md --from "$source" --apply >/dev/null || return 1
    snapshots_match "$project" "$UPDATE_TMP/base" >/dev/null || return 1
    When call no_transaction_debris "$project"
    The status should equal 0
  End

  It 'restores every live surface when an agent switch fails'
    agent_failure_restores() {
      local status=0
      project="$UPDATE_TMP/project"; make_update_project "$project"; snapshot_live "$project" "$UPDATE_TMP/base"
      (cd "$project" && CUMARU_TEST_FAIL_PHASE=after-tree-commit bash "$UPDATE_ROOT/cumaru" update agent opencode --from "$UPDATE_ROOT" --apply) >/dev/null 2>&1 || status=$?
      [ "$status" -ne 0 ] && snapshots_match "$project" "$UPDATE_TMP/base" >/dev/null && no_transaction_debris "$project"
    }
    When call agent_failure_restores
    The status should equal 0
  End

  It 'publishes framework Markdown, keeps config isolated, passes doctor, and is byte-idempotent'
    project="$UPDATE_TMP/project"; make_update_project "$project"
    run_cumaru "$project" update --from "$SOURCE" --apply > "$UPDATE_TMP/apply" || return 1
    markdown=$(grep -n 'merged domain.md' "$UPDATE_TMP/apply" | cut -d: -f1 | head -n1)
    [ -n "$markdown" ] || return 1
    grep -q 'Transactional framework prose marker.' "$project/.cumaru/domain.md" || return 1
    [ "$(yq -r '.meta.apps.values | join(",")' "$project/.cumaru/config.yaml")" != Transactional-source ] || return 1
    run_cumaru "$project" doctor --quiet | grep -q 'Summary: 0 error(s)' || return 1
    snapshot_live "$project" "$UPDATE_TMP/base"
    run_cumaru "$project" update --from "$SOURCE" --apply >/dev/null || return 1
    When call snapshots_match "$project" "$UPDATE_TMP/base"
    The status should equal 0
  End
End
