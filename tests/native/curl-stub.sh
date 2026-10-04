#!/usr/bin/env bash
set -eu

# Serves only approved fixture URLs, preserving cURL's trailing HTTP-status contract.
url="${!#}"
revision=1111111111111111111111111111111111111111
printf '%s\n' "$url" >> "$CUMARU_TEST_REQUESTS"
case "$url" in
  https://api.github.com/repos/rntgspr/cumaru/commits/main)
    printf '{"sha":"%s"}200' "$revision" ;;
  "https://api.github.com/repos/rntgspr/cumaru/git/trees/$revision?recursive=1")
    if [ "${CUMARU_TEST_TRUNCATED:-0}" = 1 ]; then
      printf '{"truncated":true,"tree":[]}200'
    else
      cat "$CUMARU_TEST_INVENTORY"
      printf 200
    fi ;;
  "https://raw.githubusercontent.com/rntgspr/cumaru/$revision/"*)
    path=${url#"https://raw.githubusercontent.com/rntgspr/cumaru/$revision/"}
    case "$path" in
      domains/*|skills/*|models/catalog.json) ;;
      *) printf 'Unexpected fixture path: %s\n' "$path" >&2; exit 1 ;;
    esac
    case "/$path/" in */../*|*/./*) exit 1 ;; esac
    if [ "${CUMARU_TEST_MISSING:-}" = "$path" ] || [ ! -f "$CUMARU_TEST_SOURCE/$path" ]; then
      printf 404
      exit 22
    fi
    cat "$CUMARU_TEST_SOURCE/$path"
    printf 200 ;;
  *) printf 'Network forbidden in native regressions: %s\n' "$url" >&2; exit 1 ;;
esac
