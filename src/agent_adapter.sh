# agent_adapter.sh — install and remove Cumaru's agent-specific integration.
#
# Adapters are selected by the command that manages their artifacts. The legacy
# config `agent` field is intentionally ignored for compatibility only.

# Normalize a CLI/config value to the internal adapter name.
_agent_normalize() {
  case "${1:-}" in
    ""|null|none) printf '%s\n' "generic" ;;
    claude|codex|opencode) printf '%s\n' "$1" ;;
    *) return 1 ;;
  esac
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

# The session-start command guarantees discipline bodies before projecting root
# candidates. Tree failures stay silent because a hook must not disturb a session.
CUMARU_SESSION_HOOK_CMD='for file in .cumaru/disciplines/*.md; do [ -f "$file" ] && { printf "\n## Discipline: %s\n\n" "$file"; cat "$file"; }; done; cumaru tree . 2>/dev/null || true'
CUMARU_LEGACY_SESSION_HOOK_CMD='cumaru tree . 2>/dev/null || true'

# Every context entry point: a fresh start plus each way a context is re-created.
CUMARU_SESSION_HOOK_MATCHER='startup|resume|clear|compact|fork'

# Return the adapter's hook config file, or nothing when hooks are unsupported.
# Claude and Codex share the same SessionStart JSON shape; OpenCode has no
# session-start event yet, so its tree projection stays prose-only.
_agent_hooks_file() {
  local parent="$1" agent="$2"
  case "$agent" in
    claude) printf '%s\n' "$parent/.claude/settings.json" ;;
    codex) printf '%s\n' "$parent/.codex/hooks.json" ;;
    generic|opencode) return 0 ;;
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

# Validate OpenCode's exact Cumaru instruction set while allowing project-owned
# entries anywhere. Raw jq status/stderr are retained for focused diagnostics.
_agent_opencode_instructions_valid() {
  local config="$1"
  jq -e '
    if (.instructions | type) != "array" then false
    else
      .instructions as $instructions
      | ($instructions | map(select(. == ".cumaru/index.md")) | length) as $kernel_count
      | ($instructions | map(select(. == ".cumaru/domain.md")) | length) as $domain_count
      | ($instructions | map(select(. == ".cumaru/disciplines/*.md")) | length) as $disciplines_count
      | ($instructions | index(".cumaru/index.md")) as $kernel
      | ($instructions | index(".cumaru/domain.md")) as $domain
      | ($instructions | index(".cumaru/disciplines/*.md")) as $disciplines
      | $kernel_count == 1 and $domain_count == 1 and $disciplines_count == 1
        and $kernel < $domain and $domain < $disciplines
    end
  ' "$config"
}

# Require exactly one canonical Cumaru SessionStart entry while allowing every
# unrelated adopter hook to coexist beside it.
_agent_session_hook_valid() {
  local config="$1"
  jq -e --arg cmd "$CUMARU_SESSION_HOOK_CMD" \
    --arg legacy_cmd "$CUMARU_LEGACY_SESSION_HOOK_CMD" \
    --arg matcher "$CUMARU_SESSION_HOOK_MATCHER" '
    def nested_hooks:
      .hooks.SessionStart[]
      | select(type == "object")
      | .hooks
      | select(type == "array")
      | .[];
    if type != "object" or (.hooks | type) != "object" or
       (.hooks.SessionStart | type) != "array" then false
    else
      ([.hooks.SessionStart[]
        | select(. == {
            matcher: $matcher,
            hooks: [{type: "command", command: $cmd}]
          })] | length) == 1
      and ([nested_hooks | select(.command? == $cmd)] | length) == 1
      and ([nested_hooks | select(.command? == $legacy_cmd)] | length) == 0
    end
  ' "$config"
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
      _agent_refresh_markdown_hook "$parent" "$agent"
      return
    fi
    {
      echo ""
      _cumaru_hook_block "$rel_index" "0" "$agent"
    } >> "$instructions"
    green "  + ${instructions#"$parent"/} hook appended"
  else
    {
      echo "# Project instructions"
      echo ""
      _cumaru_hook_block "$rel_index" "1" "$agent"
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
  _cumaru_hook_block "$rel_index" "$created" "$agent" >> "$tmp"
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
      (if (.instructions == null) then []
       elif (.instructions | type) == "array" then .instructions
       else error("instructions must be an array or null") end) as $instructions
      | .instructions = (
        ($instructions | map(select(
          . != ".cumaru/index.md" and
          . != ".cumaru/domain.md" and
          . != ".cumaru/disciplines/*.md"
        ))) +
        [".cumaru/index.md", ".cumaru/domain.md", ".cumaru/disciplines/*.md"]
      )
    ' "$config" > "$tmp" || {
      rm -f "$tmp"
      red "✗ cannot merge instructions into $config"
      return 1
    }
  else
    jq -n '{
      "$schema": "https://opencode.ai/config.json",
      "instructions": [".cumaru/index.md", ".cumaru/domain.md", ".cumaru/disciplines/*.md"]
    }' > "$tmp"
  fi
  mv "$tmp" "$config"
  green "  + opencode.json instructions"
}

