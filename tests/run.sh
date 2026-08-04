#!/usr/bin/env bash

set -u

REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CI_MODE=0

case "${1:-}" in
  "") ;;
  --ci) CI_MODE=1 ;;
  *)
    printf 'Usage: bash tests/run.sh [--ci]\n' >&2
    exit 2
    ;;
esac

if [[ $# -gt 1 ]]; then
  printf 'Usage: bash tests/run.sh [--ci]\n' >&2
  exit 2
fi

if ! command -v shellspec >/dev/null 2>&1; then
  printf 'ShellSpec is required. Install it from https://shellspec.info/\n' >&2
  exit 1
fi

if [[ $CI_MODE -eq 1 ]]; then
  exec shellspec --directory "$REPO_DIR" --format tap
fi

exec shellspec --directory "$REPO_DIR" --format documentation
