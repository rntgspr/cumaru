#!/usr/bin/env bash

set -u

TESTS_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
shopt -s nullglob
tests=("$TESTS_DIR"/test_*.sh)
shopt -u nullglob

if [[ ${#tests[@]} -eq 0 ]]; then
  printf 'No test_*.sh files found under %s\n' "$TESTS_DIR" >&2
  exit 1
fi

failures=0
for test_file in "${tests[@]}"; do
  printf '==> %s\n' "$(basename "$test_file")"
  if bash "$test_file"; then
    printf '<== PASS %s\n' "$(basename "$test_file")"
  else
    printf '<== FAIL %s\n' "$(basename "$test_file")" >&2
    failures=$((failures + 1))
  fi
done

if [[ $failures -ne 0 ]]; then
  printf '%d test script(s) failed\n' "$failures" >&2
  exit 1
fi
printf 'All %d test script(s) passed\n' "${#tests[@]}"
