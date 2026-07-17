#!/usr/bin/env bash

set -u
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

run_doctor() {
  local project="$1"
  shift
  RUN_NUMBER=$((RUN_NUMBER + 1))
  local stdout="$TEST_TMP/doctor-stdout.$RUN_NUMBER" stderr="$TEST_TMP/doctor-stderr.$RUN_NUMBER"
  (cd "$project" && "$CLI" doctor "$@") > "$stdout" 2> "$stderr"
  RUN_STATUS=$?
  RUN_STDOUT=$(<"$stdout")
  RUN_STDERR=$(<"$stderr")
}

write_fixture_md() {
  local path="$1" summary="$2" extra="${3:-}"
  mkdir -p "$(dirname "$path")"
  {
    printf '%s\n' '---' 'human_revised: false' "summary: '$summary'" 'generated: false' 'apps: [meta]'
    [[ -z "$extra" ]] || printf '%s\n' "$extra"
    printf '%s\n' '---' '' '# Fixture' '' 'Stable fixture prose for doctor validation.'
  } > "$path"
}

write_schema() {
  local path="$1"
  cat > "$path" <<'EOF'
version: 6
domain: base
rules:
  markdown:
    required_heading: h1
    frontmatter: [human_revised!, summary!]
  index_md:
    frontmatter: [generated!, apps!]
  pillar_index:
    frontmatter: [generated!, apps!]
root:
  frontmatter: [framework-version!, depends-on]
  entities:
    notes:
      entities:
        note:
          path: <slug>.md
          frontmatter: [generated!, apps!]
meta:
  apps:
    values: [meta]
  tags:
    components: { host_file: domain.md, type: default }
    root: { host_file: domain.md, type: prose }
    files: { host_file: "*", type: default }
    "touched": { host_file: "*", type: default }
    reference: { host_file: "*", type: default }
  migrations:
    v6:
      removable_tags:
        - { host_file: notes/index.md, tag: notes }
EOF
}

wire_agents() {
  local project="$1" block
  mkdir -p "$project/.agents"
  block=$(bash -c '. "$1"; _cumaru_hook_block ".cumaru/index.md" 1' _ "$REPO_DIR/src/common.sh")
  printf '# Project instructions\n\n%s\n' "$block" > "$project/.agents/AGENTS.md"
}

make_fixture() {
  local name="$1"
  new_project "$name"
  local project="$PROJECT"
  write_schema "$project/.cumaru/schema.yaml"
  write_fixture_md "$project/.cumaru/index.md" \
    'Root navigation contract for the focused doctor fixture.' \
    $'framework-version: 6\ndepends-on: [domain.md]'
  write_fixture_md "$project/.cumaru/domain.md" \
    'Domain context declares retained semantic marker contracts.'
  cat >> "$project/.cumaru/domain.md" <<'EOF'

<!-- cumaru:components -->
| Link | Description |
|---|---|
<!-- /cumaru:components -->

<!-- cumaru:root -->
Fixture project context remains adopter-owned prose.
<!-- /cumaru:root -->
EOF
  write_fixture_md "$project/.cumaru/notes/index.md" \
    'Notes group durable fixture details for explicit navigation.'
  write_fixture_md "$project/.cumaru/notes/leaf.md" \
    'Leaf note remains selectable through its stable summary text.'
  write_fixture_md "$project/.cumaru/support/index.md" \
    'Local support directory also participates in indexed navigation.'
  wire_agents "$project"
}

set_leaf_scalar() {
  local file="$1" yaml="$2"
  local tmp="$TEST_TMP/leaf-rewrite.$RUN_NUMBER"
  {
    printf '%s\n' '---' 'human_revised: false'
    printf '%s\n' "$yaml"
    printf '%s\n' 'generated: false' 'apps: [meta]' '---' '' '# Fixture' '' 'Stable fixture prose.'
  } > "$tmp"
  mv "$tmp" "$file"
}

make_fixture healthy
healthy="$PROJECT"
run_doctor "$healthy" --quiet
assert_status 0 "healthy v6 fixture passes doctor"
assert_contains "$RUN_STDOUT" 'Summary: 0 error(s), 0 warning(s), 7 ok' "healthy fixture runs all seven checks"
assert_eq "" "$RUN_STDERR" "doctor keeps diagnostics in its conventional stdout report"

# CLAUDE.md is not part of the Cumaru agent integration dialect.
mv "$healthy/.agents/AGENTS.md" "$healthy/CLAUDE.md"
run_doctor "$healthy" --quiet
assert_status 0 "CLAUDE.md is ignored by doctor"
assert_contains "$RUN_STDOUT" '.agents/AGENTS.md not found' "doctor requires the canonical agent instruction path"
mv "$healthy/CLAUDE.md" "$healthy/.agents/AGENTS.md"

# Every non-hidden directory needs an index, including local support dirs.
rm "$healthy/.cumaru/support/index.md"
run_doctor "$healthy" --quiet
assert_status 1 "missing local directory index is a hard failure"
assert_contains "$RUN_STDOUT" 'non-hidden directory lacks a real index.md: support/' "local support directory is covered"
assert_contains "$RUN_STDOUT" 'cumaru tree --deep' "navigation failure keeps deep traversal diagnostic"
write_fixture_md "$healthy/.cumaru/support/index.md" \
  'Local support directory also participates in indexed navigation.'

