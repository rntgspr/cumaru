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
    [ "$(yq -r '.meta.targets.values | join(",")' "$project/.cumaru/config.yaml")" != Transactional-source ] || return 1
    run_cumaru "$project" doctor --quiet | grep -q 'Summary: 0 error(s)' || return 1
    commit_update_project "$project" 'after update' || return 1
    snapshot_live "$project" "$UPDATE_TMP/base"
    run_cumaru "$project" update --from "$SOURCE" --apply >/dev/null || return 1
    When call snapshots_match "$project" "$UPDATE_TMP/base"
    The status should equal 0
  End

  It 'allows every mutating update mode outside Git with an explicit warning'
    nongit_update() {
      local project="$1" output
      shift
      output=$(run_cumaru "$project" update "$@" 2>&1) || {
        command printf '%s\n' "$output" >&2
        return 1
      }
      [[ "$output" == *'Not a Git work tree; continuing without a Git recovery point.'* ]] || return 1
      no_transaction_debris "$project"
    }

    nongit_mutations_succeed() {
      local project

      project="$UPDATE_TMP/nongit-general"
      make_update_project "$project" || return 1
      rm -rf "$project/.git"
      nongit_update "$project" --from "$SOURCE" --apply || return 1
      grep -qF 'Transactional framework prose marker.' "$project/.cumaru/domain.md" || return 1

      project="$UPDATE_TMP/nongit-scoped"
      make_update_project "$project" || return 1
      rm -rf "$project/.git"
      nongit_update "$project" domain.md --from "$SOURCE" --apply || return 1
      grep -qF 'Transactional framework prose marker.' "$project/.cumaru/domain.md" || return 1

      project="$UPDATE_TMP/nongit-agent"
      make_update_project "$project" || return 1
      rm -rf "$project/.git"
      nongit_update "$project" agent claude --apply || return 1
      [ -f "$project/CLAUDE.md" ] || return 1
      nongit_update "$project" agent claude --clear || return 1
      [ ! -f "$project/CLAUDE.md" ] || return 1
      nongit_update "$project" agent opencode --apply || return 1
      nongit_update "$project" agent --clear || return 1
      ! grep -qF '.cumaru/index.md' "$project/opencode.json" || return 1
      [ ! -f "$project/.agents/skills/cumaru-doctor/SKILL.md" ] || return 1
      [ ! -f "$project/.opencode/commands/cumaru/doctor.md" ] || return 1

      project="$UPDATE_TMP/nongit-skills"
      make_update_project "$project" || return 1
      rm -rf "$project/.git"
      nongit_update "$project" skills claude --apply || return 1
      [ -f "$project/.claude/skills/cumaru-doctor/SKILL.md" ] || return 1
      nongit_update "$project" skills claude --clear || return 1
      [ ! -f "$project/.claude/skills/cumaru-doctor/SKILL.md" ] || return 1
      nongit_update "$project" skills claude --apply || return 1
      nongit_update "$project" skills --clear || return 1
      [ ! -f "$project/.claude/skills/cumaru-doctor/SKILL.md" ] || return 1

      project="$UPDATE_TMP/nongit-commands"
      make_update_project "$project" || return 1
      rm -rf "$project/.git"
      nongit_update "$project" commands claude --apply || return 1
      [ -f "$project/.claude/commands/cumaru/doctor.md" ] || return 1
      nongit_update "$project" commands claude --clear || return 1
      [ ! -f "$project/.claude/commands/cumaru/doctor.md" ] || return 1
      nongit_update "$project" commands claude --apply || return 1
      nongit_update "$project" commands --clear || return 1
      [ ! -f "$project/.claude/commands/cumaru/doctor.md" ] || return 1
    }

    When call nongit_mutations_succeed
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

# The trailing `doctor` gate runs after every write. A gate failure caused by
# the update itself must leave the tree exactly as it was.
Describe 'update rollback when the trailing gate fails'
  gate_setup() {
    update_tmp_create
    SOURCE="$UPDATE_TMP/gate-source"
    PROJECT="$UPDATE_TMP/gate-project"
    make_plain_source "$SOURCE" || return
    make_update_project "$PROJECT" || return

    for config in "$SOURCE/domains/__base/config.yaml" "$PROJECT/.cumaru/config.yaml"; do
      printf '%s\n' \
        'version: 9' 'domain: base' 'rules:' \
        '  markdown: {required_heading: h1, frontmatter: {summary: {}}}' \
        '  index_md: {frontmatter: {}}' \
        '  pillar_index: {frontmatter: {}}' \
        'root:' \
        '  framework: true' \
        '  gated: {framework: true, "*.md": {framework: true}}' \
        'meta: {targets: {values: [meta]}}' > "$config" || return
    done

    mkdir -p "$SOURCE/domains/__base/gated" "$PROJECT/.cumaru/gated"
    printf '%s\n' '---' 'summary: Canonical gated index for the rollback boundary.' '---' '# Gated' > "$SOURCE/domains/__base/gated/index.md"
    cp "$SOURCE/domains/__base/gated/index.md" "$PROJECT/.cumaru/gated/index.md"
    # The canonical body drops the required `summary:` field, so the merge is
    # buildable but the post-write doctor gate must reject the result.
    printf '%s\n' '---' 'other: value' '---' '# Canonical gated member' > "$SOURCE/domains/__base/gated/member.md"
    printf '%s\n' '---' 'summary: Local gated member must survive a failed gate.' '---' '# Local gated member' > "$PROJECT/.cumaru/gated/member.md"
    commit_update_project "$PROJECT" 'gate rollback baseline'
  }

  gate_cleanup() { update_tmp_remove; }

  # A failed gate must restore every written file and report the rollback.
  verify_gate_rollback() {
    local output status
    snapshot_live "$PROJECT" "$UPDATE_TMP/gate-base"
    output=$(run_cumaru_combined "$PROJECT" update --from "$SOURCE" --apply); status=$?
    [ "$status" -eq 1 ] || return 1
    [[ "$output" == *'rolled back'* ]] || return 1
    snapshots_match "$PROJECT" "$UPDATE_TMP/gate-base" >/dev/null || return 1
    no_transaction_debris "$PROJECT"
  }

  BeforeEach 'gate_setup'
  AfterEach 'gate_cleanup'

  It 'restores every written file when doctor rejects the result'
    When call verify_gate_rollback
    The status should equal 0
  End
End
