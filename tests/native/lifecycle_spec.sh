Include tests/native/helpers.sh

Describe 'native installation and update regressions adapted from legacy adapter/update suites'
  BeforeEach 'native_setup'
  AfterEach 'native_cleanup'

  Context 'adapter matrix'
  Parameters
    none .agents/AGENTS.md .agents/skills/cumaru-role/SKILL.md
    claude CLAUDE.md .claude/skills/cumaru-role/SKILL.md
    codex AGENTS.md .agents/skills/cumaru-role/SKILL.md
    opencode opencode.json .agents/skills/cumaru-role/SKILL.md
  End
  It 'materializes each stateless adapter and preserves unrelated files through uninstall'
    printf 'keep\n' > "$PROJECT/notes.txt"
    When call cli install agent "$1" --domain sdlc-light
    The status should be success
    The error should be blank
    The output should include 'Installed'
    The path "$PROJECT/$2" should be file
    The path "$PROJECT/$3" should be file
    The path "$PROJECT/.cumaru/config.yaml" should be file
    The contents of file "$PROJECT/.cumaru/config.yaml" should not include 'agent:'
    The result of function uninstall_and_read should equal keep
  End
  End

  It 'refuses replacement before network access and preserves the whole adopter'
    cli install --domain sdlc-light >/dev/null
    before=$(snapshot)
    : > "$CUMARU_TEST_REQUESTS"
    When call cli install --domain sdlc-light
    The status should equal 1
    The output should be blank
    The error should include 'already exists'
    The value "$(snapshot)" should equal "$before"
    The contents of file "$CUMARU_TEST_REQUESTS" should be blank
  End

  It 'rejects truncated source inventories before any project write'
    export CUMARU_TEST_TRUNCATED=1
    before=$(snapshot)
    When call cli install --domain sdlc-light
    The status should equal 1
    The output should not include 'Installed'
    The error should include 'truncated'
    The value "$(snapshot)" should equal "$before"
  End

  It 'rejects a missing remote asset before publishing an installation'
    export CUMARU_TEST_MISSING=domains/sdlc-light/domain.md
    before=$(snapshot)
    When call cli install --domain sdlc-light
    The status should equal 1
    The output should not include 'Installed'
    The error should include 'HTTP 404'
    The value "$(snapshot)" should equal "$before"
  End
End

