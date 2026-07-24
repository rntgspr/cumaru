# agent_adapter.sh — install and remove Cumaru's agent-specific integration.
#
# The schema stores the selected adapter in `agent`. A missing or null value is
# the generic adapter retained for backward compatibility.

# Normalize a CLI/schema value to the internal adapter name.
_agent_normalize() {
  case "${1:-}" in
    ""|null|none) printf '%s\n' "generic" ;;
    claude|codex|opencode) printf '%s\n' "$1" ;;
    *) return 1 ;;
  esac
}

# Read the active adapter from schema.yaml.
_agent_current() {
  local value=""
  [[ -f "$SCHEMA" ]] && value=$(yq -r '.agent // ""' "$SCHEMA" 2>/dev/null || true)
  _agent_normalize "$value"
}

# Persist an adapter only after its artifacts have been installed successfully.
_agent_set() {
  local agent="$1"
  if [[ "$agent" == "generic" ]]; then
    yq -i '.agent = null' "$SCHEMA"
  else
    AGENT_VALUE="$agent" yq -i '.agent = strenv(AGENT_VALUE)' "$SCHEMA"
  fi
}

# Return the project-local skill directory for an adapter.
_agent_skills_dir() {
  local parent="$1" agent="$2"
  case "$agent" in
    claude) printf '%s\n' "$parent/.claude/skills" ;;
    generic|codex|opencode) printf '%s\n' "$parent/.agents/skills" ;;
  esac
}

# Return the project-local command directory, or nothing when unsupported.
_agent_commands_dir() {
  local parent="$1" agent="$2"
  case "$agent" in
    generic) printf '%s\n' "$parent/.agents/commands" ;;
    claude) printf '%s\n' "$parent/.claude/commands" ;;
    opencode) printf '%s\n' "$parent/.opencode/commands" ;;
    codex) return 0 ;;
  esac
}

# Return the native instruction file, or nothing when config owns instructions.
_agent_instructions_file() {
  local parent="$1" agent="$2"
  case "$agent" in
    generic) printf '%s\n' "$parent/.agents/AGENTS.md" ;;
    claude) printf '%s\n' "$parent/CLAUDE.md" ;;
    codex) printf '%s\n' "$parent/AGENTS.md" ;;
    opencode) return 0 ;;
  esac
}

# Install the canonical hook in a native Markdown instruction file.
_agent_wire_markdown_hook() {
  local parent="$1" agent="$2"
  local instructions rel_index
  instructions=$(_agent_instructions_file "$parent" "$agent")
  rel_index="$CUMARU_DIR/index.md"

  mkdir -p "$(dirname "$instructions")"

  if [[ -f "$instructions" ]]; then
    if grep -q "BEGIN CUMARU-HOOK" "$instructions"; then
      say "  · ${instructions#"$parent"/} hook already present (skip)"
      return 0
    fi
    {
      echo ""
      _cumaru_hook_block "$rel_index" "0"
    } >> "$instructions"
    green "  + ${instructions#"$parent"/} hook appended"
  else
    {
      echo "# Project instructions"
      echo ""
      _cumaru_hook_block "$rel_index" "1"
    } > "$instructions"
    green "  + ${instructions#"$parent"/} created (with .cumaru/ hook)"
  fi
}

# Replace an existing Cumaru/legacy hook with the canonical block while
# preserving project-owned prose and the install-created ownership marker.
_agent_refresh_markdown_hook() {
  local parent="$1" agent="$2"
  local instructions rel_index created=0 tmp
  instructions=$(_agent_instructions_file "$parent" "$agent")
  rel_index="$CUMARU_DIR/index.md"

  if [[ ! -f "$instructions" ]] ||
     ! grep -qE "BEGIN (CUMARU|DOT-LLM)-HOOK" "$instructions"; then
    _agent_wire_markdown_hook "$parent" "$agent"
    return
  fi

  grep -Eq "BEGIN (CUMARU|DOT-LLM)-HOOK created" "$instructions" && created=1
  tmp=$(mktemp)
  awk '
    { lines[NR] = $0 }
    END {
      b = 0; e = 0
      for (i = 1; i <= NR; i++) {
        if (lines[i] ~ /BEGIN (CUMARU|DOT-LLM)-HOOK/) b = i
        if (lines[i] ~ /END (CUMARU|DOT-LLM)-HOOK/)   e = i
      }
      drop = (b > 1 && lines[b-1] ~ /^[[:space:]]*$/) ? b - 1 : 0
      for (i = 1; i <= NR; i++) {
        if (i >= b && i <= e) continue
        if (i == drop)        continue
        print lines[i]
      }
      print ""
    }
  ' "$instructions" > "$tmp"
  _cumaru_hook_block "$rel_index" "$created" >> "$tmp"
  mv "$tmp" "$instructions"
  green "  ~ ${instructions#"$parent"/} hook refreshed"
}

