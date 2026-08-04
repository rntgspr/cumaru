Include tests/spec/update/support/update_helpers.sh

Describe 'update integer version gate'
  setup() { update_tmp_create; }
  cleanup() { update_tmp_remove; }
  BeforeEach 'setup'
  AfterEach 'cleanup'

  make_gate_source() {
    local dir="$1" version="$2" index="$3" domain="${4:-base}"
    mkdir -p "$dir/domains/__base"; : > "$dir/cumaru"
    gate_config "$dir/domains/__base/config.yaml" "$version" "$domain"
    gate_index "$dir/domains/__base/index.md" "$index" true
  }
  make_gate_project() {
    local dir="$1" version="$2" index="$3"
    mkdir -p "$dir/.cumaru"
    gate_config "$dir/.cumaru/config.yaml" "$version" base
    gate_index "$dir/.cumaru/index.md" "$index" false
  }
  gate_config() {
    local file="$1" version="$2" domain="$3"
    printf '%s\n' "version: $version" "domain: $domain" 'agent: null' 'rules:' '  markdown:' '    required_heading: h1' '    frontmatter: [human_revised!, summary!]' '  index_md:' '    frontmatter: [apps!]' '  pillar_index:' '    frontmatter: [apps!, summary!]' 'root:' '  frontmatter: [framework-version!]' '  tags: {}' '  entities: {}' 'meta:' '  apps:' '    values: [meta]' '  tags: {}' '  compatibility:' '    framework_version_field: framework-version' '    framework_version_location: .cumaru/index.md' '    rule: [Schema and root versions must agree.]' > "$file"
  }
  gate_index() {
    local file="$1" version="$2" summary="$3"
    printf '%s\n' '---' 'human_revised: false' > "$file"
    [ "$summary" = true ] && printf '%s\n' 'summary: Source kernel summary used by the update version gate tests.' >> "$file"
    printf '%s\n' 'generated: false' "framework-version: $version" 'apps: [meta]' '---' '' '# Kernel' >> "$file"
  }

  It 'allows a higher-source preview and points to migrate'
    source="$UPDATE_TMP/source"; project="$UPDATE_TMP/project"; make_gate_source "$source" 7 7; make_gate_project "$project" 5 5
    preview_case() { run_cumaru "$project" update --from "$source" > "$UPDATE_TMP/out" 2>&1 && grep -qF "cumaru migrate --from $source" "$UPDATE_TMP/out" || { command cat "$UPDATE_TMP/out" >&2; return 1; }; }
    When call preview_case
    The status should equal 0
  End

  It 'refuses higher-source apply and changes no local file'
    source="$UPDATE_TMP/source"; project="$UPDATE_TMP/project"; make_gate_source "$source" 7 7; make_gate_project "$project" 5 5
    cp "$project/.cumaru/config.yaml" "$UPDATE_TMP/config"; cp "$project/.cumaru/index.md" "$UPDATE_TMP/index"
    apply_case() { local status=0; run_cumaru "$project" update --from "$source" --apply > "$UPDATE_TMP/out" 2>&1 || status=$?; [ "$status" -eq 1 ] && grep -q 'cannot cross an integer version boundary' "$UPDATE_TMP/out" || { command cat "$UPDATE_TMP/out" >&2; return 1; }; }
    When call apply_case
    The status should equal 0
    The value "$(cmp -s "$project/.cumaru/config.yaml" "$UPDATE_TMP/config"; printf '%s' $?)" should equal 0
    The value "$(cmp -s "$project/.cumaru/index.md" "$UPDATE_TMP/index"; printf '%s' $?)" should equal 0
  End

  It 'rejects local config and index version disagreement'
    source="$UPDATE_TMP/source"; project="$UPDATE_TMP/project"; make_gate_source "$source" 7 7; make_gate_project "$project" 5 4
    disagreement() { local status=0; run_cumaru "$project" update --from "$source" > "$UPDATE_TMP/out" 2>&1 || status=$?; [ "$status" -eq 1 ] && grep -q 'version disagreement' "$UPDATE_TMP/out" || { command cat "$UPDATE_TMP/out" >&2; return 1; }; }
    When call disagreement
    The status should equal 0
  End

  It 'rejects source config and index version disagreement'
    source="$UPDATE_TMP/source"; project="$UPDATE_TMP/project"; make_gate_source "$source" 7 6; make_gate_project "$project" 5 5
    disagreement() { local status=0; run_cumaru "$project" update --from "$source" > "$UPDATE_TMP/out" 2>&1 || status=$?; [ "$status" -eq 1 ] && grep -q 'version disagreement' "$UPDATE_TMP/out"; }
    When call disagreement
    The status should equal 0
  End

  It 'rejects selected source and source config domain disagreement'
    source="$UPDATE_TMP/source"; project="$UPDATE_TMP/project"; make_gate_source "$source" 5 5 other-domain; make_gate_project "$project" 5 5
    domain_disagreement() { local status=0; run_cumaru "$project" update --from "$source" > "$UPDATE_TMP/out" 2>&1 || status=$?; [ "$status" -eq 1 ] && grep -q 'source domain disagreement' "$UPDATE_TMP/out"; }
    When call domain_disagreement
    The status should equal 0
  End

  It 'refuses framework downgrade'
    source="$UPDATE_TMP/source"; project="$UPDATE_TMP/project"; make_gate_source "$source" 6 6; make_gate_project "$project" 7 7
    downgrade() { local status=0; run_cumaru "$project" update --from "$source" > "$UPDATE_TMP/out" 2>&1 || status=$?; [ "$status" -eq 1 ] && grep -q 'refusing framework downgrade' "$UPDATE_TMP/out" || { command cat "$UPDATE_TMP/out" >&2; return 1; }; }
    When call downgrade
    The status should equal 0
  End

  It 'rejects decimal config versions'
    source="$UPDATE_TMP/source"; project="$UPDATE_TMP/project"; make_gate_source "$source" 7.1 7.1; make_gate_project "$project" 7 7
    decimal() { local status=0; run_cumaru "$project" update --from "$source" > "$UPDATE_TMP/out" 2>&1 || status=$?; [ "$status" -eq 1 ] && grep -q 'invalid config' "$UPDATE_TMP/out"; }
    When call decimal
    The status should equal 0
  End
End
