#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
SKILL="$ROOT/domains/__base/skills/cumaru-summarize/SKILL.md"
COMMAND="$ROOT/domains/__base/commands/cumaru/summarize.md"
DOMAINS="iac-basic qa-basic sdlc-full sdlc-light vault-memory"

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

require_text() {
  local text="$1"
  grep -Fq "$text" "$SKILL" || fail "summarize skill missing contract text: $text"
}

[[ -f "$SKILL" ]] || fail "canonical summarize skill is missing"
[[ -f "$COMMAND" ]] || fail "canonical summarize command is missing"

for domain in $DOMAINS; do
  mirror="$ROOT/domains/$domain/skills/cumaru-summarize/SKILL.md"
  command_mirror="$ROOT/domains/$domain/commands/cumaru/summarize.md"
  [[ -f "$mirror" ]] || fail "summarize skill missing in $domain"
  [[ -f "$command_mirror" ]] || fail "summarize command missing in $domain"
  cmp -s "$SKILL" "$mirror" || fail "summarize skill mirror drift in $domain"
  cmp -s "$COMMAND" "$command_mirror" || fail "summarize command mirror drift in $domain"
done

require_text "name: cumaru-summarize"
require_text "Use this universal skill whenever"
require_text "fill missing summaries"
require_text "fix invalid summaries"
require_text "refresh stale summaries"
require_text 'every regular Markdown file under `.cumaru/`'
require_text "local root-level support"
require_text "leaves first"
require_text 'directory `index.md` files deepest-first'
require_text "Preserve every valid summary by default"
require_text "ask the user before changing it"
require_text 'Modify only the `summary` frontmatter value'
require_text "between 32 and 256 Unicode code points"
require_text 'no CR, LF, or tab'
require_text 'Run `cumaru doctor` when complete'

grep -Fq 'Load the installed `cumaru-summarize` skill' "$COMMAND" \
  || fail "summarize command does not load the canonical skill"

bash -n "$ROOT/tests/test_summarize_artifacts.sh"

printf 'ok - summarize artifacts\n'
