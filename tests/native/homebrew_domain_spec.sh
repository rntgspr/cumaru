Include tests/native/helpers.sh

Describe 'native homebrew-management domain'
  BeforeEach 'native_setup'
  AfterEach 'native_cleanup'

  # Writes one formula and one cask entity, each pointing at its real Ruby file.
  homebrew_entities() {
    mkdir -p "$PROJECT/Formula" "$PROJECT/Casks"
    printf 'class Tool < Formula\nend\n' > "$PROJECT/Formula/tool.rb"
    printf 'class Other < Formula\nend\n' > "$PROJECT/Formula/other.rb"
    printf 'cask "app" do\nend\n' > "$PROJECT/Casks/app.rb"

    cli fs templates/formula.md copy formulae/tool/index.md >/dev/null || return
    cli fs templates/cask.md copy casks/app/index.md >/dev/null || return
    for pair in formulae/tool:Formula/tool.rb casks/app:Casks/app.rb; do
      entity=${pair%%:*}; target=${pair#*:}; name=${entity#*/}
      cat > "$PROJECT/.cumaru/$entity/index.md" <<ENTITY
---
human_revised: false
name: $name
summary: Fixture entity that points at its real Ruby package file.
targets: [platform]
upstream: example/$name
visibility: public
---

# $name

<!-- cumaru:reference -->
| Link | Description |
|------|-------------|
| [$target]($target) | Fixture package definition. |
<!-- /cumaru:reference -->
ENTITY
    done
    git_baseline
  }

  It 'installs both package pillars, the bump procedure, and the gate discipline'
    When call cli install --domain homebrew-management
    The status should be success
    The output should include 'Installed'
    The path "$PROJECT/.cumaru/formulae/index.md" should be file
    The path "$PROJECT/.cumaru/casks/index.md" should be file
    The path "$PROJECT/.cumaru/release/bump.md" should be file
    The path "$PROJECT/.cumaru/templates/formula.md" should be file
    The path "$PROJECT/.cumaru/templates/cask.md" should be file
    The path "$PROJECT/.cumaru/disciplines/package-change.md" should be file
    The path "$PROJECT/.cumaru/migration.md" should not be exist
    The path "$PROJECT/.cumaru/bootstrap.md" should not be exist
  End

  It 'counts reference rows from formulae and casks against the real Ruby'
    cli install --domain homebrew-management >/dev/null
    homebrew_entities
    When call cli coverage --rows
    The status should be success
    The output should include "covered	Formula/tool.rb	formulae/tool/index.md"
    The output should include "covered	Casks/app.rb	casks/app/index.md"
    The output should include "uncovered	Formula/other.rb"
    The error should be blank
  End

  It 'validates installed entities with doctor'
    cli install --domain homebrew-management >/dev/null
    homebrew_entities
    When call cli doctor
    The output should include '0 error(s)'
    The error should be blank
  End
End