# Full summary contract: type, trim/control checks, code-point boundaries.
leaf="$healthy/.cumaru/notes/leaf.md"
set_leaf_scalar "$leaf" 'summary: true'
run_doctor "$healthy" --quiet
assert_status 1 "non-string summary fails"
assert_contains "$RUN_STDOUT" 'summary must be a YAML string' "summary type diagnostic"

set_leaf_scalar "$leaf" "summary: ' leading whitespace makes this summary invalid.'"
run_doctor "$healthy" --quiet
assert_status 1 "untrimmed summary fails"
assert_contains "$RUN_STDOUT" 'summary has leading or trailing whitespace' "summary trim diagnostic"

set_leaf_scalar "$leaf" $'summary: |-\n  First valid-looking line has enough characters.\n  Second line makes the scalar invalid.'
run_doctor "$healthy" --quiet
assert_status 1 "multiline summary fails"
assert_contains "$RUN_STDOUT" 'summary contains a control character' "summary control diagnostic"

short31=""
long256=""
i=0
while [[ $i -lt 31 ]]; do short31="${short31}a"; i=$((i + 1)); done
i=0
while [[ $i -lt 256 ]]; do long256="${long256}a"; i=$((i + 1)); done
set_leaf_scalar "$leaf" "summary: '$short31'"
run_doctor "$healthy" --quiet
assert_status 1 "31-code-point summary fails"
assert_contains "$RUN_STDOUT" 'shorter than 32 Unicode code points' "lower summary boundary diagnostic"

unicode32=""
i=0
while [[ $i -lt 32 ]]; do unicode32="${unicode32}"$'\xc3\xa9'; i=$((i + 1)); done
set_leaf_scalar "$leaf" "summary: '$unicode32'"
run_doctor "$healthy" --quiet
assert_status 0 "32 multibyte code points pass"

set_leaf_scalar "$leaf" "summary: '$long256'"
run_doctor "$healthy" --quiet
assert_status 0 "256-code-point summary passes"
set_leaf_scalar "$leaf" "summary: '${long256}a'"
run_doctor "$healthy" --quiet
assert_status 1 "257-code-point summary fails"
assert_contains "$RUN_STDOUT" 'longer than 256 Unicode code points' "upper summary boundary diagnostic"
set_leaf_scalar "$leaf" "summary: 'Leaf note remains selectable through its stable summary text.'"

# Unknown blocks are audited but never inferred as default/path tables.
cat >> "$leaf" <<'EOF'

<!-- cumaru:custom-local -->
| Link | Description |
|---|---|
| [ghost](missing/ghost.md) | Must remain opaque. |
<!-- /cumaru:custom-local -->
EOF
run_doctor "$healthy" --quiet
assert_status 0 "unknown marker is warning-only"
assert_contains "$RUN_STDOUT" 'body kept opaque and not path-resolved' "unknown marker audit explains preservation"
assert_not_contains "$RUN_STDOUT" 'missing/ghost.md - target not found' "unknown marker row is not path-resolved"

# A source/declaration-known structural block is a hard migration defect.
cat >> "$healthy/.cumaru/notes/index.md" <<'EOF'

<!-- cumaru:notes -->
| Link | Description |
|---|---|
<!-- /cumaru:notes -->
EOF
run_doctor "$healthy" --quiet
assert_status 1 "retired structural marker fails"
assert_contains "$RUN_STDOUT" 'retired structural inventory block remains after migration' "structural manifest drives detection"

# Project file tags share project-root semantics and preserve removed paths.
make_fixture refs
refs="$PROJECT"
mkdir -p "$refs/src"
printf 'live\n' > "$refs/src/live.txt"
cat >> "$refs/.cumaru/notes/leaf.md" <<'EOF'

<!-- cumaru:touched -->
| Link | Description |
|---|---|
| [live](src/live.txt) | modified - still present |
| [gone](src/gone.txt) | removed - intentionally absent |
<!-- /cumaru:touched -->
EOF
run_doctor "$refs" --quiet
assert_status 0 "touched resolves from project root and accepts explicit removals"

cat >> "$refs/.cumaru/notes/leaf.md" <<'EOF'

<!-- cumaru:reference -->
| Link | Description |
|---|---|
| [escape](../outside.txt) | Invalid traversal must not become stale. |
<!-- /cumaru:reference -->
EOF
run_doctor "$refs" --quiet
assert_status 0 "invalid retained reference remains a warning"
assert_contains "$RUN_STDOUT" 'invalid path, file type, containment, or final symlink target' "validity precedes existence"
assert_not_contains "$RUN_STDOUT" '../outside.txt - target not found' "escaping missing path is invalid, not missing"

# Replace the invalid target with a final symlink that escapes the project.
outside="$TEST_TMP/outside.txt"
printf 'outside\n' > "$outside"
ln -s "$outside" "$refs/escape.txt"
rewrite="$TEST_TMP/reference-rewrite.md"
awk '{ gsub(/\.\.\/outside\.txt/, "escape.txt"); print }' "$refs/.cumaru/notes/leaf.md" > "$rewrite"
mv "$rewrite" "$refs/.cumaru/notes/leaf.md"
run_doctor "$refs" --quiet
assert_status 0 "final symlink escape remains warning-only"
assert_contains "$RUN_STDOUT" 'escape.txt - invalid path, file type, containment, or final symlink target' "final symlink target containment is checked"

# Complete agent wiring is checked, not only instruction prose.

help_output=$(cd "$refs" && "$CLI" tag all --help)
assert_contains "$help_output" 'touched' "tag help names the canonical touched-file tag"
assert_contains "$help_output" 'removed' "tag help documents removed-file status"

finish_tests