Describe 'native preservation regressions adapted from legacy update transactions and opaque tags'
  BeforeEach 'installed_setup'
  AfterEach 'native_cleanup'

  It 'previews update and config reconciliation without modifying adopter bytes'
    before=$(snapshot)
    When call preview_both
    The status should be success
    The output should include 'source: main (1111111111111111111111111111111111111111)'
    The error should be blank
    The value "$(snapshot)" should equal "$before"
    The contents of file "$CUMARU_TEST_REQUESTS" should not include '/main/domains/'
  End

  It 'refreshes framework prose while retaining opaque bodies and local-only files'
    printf '\nLocally altered framework prose.\n' >> "$PROJECT/.cumaru/domain.md"
    cli tag domain.md set reference 'Opaque adopter body, without table interpretation.' >/dev/null
    write_md "$PROJECT/.cumaru/local.md" 'Local-only adopter knowledge survives framework refresh.'
    local_before=$(cat "$PROJECT/.cumaru/local.md")
    When call cli update domain.md --apply
    The status should be success
    The output should include 'domain.md'
    The error should include 'without a Git recovery point'
    The contents of file "$PROJECT/.cumaru/domain.md" should include 'Opaque adopter body, without table interpretation.'
    The contents of file "$PROJECT/.cumaru/domain.md" should not include 'Locally altered framework prose.'
    The contents of file "$PROJECT/.cumaru/local.md" should equal "$local_before"
    The contents of file "$PROJECT/AGENTS.md" should include 'Keep this policy.'
  End

  It 'preserves prose in a content selector preview and apply'
    sed 's/^summary:.*/summary: Locally changed metadata retains a valid navigation summary./' "$PROJECT/.cumaru/domain.md" > "$PROJECT/domain.tmp"
    mv "$PROJECT/domain.tmp" "$PROJECT/.cumaru/domain.md"
    printf '\nLocally retained prose.\n' >> "$PROJECT/.cumaru/domain.md"
    before=$(snapshot)
    cli update domain.md --skip-prose >/dev/null
    preview_after=$(snapshot)
    When call cli update domain.md --skip-prose --apply
    The status should be success
    The output should include 'updated:'
    The error should include 'without a Git recovery point'
    The value "$preview_after" should equal "$before"
    The contents of file "$PROJECT/.cumaru/domain.md" should include 'Locally retained prose.'
    The contents of file "$PROJECT/.cumaru/domain.md" should not include 'Locally changed metadata'
  End

  It 'refreshes integration alone without modifying local Markdown'
    printf '\nLocally retained prose.\n' >> "$PROJECT/.cumaru/domain.md"
    printf '\nStale skill prose.\n' >> "$PROJECT/.agents/skills/cumaru-role/SKILL.md"
    domain_before=$(cat "$PROJECT/.cumaru/domain.md")
    When call cli update agent codex --skills --apply
    The status should be success
    The output should include 'updated:'
    The error should include 'without a Git recovery point'
    The contents of file "$PROJECT/.cumaru/domain.md" should equal "$domain_before"
    The contents of file "$PROJECT/.agents/skills/cumaru-role/SKILL.md" should not include 'Stale skill prose.'
  End

  It 'combines canonical prose and complete integration in one apply'
    printf '\nLocally replaced prose.\n' >> "$PROJECT/.cumaru/domain.md"
    printf '\nStale skill prose.\n' >> "$PROJECT/.agents/skills/cumaru-role/SKILL.md"
    When call cli update agent codex --prose --skills --apply
    The status should be success
    The output should include 'updated:'
    The error should include 'without a Git recovery point'
    The contents of file "$PROJECT/.cumaru/domain.md" should not include 'Locally replaced prose.'
    The contents of file "$PROJECT/.agents/skills/cumaru-role/SKILL.md" should not include 'Stale skill prose.'
    The contents of file "$PROJECT/.codex/hooks.json" should include 'SessionStart'
  End

  It 'rejects conflicting content selectors before source reads or mutation'
    before=$(snapshot)
    : > "$CUMARU_TEST_REQUESTS"
    When call cli update --prose --skip-prose
    The status should equal 2
    The output should be blank
    The error should include 'cannot be used with'
    The value "$(snapshot)" should equal "$before"
    The contents of file "$CUMARU_TEST_REQUESTS" should be blank
  End

  It 'clears owned adapter artifacts offline while retaining adopter skills and instructions'
    mkdir -p "$PROJECT/.agents/skills/adopter"
    printf 'custom\n' > "$PROJECT/.agents/skills/adopter/SKILL.md"
    : > "$CUMARU_TEST_REQUESTS"
    When call cli update agent codex --clear
    The status should be success
    The output should include 'remove:'
    The error should include 'without a Git recovery point'
    The contents of file "$PROJECT/AGENTS.md" should include 'Keep this policy.'
    The contents of file "$PROJECT/.agents/skills/adopter/SKILL.md" should equal custom
    The path "$PROJECT/.agents/skills/cumaru-role/SKILL.md" should not be exist
    The contents of file "$CUMARU_TEST_REQUESTS" should be blank
  End

  It 'rejects unbalanced tag edits and preserves the original host'
    before=$(snapshot)
    When call cli tag domain.md set reference '<!-- cumaru:unclosed -->'
    The status should equal 1
    The output should be blank
    The error should include 'unclosed'
    The value "$(snapshot)" should equal "$before"
  End

  It 'refuses dirty Git apply and preserves every adopter byte'
    git_baseline
    printf '\nChanged framework prose.\n' >> "$PROJECT/.cumaru/domain.md"
    before=$(snapshot)
    When call cli update domain.md --apply
    The status should equal 1
    The output should not include 'updated:'
    The error should include 'clean'
    The value "$(snapshot)" should equal "$before"
  End

  It 'refuses untracked Git state during clear and preserves owned artifacts'
    git_baseline
    printf 'pending\n' > "$PROJECT/untracked.txt"
    before=$(snapshot)
    When call cli update agent codex --clear
    The status should equal 1
    The output should not include 'updated:'
    The error should include 'clean'
    The value "$(snapshot)" should equal "$before"
  End

  It 'preserves adopter hooks and instructions through repeated adapter refresh'
    printf '{"custom":true,"hooks":{"SessionStart":[{"hooks":[{"type":"command","command":"echo adopter"}]}]}}' > "$PROJECT/.codex/hooks.json"
    mkdir -p "$PROJECT/.agents/skills/adopter"
    printf 'custom\n' > "$PROJECT/.agents/skills/adopter/SKILL.md"
    When call refresh_twice
    The status should equal 0
    The output should include 'doctor checks passed'
    The error should include 'without a Git recovery point'
    The contents of file "$PROJECT/.codex/hooks.json" should include 'echo adopter'
    The contents of file "$PROJECT/.codex/hooks.json" should include '"custom": true'
    The contents of file "$PROJECT/.agents/skills/adopter/SKILL.md" should equal custom
    The contents of file "$PROJECT/AGENTS.md" should include 'Keep this policy.'
  End
End
