Include tests/spec/update/support/update_helpers.sh

Describe 'update transaction and Git recovery boundary'
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

  malformed_case() {
    local side="$1" identical="${2:-false}" project="$UPDATE_TMP/project" source="$SOURCE"
    [ "$identical" = true ] && { source="$UPDATE_TMP/plain"; make_plain_source "$source"; }
    make_update_project "$project"
    malformed=$'\n<!-- cumaru:broken -->\nUnclosed adopter body.\n'
    [ "$side" = local ] && printf '%s' "$malformed" >> "$project/.cumaru/domain.md"
    if [ "$side" = source ]; then source="$UPDATE_TMP/malformed-source"; make_update_source "$source" Transactional; printf '%s' "$malformed" >> "$source/domains/__base/domain.md"; fi
    if [ "$identical" = true ]; then printf '%s' "$malformed" >> "$source/domains/__base/domain.md"; printf '%s' "$malformed" >> "$project/.cumaru/domain.md"; fi
    if [ "$side" = local ] || [ "$identical" = true ]; then commit_update_project "$project" 'malformed baseline' || return 1; fi
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

  It 'publishes framework Markdown, keeps config isolated, passes doctor, and is byte-idempotent'
    project="$UPDATE_TMP/project"; make_update_project "$project"
    run_cumaru "$project" update --from "$SOURCE" --apply > "$UPDATE_TMP/apply" || return 1
    markdown=$(grep -n 'merged domain.md' "$UPDATE_TMP/apply" | cut -d: -f1 | head -n1)
    [ -n "$markdown" ] || return 1
    grep -q 'Transactional framework prose marker.' "$project/.cumaru/domain.md" || return 1
    [ "$(yq -r '.meta.apps.values | join(",")' "$project/.cumaru/config.yaml")" != Transactional-source ] || return 1
    run_cumaru "$project" doctor --quiet | grep -q 'Summary: 0 error(s)' || return 1
    commit_update_project "$project" 'after update' || return 1
    snapshot_live "$project" "$UPDATE_TMP/base"
    run_cumaru "$project" update --from "$SOURCE" --apply >/dev/null || return 1
    When call snapshots_match "$project" "$UPDATE_TMP/base"
    The status should equal 0
  End

  It 'refuses apply outside a Git work tree before creating transaction state'
    nongit_rejected() {
      local nongit="$UPDATE_TMP/nongit" output status=0
      make_update_project "$nongit" || return 1
      rm -rf "$nongit/.git"
      output=$(run_cumaru "$nongit" update --from "$SOURCE" --apply 2>&1) || status=$?
      [ "$status" -ne 0 ] && [[ "$output" == *'requires a Git work tree'* ]] && no_transaction_debris "$nongit"
    }
    When call nongit_rejected
    The status should equal 0
  End

  dirty_rejected() {
    local mode="$1" project="$UPDATE_TMP/dirty-$mode" output status=0
    make_update_project "$project" || return
    case "$mode" in
      staged) printf 'x\n' > "$project/staged.txt"; git -C "$project" add staged.txt >/dev/null 2>&1 ;;
      unstaged) printf '\nlocal edit\n' >> "$project/.cumaru/domain.md" ;;
      untracked) printf 'x\n' > "$project/untracked.txt" ;;
    esac
    output=$(run_cumaru "$project" update --from "$SOURCE" --apply 2>&1); status=$?
    [ "$status" -ne 0 ] && [[ "$output" == *'Git work tree has pending changes'* ]] && no_transaction_debris "$project"
  }
  It 'refuses dirty staged, unstaged, and untracked work before creating transaction state'
    dirty_all_modes_rejected() {
      local mode
      for mode in staged unstaged untracked; do
        dirty_rejected "$mode" || return 1
      done
    }
    When call dirty_all_modes_rejected
    The status should equal 0
  End

  It 'refuses a clean repository whose Cumaru installation is not tracked'
    untracked_install_rejected() {
      local project="$UPDATE_TMP/untracked-install" output status=0
      make_update_project "$project" || return 1
      printf '%s\n' '.cumaru/' >> "$project/.gitignore"
      git -C "$project" rm -r --cached .cumaru >/dev/null 2>&1 || return 1
      commit_update_project "$project" 'ignore installed tree' || return 1
      snapshot_live "$project" "$UPDATE_TMP/untracked-install-base"
      output=$(run_cumaru "$project" update --from "$SOURCE" --apply 2>&1) || status=$?
      [ "$status" -ne 0 ] && [[ "$output" == *'.cumaru/config.yaml and .cumaru/index.md must be tracked by Git'* ]] || return 1
      snapshots_match "$project" "$UPDATE_TMP/untracked-install-base" >/dev/null && no_transaction_debris "$project"
    }
    When call untracked_install_rejected
    The status should equal 0
  End

  It 'blocks every explicit artifact mutation on a dirty work tree'
    dirty_artifact_modes_rejected() {
      local project="$UPDATE_TMP/dirty-artifacts" output status command
      make_update_project "$project" || return 1
      printf 'dirty\n' > "$project/untracked.txt"
      snapshot_live "$project" "$UPDATE_TMP/dirty-artifacts-base"
      while IFS= read -r command; do
        status=0
        output=$(run_cumaru "$project" update $command 2>&1) || status=$?
        [ "$status" -ne 0 ] && [[ "$output" == *'Git work tree has pending changes'* ]] || return 1
        snapshots_match "$project" "$UPDATE_TMP/dirty-artifacts-base" >/dev/null || return 1
      done <<'EOF'
agent claude --apply
agent claude --clear
skills claude --apply
skills claude --clear
commands claude --apply
commands claude --clear
EOF
      no_transaction_debris "$project"
    }
    When call dirty_artifact_modes_rejected
    The status should equal 0
  End

  It 'rejects unsupported update agent options instead of ignoring them'
    project="$UPDATE_TMP/agent-options"; make_update_project "$project"
    When call run_cumaru "$project" update agent claude --from "$SOURCE" --apply
    The status should equal 2
    The output should include 'unexpected arg: --from'
  End
End
