Include tests/native/helpers.sh

Describe 'native ai-ccn domain'
  BeforeEach 'native_setup'
  AfterEach 'native_cleanup'

  # Writes one creator profile, one task, and one post plan named by that creator's prefix.
  ai_ccn_entities() {
    cli fs templates/creator.md copy creator/ada/index.md >/dev/null || return
    cli fs templates/post.md copy posts/ADA-0001/index.md >/dev/null || return

    cat > "$PROJECT/.cumaru/creator/ada/index.md" <<'ENTITY'
---
human_revised: false
targets: [platform]
summary: Fixture creator who explains personal finance to first-time investors.
slug: ada
post-prefix: ADA
---

# Ada

## Characteristics
ENTITY

    cli fs templates/task.md copy tasks/weekly-recap/index.md >/dev/null || return
    cat > "$PROJECT/.cumaru/tasks/weekly-recap/index.md" <<'ENTITY'
---
human_revised: false
targets: [platform]
summary: Fixture task that assembles a weekly recap for one creator.
status: draft
mode: automatic
creator: ada
---

# Weekly recap
ENTITY

    cat > "$PROJECT/.cumaru/posts/ADA-0001/index.md" <<'ENTITY'
---
human_revised: false
targets: [platform]
summary: Fixture post plan that introduces the creator to a new audience.
---

# ADA-0001 | Fixture introduction

- **Creator** — [Ada](../../creator/ada/index.md).
- **Status** — `draft`.
ENTITY
  }

  It 'installs the constitution, every pillar, and their templates'
    When call cli install --domain ai-ccn
    The status should be success
    The output should include 'Installed'
    The path "$PROJECT/.cumaru/constitution.md" should be file
    The path "$PROJECT/.cumaru/creator/index.md" should be file
    The path "$PROJECT/.cumaru/posts/index.md" should be file
    The path "$PROJECT/.cumaru/tasks/index.md" should be file
    The path "$PROJECT/.cumaru/templates/creator.md" should be file
    The path "$PROJECT/.cumaru/templates/post.md" should be file
    The path "$PROJECT/.cumaru/templates/task.md" should be file
    The path "$PROJECT/.cumaru/migration.md" should not be exist
    The path "$PROJECT/.cumaru/bootstrap.md" should not be exist
  End

  It 'validates a fresh install with doctor'
    cli install --domain ai-ccn >/dev/null
    When call cli doctor
    The output should include '0 error(s)'
    The error should be blank
  End

  It 'validates a creator profile, a task, and a prefixed post plan with doctor'
    cli install --domain ai-ccn >/dev/null
    ai_ccn_entities
    When call cli doctor
    The output should include '0 error(s)'
    The error should be blank
  End

  It 'reports a creator profile without its post prefix'
    cli install --domain ai-ccn >/dev/null
    ai_ccn_entities
    sed -i.bak '/^post-prefix:/d' "$PROJECT/.cumaru/creator/ada/index.md"
    rm "$PROJECT/.cumaru/creator/ada/index.md.bak"
    When call cli doctor
    The status should be failure
    The output should include 'post-prefix'
    The output should include '1 error(s)'
  End

  It 'reports a task without its mode'
    cli install --domain ai-ccn >/dev/null
    ai_ccn_entities
    sed -i.bak '/^mode:/d' "$PROJECT/.cumaru/tasks/weekly-recap/index.md"
    rm "$PROJECT/.cumaru/tasks/weekly-recap/index.md.bak"
    When call cli doctor
    The status should be failure
    The output should include 'mode'
    The output should include '1 error(s)'
  End
End
