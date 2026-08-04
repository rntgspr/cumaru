Include tests/spec/cli/support/helpers.sh

Describe 'cumaru map'
  BeforeEach 'tree_setup'
  AfterEach 'tree_cleanup'

  It 'prints help outside a project'
    rm -rf "$TREE_PROJECT/.cumaru"
    When call cli_in "$TREE_PROJECT" map --help
    The status should be success
    The output should include 'cumaru map [<directory-or-md>] [--rows]'
    The error should be blank
  End

  It 'maps level-two headings recursively in deterministic rg-compatible output'
    printf '%s\n' '## Alpha title' >> "$TREE_PROJECT/.cumaru/alpha.md"
    printf '%s\n' '## Area title' >> "$TREE_PROJECT/.cumaru/area/index.md"
    printf '%s\n' '## Leaf title' >> "$TREE_PROJECT/.cumaru/area/leaf.md"
    printf '%s\n' '## Hidden title' >> "$TREE_PROJECT/.cumaru/.hidden.md"
    When call cli_in "$TREE_PROJECT" map
    The status should be success
    The output should equal 'alpha.md:7:## Alpha title
area/index.md:7:## Area title
area/leaf.md:7:## Leaf title'
    The error should be blank
  End

  It 'maps an exact Markdown target with literal ripgrep heading matching'
    cat >> "$TREE_PROJECT/.cumaru/alpha.md" <<'EOF'
## Visible title
```
## Example title
```
EOF
    When call cli_in "$TREE_PROJECT" map alpha.md --rows
    The status should be success
    The output should equal 'alpha.md	7	Visible title
alpha.md	9	Example title'
    The error should be blank
  End

  It 'skips heading-shaped frontmatter while retaining the document heading'
    write_raw_md "$TREE_PROJECT/.cumaru/frontmatter.md" $'---\n# ## Metadata title\nsummary: Frontmatter fixture remains a safe map target.\n---\n## Document title\n'
    When call cli_in "$TREE_PROJECT" map frontmatter.md --rows
    The status should be success
    The output should equal 'frontmatter.md	5	Document title'
    The error should be blank
  End

  It 'falls back to find and awk when ripgrep is unavailable'
    cat >> "$TREE_PROJECT/.cumaru/alpha.md" <<'EOF'
## Visible title
```
## Example title
```
EOF
    When run env PATH=/usr/bin:/bin /bin/bash -c 'cd "$1" && exec /bin/bash "$2" map alpha.md --rows' _ "$TREE_PROJECT" "$CLI"
    The status should be success
    The output should equal 'alpha.md	7	Visible title'
    The error should be blank
  End

  It 'composes rows and installed filters for a directory target'
    rm -rf "$TREE_PROJECT/.cumaru"
    cp -R "$REPO_ROOT/tests/fixtures/tree-filters/.cumaru" "$TREE_PROJECT/.cumaru"
    printf '%s\n' '## Plan title' >> "$TREE_PROJECT/.cumaru/plans/active.md"
    printf '%s\n' '## Spec title' >> "$TREE_PROJECT/.cumaru/specs/overview.md"
    When call cli_in "$TREE_PROJECT" map --domain test-domain --pillars specs --rows
    The status should be success
    The output should equal 'specs/overview.md	5	Spec title'
    The error should be blank
  End

  It 'rejects unsafe targets before output'
    When call cli_in "$TREE_PROJECT" map ../alpha.md
    The status should be failure
    The output should be blank
    The error should include '`..` path segments are not allowed'
  End
End
