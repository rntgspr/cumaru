#!/usr/bin/env bash

set -u
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

ROOT_SUMMARY="Root navigation context for focused tree command tests."

# Help must not require a project or yq initialization.
new_project outside
outside="$PROJECT"
rm -rf "$outside/.cumaru"
run_tree "$outside" --help
assert_status 0 "tree help works outside a project"
assert_contains "$RUN_STDOUT" 'cumaru tree [<directory-or-md>] [--deep] [--rows]' "tree help documents usage"
assert_eq "" "$RUN_STDERR" "tree help keeps stderr empty"

run_tree "$outside"
assert_status 1 "tree without a project fails"
assert_contains "$RUN_STDERR" '.cumaru/ not found' "missing project diagnostic is on stderr"

# Clean shallow navigation, sorting, escaping, hidden policy, and file target.
new_project clean
clean="$PROJECT"
write_md "$clean/.cumaru/index.md" "$ROOT_SUMMARY"
write_md "$clean/.cumaru/alpha.md" "Alpha behavior provides stable selection context."
write_md "$clean/.cumaru/zeta.md" "Zeta behavior provides stable selection context."
write_md "$clean/.cumaru/area/index.md" "Area contracts group related behavior for navigation."
write_md "$clean/.cumaru/area/leaf.md" "Area leaf behavior is available after explicit selection."
mkdir -p "$clean/.cumaru/unindexed"
write_md "$clean/.cumaru/.hidden.md" "Hidden files are deliberately excluded from navigation."
write_md "$clean/.cumaru/.secret/index.md" "Hidden directories are deliberately excluded from navigation."
write_md "$clean/.cumaru/back\\name.md" "Backslash \\ and pipe | remain deterministic in summaries."
write_md "$clean/.cumaru/pipe|name.md" "Pipe paths remain deterministic in Markdown and TSV output."
printf '%s\n' 'ignored' > "$clean/.cumaru/note.txt"

run_tree "$clean"
assert_status 0 "clean shallow navigation succeeds"
expected_markdown=$(cat <<'EOF'
| Path | Summary |
|---|---|
| alpha.md | Alpha behavior provides stable selection context. |
| area/ | Area contracts group related behavior for navigation. |
| back\\name.md | Backslash \\ and pipe \| remain deterministic in summaries. |
| pipe\|name.md | Pipe paths remain deterministic in Markdown and TSV output. |
| zeta.md | Zeta behavior provides stable selection context. |
EOF
)
assert_eq "$expected_markdown" "$RUN_STDOUT" "Markdown output is C-sorted and escaped"
assert_eq "" "$RUN_STDERR" "clean shallow navigation has no diagnostics"

run_tree "$clean" --rows
assert_status 0 "rows mode succeeds"
expected_rows=$(cat <<'EOF'
alpha.md	Alpha behavior provides stable selection context.
area/	Area contracts group related behavior for navigation.
back\name.md	Backslash \ and pipe | remain deterministic in summaries.
pipe|name.md	Pipe paths remain deterministic in Markdown and TSV output.
zeta.md	Zeta behavior provides stable selection context.
EOF
)
assert_eq "$expected_rows" "$RUN_STDOUT" "rows mode emits stable raw TSV without a header"
assert_not_contains "$RUN_STDOUT" '.hidden' "shallow output omits hidden files"
assert_not_contains "$RUN_STDOUT" 'unindexed/' "shallow output omits unindexed child directories"

run_tree "$clean" alpha.md --rows
assert_status 0 "Markdown file target normalizes to its parent"
assert_eq "$expected_rows" "$RUN_STDOUT" "file target lists parent directory candidates"

run_tree "$clean" area --rows
assert_status 0 "directory target succeeds"
assert_eq $'area/leaf.md\tArea leaf behavior is available after explicit selection.' "$RUN_STDOUT" "directory target remains root-relative"

run_tree "$clean" /tmp
assert_status 1 "absolute target is rejected"
assert_contains "$RUN_STDERR" 'target must be relative' "absolute target diagnostic"
run_tree "$clean" area/../alpha.md
assert_status 1 "parent segment is rejected"
assert_contains "$RUN_STDERR" '`..` path segments are not allowed' "parent segment diagnostic"
run_tree "$clean" note.txt
assert_status 1 "non-Markdown file target is rejected"
assert_contains "$RUN_STDERR" 'file target must end in .md' "non-Markdown target diagnostic"
run_tree "$clean" .secret
assert_status 1 "hidden target is rejected"
run_tree "$clean" --unknown
assert_status 2 "unknown tree option is a usage error"

