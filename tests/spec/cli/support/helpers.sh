REPO_ROOT=${SHELLSPEC_PROJECT_ROOT:-$(pwd)}
CLI="$REPO_ROOT/cumaru"

cli_in() {
  project=$1
  shift
  (cd "$project" && /bin/bash "$CLI" "$@")
}

write_md() {
  path=$1 summary=$2
  mkdir -p "$(dirname "$path")"
  printf '%s\n' '---' "summary: '$summary'" '---' '# Fixture' '' 'Fixture body.' > "$path"
}

write_doctor_md() {
  path=$1 summary=$2 extra=${3:-}
  mkdir -p "$(dirname "$path")"
  {
    printf '%s\n' '---' 'human_revised: false' "summary: '$summary'" 'generated: false' 'apps: [meta]'
    [ -z "$extra" ] || printf '%s\n' "$extra"
    printf '%s\n' '---' '' '# Fixture' '' 'Stable fixture prose.'
  } > "$path"
}

tree_setup() {
  TREE_TMP=$(mktemp -d "${TMPDIR:-/tmp}/cumaru-tree-spec.XXXXXX")
  TREE_PROJECT="$TREE_TMP/project"
  mkdir -p "$TREE_PROJECT/.cumaru/area" "$TREE_PROJECT/.cumaru/unindexed"
  write_md "$TREE_PROJECT/.cumaru/index.md" 'Root navigation context for focused tree command tests.'
  write_md "$TREE_PROJECT/.cumaru/alpha.md" 'Alpha behavior provides stable selection context.'
  write_md "$TREE_PROJECT/.cumaru/zeta.md" 'Zeta behavior provides stable selection context.'
  write_md "$TREE_PROJECT/.cumaru/area/index.md" 'Area contracts group related behavior for navigation.'
  write_md "$TREE_PROJECT/.cumaru/area/leaf.md" 'Area leaf behavior is available after explicit selection.'
  write_md "$TREE_PROJECT/.cumaru/.hidden.md" 'Hidden files are deliberately excluded from navigation.'
  printf 'ignored\n' > "$TREE_PROJECT/.cumaru/note.txt"
}

tree_cleanup() { rm -rf "$TREE_TMP"; }

flow_setup() {
  FLOW_TMP=$(mktemp -d "${TMPDIR:-/tmp}/cumaru-flow-spec.XXXXXX")
  FLOW_PROJECT="$FLOW_TMP/project"
  mkdir -p "$FLOW_PROJECT"
  cp -R "$REPO_ROOT/tests/fixtures/flow/.cumaru" "$FLOW_PROJECT/.cumaru"
}

flow_cleanup() { rm -rf "$FLOW_TMP"; }

flow_snapshot() { (cd "$FLOW_PROJECT" && find .cumaru -print | LC_ALL=C sort && cksum .cumaru/plans/item/index.md .cumaru/plans/item/note.md); }

write_raw_md() {
  path=$1 content=$2
  mkdir -p "$(dirname "$path")"
  printf '%s' "$content" > "$path"
}

coverage_setup() {
  COVERAGE_TMP=$(mktemp -d "${TMPDIR:-/tmp}/cumaru-coverage-spec.XXXXXX")
  COVERAGE_PROJECT="$COVERAGE_TMP/project"
  mkdir -p "$COVERAGE_PROJECT"
  cli_in "$COVERAGE_PROJECT" install --domain sdlc-light >/dev/null
  mkdir -p "$COVERAGE_PROJECT/src" "$COVERAGE_PROJECT/.agents/fixture"
  printf 'covered\n' > "$COVERAGE_PROJECT/src/covered.ts"
  printf 'uncovered\n' > "$COVERAGE_PROJECT/src/uncovered.ts"
  printf 'foreign\n' > "$COVERAGE_PROJECT/src/foreign-filtered.ts"
  printf 'ignored\n' > "$COVERAGE_PROJECT/.agents/fixture/ignored.ts"
  printf 'readme\n' > "$COVERAGE_PROJECT/README.md"
  cat > "$COVERAGE_PROJECT/.cumaru/specs/coverage-fixture.md" <<'EOF'
---
human_revised: false
summary: Coverage fixture exercises every reference adjudication bucket.
apps: []
depends-on: []
relates: []
---
# Coverage fixture
<!-- cumaru:reference -->
| Link | Description |
|---|---|
| [covered](src/covered.ts) | Covered source implementation. |
| [foreign](src/foreign-filtered.ts) | Existing file outside configured scope. |
| [stale](src/missing.ts) | Removed source implementation. |
| [invalid](.cumaru/index.md) | Invalid framework-internal target. |
| [template](<source-file>) | Template row ignored by coverage. |
|  |  |
<!-- /cumaru:reference -->
EOF
  cat >> "$COVERAGE_PROJECT/.cumaru/domain.md" <<'EOF'
<!-- cumaru:reference -->
| Link | Description |
|---|---|
| [outside](src/covered.ts) | Valid row hosted outside the specification pillar. |
<!-- /cumaru:reference -->
EOF
  yq -i '.meta.coverage.source = ["src/covered.ts", "src/uncovered.ts"]' "$COVERAGE_PROJECT/.cumaru/config.yaml"
  (cd "$COVERAGE_PROJECT" && git init -q && git add README.md src .cumaru .agents)
}

