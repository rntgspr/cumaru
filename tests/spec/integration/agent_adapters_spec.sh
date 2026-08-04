Include tests/spec/integration/support/integration_helpers.sh

Describe 'stateless agent artifact integration'
  setup_adapters() { integration_tmp_create; }
  Before 'setup_adapters'
  After 'integration_tmp_remove'

  install_base() {
    mkdir -p "$1"
    run_in_project "$1" "$INTEGRATION_ROOT/cumaru" install --domain base >/dev/null
  }

  It 'does not persist an install-time adapter in config'
    project="$INTEGRATION_TMP/claude"; mkdir -p "$project"
    run_in_project "$project" "$INTEGRATION_ROOT/cumaru" install agent claude --domain base >/dev/null
    When run bash -c 'yq -e '\''has("agent") | not'\'' "$1/.cumaru/config.yaml" >/dev/null && test -f "$1/CLAUDE.md"' _ "$project"
    The status should be success
  End

  It 'requires an explicit adapter when applying artifacts'
    project="$INTEGRATION_TMP/project"; install_base "$project"
    When run run_in_project "$project" "$INTEGRATION_ROOT/cumaru" update skills --apply
    The status should eq 2
    The output should include 'requires an explicit agent'
  End

  It 'installs complete Claude instructions, skills, and commands explicitly'
    project="$INTEGRATION_TMP/project"; install_base "$project"
    run_in_project "$project" "$INTEGRATION_ROOT/cumaru" update agent claude --apply >/dev/null
    When run bash -c 'test -f "$1/CLAUDE.md" && test -f "$1/.claude/skills/cumaru-doctor/SKILL.md" && test -f "$1/.claude/commands/cumaru/doctor.md" && cd "$1" && "$2/cumaru" doctor | grep -q "Complete Cumaru claude instructions are installed"' _ "$project" "$INTEGRATION_ROOT"
    The status should be success
  End

  It 'rejects Codex project commands without mutation'
    project="$INTEGRATION_TMP/project"; install_base "$project"
    snapshot="$INTEGRATION_TMP/snapshot"; snapshot_managed_surfaces "$project" "$snapshot"
    When run run_in_project "$project" "$INTEGRATION_ROOT/cumaru" update commands codex --apply
    The status should be failure
    The output should include 'does not support a project slash-command directory'
    managed_surfaces_equal "$project" "$snapshot"; unchanged=$?
    The variable unchanged should eq 0
  End

  It 'preserves shared paths on scoped clear and directories on global clear'
    project="$INTEGRATION_TMP/project"; install_base "$project"
    run_in_project "$project" "$INTEGRATION_ROOT/cumaru" update agent codex --apply >/dev/null
    run_in_project "$project" "$INTEGRATION_ROOT/cumaru" update agent claude --apply >/dev/null
    printf '%s\n' adopter >"$project/.claude/skills/adopter.txt"
    run_in_project "$project" "$INTEGRATION_ROOT/cumaru" update agent claude --clear >/dev/null
    When run bash -c 'test -d "$1/.claude/skills/cumaru-doctor" && test ! -f "$1/.claude/skills/cumaru-doctor/SKILL.md" && test -f "$1/.claude/skills/adopter.txt" && test -f "$1/.agents/skills/cumaru-doctor/SKILL.md"' _ "$project"
    The status should be success
    run_in_project "$project" "$INTEGRATION_ROOT/cumaru" update agent --clear >/dev/null
    The path "$project/.agents/skills/cumaru-doctor" should be directory
    The path "$project/.agents/skills/cumaru-doctor/SKILL.md" should not be exist
  End

  It 'warns for legacy config when no instructions are installed'
    project="$INTEGRATION_TMP/project"; install_base "$project"
    yq -i '.agent = "claude"' "$project/.cumaru/config.yaml"
    When run run_in_project "$project" "$INTEGRATION_ROOT/cumaru" doctor --quiet
    The status should be success
    The output should include 'Retired config field: agent'
    The output should include 'No complete Cumaru agent instruction set is installed'
  End

  It 'warns for an incomplete instruction set'
    project="$INTEGRATION_TMP/project"; install_base "$project"
    run_in_project "$project" "$INTEGRATION_ROOT/cumaru" update agent claude --apply >/dev/null
    perl -0pi -e 's/<!-- END CUMARU-HOOK -->/<!-- END CUMARU-HOOK BROKEN -->/' "$project/CLAUDE.md"
    When run run_in_project "$project" "$INTEGRATION_ROOT/cumaru" doctor --quiet
    The status should be success
    The output should include 'No complete Cumaru agent instruction set is installed'
  End
End
