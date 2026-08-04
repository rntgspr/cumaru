Include tests/spec/update/support/update_helpers.sh

# Verify v9 ownership while keeping ShellSpec's mutation assertions in one call.
verify_owned_update() {
  run_cumaru "$PROJECT" update --from "$SOURCE" >/dev/null || return 1
  cmp -s "$PROJECT/.cumaru/moved.md" "$PROJECT/.cumaru/framework.md" || return 1
  run_cumaru "$PROJECT" update --from "$SOURCE" --apply >/dev/null || return 1
  grep -qF '# Framework' "$PROJECT/.cumaru/moved.md" || return 1
  grep -qF 'adopter body' "$PROJECT/.cumaru/moved.md" || return 1
  grep -qF '# Local adopter file' "$PROJECT/.cumaru/adopter.md" || return 1
  grep -qF '# Local child' "$PROJECT/.cumaru/container/inside.md" || return 1
  grep -qF '# Local' "$PROJECT/.cumaru/framework.md"
}

Describe 'v9 explicit framework update ownership'
  setup() {
    update_tmp_create
    SOURCE="$UPDATE_TMP/source"
    PROJECT="$UPDATE_TMP/project"
    make_plain_source "$SOURCE" || return
    make_update_project "$PROJECT" || return

    # Install the minimal valid v9 direct-tree model in both isolated trees.
    for config in "$SOURCE/domains/__base/config.yaml" "$PROJECT/.cumaru/config.yaml"; do
      printf '%s\n' \
        'version: 9' 'domain: base' 'rules:' \
        '  markdown: {required_heading: h1, frontmatter: {}}' \
        '  index_md: {frontmatter: {}}' \
        '  pillar_index: {frontmatter: {}}' \
        'root: {framework: true}' \
        'meta: {targets: {values: [meta]}}' > "$config" || return
    done

    mkdir -p "$SOURCE/domains/__base/container" "$PROJECT/.cumaru/container"
    printf '%s\n' '---' 'summary: Canonical framework update content remains valid for diagnostic checks.' '---' '# Framework' '<!-- cumaru:notes -->' 'canonical' '<!-- /cumaru:notes -->' > "$SOURCE/domains/__base/framework.md"
    printf '%s\n' '---' 'summary: Local framework content remains valid before the canonical refresh.' '---' '# Local' '<!-- cumaru:notes -->' 'adopter body' '<!-- /cumaru:notes -->' > "$PROJECT/.cumaru/moved.md"
    cp "$PROJECT/.cumaru/moved.md" "$PROJECT/.cumaru/framework.md"
    printf '%s\n' '---' 'summary: Canonical adopter fixture content for ownership verification.' '---' '# Canonical adopter file' > "$SOURCE/domains/__base/adopter.md"
    printf '%s\n' '---' 'summary: Local adopter fixture content must remain untouched by update.' '---' '# Local adopter file' > "$PROJECT/.cumaru/adopter.md"
    printf '%s\n' '---' 'summary: Canonical container index content for ownership verification.' '---' '# Canonical container' > "$SOURCE/domains/__base/container/index.md"
    printf '%s\n' '---' 'summary: Canonical nested child content for ownership verification.' '---' '# Canonical child' > "$SOURCE/domains/__base/container/inside.md"
    printf '%s\n' '---' 'summary: Local container index content remains valid before refresh.' '---' '# Local container' > "$PROJECT/.cumaru/container/index.md"
    printf '%s\n' '---' 'summary: Local nested child content must remain untouched by update.' '---' '# Local child' > "$PROJECT/.cumaru/container/inside.md"

    yq -i '.root."framework.md" = {"framework": true} | .root."adopter.md" = {} | .root.container = {"framework": true, "inside.md": {}}' "$SOURCE/domains/__base/config.yaml" || return
    yq -i '.root."framework.md" = {"path": "moved.md", "framework": true} | .root."adopter.md" = {} | .root.container = {"framework": true, "inside.md": {}}' "$PROJECT/.cumaru/config.yaml" || return
    commit_update_project "$PROJECT" 'v9 ownership baseline'
  }
  cleanup() { update_tmp_remove; }
  BeforeEach 'setup'
  AfterEach 'cleanup'

  It 'updates only explicitly owned destinations and preserves tag bodies'
    When call verify_owned_update
    The status should equal 0
  End

  It 'reports an old alternative path without removing it'
    When call run_cumaru "$PROJECT" update --from "$SOURCE"
    The status should equal 0
    The output should include 'stale framework path retained for review: framework.md (current destination: moved.md)'
    The contents of file "$PROJECT/.cumaru/framework.md" should include '# Local'
  End
End

