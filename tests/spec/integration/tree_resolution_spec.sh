Include tests/spec/cli/support/helpers.sh

Describe 'v9 direct-tree resolution'
  # Build one renamed direct tree with literal and wildcard sibling selectors.
  resolution_setup() {
    RESOLUTION_TMP=$(mktemp -d "${TMPDIR:-/tmp}/cumaru-resolution-spec.XXXXXX")
    RESOLUTION_PROJECT="$RESOLUTION_TMP/project"
    mkdir -p "$RESOLUTION_PROJECT/.cumaru/custom/nested" "$RESOLUTION_PROJECT/.cumaru/specification" "$RESOLUTION_PROJECT/src"

    write_md "$RESOLUTION_PROJECT/.cumaru/index.md" 'Root configuration summary remains long enough for navigation.'
    write_md "$RESOLUTION_PROJECT/.cumaru/custom/index.md" 'Renamed pillar summary remains long enough for navigation.'
    write_md "$RESOLUTION_PROJECT/.cumaru/custom/literal.md" 'Literal selector summary remains long enough for navigation.'
    write_md "$RESOLUTION_PROJECT/.cumaru/custom/wildcard.md" 'Wildcard selector summary remains long enough for navigation.'
    write_md "$RESOLUTION_PROJECT/.cumaru/custom/nested/index.md" 'Nested area summary remains long enough for navigation.'
    write_md "$RESOLUTION_PROJECT/.cumaru/custom/nested/wildcard.md" 'Nested wildcard summary remains long enough for navigation.'
    write_md "$RESOLUTION_PROJECT/.cumaru/specification/index.md" 'Specification pillar summary remains long enough for navigation.'
    printf 'source\n' > "$RESOLUTION_PROJECT/src/covered.ts"
    printf '%s\n' '<!-- cumaru:section -->' '<!-- /cumaru:section -->' >> "$RESOLUTION_PROJECT/.cumaru/custom/index.md"
    cat > "$RESOLUTION_PROJECT/.cumaru/specification/contract.md" <<'EOF'
---
summary: Specification reference host remains long enough for coverage.
---
# Contract
<!-- cumaru:reference -->
| Link | Description |
|---|---|
| [covered](src/covered.ts) | Covered implementation. |
<!-- /cumaru:reference -->
EOF
    cat > "$RESOLUTION_PROJECT/.cumaru/config.yaml" <<'EOF'
version: 9
domain: base
rules:
  markdown: {required_heading: h1, frontmatter: {summary: {}}}
  index_md: {frontmatter: {generated: {}}}
  pillar_index: {frontmatter: {targets: {}}}
root:
  renamed:
    path: custom
    frontmatter: {section: {}}
    tags: [section]
    literal.md: {frontmatter: {literal: {}}, tags: [literal-tag]}
    '*.md': {frontmatter: {wildcard: {}}, tags: [wildcard-tag]}
    nested:
      '*.md': {frontmatter: {first: {}}}
      'wild*.md': {frontmatter: {second: {}}}
  specs: {path: specification}
meta: {targets: {values: [all]}, specification_dir: specs, coverage: {source: [src/*.ts]}}
EOF
    git -C "$RESOLUTION_PROJECT" init -q
    git -C "$RESOLUTION_PROJECT" add .cumaru src
  }

  # Remove the isolated project after each example.
  resolution_cleanup() { rm -rf "$RESOLUTION_TMP"; }

  # Invoke the shared resolver with the fixture's local configuration.
  resolution_rows() {
    (
      cd "$RESOLUTION_PROJECT" || return
      CUMARU_DIR=.cumaru CONFIG=.cumaru/config.yaml
      . "$REPO_ROOT/src/common.sh"
      config_tree_resolve
    )
  }

  BeforeEach 'resolution_setup'
  AfterEach 'resolution_cleanup'

  It 'resolves renamed paths with literal sibling precedence and global rules'
    When call resolution_rows
    The status should be success
    The output should include $'renamed\tcustom/index.md\tfalse\t{"summary":{},"generated":{},"targets":{},"section":{}}\t["section"]'
    The output should include $'renamed/literal.md\tcustom/literal.md\tfalse\t{"summary":{},"literal":{}}\t["literal-tag"]'
    The output should include $'renamed/*.md\tcustom/wildcard.md\tfalse\t{"summary":{},"wildcard":{}}\t["wildcard-tag"]'
    The output should include $'renamed/nested/*.md\tcustom/nested/wildcard.md\tfalse\t{"summary":{},"first":{},"second":{}}\t[]'
    The output should not include $'renamed/*.md\tcustom/literal.md'

  End

  It 'uses the resolved directory contract for tags'
    When call cli_in "$RESOLUTION_PROJECT" tag custom/index.md
    The status should be success
    The output should include 'section'
  End

  It 'uses renamed paths for tree pillar filters'
    When call cli_in "$RESOLUTION_PROJECT" tree --pillars renamed --deep --rows
    The status should be success
    The output should include 'custom/literal.md'
    The output should include 'custom/wildcard.md'
  End

  It 'uses the physical specification directory for coverage'
    When call cli_in "$RESOLUTION_PROJECT" coverage --refs
    The status should be success
    The output should include 'specification/contract.md'
    The output should include 'src/covered.ts'
  End

  It 'reports direct-tree frontmatter and required marker failures through doctor'
    When call cli_in "$RESOLUTION_PROJECT" doctor --quiet
    The status should be failure
    The output should include "custom/literal.md: missing required frontmatter field 'literal'"
    The output should include "custom/literal.md: missing required tag 'literal-tag'"
  End

  It 'reports a missing required literal selector through doctor without writes'
    cp "$RESOLUTION_PROJECT/.cumaru/config.yaml" "$RESOLUTION_TMP/config.before.yaml"
    rm "$RESOLUTION_PROJECT/.cumaru/custom/literal.md"
    When call cli_in "$RESOLUTION_PROJECT" doctor --quiet
    The status should be failure
    The output should include 'Configured v9 tree is invalid'
    The output should include 'required entry is missing: renamed/literal.md'
    The value "$(cmp -s "$RESOLUTION_TMP/config.before.yaml" "$RESOLUTION_PROJECT/.cumaru/config.yaml"; printf '%s' $?)" should equal 0
  End

  It 'rejects unsafe path overrides before producing a resolution'
    cp "$RESOLUTION_PROJECT/.cumaru/config.yaml" "$RESOLUTION_PROJECT/before.yaml"
    yq -i '.root.renamed.path = "../outside"' "$RESOLUTION_PROJECT/.cumaru/config.yaml"
    When call resolution_rows
    The status should be failure
    The output should be blank
    The error should include 'unsafe resolved path for renamed'
    The path "$RESOLUTION_PROJECT/before.yaml" should be exist
  End

  It 'rejects symlinked destinations'
    mkdir "$RESOLUTION_PROJECT/outside"
    ln -s "$RESOLUTION_PROJECT/outside" "$RESOLUTION_PROJECT/.cumaru/unsafe"
    yq -i '.root.renamed.path = "unsafe"' "$RESOLUTION_PROJECT/.cumaru/config.yaml"
    When call resolution_rows
    The status should be failure
    The output should be blank
    The error should include 'directory entry is unsafe: renamed'

  End

  It 'rejects logical destination collisions'
    yq -i '.root.duplicate.path = "custom"' "$RESOLUTION_PROJECT/.cumaru/config.yaml"
    When call resolution_rows
    The status should be failure
    The output should be blank
    The error should include 'destination collision: renamed and duplicate'
  End
End