new_project missing-index
missing_index="$PROJECT"
write_md "$missing_index/.cumaru/leaf.md" "Valid leaf remains unavailable without a target index."
run_tree "$missing_index" --rows
assert_status 1 "shallow target requires index.md"
assert_eq "" "$RUN_STDOUT" "fatal shallow index error emits no rows"
assert_contains "$RUN_STDERR" 'target requires a regular index.md' "shallow missing index diagnostic"

# Deep mode emits valid descendants while reporting every invalid entry.
new_project deep
deep="$PROJECT"
write_md "$deep/.cumaru/index.md" "$ROOT_SUMMARY"
write_md "$deep/.cumaru/good.md" "Good root behavior remains available during a failed audit."
write_md "$deep/.cumaru/nested/index.md" "Nested behavior groups valid deep navigation candidates."
write_md "$deep/.cumaru/nested/leaf.md" "Nested leaf behavior remains valid during deep inspection."
write_md "$deep/.cumaru/noindex/leaf.md" "A valid leaf remains discoverable below a missing index."
mkdir -p "$deep/.cumaru/empty"
write_md "$deep/.cumaru/bad.md" "too short"
write_md "$deep/.cumaru/.hidden.md" "Hidden invalid entries are outside the navigation surface."
write_md "$deep/.cumaru/nested/.private.md" "Nested hidden entries are outside the navigation surface."
control_path=$'control\nname.md'
write_md "$deep/.cumaru/$control_path" "Control character paths must never reach output records."

run_tree "$deep" --deep --rows
assert_status 1 "deep audit returns nonzero after walking all entries"
expected_deep=$(cat <<'EOF'
good.md	Good root behavior remains available during a failed audit.
nested/	Nested behavior groups valid deep navigation candidates.
nested/leaf.md	Nested leaf behavior remains valid during deep inspection.
noindex/leaf.md	A valid leaf remains discoverable below a missing index.
EOF
)
assert_eq "$expected_deep" "$RUN_STDOUT" "deep audit emits every valid candidate"
assert_contains "$RUN_STDERR" 'bad.md' "deep audit reports invalid summary"
assert_contains "$RUN_STDERR" 'empty/index.md' "deep audit reports empty directory index"
assert_contains "$RUN_STDERR" 'noindex/index.md' "deep audit reports missing ancestor index"
assert_contains "$RUN_STDERR" 'control character' "deep audit rejects control characters in paths"
assert_not_contains "$RUN_STDERR" '.hidden' "deep audit prunes hidden paths"
assert_not_contains "$RUN_STDOUT" 'index.md' "deep output never emits index.md separately"

run_tree "$deep" noindex --deep --rows
assert_status 1 "deep target may be inspected without index.md"
assert_eq $'noindex/leaf.md\tA valid leaf remains discoverable below a missing index.' "$RUN_STDOUT" "deep missing-index target still emits valid descendants"
assert_contains "$RUN_STDERR" 'noindex/index.md' "deep target missing index is diagnosed"

# YAML type, whitespace, control, folded/literal, boundary, and Unicode checks.
new_project summaries
summary_project="$PROJECT"
write_md "$summary_project/.cumaru/index.md" "$ROOT_SUMMARY"
valid32="12345678901234567890123456789012"
invalid31="1234567890123456789012345678901"
valid256=""
invalid257=""
unicode32=""
i=0
while [[ $i -lt 256 ]]; do valid256="${valid256}a"; i=$((i + 1)); done
invalid257="${valid256}a"
i=0
while [[ $i -lt 32 ]]; do unicode32="${unicode32}é"; i=$((i + 1)); done
write_md "$summary_project/.cumaru/valid32.md" "$valid32"
write_md "$summary_project/.cumaru/valid256.md" "$valid256"
write_md "$summary_project/.cumaru/unicode32.md" "$unicode32"
write_md "$summary_project/.cumaru/invalid31.md" "$invalid31"
write_md "$summary_project/.cumaru/invalid257.md" "$invalid257"
write_raw_md "$summary_project/.cumaru/bool.md" $'---\nsummary: true\n---\n# Bool\n'
write_md "$summary_project/.cumaru/padded.md" " This padded summary has invalid surrounding whitespace. "
write_raw_md "$summary_project/.cumaru/tab.md" $'---\nsummary: "This otherwise valid summary contains\\tone tab."\n---\n# Tab\n'
write_raw_md "$summary_project/.cumaru/folded.md" $'---\nsummary: >-\n  This folded summary remains valid\n  as one resolved line for navigation.\n---\n# Folded\n'
write_raw_md "$summary_project/.cumaru/literal.md" $'---\nsummary: |-\n  This literal summary retains a newline\n  and therefore cannot be a selection signal.\n---\n# Literal\n'
write_raw_md "$summary_project/.cumaru/malformed.md" $'---\nsummary: [unterminated\n---\n# Malformed\n'

