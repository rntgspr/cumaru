Include tests/spec/contracts/spec_helper.sh

Describe 'focus directive template'
  BeforeEach 'contract_tmp_setup'
  AfterEach 'contract_tmp_cleanup'

  # Instantiate a proposed directive from the shipped template and run doctor.
  check_focus_directive_template() {
    local project="$CONTRACT_TMP/focus-project"

    mkdir -p "$project"
    (
      cd "$project" || exit 1
      /bin/bash "$CONTRACT_CLI" install --domain focus >/dev/null || exit
      cp .cumaru/templates/directive.md .cumaru/directives/reliability.md
      yq -i --front-matter=process \
        '.summary = "Keep production reliability ahead of feature work." | .status = "proposed" | .priority = null' \
        .cumaru/directives/reliability.md || exit
      /bin/bash "$CONTRACT_CLI" doctor --quiet >/dev/null
    )
  }

  It 'produces a leaf that passes doctor'
    When call check_focus_directive_template
    The status should be success
  End

  It 'carries every contract field and section and is referenced by its consumers'
    template="$CONTRACT_ROOT/domains/focus/templates/directive.md"
    The value "$(yq --front-matter=extract -r 'keys | join(",")' "$template")" should equal 'human_revised,summary,status,priority'
    for section in Purpose Scope 'Value scope' 'Completion evidence' 'Decision points' 'Attention evidence' Boundaries 'Related threads' Changes; do
      The contents of file "$template" should include "## $section"
    done
    The contents of file "$template" should include '`parent`'
    The contents of file "$CONTRACT_ROOT/domains/focus/directives/index.md" should include 'templates/directive.md'
    The contents of file "$CONTRACT_ROOT/domains/focus/skills/cumaru-directives/SKILL.md" should include 'templates/directive.md'
  End
End

Describe 'focus cumaru-sources skill'
  BeforeEach 'contract_tmp_setup'
  AfterEach 'contract_tmp_cleanup'

  # Install focus for one adapter and verify the sources skill and command paths.
  check_focus_sources_adapter() {
    local agent="$1" project="$CONTRACT_TMP/focus-$1" skills commands
    mkdir -p "$project"
    (
      cd "$project" || exit 1
      /bin/bash "$CONTRACT_CLI" install agent "$agent" --domain focus >/dev/null || exit
      case "$agent" in
        claude) skills=.claude/skills; commands=.claude/commands ;;
        codex) skills=.agents/skills; commands= ;;
        opencode) skills=.agents/skills; commands=.opencode/commands ;;
        *) skills=.agents/skills; commands=.agents/commands ;;
      esac
      [ -f "$skills/cumaru-sources/SKILL.md" ] || exit 1
      [ -z "$commands" ] || [ -f "$commands/cumaru/sources.md" ] || exit 1
    )
  }

  Describe "adapter install"
    Parameters
      none
      claude
      codex
      opencode
    End

    It "installs the skill and command for adapter $1"
      When call check_focus_sources_adapter "$1"
      The status should be success
    End
  End

  # Simulate a scan run: one updated thread, one created thread, then doctor.
  check_focus_sources_run() {
    local project="$CONTRACT_TMP/focus-run"
    mkdir -p "$project"
    (
      cd "$project" || exit 1
      /bin/bash "$CONTRACT_CLI" install --domain focus >/dev/null || exit
      cp .cumaru/templates/source.md .cumaru/sources/jira-platform.md
      yq -i --front-matter=process '.summary = "Platform Jira project issues read for triage." | .status = "active"' \
        .cumaru/sources/jira-platform.md || exit
      cp .cumaru/templates/thread.md .cumaru/threads/A1B2C3.md
      yq -i --front-matter=process '.summary = "Existing platform ticket awaiting a source scan."' .cumaru/threads/A1B2C3.md || exit
      /bin/bash "$CONTRACT_CLI" doctor --quiet >/dev/null || exit
      yq -i --front-matter=process '.summary = "Platform ticket updated by a source scan." | .group = "today"' \
        .cumaru/threads/A1B2C3.md || exit
      cp .cumaru/templates/thread.md .cumaru/threads/D4E5F6.md
      yq -i --front-matter=process '.summary = "New platform ticket found by a source scan."' .cumaru/threads/D4E5F6.md || exit
      /bin/bash "$CONTRACT_CLI" doctor --quiet >/dev/null
    )
  }

  It 'passes doctor after a run that updates one thread and creates one'
    When call check_focus_sources_run
    The status should be success
  End

  It 'reports unavailable sources as unavailable and stays read-only'
    skill="$CONTRACT_ROOT/domains/focus/skills/cumaru-sources/SKILL.md"
    The contents of file "$skill" should include 'unavailable, never empty'
    The contents of file "$skill" should include 'strictly read-only'
    The contents of file "$skill" should include '`cumaru-thread`'
    The contents of file "$CONTRACT_ROOT/domains/focus/domain.md" should include 'skills/cumaru-sources/SKILL.md'
    The contents of file "$CONTRACT_ROOT/domains/focus/commands/cumaru/sources.md" should include '`cumaru-sources`'
  End
End
