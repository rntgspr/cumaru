#!/usr/bin/env bash

set -u

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TMP=$(mktemp -d "${TMPDIR:-/tmp}/cumaru-manual-agent-hooks.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

. "$ROOT/src/common.sh"
. "$ROOT/src/agent_adapter.sh"

assertions=0
failures=0
pass() { assertions=$((assertions + 1)); printf 'ok - %s\n' "$1"; }
fail() {
  assertions=$((assertions + 1)); failures=$((failures + 1))
  printf 'not ok - %s\n%s\n' "$1" "$2" >&2
}

install_agent() {
  local project="$1" agent="$2"
  mkdir -p "$project"
  (cd "$project" && "$ROOT/cumaru" install agent "$agent" --domain base) \
    > "$TMP/install-$agent.out" 2>&1
}

run_doctor() {
  local project="$1" output="$2"
  (cd "$project" && "$ROOT/cumaru" doctor --quiet) > "$output" 2>&1
  DOCTOR_STATUS=$?
}

codex="$TMP/codex"
if install_agent "$codex" codex; then
  pass "Codex fixture installs"
else
  fail "Codex fixture installs" "$(<"$TMP/install-codex.out")"
fi
hooks="$codex/.codex/hooks.json"
cp "$hooks" "$TMP/canonical-hooks.json"

jq '.hooks.SessionStart += [{matcher:"startup", hooks:[{type:"command", command:"echo adopter"}]}]
    | .hooks.PreToolUse = [{matcher:"Edit", hooks:[{type:"command", command:"echo guard"}]}]' \
  "$TMP/canonical-hooks.json" > "$hooks"
if _agent_session_hook_valid "$hooks" >/dev/null 2>&1; then
  run_doctor "$codex" "$TMP/canonical-doctor.out"
  if [[ $DOCTOR_STATUS -eq 0 ]] && ! grep -q "Agent adapter 'codex' is incomplete" "$TMP/canonical-doctor.out"; then
    pass "Codex accepts one canonical hook beside unrelated adopter hooks"
  else
    fail "Codex accepts one canonical hook beside unrelated adopter hooks" "$(<"$TMP/canonical-doctor.out")"
  fi
else
  fail "Codex accepts one canonical hook beside unrelated adopter hooks" "validator rejected canonical merge"
fi

check_codex_defect() {
  local name="$1" jq_filter="$2" output doctor_output
  output="$TMP/$name.json"
  doctor_output="$TMP/$name.doctor"
  jq "$jq_filter" "$TMP/canonical-hooks.json" > "$output"
  cp "$output" "$hooks"
  if _agent_session_hook_valid "$hooks" >/dev/null 2>&1; then
    fail "Codex rejects $name" "shared validator accepted invalid hook"
    return
  fi
  run_doctor "$codex" "$doctor_output"
  if [[ $DOCTOR_STATUS -eq 0 ]] &&
     grep -qF 'does not contain exactly one canonical Cumaru SessionStart hook' "$doctor_output"; then
    pass "Codex rejects $name"
  else
    fail "Codex rejects $name" "status: $DOCTOR_STATUS; output: $(<"$doctor_output")"
  fi
}

check_codex_defect wrong-matcher '.hooks.SessionStart[0].matcher = "startup"'
check_codex_defect wrong-type '.hooks.SessionStart[0].hooks[0].type = "prompt"'
check_codex_defect duplicate-entry '.hooks.SessionStart += [.hooks.SessionStart[0]]'
check_codex_defect malformed-nesting '.hooks.SessionStart = {matcher:"startup"}'
check_codex_defect missing-command 'del(.hooks.SessionStart[0].hooks[0].command)'

opencode="$TMP/opencode"
if install_agent "$opencode" opencode; then
  pass "OpenCode fixture installs"
else
  fail "OpenCode fixture installs" "$(<"$TMP/install-opencode.out")"
fi
if [[ ! -e "$opencode/.codex/hooks.json" && ! -e "$opencode/.claude/settings.json" ]] &&
   _agent_opencode_instructions_valid "$opencode/opencode.json" >/dev/null 2>&1; then
  run_doctor "$opencode" "$TMP/opencode-doctor.out"
  if [[ $DOCTOR_STATUS -eq 0 ]] && ! grep -q "Agent adapter 'opencode' is incomplete" "$TMP/opencode-doctor.out"; then
    pass "OpenCode remains hook-free and validates native instructions"
  else
    fail "OpenCode remains hook-free and validates native instructions" "$(<"$TMP/opencode-doctor.out")"
  fi
else
  fail "OpenCode remains hook-free and validates native instructions" "unexpected hook or invalid instructions"
fi

printf 'ok - Claude manual client coverage skipped (client unavailable)\n'

if [[ $failures -ne 0 ]]; then
  printf '%d assertion(s), %d failure(s)\n' "$assertions" "$failures" >&2
  exit 1
fi
printf '%d assertion(s), 0 failures\n' "$assertions"
