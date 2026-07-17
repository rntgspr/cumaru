#!/usr/bin/env bash
set -u

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TMP=$(mktemp -d "${TMPDIR:-/tmp}/cumaru-update-gate.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
pass() { printf 'ok: %s\n' "$*"; }

make_source() {
  local dir="$1" schema_version="$2" index_version="$3" domain="${4:-base}"
  mkdir -p "$dir/domains/__base"
  : > "$dir/cumaru"
  cat > "$dir/domains/__base/schema.yaml" <<EOF
version: $schema_version
domain: $domain
rules:
  markdown:
    frontmatter: [human_revised!, summary!]
root:
  frontmatter: [framework-version!]
  tags: {}
  entities: {}
meta:
  apps:
    values: [meta]
  tags: {}
EOF
  cat > "$dir/domains/__base/index.md" <<EOF
---
human_revised: false
summary: Source kernel summary used by the update version gate tests.
generated: false
framework-version: $index_version
apps: [meta]
---

# Kernel
EOF
}

make_project() {
  local dir="$1" schema_version="$2" index_version="$3"
  mkdir -p "$dir/.cumaru"
  cat > "$dir/.cumaru/schema.yaml" <<EOF
version: $schema_version
domain: base
rules:
  markdown:
    frontmatter: [human_revised!]
root:
  frontmatter: [framework-version!]
  tags: {}
  entities: {}
meta:
  apps:
    values: [meta]
  tags: {}
EOF
  cat > "$dir/.cumaru/index.md" <<EOF
---
human_revised: false
generated: false
framework-version: $index_version
apps: [meta]
---

# Kernel
EOF
}

run_update() {
  local project="$1" source="$2" output="$3"; shift 3
  (cd "$project" && bash "$ROOT/cumaru" update --from "$source" "$@") > "$output" 2>&1
}

source_v6="$TMP/source-v6"; make_source "$source_v6" 6 6
project_v5="$TMP/project-v5"; make_project "$project_v5" 5 5
before=$(cksum "$project_v5/.cumaru/index.md" "$project_v5/.cumaru/schema.yaml")
run_update "$project_v5" "$source_v6" "$TMP/upgrade-dry.out" || fail "major-upgrade dry-run should be informational"
grep -q 'cumaru migrate v6' "$TMP/upgrade-dry.out" || fail "major-upgrade dry-run did not direct migrate v6"
if run_update "$project_v5" "$source_v6" "$TMP/upgrade-apply.out" --apply; then fail "major-upgrade apply was allowed"; fi
grep -q 'cannot cross a major version boundary' "$TMP/upgrade-apply.out" || fail "major-upgrade apply refusal was not explicit"
after=$(cksum "$project_v5/.cumaru/index.md" "$project_v5/.cumaru/schema.yaml")
[[ "$before" == "$after" ]] || fail "version gate changed local files"
pass "major upgrade is dry-run-only and points to migrate"

project_split="$TMP/project-split"; make_project "$project_split" 5 4
if run_update "$project_split" "$source_v6" "$TMP/local-split.out"; then fail "local schema/index disagreement was allowed"; fi
grep -q 'local version disagreement' "$TMP/local-split.out" || fail "local disagreement was not diagnosed"
pass "local schema and framework-version must agree"

source_split="$TMP/source-split"; make_source "$source_split" 6 5
if run_update "$project_v5" "$source_split" "$TMP/source-split.out"; then fail "source schema/index disagreement was allowed"; fi
grep -q 'source version disagreement' "$TMP/source-split.out" || fail "source disagreement was not diagnosed"
pass "source schema and framework-version must agree"

source_wrong_domain="$TMP/source-wrong-domain"; make_source "$source_wrong_domain" 5 5 other-domain
if run_update "$project_v5" "$source_wrong_domain" "$TMP/source-domain.out"; then fail "source domain disagreement was allowed"; fi
grep -q 'source domain disagreement' "$TMP/source-domain.out" || fail "source domain disagreement was not diagnosed"
pass "selected source path and source schema domain must agree"

source_v5="$TMP/source-v5"; make_source "$source_v5" 5 5
project_v6="$TMP/project-v6"; make_project "$project_v6" 6 6
if run_update "$project_v6" "$source_v5" "$TMP/downgrade.out"; then fail "downgrade was allowed"; fi
grep -q 'refusing framework downgrade' "$TMP/downgrade.out" || fail "downgrade refusal was not diagnosed"
pass "downgrades are refused"

source_v61="$TMP/source-v61"; make_source "$source_v61" 6.1 6.1
run_update "$project_v6" "$source_v61" "$TMP/same-major.out" || fail "same-major update was refused"
grep -q 'steady state' "$TMP/same-major.out" || grep -q 'already in sync' "$TMP/same-major.out" || fail "same-major update did not reach steady-state review"
pass "same-major steady update is allowed"
