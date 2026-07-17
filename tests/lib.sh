#!/usr/bin/env bash

TESTS_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_DIR=$(cd "$TESTS_DIR/.." && pwd)
CLI="$REPO_DIR/cumaru"
TEST_TMP=$(mktemp -d "${TMPDIR:-/tmp}/cumaru-tests.XXXXXX") || exit 1
ASSERTIONS=0
FAILURES=0
RUN_STATUS=0
RUN_STDOUT=""
RUN_STDERR=""
RUN_NUMBER=0

trap 'rm -rf "$TEST_TMP"' EXIT

new_project() {
  local name="$1" project
  project="$TEST_TMP/$name"
  mkdir -p "$project/.cumaru"
  PROJECT="$project"
}

write_md() {
  local path="$1" summary="$2"
  mkdir -p "$(dirname "$path")"
  printf '%s\n' '---' "summary: '$summary'" '---' '# Fixture' '' \
    'The Markdown body is not part of tree summary extraction.' > "$path"
}

write_raw_md() {
  local path="$1" content="$2"
  mkdir -p "$(dirname "$path")"
  printf '%s' "$content" > "$path"
}

run_tree() {
  local project="$1"
  shift
  RUN_NUMBER=$((RUN_NUMBER + 1))
  local stdout="$TEST_TMP/stdout.$RUN_NUMBER" stderr="$TEST_TMP/stderr.$RUN_NUMBER"
  (cd "$project" && "$CLI" tree "$@") > "$stdout" 2> "$stderr"
  RUN_STATUS=$?
  RUN_STDOUT=$(<"$stdout")
  RUN_STDERR=$(<"$stderr")
}

run_tree_with_path() {
  local project="$1" path="$2"
  shift 2
  RUN_NUMBER=$((RUN_NUMBER + 1))
  local stdout="$TEST_TMP/stdout.$RUN_NUMBER" stderr="$TEST_TMP/stderr.$RUN_NUMBER"
  (cd "$project" && PATH="$path" "$CLI" tree "$@") > "$stdout" 2> "$stderr"
  RUN_STATUS=$?
  RUN_STDOUT=$(<"$stdout")
  RUN_STDERR=$(<"$stderr")
}

fail() {
  local label="$1" detail="$2"
  FAILURES=$((FAILURES + 1))
  printf 'not ok - %s\n%s\n' "$label" "$detail" >&2
}

pass() {
  printf 'ok - %s\n' "$1"
}

assert_status() {
  local expected="$1" label="$2"
  ASSERTIONS=$((ASSERTIONS + 1))
  if [[ "$RUN_STATUS" == "$expected" ]]; then
    pass "$label"
  else
    fail "$label" "expected status $expected, got $RUN_STATUS; stderr: $RUN_STDERR"
  fi
}

assert_eq() {
  local expected="$1" actual="$2" label="$3"
  ASSERTIONS=$((ASSERTIONS + 1))
  if [[ "$actual" == "$expected" ]]; then
    pass "$label"
  else
    fail "$label" "expected:\n$expected\nactual:\n$actual"
  fi
}

assert_contains() {
  local haystack="$1" needle="$2" label="$3"
  ASSERTIONS=$((ASSERTIONS + 1))
  if [[ "$haystack" == *"$needle"* ]]; then
    pass "$label"
  else
    fail "$label" "missing '$needle' in:\n$haystack"
  fi
}

assert_not_contains() {
  local haystack="$1" needle="$2" label="$3"
  ASSERTIONS=$((ASSERTIONS + 1))
  if [[ "$haystack" != *"$needle"* ]]; then
    pass "$label"
  else
    fail "$label" "unexpected '$needle' in:\n$haystack"
  fi
}

finish_tests() {
  if [[ $FAILURES -ne 0 ]]; then
    printf '%d assertion(s), %d failure(s)\n' "$ASSERTIONS" "$FAILURES" >&2
    return 1
  fi
  printf '%d assertion(s), 0 failures\n' "$ASSERTIONS"
  return 0
}
