Include tests/spec/update/support/update_helpers.sh

Describe 'balanced tag update merging'
  setup_tags() {
    update_tmp_create
    FIXTURES="$UPDATE_ROOT/tests/fixtures/update-tags"
    CUMARU_DIR=.cumaru
    . "$UPDATE_ROOT/src/common.sh"
    . "$UPDATE_ROOT/src/cmd_update.sh"
    . "$UPDATE_ROOT/src/cmd_tag.sh"
  }
  cleanup() { update_tmp_remove; }
  BeforeEach 'setup_tags'
  AfterEach 'cleanup'

  merge_valid_fixture() {
    local name="$1" fixture="$FIXTURES/$1" work="$UPDATE_TMP/$1" tag
    mkdir -p "$work"; cp "$fixture/source.md" "$work/source.md"; cp "$fixture/local.md" "$work/local.md"
    _update_build_expected "$work/source.md" "$work/local.md" > "$work/actual.md" || return
    cmp -s "$fixture/expected.md" "$work/actual.md" || return
    while IFS= read -r tag; do
      [ -n "$tag" ] || continue
      _fm_block_top_list "$work/local.md" local | grep -qxF "$tag" || return 1
      _fm_block_extract_top "$work/local.md" "$tag" local > "$work/local-body" || return
      _fm_block_top_list "$work/actual.md" result | grep -qxF "$tag" || return 1
      _fm_block_extract_top "$work/actual.md" "$tag" result > "$work/result-body" || return
      cmp -s "$work/local-body" "$work/result-body" || return
    done < <(_fm_block_top_list "$work/local.md" local | sort -u)
    _update_build_expected "$work/source.md" "$work/actual.md" > "$work/second.md" && cmp -s "$work/actual.md" "$work/second.md"
  }

  Context 'with a valid fixture'
    Parameters
      adds-source-only-empty-tag
      avoids-identity-collision
      ignores-marker-like-prose
      merges-duplicate-source-tags
      merges-duplicate-tags
      preserves-body-types
      preserves-nested-tags
      preserves-orphan-tag
      preserves-source-scaffolds
      preserves-valid-names
    End
    It 'merges $1 to exact bytes, preserves bodies, and is idempotent'
      When call merge_valid_fixture "$1"
      The status should equal 0
    End
  End

  reject_fixture() {
    local name="$1" fixture="$FIXTURES/$1" work="$UPDATE_TMP/$1" status before
    mkdir -p "$work"; cp "$fixture/source.md" "$work/source.md"; cp "$fixture/local.md" "$work/local.md"; cp "$work/local.md" "$work/before.md"
    _update_build_expected "$work/source.md" "$work/local.md" > "$work/actual.md" 2> "$work/error"; status=$?
    [ "$status" -ne 0 ] && grep -qF "$(<"$fixture/expected-error.txt")" "$work/error" && cmp -s "$work/before.md" "$work/local.md"
  }
  Context 'with an invalid fixture'
    Parameters
      rejects-crossing-tags
      rejects-invalid-source
      rejects-missing-closer
      rejects-unclosed-with-foreign-closer
    End
    It 'rejects $1 with its exact diagnostic and unchanged local bytes'
      When call reject_fixture "$1"
      The status should equal 0
    End
  End

  It 'returns exact independently authored nested inner and outer bodies'
    fixture="$FIXTURES/preserves-nested-tags"
    fm_block_extract "$fixture/local.md" inner local > "$UPDATE_TMP/inner"
    fm_block_extract "$fixture/local.md" outer local > "$UPDATE_TMP/outer"
    The value "$(cmp -s "$UPDATE_TMP/inner" "$fixture/expected-inner-body.md"; printf '%s' $?)" should equal 0
    The value "$(cmp -s "$UPDATE_TMP/outer" "$fixture/expected-outer-body.md"; printf '%s' $?)" should equal 0
  End

  extract_required_top() {
    local file="$1" tag="$2" output="$3" context="$4"
    _fm_block_top_list "$file" "$context" | grep -qxF "$tag" || return 1
    _fm_block_extract_top "$file" "$tag" "$context" > "$output"
  }

  It 'rejects required extraction of a missing tag'
    When call extract_required_top "$FIXTURES/preserves-nested-tags/local.md" missing "$UPDATE_TMP/missing-body" local
    The status should not equal 0
    The path "$UPDATE_TMP/missing-body" should not be exist
  End

  It 'rejects required extraction from malformed tag structure'
    When call extract_required_top "$FIXTURES/rejects-missing-closer/local.md" notes "$UPDATE_TMP/malformed-body" local
    The status should not equal 0
    The stderr should include 'was never closed'
  End

  It 'consolidates duplicate replacement and writes the requested body once'
    file="$UPDATE_TMP/set.md"; cp "$FIXTURES/merges-duplicate-tags/local.md" "$file"
    printf '%s\n' 'Replacement body written through the shared parser.' | fm_block_replace "$file" notes
    The value "$(_fm_block_top_list "$file" file | grep -c '^notes$')" should equal 1
    The value "$(fm_block_extract "$file" notes)" should equal 'Replacement body written through the shared parser.'
  End

  It 'updates an independently addressable nested tag in both lookups'
    file="$UPDATE_TMP/nested.md"; cp "$FIXTURES/preserves-nested-tags/local.md" "$file"
    printf '%s\n' 'Updated nested body.' | fm_block_replace "$file" inner
    The value "$(fm_block_extract "$file" inner)" should equal 'Updated nested body.'
    The value "$(fm_block_extract "$file" outer)" should include 'Updated nested body.'
  End

  It 'rejects malformed tag set before mutation'
    file="$UPDATE_TMP/malformed.md"; cp "$FIXTURES/rejects-missing-closer/local.md" "$file"; cp "$file" "$UPDATE_TMP/before"
    malformed_set() { printf '%s\n' 'Must not be written.' | _tag_do_set "$file" notes; }
    When call malformed_set
    The status should not equal 0
    The stderr should include 'was never closed'
    The value "$(cmp -s "$file" "$UPDATE_TMP/before"; printf '%s' $?)" should equal 0
  End
End
