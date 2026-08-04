Include tests/spec/contracts/spec_helper.sh

Describe 'cumaru-flow workflow orchestrator skill'
  flow_skill_policy_is_complete() {
    skill=$1

    file_has_compact_text "$skill" 'every name in its optional `needs` list has completed successfully' &&
      file_has_compact_text "$skill" 'choose the lexically first step name' &&
      file_has_compact_text "$skill" 'Recompute readiness after each successful step' &&
      file_has_compact_text "$skill" 'Never treat a partial result, a proposed edit, or an unanswered question as success' &&
      file_has_compact_text "$skill" 'Stop immediately when a step fails, needs user input, requests authorization, or cannot establish success' &&
      file_has_compact_text "$skill" 'Do not start any dependent step, including absorption or close-out, after an unsatisfied prerequisite' &&
      file_has_compact_text "$skill" 'Do not rerun any completed step automatically' &&
      file_has_compact_text "$skill" 'does not define, modify, or persist workflows or step state'
  }

  It 'keeps flow skill and launcher universal mirrors synchronized'
    canonical_skill="$CONTRACT_ROOT/domains/__base/skills/cumaru-flow/SKILL.md"
    canonical_launcher="$CONTRACT_ROOT/domains/__base/commands/cumaru/flow.md"

    The path "$canonical_skill" should be file
    The path "$canonical_launcher" should be file
    for domain in design-as-code iac-basic qa-basic sdlc-full sdlc-light vault-memory; do
      The value "$(files_equal "$canonical_skill" "$CONTRACT_ROOT/domains/$domain/skills/cumaru-flow/SKILL.md"; printf '%s' $?)" should equal 0
      The value "$(files_equal "$canonical_launcher" "$CONTRACT_ROOT/domains/$domain/commands/cumaru/flow.md"; printf '%s' $?)" should equal 0
    done
  End

  It 'keeps every launcher thin and linked to its namesake skill'
    When run bash -c '
      root=$1
      for command in "$root"/domains/*/commands/cumaru/flow.md; do
        grep -Fqx "Arguments: \`\$ARGUMENTS\`" "$command" &&
          grep -Fq "Load the installed \`cumaru-flow\` skill" "$command" &&
          ! grep -Eq "needs|success|failure|absorption" "$command" || exit 1
      done
    ' _ "$CONTRACT_ROOT"
    The status should be success
    The output should equal ''
    The stderr should equal ''
  End

  It 'requires successful prerequisites before chains, branches, joins, and absorption can proceed'
    skill="$CONTRACT_ROOT/domains/__base/skills/cumaru-flow/SKILL.md"
    When call flow_skill_policy_is_complete "$skill"
    The status should be success
    The output should equal ''
    The stderr should equal ''
  End
End
