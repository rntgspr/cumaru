Include tests/spec/contracts/spec_helper.sh

Describe 'slash command skill launchers'
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

  It 'keeps role and resolve as universal mirrored skills'
    for skill in role resolve; do
      canonical="$CONTRACT_ROOT/domains/__base/skills/cumaru-$skill/SKILL.md"
      The path "$canonical" should be file
      for domain in design-as-code iac-basic qa-basic sdlc-full sdlc-light vault-memory; do
        The value "$(files_equal "$canonical" "$CONTRACT_ROOT/domains/$domain/skills/cumaru-$skill/SKILL.md"; printf '%s' $?)" should equal 0
      done
    done
  End
End
