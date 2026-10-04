#!/usr/bin/env bash

set -u

REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CI_MODE=0
RANDOM_MODE=0

case "${1:-}" in
  "") ;;
  --ci) CI_MODE=1 ;;
  --random) RANDOM_MODE=1 ;;
  *)
    printf 'Usage: bash tests/run.sh [--ci|--random]\n' >&2
    exit 2
    ;;
esac

if [[ $# -gt 1 ]]; then
  printf 'Usage: bash tests/run.sh [--ci|--random]\n' >&2
  exit 2
fi

binary=${CUMARU_TEST_BINARY:-"$REPO_DIR/rust/target/release/cumaru"}
if [[ ! -x "$binary" || "$binary" != /* ]]; then
  printf 'Native binary must be an absolute executable path: %s. Build with bash rust/build.sh.\n' "$binary" >&2
  exit 1
fi
export CUMARU_TEST_BINARY="$binary"

if ! command -v shellspec >/dev/null 2>&1; then
  printf 'ShellSpec is required. Install it from https://shellspec.info/\n' >&2
  exit 1
fi

# Selects only native processes and reviewed source-independent legacy contracts.
selected=(
  tests/native
  tests/spec/contracts/auxiliary_skills_spec.sh
  tests/spec/contracts/command_skill_launchers_spec.sh
  tests/spec/contracts/summarize_artifacts_spec.sh
  tests/spec/contracts/terraform_skill_spec.sh
  tests/spec/contracts/workflow_orchestrator_skill_spec.sh
)

if [[ $CI_MODE -eq 1 ]]; then
  exec shellspec --directory "$REPO_DIR" --format tap "${selected[@]}"
fi

if [[ $RANDOM_MODE -eq 1 ]]; then
  exec shellspec --directory "$REPO_DIR" --env-from "$REPO_DIR/tests/native/random-env.sh" --random examples --format documentation "${selected[@]}"
fi

exec shellspec --directory "$REPO_DIR" --format documentation "${selected[@]}"