# Merge Cumaru's instruction files into OpenCode's native project config.
_agent_wire_opencode_config() {
  local parent="$1" config="$parent/opencode.json" tmp
  command -v jq >/dev/null 2>&1 || {
    red "✗ jq is required for the opencode adapter"
    return 1
  }

  tmp=$(mktemp)
  if [[ -f "$config" ]]; then
    jq '
      .instructions = (((.instructions // []) +
        [".cumaru/index.md", ".cumaru/domain.md"]) | unique)
    ' "$config" > "$tmp" || {
      rm -f "$tmp"
      red "✗ cannot merge instructions into $config"
      return 1
    }
  else
    jq -n '{
      "$schema": "https://opencode.ai/config.json",
      "instructions": [".cumaru/index.md", ".cumaru/domain.md"]
    }' > "$tmp"
  fi
  mv "$tmp" "$config"
  green "  + opencode.json instructions"
}

# Install the instruction surface for one adapter.
_agent_wire_instructions() {
  local parent="$1" agent="$2"
  if [[ "$agent" == "opencode" ]]; then
    _agent_wire_opencode_config "$parent"
  else
    _agent_wire_markdown_hook "$parent" "$agent"
  fi
}

# Reconcile an adapter's instruction surface to the current canonical form.
_agent_refresh_instructions() {
  local parent="$1" agent="$2"
  if [[ "$agent" == "opencode" ]]; then
    _agent_wire_opencode_config "$parent"
  else
    _agent_refresh_markdown_hook "$parent" "$agent"
  fi
}

# Remove Cumaru's exact OpenCode instruction entries while preserving config.
_agent_strip_opencode_config() {
  local parent="$1" config="$parent/opencode.json" tmp
  [[ -f "$config" ]] || return 0
  command -v jq >/dev/null 2>&1 || return 1

  tmp=$(mktemp)
  jq '
    if (.instructions | type) == "array" then
      .instructions |= map(select(
        . != ".cumaru/index.md" and . != ".cumaru/domain.md"
      ))
      | if (.instructions | length) == 0 then del(.instructions) else . end
    else . end
  ' "$config" > "$tmp" || {
    rm -f "$tmp"
    return 1
  }
  mv "$tmp" "$config"
  green "  - removed Cumaru instructions from: opencode.json"
}

# Remove a Cumaru hook from an adapter's native instruction surface.
_agent_strip_instructions() {
  local parent="$1" agent="$2" file
  if [[ "$agent" == "opencode" ]]; then
    _agent_strip_opencode_config "$parent"
    return
  fi

  file=$(_agent_instructions_file "$parent" "$agent")
  [[ -f "$file" ]] || return 0
  if grep -qE "BEGIN (CUMARU|DOT-LLM)-HOOK" "$file"; then
    _uninstall_strip_hook "$file"
  fi
}

# Remove only Cumaru-owned skills from a directory.
_agent_remove_skills_at() {
  local skills_dir="$1" dir
  [[ -d "$skills_dir" ]] || return 0
  for dir in "$skills_dir"/cumaru-*/; do
    [[ -d "$dir" ]] || continue
    rm -rf "${dir%/}"
    green "  - removed skill: ${dir%/}"
  done
  rmdir "$skills_dir" 2>/dev/null || true
  rmdir "$(dirname "$skills_dir")" 2>/dev/null || true
}

# Remove an old adapter without deleting paths shared with the new adapter.
_agent_remove_adapter() {
  local parent="$1" old="$2" new="${3:-}"
  local old_skills new_skills old_commands new_commands
  old_skills=$(_agent_skills_dir "$parent" "$old")
  [[ -n "$new" ]] && new_skills=$(_agent_skills_dir "$parent" "$new") || new_skills=""
  old_commands=$(_agent_commands_dir "$parent" "$old")
  [[ -n "$new" ]] && new_commands=$(_agent_commands_dir "$parent" "$new") || new_commands=""

  _agent_strip_instructions "$parent" "$old" || return 1

  if [[ "$old_skills" != "$new_skills" ]]; then
    _agent_remove_skills_at "$old_skills"
  fi
  if [[ -n "$old_commands" && "$old_commands" != "$new_commands" && -d "$old_commands/cumaru" ]]; then
    rm -rf "$old_commands/cumaru"
    green "  - removed commands: $old_commands/cumaru/"
    rmdir "$old_commands" 2>/dev/null || true
    rmdir "$(dirname "$old_commands")" 2>/dev/null || true
  fi
}

# Describe an adapter's native artifacts for dry-run output.
_agent_describe() {
  local parent="$1" agent="$2" skills commands instructions
  skills=$(_agent_skills_dir "$parent" "$agent")
  commands=$(_agent_commands_dir "$parent" "$agent")
  instructions=$(_agent_instructions_file "$parent" "$agent")

  if [[ "$agent" == "opencode" ]]; then
    say "  instructions: opencode.json → .cumaru/index.md, .cumaru/domain.md"
  else
    say "  instructions: ${instructions#"$parent"/}"
  fi
  say "  skills:       ${skills#"$parent"/}/cumaru-*"
  [[ -n "$commands" ]] && say "  commands:     ${commands#"$parent"/}/cumaru/"
  [[ "$agent" == "codex" ]] && say "  commands:     native skills only (no project command directory)"
}
