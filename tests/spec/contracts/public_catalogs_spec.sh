Include tests/spec/contracts/spec_helper.sh

Describe 'public discovery catalogs'
  It 'lists every shipped public domain'
    for path in "$CONTRACT_ROOT"/domains/*; do
      domain=$(basename "$path")
      [ "$domain" = __base ] && domain=base

      The contents of file "$CONTRACT_ROOT/README.md" should include "\`$domain\`"
      The contents of file "$CONTRACT_ROOT/docs/install.md" should include "\`$domain\`"
    done
  End

  It 'matches the verified dispatcher and help catalog without retired commands'
    dispatcher=$(sed -n '/^case "$sub" in/,/^esac/p' "$CONTRACT_ROOT/cumaru" |
      sed -nE 's/^  ([a-z][a-z-]*)\)$/\1/p' | LC_ALL=C sort)

    for command in $dispatcher; do
      The contents of file "$CONTRACT_ROOT/README.md" should include "| \`cumaru $command\` |"
    done
    The contents of file "$CONTRACT_ROOT/README.md" should include '| `cumaru help` |'
    The contents of file "$CONTRACT_ROOT/README.md" should include '| `cumaru help domains` |'
    The contents of file "$CONTRACT_ROOT/README.md" should not include '| `cumaru domains` |'
    The contents of file "$CONTRACT_ROOT/README.md" should not include '| `cumaru intake` |'
    The contents of file "$CONTRACT_ROOT/README.md" should include 'agent surfaces, not CLI'
  End

  It 'resolves every cataloged skill and launcher to shipped artifacts'
    install="$CONTRACT_ROOT/docs/install.md"

    for skill_path in "$CONTRACT_ROOT"/skills/*/SKILL.md "$CONTRACT_ROOT"/domains/*/skills/*/SKILL.md; do
      skill=$(basename "$(dirname "$skill_path")")
      The contents of file "$install" should include "\`$skill\`"
    done

    for command_path in "$CONTRACT_ROOT"/domains/*/commands/cumaru/*.md; do
      command=$(basename "$command_path" .md)
      The contents of file "$install" should include "/cumaru:$command"
    done
  End

  It 'preserves the bounded summary-curation trigger in public descriptions'
    for catalog in "$CONTRACT_ROOT/README.md" "$CONTRACT_ROOT/docs/install.md"; do
      The contents of file "$catalog" should include 'explicit `.cumaru` `summary:`'
      The value "$(file_has_compact_text "$catalog" 'General requests to summarize'; printf '%s' $?)" should equal 0
      The value "$(file_has_compact_text "$catalog" 'do not select'; printf '%s' $?)" should equal 0
      The contents of file "$catalog" should not include 'summarize anything'
    done
  End
End
