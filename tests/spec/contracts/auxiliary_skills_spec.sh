Include tests/spec/contracts/spec_helper.sh

Describe 'auxiliary skill evidence contracts'
  It 'does not ship a release workflow'
    The path "$CONTRACT_ROOT/domains/sdlc-full/skills/cumaru-release/SKILL.md" should not be exist
    The path "$CONTRACT_ROOT/domains/sdlc-full/commands/cumaru/release.md" should not be exist
    The path "$CONTRACT_ROOT/domains/sdlc-full/templates/release-report.md" should not be exist
  End

  It 'keeps Cypress video disabled and reports only observed artifacts'
    skill="$CONTRACT_ROOT/skills/cypress/SKILL.md"
    The contents of file "$skill" should include 'video recording disabled (`video: false`'
    The contents of file "$skill" should include 'video exists without checking the runner configuration'
    The contents of file "$skill" should not include 'saves a **screenshot** and (in `run`) a **video**'
  End

  It 'distinguishes Vitest mock cleanup from application-state cleanup'
    skill="$CONTRACT_ROOT/skills/vitest/SKILL.md"
    The contents of file "$skill" should include '`vi.clearAllMocks()` clears call history'
    The contents of file "$skill" should include '`vi.resetAllMocks()` clears history and resets mock implementations'
    The contents of file "$skill" should include '`vi.restoreAllMocks()` also restores original descriptors'
    The contents of file "$skill" should include 'does not reset application state'
  End

  It 'keeps Playwright retries disabled and retains first-attempt failure traces'
    skill="$CONTRACT_ROOT/skills/playwright/SKILL.md"
    The contents of file "$skill" should include 'retries: 0'
    The contents of file "$skill" should include "trace: 'retain-on-failure'"
    The contents of file "$skill" should include 'tell the user'
    The contents of file "$skill" should not include "trace: 'on-first-retry'"
  End
End