coverage_cleanup() { rm -rf "$COVERAGE_TMP"; }

doctor_config() {
  cat > "$1" <<'EOF'
version: 7
domain: base
rules:
  markdown: { required_heading: h1, frontmatter: [human_revised!, summary!] }
  index_md: { frontmatter: [generated!, apps!] }
  pillar_index: { frontmatter: [generated!, apps!] }
root:
  frontmatter: [framework-version!, depends-on]
  entities:
    notes:
      entities:
        note: { path: <slug>.md, frontmatter: [generated!, apps!] }
meta:
  apps: { values: [meta] }
  tags:
    components: { host_file: domain.md, type: default }
    root: { host_file: domain.md, type: prose }
    files: { host_file: "*", type: default }
    touched: { host_file: "*", type: default }
    reference: { host_file: "*", type: default }
  compatibility:
    framework_version_field: framework-version
    framework_version_location: .cumaru/index.md
    rule: [Schema and root versions must agree.]
EOF
}

doctor_setup() {
  DOCTOR_TMP=$(mktemp -d "${TMPDIR:-/tmp}/cumaru-doctor-spec.XXXXXX")
  DOCTOR_PROJECT="$DOCTOR_TMP/project"
  mkdir -p "$DOCTOR_PROJECT/.cumaru"
  doctor_config "$DOCTOR_PROJECT/.cumaru/config.yaml"
  write_doctor_md "$DOCTOR_PROJECT/.cumaru/index.md" 'Root navigation contract for the focused doctor fixture.' $'framework-version: 7\ndepends-on: [domain.md]'
  write_doctor_md "$DOCTOR_PROJECT/.cumaru/domain.md" 'Domain context declares retained semantic marker contracts.'
  cat >> "$DOCTOR_PROJECT/.cumaru/domain.md" <<'EOF'
<!-- cumaru:components -->
| Link | Description |
|---|---|
<!-- /cumaru:components -->
<!-- cumaru:root -->
Fixture project context remains adopter-owned prose.
<!-- /cumaru:root -->
EOF
  write_doctor_md "$DOCTOR_PROJECT/.cumaru/notes/index.md" 'Notes group durable fixture details for explicit navigation.'
  write_doctor_md "$DOCTOR_PROJECT/.cumaru/notes/leaf.md" 'Leaf note remains selectable through its stable summary text.'
  write_doctor_md "$DOCTOR_PROJECT/.cumaru/support/index.md" 'Local support directory also participates in indexed navigation.'
  mkdir -p "$DOCTOR_PROJECT/.agents/skills" "$DOCTOR_PROJECT/.agents/commands"
  block=$(bash -c '. "$1"; _cumaru_hook_block ".cumaru/index.md" 1 codex' _ "$REPO_ROOT/src/common.sh")
  printf '# Project instructions\n\n%s\n' "$block" > "$DOCTOR_PROJECT/AGENTS.md"
  cp -R "$REPO_ROOT/domains/__base/skills/." "$DOCTOR_PROJECT/.agents/skills/"
  cp -R "$REPO_ROOT/domains/__base/commands/." "$DOCTOR_PROJECT/.agents/commands/"
}

doctor_cleanup() { rm -rf "$DOCTOR_TMP"; }
