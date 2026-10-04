Include tests/native/helpers.sh

Describe 'native coverage adapted from legacy reference buckets'
  BeforeEach 'installed_setup'
  AfterEach 'native_cleanup'

  It 'classifies covered, stale, invalid and uncovered targets without changing bytes'
    mkdir -p "$PROJECT/src"
    printf 'covered\n' > "$PROJECT/src/covered.rs"
    printf 'uncovered\n' > "$PROJECT/src/uncovered.rs"
    write_md "$PROJECT/.cumaru/specs/refs.md" 'Reference fixture exercises native source coverage buckets.'
    cat >> "$PROJECT/.cumaru/specs/refs.md" <<'EOF'
<!-- cumaru:reference -->
| Link | Description |
|---|---|
| [covered](src/covered.rs) | Covered implementation. |
| [stale](src/missing.rs) | Removed implementation. |
| [invalid](.cumaru/index.md) | Knowledge is not source. |
| [template](<source-file>) | Ignored template. |
<!-- /cumaru:reference -->
EOF
    git_baseline
    before=$(snapshot)
    When call cli coverage --rows --strict
    The status should equal 1
    The output should include "covered	src/covered.rs"
    The output should include "uncovered	src/uncovered.rs"
    The output should include "stale	src/missing.rs"
    The output should include "invalid	.cumaru/index.md"
    The output should not include '<source-file>'
    The error should be blank
    The value "$(snapshot)" should equal "$before"
  End

  It 'rejects multiple output modes before a report'
    When call cli coverage --rows --gaps
    The status should equal 2
    The output should be blank
    The error should not be blank
  End
End
