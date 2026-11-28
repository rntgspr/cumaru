Include tests/spec/contracts/spec_helper.sh

Describe 'cumaru bootstrap prose delivery'
  FOCUS_DOC="$CONTRACT_ROOT/domains/focus/bootstrap.md"
  BeforeEach 'contract_tmp_setup'
  AfterEach 'contract_tmp_cleanup'

  # Installs focus into a fresh project and prints its path.
  focus_project() {
    project="$CONTRACT_TMP/focus"
    mkdir -p "$project"
    (cd "$project" && bash "$CONTRACT_CLI" install --domain focus) >/dev/null 2>&1 || return
    printf '%s\n' "$project"
  }

  # Verifies install and update both keep bootstrap.md out of .cumaru/.
  source_only() {
    project=$(focus_project) || return
    test ! -e "$project/.cumaru/bootstrap.md" || return
    (cd "$project" && bash "$CONTRACT_CLI" update --from "$CONTRACT_ROOT" --apply) >/dev/null 2>&1
    test ! -e "$project/.cumaru/bootstrap.md"
  }
  It 'never installs or updates bootstrap.md into .cumaru/'
    When call source_only
    The status should be success
    The stdout should equal ''
  End

  # Prints bootstrap output and fails if the command wrote any file.
  bootstrap_readonly() {
    project=$(focus_project) || return
    before=$(find "$project" -type f -exec cksum {} + | sort)
    (cd "$project" && bash "$CONTRACT_CLI" bootstrap) || return
    after=$(find "$project" -type f -exec cksum {} + | sort)
    test "$before" = "$after"
  }
  It 'prints __base then focus with frontmatter stripped and writes nothing'
    When call bootstrap_readonly
    The status should be success
    The line 1 of output should equal '# Bootstrap — focus'
    The output should include '## Universal rules'
    The output should include '## focus — bootstrap steps'
    The output should not include 'summary:'
    The output should not include '---'
  End

  bootstrap_order() {
    bootstrap_readonly | awk '/^## Universal rules/{b=NR} /^## focus — bootstrap steps/{f=NR} END{exit !(b && b < f)}'
  }
  It 'orders the base body before the domain body'
    When call bootstrap_order
    The status should be success
  End

  unknown_domain() {
    project="$CONTRACT_TMP/unknown"
    mkdir -p "$project/.cumaru"
    printf 'version: 9\ndomain: nope\n' >"$project/.cumaru/config.yaml"
    (cd "$project" && bash "$CONTRACT_CLI" bootstrap)
  }
  It 'fails with a diagnostic for an unknown domain'
    When call unknown_domain
    The status should be failure
    The output should include "unknown domain 'nope'"
  End

  absent_doc() {
    project="$CONTRACT_TMP/absent"
    mkdir -p "$project/.cumaru"
    printf 'version: 9\ndomain: sdlc-light\n' >"$project/.cumaru/config.yaml"
    (cd "$project" && bash "$CONTRACT_CLI" bootstrap)
  }
  It 'prints the domain body for a domain that used to ship none'
    When call absent_doc
    The status should be success
    The output should include '## Universal rules'
    The output should include '## sdlc-light — bootstrap steps'
    The output should not include 'ships no bootstrap.md'
  End

  # Lists every domain pillar dir and template missing from its bootstrap.md.
  domain_coverage_gaps() {
    for dir in "$CONTRACT_ROOT"/domains/*/; do
      domain=$(basename "$dir")
      [ "$domain" = __base ] && continue
      doc="$dir/bootstrap.md"
      [ -f "$doc" ] || { printf "%s: missing bootstrap.md\n" "$domain"; continue; }
      for pillar in $(yq ".root | keys | .[]" "$dir/config.yaml"); do
        [ -d "$dir/$pillar" ] || continue
        grep -Fq "\`$pillar/" "$doc" || printf "%s: pillar %s\n" "$domain" "$pillar"
      done
      for tpl in "$dir"/templates/*.md; do
        name=$(basename "$tpl")
        [ "$name" = index.md ] && continue
        grep -Fq "templates/$name" "$doc" || printf "%s: template %s\n" "$domain" "$name"
      done
    done
  }
  It 'names every pillar and template in each domain bootstrap.md'
    When call domain_coverage_gaps
    The stdout should equal ''
  End

  # Lists focus bootstrap skills missing from focus bootstrap.md.
  focus_coverage_gaps() {
    grep -Fq 'cumaru-sources' "$FOCUS_DOC" || printf 'skill cumaru-sources\n'
    grep -Fq 'cumaru-directives' "$FOCUS_DOC" || printf 'skill cumaru-directives\n'
  }
  It 'names every focus bootstrap skill'
    When call focus_coverage_gaps
    The stdout should equal ''
  End

  # Print the focus bootstrap step titles in document order.
  focus_step_order() {
    sed -nE 's/^[0-9]+\. \*\*([^*]+)\.\*\*.*/\1/p' "$FOCUS_DOC" | paste -sd, -
  }

  It 'orders sources, directives, outcomes, then the presentation skill'
    When call focus_step_order
    The stdout should start with 'Sources,Directives,Outcomes,Presentation skill,'
  End

  It 'keeps the presentation skill adopter-owned and read-only'
    The contents of file "$FOCUS_DOC" should include 'without the `cumaru-` prefix'
    The contents of file "$FOCUS_DOC" should include 'never edits threads'
    The contents of file "$FOCUS_DOC" should include 'reported as unavailable, never written as active'
    The contents of file "$CONTRACT_ROOT/domains/__base/bootstrap.md" should include 'write it only once the user confirms'
  End

  It 'points the focus install skill to cumaru bootstrap'
    The contents of file "$CONTRACT_ROOT/domains/focus/skills/cumaru-install/SKILL.md" should include 'cumaru bootstrap'
    The contents of file "$CONTRACT_ROOT/domains/focus/skills/cumaru-install/SKILL.md" should not include '## Bootstrap (ask, do not assume)'
  End
End