# Register the SessionStart hook, preserving every hook the adopter owns.
_agent_wire_session_hook() {
  local parent="$1" agent="$2" config tmp
  config=$(_agent_hooks_file "$parent" "$agent")
  [[ -n "$config" ]] || return 0
  command -v jq >/dev/null 2>&1 || return 1

  mkdir -p "$(dirname "$config")"
  [[ -f "$config" ]] || echo '{}' > "$config"

  tmp=$(mktemp "${TMPDIR:-/tmp}/cumaru-hooks.XXXXXX")
  # Drop any previous Cumaru entry before appending, so the merge is idempotent
  # and an adopter entry that also carried our command keeps its other hooks.
  jq --arg cmd "$CUMARU_SESSION_HOOK_CMD" --arg legacy_cmd "$CUMARU_LEGACY_SESSION_HOOK_CMD" --arg matcher "$CUMARU_SESSION_HOOK_MATCHER" '
    .hooks //= {}
    | .hooks.SessionStart = (
        ((.hooks.SessionStart // [])
          | map(.hooks = ((.hooks // []) | map(select(.command != $cmd and .command != $legacy_cmd))))
          | map(select((.hooks | length) > 0)))
        + [{matcher: $matcher, hooks: [{type: "command", command: $cmd}]}]
      )
  ' "$config" > "$tmp" || {
    rm -f "$tmp"
    red "  ✗ ${config#"$parent"/} is not valid JSON — SessionStart hook not installed"
    return 1
  }
  _agent_session_hook_valid "$tmp" >/dev/null 2>&1 || {
    rm -f "$tmp"
    red "  ✗ ${config#"$parent"/} could not be normalized to the canonical SessionStart hook"
    return 1
  }
  mv "$tmp" "$config"
  green "  + ${config#"$parent"/} SessionStart hook (cumaru tree .)"
}

# Remove only Cumaru's SessionStart entry, leaving adopter hooks untouched.
_agent_strip_session_hook() {
  local parent="$1" agent="$2" config tmp
  config=$(_agent_hooks_file "$parent" "$agent")
  [[ -n "$config" && -f "$config" ]] || return 0
  command -v jq >/dev/null 2>&1 || return 1

  tmp=$(mktemp "${TMPDIR:-/tmp}/cumaru-hooks.XXXXXX")
  jq --arg cmd "$CUMARU_SESSION_HOOK_CMD" --arg legacy_cmd "$CUMARU_LEGACY_SESSION_HOOK_CMD" '
    if (.hooks.SessionStart | type) == "array" then
      .hooks.SessionStart = (.hooks.SessionStart
        | map(.hooks = ((.hooks // []) | map(select(.command != $cmd and .command != $legacy_cmd))))
        | map(select((.hooks | length) > 0)))
      | if (.hooks.SessionStart | length) == 0 then del(.hooks.SessionStart) else . end
      | if (.hooks | length) == 0 then del(.hooks) else . end
    else . end
  ' "$config" > "$tmp" || {
    rm -f "$tmp"
    return 1
  }
  mv "$tmp" "$config"
  green "  - removed SessionStart hook from: ${config#"$parent"/}"

  # An empty config Cumaru just emptied is noise; a populated one is adopter data.
  if [[ "$(jq -S -c . "$config" 2>/dev/null)" == "{}" ]]; then
    rm -f "$config"
    rmdir "$(dirname "$config")" 2>/dev/null || true
  fi
}

# Install the instruction surface for one adapter.
_agent_wire_instructions() {
  local parent="$1" agent="$2"
  if [[ "$agent" == "opencode" ]]; then
    _agent_wire_opencode_config "$parent" || return 1
  else
    _agent_wire_markdown_hook "$parent" "$agent" || return 1
  fi
  _agent_wire_session_hook "$parent" "$agent"
}

# Reconcile an adapter's instruction surface to the current canonical form.
_agent_refresh_instructions() {
  local parent="$1" agent="$2"
  if [[ "$agent" == "opencode" ]]; then
    _agent_wire_opencode_config "$parent" || return 1
  else
    _agent_refresh_markdown_hook "$parent" "$agent" || return 1
  fi
  _agent_wire_session_hook "$parent" "$agent"
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
        . != ".cumaru/index.md" and
        . != ".cumaru/domain.md" and
        . != ".cumaru/disciplines/*.md"
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
  _agent_strip_session_hook "$parent" "$agent" || return 1

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
  local skills_dir="$1" dir file
  [[ -d "$skills_dir" ]] || return 0
  for dir in "$skills_dir"/cumaru-*/; do
    [[ -d "$dir" ]] || continue
    while IFS= read -r -d '' file; do
      rm -f "$file" || return 1
      green "  - removed skill file: $file"
    done < <(find "$dir" -type f -print0)
  done
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

  # `.agents/skills` is shared by generic, Codex, and OpenCode. A scoped
  # clear must never delete it because another adapter may still rely on it.
  # The all-adapters clear calls _agent_remove_skills_at explicitly after the
  # scoped cleanup pass.
  if [[ "$old_skills" != "$new_skills" && "$old_skills" != "$parent/.agents/skills" ]]; then
    _agent_remove_skills_at "$old_skills"
  fi
  if [[ -n "$old_commands" && "$old_commands" != "$new_commands" && -d "$old_commands/cumaru" ]]; then
    local file
    while IFS= read -r -d '' file; do
      rm -f "$file" || return 1
      green "  - removed command file: $file"
    done < <(find "$old_commands/cumaru" -type f -name '*.md' -print0)
  fi
}

# Describe an adapter's native artifacts for dry-run output.
_agent_describe() {
  local parent="$1" agent="$2" skills commands instructions hooks
  skills=$(_agent_skills_dir "$parent" "$agent")
  commands=$(_agent_commands_dir "$parent" "$agent")
  instructions=$(_agent_instructions_file "$parent" "$agent")
  hooks=$(_agent_hooks_file "$parent" "$agent")

  if [[ "$agent" == "opencode" ]]; then
    say "  instructions: opencode.json → kernel, domain, and all disciplines"
  else
    say "  instructions: ${instructions#"$parent"/}"
  fi
  say "  skills:       ${skills#"$parent"/}/cumaru-*"
  [[ -n "$commands" ]] && say "  commands:     ${commands#"$parent"/}/cumaru/"
  [[ "$agent" == "codex" ]] && say "  commands:     native skills only (no project command directory)"
  if [[ -n "$hooks" ]]; then
    say "  hooks:        ${hooks#"$parent"/} → SessionStart: $CUMARU_SESSION_HOOK_CMD"
  else
    say "  hooks:        none (adapter has no session-start event)"
  fi
}
