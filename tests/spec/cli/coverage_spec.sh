Include tests/spec/cli/support/helpers.sh

Describe 'cumaru coverage'
  BeforeEach 'coverage_setup'
  AfterEach 'coverage_cleanup'

  It 'classifies every bucket and reports outside-host rows'
    When call cli_in "$COVERAGE_PROJECT" coverage
    The status should be success
    The output should include '[covered]   1/2 source file(s) referenced (50%)'
    The output should include '[foreign]   1 referenced file(s) outside the source scope'
    The output should include '[note]      1 reference row(s) hosted outside specs/ ignored'
    The output should include 'Summary: 1 covered, 1 uncovered, 1 stale, 1 invalid'
    The error should be blank
  End

  It 'emits exact machine-readable rows'
    When call cli_in "$COVERAGE_PROJECT" coverage --rows
    The status should be success
    The output should equal "covered	src/covered.ts	specs/coverage-fixture.md	Covered source implementation.
foreign	src/foreign-filtered.ts	specs/coverage-fixture.md	Existing file outside configured scope.
uncovered	src/uncovered.ts		
stale	src/missing.ts	specs/coverage-fixture.md	[stale](src/missing.ts)
invalid	.cumaru/index.md	specs/coverage-fixture.md	[invalid](.cumaru/index.md)"
    The error should be blank
  End

  It 'emits only uncovered paths in gaps mode'
    When call cli_in "$COVERAGE_PROJECT" coverage --gaps
    The status should be success
    The output should equal 'src/uncovered.ts'
    The error should be blank
  End

  It 'groups actionable refs and skips template rows'
    When call cli_in "$COVERAGE_PROJECT" coverage --refs
    The status should be success
    The output should include 'File: specs/coverage-fixture.md'
    The output should include 'src/missing.ts'
    The output should not include '<source-file>'
  End

  It 'strict mode fails while actionable gaps exist'
    When call cli_in "$COVERAGE_PROJECT" coverage --strict
    The status should be failure
    The output should include 'Summary: 1 covered, 1 uncovered, 1 stale, 1 invalid'
    The error should be blank
  End

  It 'strict mode succeeds after tag rotation closes every gap'
    body='| Link | Description |
|---|---|
| [covered](src/covered.ts) | Covered source implementation. |'
    printf '%s\n' "$body" | cli_in "$COVERAGE_PROJECT" tag set specs/coverage-fixture.md reference >/dev/null
    yq -i '.meta.coverage.source = ["src/covered.ts"]' "$COVERAGE_PROJECT/.cumaru/config.yaml"
    When call cli_in "$COVERAGE_PROJECT" coverage --strict
    The status should be success
    The output should include 'Summary: 1 covered, 0 uncovered, 0 stale, 0 invalid'
    The error should be blank
  End

  It 'reports an empty reference set without failing'
    printf '%s\n' '| Link | Description |' '|---|---|' | cli_in "$COVERAGE_PROJECT" tag set specs/coverage-fixture.md reference >/dev/null
    When call cli_in "$COVERAGE_PROJECT" coverage --refs
    The status should be success
    The output should include 'No reference rows found under .cumaru/specs/'
    The error should be blank
  End

  It 'all report modes leave the project byte-identical'
    cp -R "$COVERAGE_PROJECT" "$COVERAGE_TMP/baseline"
    cli_in "$COVERAGE_PROJECT" coverage >/dev/null
    cli_in "$COVERAGE_PROJECT" coverage --rows >/dev/null
    cli_in "$COVERAGE_PROJECT" coverage --gaps >/dev/null
    cli_in "$COVERAGE_PROJECT" coverage --refs >/dev/null
    cli_in "$COVERAGE_PROJECT" coverage --strict >/dev/null || :
    When call diff -r "$COVERAGE_TMP/baseline" "$COVERAGE_PROJECT"
    The status should be success
    The output should be blank
  End

  Context 'with invalid runtime state'
    Parameters
      missing-root '.cumaru not found'
      missing-config '.cumaru/config.yaml not found'
      missing-spec '.cumaru/specs/ not found'
      non-git 'needs a git work tree'
    End
    It 'fails guards on stderr without stdout'
      guarded="$COVERAGE_TMP/$1"
      case "$1" in
        missing-root) mkdir -p "$guarded" ;;
        missing-config) cp -R "$COVERAGE_PROJECT" "$guarded"; rm "$guarded/.cumaru/config.yaml" ;;
        missing-spec) cp -R "$COVERAGE_PROJECT" "$guarded"; rm -rf "$guarded/.cumaru/specs" ;;
        non-git) mkdir -p "$guarded"; cp -R "$COVERAGE_PROJECT/.cumaru" "$guarded/.cumaru" ;;
      esac
      When call cli_in "$guarded" coverage --rows
      The status should be failure
      The output should be blank
      The error should include "$2"
    End
  End
End
