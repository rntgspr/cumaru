#!/usr/bin/env bash
set -u

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TMP=$(mktemp -d "${TMPDIR:-/tmp}/cumaru-agent-adapters.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
pass() { printf 'ok: %s\n' "$*"; }

# Install one clean project for each supported adapter.
install_agent() {
  local name="$1"
  local project="$TMP/$name"
  local extra=()
  [[ "$name" == "claude" ]] && extra=(--with git)
  mkdir -p "$project"
  (cd "$project" && "$ROOT/cumaru" install agent "$name" --domain base "${extra[@]+"${extra[@]}"}") \
    > "$TMP/install-$name.out" 2>&1 || fail "install agent $name"
}

for adapter in none claude codex opencode; do
  install_agent "$adapter"
done

[[ "$(yq -r '.agent // "null"' "$TMP/none/.cumaru/schema.yaml")" == "null" ]] ||
  fail "none did not serialize as YAML null"
[[ -f "$TMP/none/.agents/AGENTS.md" ]] ||
  fail "generic instruction file is missing"
[[ -f "$TMP/none/.agents/commands/cumaru/doctor.md" ]] ||
  fail "generic commands are missing"
pass "none installs the backward-compatible generic adapter"

[[ "$(yq -r '.agent' "$TMP/claude/.cumaru/schema.yaml")" == "claude" ]] ||
  fail "claude state is missing"
[[ -f "$TMP/claude/CLAUDE.md" ]] ||
  fail "CLAUDE.md is missing"
[[ -f "$TMP/claude/.claude/skills/cumaru-doctor/SKILL.md" ]] ||
  fail "Claude skill is missing"
[[ -f "$TMP/claude/.claude/commands/cumaru/doctor.md" ]] ||
  fail "Claude command is missing"
[[ -f "$TMP/claude/.claude/skills/git/SKILL.md" ]] ||
  fail "Claude opt-in skill did not follow the selected adapter"
pass "claude installs native instructions, skills, and commands"

[[ "$(yq -r '.agent' "$TMP/codex/.cumaru/schema.yaml")" == "codex" ]] ||
  fail "codex state is missing"
[[ -f "$TMP/codex/AGENTS.md" ]] ||
  fail "Codex AGENTS.md is missing"
[[ -f "$TMP/codex/.agents/skills/cumaru-doctor/SKILL.md" ]] ||
  fail "Codex skill is missing"
[[ ! -d "$TMP/codex/.agents/commands" ]] ||
  fail "Codex received an unsupported command directory"
pass "codex installs AGENTS.md and project skills only"

[[ "$(yq -r '.agent' "$TMP/opencode/.cumaru/schema.yaml")" == "opencode" ]] ||
  fail "opencode state is missing"
jq -e '
  (.instructions | index(".cumaru/index.md") != null) and
  (.instructions | index(".cumaru/domain.md") != null)
' "$TMP/opencode/opencode.json" >/dev/null ||
  fail "OpenCode instructions are missing"
[[ -f "$TMP/opencode/.agents/skills/cumaru-doctor/SKILL.md" ]] ||
  fail "OpenCode skill is missing"
[[ -f "$TMP/opencode/.opencode/commands/cumaru/doctor.md" ]] ||
  fail "OpenCode command is missing"
pass "opencode installs config instructions, shared skills, and native commands"

before=$(yq -r '.agent // "null"' "$TMP/none/.cumaru/schema.yaml")
(cd "$TMP/none" && "$ROOT/cumaru" update agent opencode) \
  > "$TMP/update-dry.out" 2>&1 || fail "agent dry-run"
after=$(yq -r '.agent // "null"' "$TMP/none/.cumaru/schema.yaml")
[[ "$before" == "$after" && ! -f "$TMP/none/opencode.json" ]] ||
  fail "agent dry-run mutated the project"
pass "update agent is dry-run without --apply"

(cd "$TMP/none" && "$ROOT/cumaru" update agent opencode --apply) \
  > "$TMP/update-opencode.out" 2>&1 || fail "switch to opencode"
[[ "$(yq -r '.agent' "$TMP/none/.cumaru/schema.yaml")" == "opencode" ]] ||
  fail "switch did not persist opencode"
[[ ! -f "$TMP/none/.agents/AGENTS.md" ]] ||
  fail "switch left the generic instruction hook"
[[ -f "$TMP/none/.opencode/commands/cumaru/doctor.md" ]] ||
  fail "switch did not install OpenCode commands"
pass "update agent --apply replaces the active adapter"

(cd "$TMP/none" && "$ROOT/cumaru" update agent none --apply) \
  > "$TMP/update-none.out" 2>&1 || fail "switch back to none"
[[ "$(yq -r '.agent // "null"' "$TMP/none/.cumaru/schema.yaml")" == "null" ]] ||
  fail "none did not restore schema null"
[[ -f "$TMP/none/.agents/AGENTS.md" ]] ||
  fail "none did not restore generic instructions"
jq -e '(.instructions // []) | index(".cumaru/index.md") == null' \
  "$TMP/none/opencode.json" >/dev/null ||
  fail "OpenCode instructions were not removed"
pass "update agent none restores generic behavior"

for adapter in none claude codex opencode; do
  (cd "$TMP/$adapter" && "$ROOT/cumaru" doctor) \
    > "$TMP/doctor-$adapter.out" 2>&1 || fail "doctor rejected $adapter"
  grep -q "Agent adapter" "$TMP/doctor-$adapter.out" ||
    fail "doctor did not report adapter $adapter"
done
pass "doctor validates every schema-selected adapter"

printf '\nProject-owned Codex guidance.\n' >> "$TMP/codex/AGENTS.md"
sed -i.bak 's/spec-driven, agent-friendly knowledge structure/outdated knowledge structure/' \
  "$TMP/codex/AGENTS.md"
rm -f "$TMP/codex/AGENTS.md.bak"
(cd "$TMP/codex" && "$ROOT/cumaru" doctor) \
  > "$TMP/doctor-codex-drift.out" 2>&1 || fail "doctor could not inspect Codex hook drift"
grep -q "CUMARU-HOOK differs from canonical" "$TMP/doctor-codex-drift.out" ||
  fail "doctor did not diagnose Codex hook drift"
(cd "$TMP/codex" && "$ROOT/cumaru" update agent codex --apply) \
  > "$TMP/update-codex-hook.out" 2>&1 || fail "update agent codex did not repair hook drift"
grep -q "spec-driven, agent-friendly knowledge structure" "$TMP/codex/AGENTS.md" ||
  fail "update agent codex did not restore the canonical hook"
grep -q "Project-owned Codex guidance." "$TMP/codex/AGENTS.md" ||
  fail "update agent codex replaced project-owned prose"
(cd "$TMP/codex" && "$ROOT/cumaru" doctor) \
  > "$TMP/doctor-codex-repaired.out" 2>&1 || fail "doctor rejected repaired Codex hook"
if grep -q "CUMARU-HOOK differs from canonical" "$TMP/doctor-codex-repaired.out"; then
  fail "Codex hook still differs after the suggested update command"
fi
pass "update agent --apply repairs canonical hook drift and preserves project prose"

(cd "$TMP/opencode" && "$ROOT/cumaru" update skills --apply &&
  "$ROOT/cumaru" update commands --apply) \
  > "$TMP/update-artifacts.out" 2>&1 ||
  fail "normal update did not follow OpenCode adapter paths"
[[ -f "$TMP/opencode/.opencode/commands/cumaru/doctor.md" ]] ||
  fail "normal update lost OpenCode commands"
pass "normal update refreshes the schema-selected adapter"

yq -i '.rules.markdown.required_heading = "h2"' "$TMP/opencode/.cumaru/schema.yaml"
(cd "$TMP/opencode" && "$ROOT/cumaru" update schema --apply) \
  > "$TMP/update-schema.out" 2>&1 || fail "schema update"
[[ "$(yq -r '.agent' "$TMP/opencode/.cumaru/schema.yaml")" == "opencode" ]] ||
  fail "schema update reset the active agent"
pass "schema replacement preserves agent runtime state"

yq -i '.agent = "generic"' "$TMP/opencode/.cumaru/schema.yaml"
if (cd "$TMP/opencode" && "$ROOT/cumaru" doctor) > "$TMP/doctor-invalid.out" 2>&1; then
  fail "doctor accepted an invalid explicit agent value"
fi
grep -q "Invalid agent value" "$TMP/doctor-invalid.out" ||
  fail "doctor did not diagnose invalid agent state"
yq -i '.agent = "opencode"' "$TMP/opencode/.cumaru/schema.yaml"
pass "doctor rejects agent values outside the schema contract"

(cd "$TMP/claude" && "$ROOT/cumaru" uninstall --yes) \
  > "$TMP/uninstall.out" 2>&1 || fail "uninstall claude adapter"
[[ ! -e "$TMP/claude/.cumaru" && ! -e "$TMP/claude/CLAUDE.md" ]] ||
  fail "uninstall left Claude artifacts"
pass "uninstall removes the active adapter"
