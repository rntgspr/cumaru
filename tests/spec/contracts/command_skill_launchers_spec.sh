Include tests/spec/contracts/spec_helper.sh

Describe 'slash command skill launchers'
  role_bootstrap_is_ordered() {
    skill=$1
    kernel=$(grep -nF '.cumaru/index.md' "$skill" | head -n 1 | cut -d: -f1)
    domain=$(grep -nF '.cumaru/domain.md' "$skill" | head -n 1 | cut -d: -f1)
    index=$(grep -nF '.cumaru/disciplines/index.md' "$skill" | head -n 1 | cut -d: -f1)
    bodies=$(grep -nF 'every remaining regular' "$skill" | head -n 1 | cut -d: -f1)
    tree=$(grep -nF 'cumaru tree . --rows' "$skill" | head -n 1 | cut -d: -f1)

    test -n "$kernel" && test "$kernel" -lt "$domain" &&
      test "$domain" -lt "$index" && test "$index" -lt "$bodies" &&
      test "$bodies" -lt "$tree" &&
      grep -Fq 'never persists role state' "$skill"
  }

  It 'maps every command to a namesake skill and forwards arguments first'
    When run bash -c '
      root=$1
      for command in "$root"/domains/*/commands/cumaru/*.md; do
        domain=${command%/commands/cumaru/*}
        name=$(basename "$command" .md)
        skill="$domain/skills/cumaru-$name/SKILL.md"
        test -f "$skill" || { printf "missing skill: %s\n" "$skill"; exit 1; }
        arguments_line=$(grep -nF '\''Arguments: `$ARGUMENTS`'\'' "$command" | cut -d: -f1)
        skill_line=$(grep -nF "Load the installed \`cumaru-$name\` skill" "$command" | cut -d: -f1)
        test -n "$arguments_line" && test -n "$skill_line" || { printf "invalid launcher: %s\n" "$command"; exit 1; }
        test "$arguments_line" -lt "$skill_line" || { printf "arguments after skill: %s\n" "$command"; exit 1; }
        if grep -Eq '\''\$[0-9]|\$ARGUMENTS\['\'' "$command"; then
          printf "positional argument: %s\n" "$command"; exit 1
        fi
      done
    ' _ "$CONTRACT_ROOT"
    The status should be success
    The output should equal ''
    The stderr should equal ''
  End

  It 'keeps role as a universal mirrored skill'
    canonical="$CONTRACT_ROOT/domains/__base/skills/cumaru-role/SKILL.md"
    The path "$canonical" should be file
    for domain in design-as-code iac-basic qa-basic sdlc-full sdlc-light vault-memory; do
      The value "$(files_equal "$canonical" "$CONTRACT_ROOT/domains/$domain/skills/cumaru-role/SKILL.md"; printf '%s' $?)" should equal 0
    done
  End

  It 'reloads the complete ordered bootstrap before applying a role'
    skill="$CONTRACT_ROOT/domains/__base/skills/cumaru-role/SKILL.md"
    When call role_bootstrap_is_ordered "$skill"
    The status should be success
    The output should equal ''
    The error should equal ''
  End
End
