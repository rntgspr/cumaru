Include tests/spec/contracts/spec_helper.sh

Describe 'cumaru-summarize artifacts'
  SKILL="$CONTRACT_ROOT/domains/__base/skills/cumaru-summarize/SKILL.md"
  COMMAND="$CONTRACT_ROOT/domains/__base/commands/cumaru/summarize.md"

  It 'ships canonical skill and command files'
    The path "$SKILL" should be file
    The path "$COMMAND" should be file
  End

  It 'keeps the skill and command byte-identical in every domain'
    for domain in iac-basic qa-basic sdlc-full sdlc-light vault-memory; do
      The path "$CONTRACT_ROOT/domains/$domain/skills/cumaru-summarize/SKILL.md" should be file
      The path "$CONTRACT_ROOT/domains/$domain/commands/cumaru/summarize.md" should be file
      The value "$(files_equal "$SKILL" "$CONTRACT_ROOT/domains/$domain/skills/cumaru-summarize/SKILL.md"; printf '%s' $?)" should equal 0
      The value "$(files_equal "$COMMAND" "$CONTRACT_ROOT/domains/$domain/commands/cumaru/summarize.md"; printf '%s' $?)" should equal 0
    done
  End

  It 'retains summarize skill contract: %1'
    while IFS= read -r text; do
      The contents of file "$SKILL" should include "$text"
    done <<'EOF'
name: cumaru-summarize
Use only when the user explicitly requests `.cumaru` `summary:` frontmatter maintenance
repair missing summary frontmatter in .cumaru
fix invalid .cumaru summaries
refresh stale .cumaru summary frontmatter
Do not use for general requests to summarize text, documentation, files, or a conversation
every regular Markdown file under `.cumaru/`
local root-level support
leaves first
directory `index.md` files deepest-first
Preserve every valid summary by default
without per-file confirmation
meaning, ownership, scope
new authorization boundary
Modify only the `summary` frontmatter value
between 32 and 512 Unicode code points
no CR, LF, or tab
Run `cumaru doctor` when complete
EOF
  End

  It 'documents framework consumers and bounded trigger scenarios'
    for text in 'cumaru tree' 'loading rule' 'prune the rest' \
      'current navigation/summary contract' 'SessionStart adapters' \
      'root `cumaru tree .` projection' 'distinguishes neighboring candidates'; do
      The contents of file "$SKILL" should include "$text"
    done
    The contents of file "$SKILL" should include '"repair missing summary frontmatter in .cumaru" selects this workflow'
    The contents of file "$SKILL" should include '"summarize this conversation" does not select this workflow'
    The contents of file "$SKILL" should include 'not proof of automatic selection by a live agent'
  End

  It 'keeps the command as a thin launcher for the canonical skill'
    The contents of file "$COMMAND" should include 'Load the installed `cumaru-summarize` skill'
  End
End
