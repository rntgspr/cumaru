Include tests/spec/integration/support/integration_helpers.sh

Describe 'stateless agent artifact integration'
  setup_adapters() { integration_tmp_create; }
  Before 'setup_adapters'
  After 'integration_tmp_remove'

  install_base() {
    mkdir -p "$1"
    run_in_project "$1" "$INTEGRATION_ROOT/cumaru" install --domain base >/dev/null
  }

  # Verify global shared-skill cleanup, preservation, and repeatability.
  verify_shared_skill_uninstall() {
    local adapter project skill_file
    for adapter in generic codex opencode; do
      project="$INTEGRATION_TMP/uninstall-$adapter"
      mkdir -p "$project"
      if [ "$adapter" = generic ]; then
        run_in_project "$project" "$INTEGRATION_ROOT/cumaru" install --domain base --with git >/dev/null || return
      else
        run_in_project "$project" "$INTEGRATION_ROOT/cumaru" install agent "$adapter" --domain base --with git >/dev/null || return
      fi
      mkdir -p "$project/.agents/skills/adopter"
      printf '%s\n' adopter >"$project/.agents/skills/adopter/SKILL.md"

      run_in_project "$project" "$INTEGRATION_ROOT/cumaru" uninstall --yes >/dev/null || return
      test ! -d "$project/.cumaru" || return
      test -f "$project/.agents/skills/git/SKILL.md" || return
      test -f "$project/.agents/skills/adopter/SKILL.md" || return
      for skill_file in "$project"/.agents/skills/cumaru-*/SKILL.md; do
        test ! -e "$skill_file" || return
      done

      run_in_project "$project" "$INTEGRATION_ROOT/cumaru" uninstall --yes >/dev/null || return
      test -f "$project/.agents/skills/git/SKILL.md" || return
      test -f "$project/.agents/skills/adopter/SKILL.md" || return
    done
  }

  It 'does not persist an install-time adapter in config'
    project="$INTEGRATION_TMP/claude"; mkdir -p "$project"
    run_in_project "$project" "$INTEGRATION_ROOT/cumaru" install agent claude --domain base >/dev/null
    When run bash -c 'yq -e '\''has("agent") | not'\'' "$1/.cumaru/config.yaml" >/dev/null && test -f "$1/CLAUDE.md"' _ "$project"
    The status should be success
  End

  It 'refuses reinstall and routes existing projects to update without mutation'
    project="$INTEGRATION_TMP/existing"; install_base "$project"
    snapshot="$INTEGRATION_TMP/existing-snapshot"; snapshot_managed_surfaces "$project" "$snapshot"
    When run run_in_project "$project" "$INTEGRATION_ROOT/cumaru" install --domain base --with git
    The status should be failure
    The output should include 'target .cumaru is already installed'
    The output should include 'cumaru update skills <agent> --with <skill>'
    managed_surfaces_equal "$project" "$snapshot"; unchanged=$?
    The variable unchanged should eq 0
  End

  It 'materializes the discipline index before discipline bodies'
    project="$INTEGRATION_TMP/generic"; install_base "$project"
    When run bash -c '
      index=$(grep -nF "<!-- BEGIN CUMARU-DISCIPLINE .cumaru/disciplines/index.md -->" "$1/.agents/AGENTS.md" | cut -d: -f1)
      body=$(grep -nF "<!-- BEGIN CUMARU-DISCIPLINE .cumaru/disciplines/code-comments.md -->" "$1/.agents/AGENTS.md" | cut -d: -f1)
      test -n "$index" && test -n "$body" && test "$index" -lt "$body"
    ' _ "$project"
    The status should be success
  End

  It 'requires an explicit adapter when applying artifacts'
    project="$INTEGRATION_TMP/project"; install_base "$project"
    When run run_in_project "$project" "$INTEGRATION_ROOT/cumaru" update skills --apply
    The status should eq 2
    The output should include 'requires an explicit agent'
  End

  It 'installs only requested opt-in skills and preserves the knowledge tree'
    project="$INTEGRATION_TMP/opt-in"; install_base "$project"
    cp -R "$project/.cumaru" "$INTEGRATION_TMP/cumaru-before"
    git_clean_baseline "$project" || return 1
    run_in_project "$project" "$INTEGRATION_ROOT/cumaru" update skills codex --with git >/dev/null || return 1
    test ! -e "$project/.agents/skills/git" || return 1
    run_in_project "$project" "$INTEGRATION_ROOT/cumaru" update skills codex --with git --apply >/dev/null || return 1
    When run bash -c '
      diff -r "$1" "$2/.cumaru" >/dev/null &&
      test -f "$2/.agents/skills/git/SKILL.md" &&
      test -f "$2/.agents/skills/cumaru-doctor/SKILL.md" &&
      test ! -e "$2/.agents/skills/terraform"
    ' _ "$INTEGRATION_TMP/cumaru-before" "$project"
    The status should be success
  End

  It 'rejects an unknown opt-in before changing managed surfaces'
    project="$INTEGRATION_TMP/unknown-opt-in"; install_base "$project"
    git_clean_baseline "$project" || return 1
    snapshot="$INTEGRATION_TMP/unknown-snapshot"; snapshot_managed_surfaces "$project" "$snapshot"
    When run run_in_project "$project" "$INTEGRATION_ROOT/cumaru" update skills codex --with missing-skill --apply
    The status should be failure
    The output should include 'skill not found: missing-skill'
    managed_surfaces_equal "$project" "$snapshot"; unchanged=$?
    The variable unchanged should eq 0
  End

  It 'installs complete Claude instructions, skills, and commands explicitly'
    project="$INTEGRATION_TMP/project"; install_base "$project"
    git_clean_baseline "$project" || return 1
    run_in_project "$project" "$INTEGRATION_ROOT/cumaru" update agent claude --apply >/dev/null
    When run bash -c 'test -f "$1/CLAUDE.md" && test -f "$1/.claude/skills/cumaru-doctor/SKILL.md" && test -f "$1/.claude/commands/cumaru/doctor.md" && cd "$1" && "$2/cumaru" doctor | grep -q "Complete Cumaru claude instructions are installed"' _ "$project" "$INTEGRATION_ROOT"
    The status should be success
  End

  It 'installs matching OpenCode skills and argument-forwarding commands'
    project="$INTEGRATION_TMP/opencode"; mkdir -p "$project"
    run_in_project "$project" "$INTEGRATION_ROOT/cumaru" install agent opencode --domain base >/dev/null
    When run bash -c '
      test -f "$1/.agents/skills/cumaru-role/SKILL.md" &&
      test -f "$1/.opencode/commands/cumaru/role.md" &&
      grep -Fq '\''Arguments: `$ARGUMENTS`'\'' "$1/.opencode/commands/cumaru/role.md" &&
      grep -Fq '\''Load the installed `cumaru-role` skill'\'' "$1/.opencode/commands/cumaru/role.md"
    ' _ "$project"
    The status should be success
  End

  It 'removes retired Cumaru skills and commands during complete artifact refresh'
    project="$INTEGRATION_TMP/retired"; mkdir -p "$project"
    run_in_project "$project" "$INTEGRATION_ROOT/cumaru" install agent opencode --domain base >/dev/null
    mkdir -p "$project/.agents/skills/cumaru-resolve" "$project/.opencode/commands/cumaru"
    printf '%s\n' retired > "$project/.agents/skills/cumaru-resolve/SKILL.md"
    printf '%s\n' retired > "$project/.opencode/commands/cumaru/resolve.md"
    printf '%s\n' adopter > "$project/.opencode/commands/adopter.md"
    git_clean_baseline "$project" || return 1
    run_in_project "$project" "$INTEGRATION_ROOT/cumaru" update agent opencode --apply >/dev/null
    When run bash -c '
      test ! -e "$1/.agents/skills/cumaru-resolve" &&
      test ! -e "$1/.opencode/commands/cumaru/resolve.md" &&
      test -f "$1/.agents/skills/cumaru-role/SKILL.md" &&
      test -f "$1/.opencode/commands/cumaru/role.md" &&
      test -f "$1/.opencode/commands/adopter.md"
    ' _ "$project"
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

  It 'executes scoped and all-agent clear immediately without apply'
    project="$INTEGRATION_TMP/project"; install_base "$project"
    git_clean_baseline "$project" || return 1
    run_in_project "$project" "$INTEGRATION_ROOT/cumaru" update agent codex --apply >/dev/null
    git_clean_baseline "$project" 'codex artifacts' || return 1
    run_in_project "$project" "$INTEGRATION_ROOT/cumaru" update agent claude --apply >/dev/null
    printf '%s\n' adopter >"$project/.claude/skills/adopter.txt"
    git_clean_baseline "$project" 'claude artifacts and adopter file' || return 1
    run_in_project "$project" "$INTEGRATION_ROOT/cumaru" update agent claude --clear >/dev/null
    When run bash -c 'test -d "$1/.claude/skills/cumaru-doctor" && test ! -f "$1/.claude/skills/cumaru-doctor/SKILL.md" && test -f "$1/.claude/skills/adopter.txt" && test -f "$1/.agents/skills/cumaru-doctor/SKILL.md"' _ "$project"
    The status should be success
    git_clean_baseline "$project" 'after scoped clear' || return 1
    run_in_project "$project" "$INTEGRATION_ROOT/cumaru" update agent --clear >/dev/null
    The path "$project/.agents/skills/cumaru-doctor" should be directory
    The path "$project/.agents/skills/cumaru-doctor/SKILL.md" should not be exist
  End

  It 'executes skill clear immediately without removing instructions or commands'
    project="$INTEGRATION_TMP/skills-clear"; install_base "$project"
    git_clean_baseline "$project" || return 1
    run_in_project "$project" "$INTEGRATION_ROOT/cumaru" update agent claude --apply >/dev/null
    git_clean_baseline "$project" 'claude artifacts' || return 1
    run_in_project "$project" "$INTEGRATION_ROOT/cumaru" update skills claude --clear >/dev/null
    When run bash -c 'test -f "$1/CLAUDE.md" && test ! -f "$1/.claude/skills/cumaru-doctor/SKILL.md" && test -f "$1/.claude/commands/cumaru/doctor.md"' _ "$project"
    The status should be success
  End

  It 'rejects retired adapter config before checking instructions'
    project="$INTEGRATION_TMP/project"; install_base "$project"
    yq -i '.agent = "claude"' "$project/.cumaru/config.yaml"
    When run run_in_project "$project" "$INTEGRATION_ROOT/cumaru" doctor --quiet
    The status should be failure
    The output should include 'invalid config: .cumaru/config.yaml'
    The error should include '/agent: unknown property'
  End

  It 'warns for an incomplete instruction set'
    project="$INTEGRATION_TMP/project"; install_base "$project"
    git_clean_baseline "$project" || return 1
    run_in_project "$project" "$INTEGRATION_ROOT/cumaru" update agent claude --apply >/dev/null
    perl -0pi -e 's/<!-- END CUMARU-HOOK -->/<!-- END CUMARU-HOOK BROKEN -->/' "$project/CLAUDE.md"
    When run run_in_project "$project" "$INTEGRATION_ROOT/cumaru" doctor --quiet
    The status should be success
    The output should include 'No complete Cumaru agent instruction set is installed'
  End

  It 'executes command clear immediately without removing instructions or skills'
    project="$INTEGRATION_TMP/project"; install_base "$project"
    git_clean_baseline "$project" || return 1
    run_in_project "$project" "$INTEGRATION_ROOT/cumaru" update agent claude --apply >/dev/null
    git_clean_baseline "$project" 'claude artifacts' || return 1
    run_in_project "$project" "$INTEGRATION_ROOT/cumaru" update commands claude --clear >/dev/null
    When run bash -c 'test -f "$1/CLAUDE.md" && test -f "$1/.claude/skills/cumaru-doctor/SKILL.md" && test ! -f "$1/.claude/commands/cumaru/doctor.md"' _ "$project"
    The status should be success
  End

  It 'removes shared Cumaru skills for Generic, Codex, and OpenCode while preserving other skills'
    When call verify_shared_skill_uninstall
    The status should be success
  End
End