run_tree "$summary_project" --deep --rows
assert_status 1 "summary contract failures make deep mode nonzero"
assert_contains "$RUN_STDOUT" 'valid32.md' "32-code-point summary is valid"
assert_contains "$RUN_STDOUT" 'valid256.md' "256-code-point summary is valid"
assert_contains "$RUN_STDOUT" 'unicode32.md' "multibyte summary is counted as Unicode code points"
assert_contains "$RUN_STDOUT" 'folded.md' "folded YAML resolving to one line is valid"
assert_not_contains "$RUN_STDOUT" 'invalid31.md' "31-code-point summary is rejected"
assert_not_contains "$RUN_STDOUT" 'invalid257.md' "257-code-point summary is rejected"
assert_contains "$RUN_STDERR" 'bool.md' "non-string YAML summary is diagnosed"
assert_contains "$RUN_STDERR" 'padded.md' "untrimmed summary is diagnosed"
assert_contains "$RUN_STDERR" 'tab.md' "tab summary is diagnosed"
assert_contains "$RUN_STDERR" 'literal.md' "literal multiline summary is diagnosed"
assert_contains "$RUN_STDERR" 'malformed.md' "malformed YAML frontmatter is diagnosed"

# No symlink target or discovered descendant may be read or emitted.
new_project links
links="$PROJECT"
write_md "$links/.cumaru/index.md" "$ROOT_SUMMARY"
write_md "$links/.cumaru/good.md" "Good regular files remain visible beside rejected symlinks."
write_md "$links/.cumaru/nested/index.md" "Nested regular directory remains a valid navigation candidate."
write_md "$links/.cumaru/nested/leaf.md" "Nested regular leaf remains visible beside rejected symlinks."
write_md "$links/outside.md" "Outside content must never be read through an escaping link."
ln -s good.md "$links/.cumaru/link-file.md"
ln -s absent.md "$links/.cumaru/broken.md"
ln -s nested "$links/.cumaru/link-dir"
ln -s "$links/outside.md" "$links/.cumaru/escape.md"
ln -s .. "$links/.cumaru/nested/cycle"
ln -s ../good.md "$links/.cumaru/nested/descendant.md"
ln -s nested "$links/.cumaru/target-link"
mkdir -p "$links/.cumaru/actual/child"
write_md "$links/.cumaru/actual/index.md" "Actual parent directory exists for intermediate link testing."
write_md "$links/.cumaru/actual/child/index.md" "Actual child directory exists for intermediate link testing."
ln -s actual "$links/.cumaru/intermediate"

run_tree "$links" --deep --rows
assert_status 1 "deep mode rejects discovered symlinks"
assert_contains "$RUN_STDOUT" 'good.md' "regular candidate survives symlink diagnostics"
assert_contains "$RUN_STDOUT" 'nested/' "regular directory survives symlink diagnostics"
assert_not_contains "$RUN_STDOUT" 'link-file.md' "in-tree file symlink is not emitted"
assert_not_contains "$RUN_STDOUT" 'link-dir/' "directory symlink is not emitted"
assert_not_contains "$RUN_STDOUT" 'escape.md' "escaping symlink is not emitted"
assert_contains "$RUN_STDERR" 'broken.md' "broken symlink is diagnosed"
assert_contains "$RUN_STDERR" 'nested/cycle' "cyclic symlink is diagnosed"
assert_contains "$RUN_STDERR" 'nested/descendant.md' "descendant symlink is diagnosed"

run_tree "$links" target-link --rows
assert_status 1 "direct symlink target is rejected"
assert_contains "$RUN_STDERR" 'target contains a symlink' "direct target symlink diagnostic"
run_tree "$links" intermediate/child --rows
assert_status 1 "intermediate target symlink is rejected"
assert_contains "$RUN_STDERR" 'target contains a symlink' "intermediate symlink diagnostic"

# A non-mikefarah yq on PATH is a hard runtime failure.
fake_bin="$TEST_TMP/fake-bin"
mkdir -p "$fake_bin"
cat > "$fake_bin/yq" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' 'yq 3.4.1'
EOF
chmod +x "$fake_bin/yq"
run_tree_with_path "$clean" "$fake_bin:/usr/bin:/bin" --rows
assert_status 1 "incompatible yq is a hard runtime error"
assert_contains "$RUN_STDERR" 'incompatible yq' "incompatible yq diagnostic"
assert_eq "" "$RUN_STDOUT" "yq runtime failure emits no report"

finish_tests