# Exercise update pairing when one selector resolves to several source and
# destination files, including a destination with no canonical counterpart.
Describe 'v9 glob framework update ownership'
  glob_update_setup() {
    update_tmp_create
    SOURCE="$UPDATE_TMP/source"
    PROJECT="$UPDATE_TMP/project"
    make_plain_source "$SOURCE" || return
    make_update_project "$PROJECT" || return

    for config in "$SOURCE/domains/__base/config.yaml" "$PROJECT/.cumaru/config.yaml"; do
      printf '%s\n' \
        'version: 9' 'domain: base' 'rules:' \
        '  markdown: {required_heading: h1, frontmatter: {}}' \
        '  index_md: {frontmatter: {}}' \
        '  pillar_index: {frontmatter: {}}' \
        'root:' \
        '  framework: true' \
        '  managed: {framework: true, "*.md": {framework: true}}' \
        'meta: {targets: {values: [meta]}}' > "$config" || return
    done

    mkdir -p "$SOURCE/domains/__base/managed" "$PROJECT/.cumaru/managed"
    printf '%s\n' '---' 'summary: Canonical managed directory index for glob update verification.' '---' '# Managed' > "$SOURCE/domains/__base/managed/index.md"
    cp "$SOURCE/domains/__base/managed/index.md" "$PROJECT/.cumaru/managed/index.md"
    printf '%s\n' '---' 'summary: Canonical alpha file remains distinct during glob update pairing.' '---' '# Canonical alpha' > "$SOURCE/domains/__base/managed/alpha.md"
    printf '%s\n' '---' 'summary: Canonical beta file remains distinct during glob update pairing.' '---' '# Canonical beta' > "$SOURCE/domains/__base/managed/beta.md"
    printf '%s\n' '---' 'summary: Local alpha file needs its matching canonical source during update.' '---' '# Local alpha' > "$PROJECT/.cumaru/managed/alpha.md"
    printf '%s\n' '---' 'summary: Local beta file needs its matching canonical source during update.' '---' '# Local beta' > "$PROJECT/.cumaru/managed/beta.md"
    printf '%s\n' '---' 'summary: Adopter-only matching file must remain untouched by framework update.' '---' '# Adopter only' > "$PROJECT/.cumaru/managed/local.md"
    cp "$PROJECT/.cumaru/managed/local.md" "$UPDATE_TMP/local.before.md"
    commit_update_project "$PROJECT" 'v9 glob ownership baseline'
  }

  glob_update_cleanup() { update_tmp_remove; }

  verify_glob_update_pairing() {
    run_cumaru "$PROJECT" update --from "$SOURCE" --apply >/dev/null || return 1
    grep -qF '# Canonical alpha' "$PROJECT/.cumaru/managed/alpha.md" || return 1
    grep -qF '# Canonical beta' "$PROJECT/.cumaru/managed/beta.md" || return 1
    cmp -s "$UPDATE_TMP/local.before.md" "$PROJECT/.cumaru/managed/local.md" || return 1
    commit_update_project "$PROJECT" 'applied v9 glob update' || return 1
    preview=$(run_cumaru "$PROJECT" update --from "$SOURCE") || return 1
    [[ "$preview" == *'.cumaru/ files already in sync'* ]]
  }

  BeforeEach 'glob_update_setup'
  AfterEach 'glob_update_cleanup'

  It 'pairs same-path sources, preserves destination-only files, and converges'
    When call verify_glob_update_pairing
    The status should equal 0
  End
End

# Regression: a glob group with several members must pair every destination
# with its OWN canonical source. A resolver that keeps one match for the whole
# group writes one body into every sibling and destroys the rest.
Describe 'v9 glob group per-file source pairing'
  group_setup() {
    update_tmp_create
    SOURCE="$UPDATE_TMP/source"
    PROJECT="$UPDATE_TMP/project"
    make_plain_source "$SOURCE" || return
    make_update_project "$PROJECT" || return

    for config in "$SOURCE/domains/__base/config.yaml" "$PROJECT/.cumaru/config.yaml"; do
      printf '%s\n' \
        'version: 9' 'domain: base' 'rules:' \
        '  markdown: {required_heading: h1, frontmatter: {}}' \
        '  index_md: {frontmatter: {}}' \
        '  pillar_index: {frontmatter: {}}' \
        'root:' \
        '  framework: true' \
        '  group: {framework: true, "*.md": {framework: true}}' \
        'meta: {targets: {values: [meta]}}' > "$config" || return
    done

    mkdir -p "$SOURCE/domains/__base/group" "$PROJECT/.cumaru/group"
    printf '%s\n' '---' 'summary: Canonical group index for per-file glob pairing.' '---' '# Group' > "$SOURCE/domains/__base/group/index.md"
    cp "$SOURCE/domains/__base/group/index.md" "$PROJECT/.cumaru/group/index.md"
    for member in alpha kappa omega zulu; do
      printf '%s\n' '---' "summary: Canonical $member body must reach only the $member destination." '---' "# Canonical $member" \
        > "$SOURCE/domains/__base/group/$member.md"
      printf '%s\n' '---' "summary: Local $member body awaits its own canonical source." '---' "# Local $member" \
        > "$PROJECT/.cumaru/group/$member.md"
    done
    commit_update_project "$PROJECT" 'v9 glob group baseline'
  }

  group_cleanup() { update_tmp_remove; }

  # Every destination must be byte-identical to its own source after apply.
  verify_group_pairing() {
    local member
    run_cumaru "$PROJECT" update --from "$SOURCE" --apply >/dev/null || return 1
    for member in alpha kappa omega zulu; do
      cmp -s "$SOURCE/domains/__base/group/$member.md" "$PROJECT/.cumaru/group/$member.md" || return 1
    done
  }

  BeforeEach 'group_setup'
  AfterEach 'group_cleanup'

  It 'writes each canonical body into its own destination'
    When call verify_group_pairing
    The status should equal 0
  End
End
