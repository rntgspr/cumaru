# cmd_install.sh — install the framework starter into a project's .llm/.
#
# Expects from the entry-point:
#   FRAMEWORK_SRC  — path to dot-llm-framework/ (the default starter)
#   SKILLS_SRC     — path to skills/ (top-level published skills)
#   COMMANDS_SRC   — path to commands/ (slash commands installed into
#                    <parent>/.claude/commands/ alongside .llm/)
#
# Usage:
#   cmd_install [TARGET] [--with <skill>...]
#
# `--with <name>` copies skills/<name>/SKILL.md into TARGET/skills/<name>/SKILL.md.
# Repeatable: `llm install --with git --with llm-cli`.

cmd_install() {
  local target=""
  local with_skills=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --with)
        if [[ -z "${2:-}" ]]; then
          red "✗ --with requires a skill name (e.g. --with git)"
          return 2
        fi
        with_skills+=("$2"); shift 2
        ;;
      --with=*)
        with_skills+=("${1#--with=}"); shift
        ;;
      -h|--help|help)
        cmd_install_help; return 0
        ;;
      -*)
        red "unknown flag: $1"; cmd_install_help; return 2
        ;;
      *)
        if [[ -z "$target" ]]; then
          target="$1"
        else
          red "unexpected arg: $1"; return 2
        fi
        shift
        ;;
    esac
  done

  : "${target:=./.llm}"

  if [[ ! -d "$FRAMEWORK_SRC" ]]; then
    red "✗ framework starter not found at $FRAMEWORK_SRC"
    return 1
  fi

  if [[ -e "$target" ]]; then
    if [[ ! -t 0 ]]; then
      red "✗ target $target already exists (run interactively to confirm overwrite)"
      return 1
    fi
    local answer=""
    read -r -p "Target $target already exists. Overwrite? This will replace its contents. [y/N] " answer
    case "${answer:-N}" in
      [Yy]*)
        rm -rf "$target"
        ;;
      *)
        red "✗ aborted; target $target left untouched"
        return 1
        ;;
    esac
  fi

  # Pre-validate skills before any write — fail fast.
  local skill src
  for skill in "${with_skills[@]+"${with_skills[@]}"}"; do
    src="$SKILLS_SRC/${skill}/SKILL.md"
    if [[ ! -f "$src" ]]; then
      red "✗ skill not found: $skill (looked for $src)"
      return 1
    fi
  done

  local parent
  parent=$(dirname "$target")
  mkdir -p "$parent"
  cp -R "$FRAMEWORK_SRC" "$target"

  green "✓ installed framework starter to $target"

  # Regenerate shallow pillar indexes against the freshly copied tree so the
  # starter's didactic placeholder tables are replaced by the canonical empty
  # form `regen` produces — `llm doctor` would otherwise report drift on the
  # very first run.
  ( DOT_LLM_DIR="$target" cmd_regen_index ) >/dev/null
  green "  + shallow indexes regenerated"

  # Apply opt-in skills.
  for skill in "${with_skills[@]+"${with_skills[@]}"}"; do
    src="$SKILLS_SRC/${skill}/SKILL.md"
    mkdir -p "$target/skills/${skill}"
    cp "$src" "$target/skills/${skill}/SKILL.md"
    green "  + skill: $skill"
  done

  # Wire CLAUDE.md so the LLM auto-loads .llm/index.md on every session.
  _install_wire_claude_md "$parent" "$target"

  # Install slash commands into $parent/.claude/commands/.
  _install_wire_claude_commands "$parent"

  # Offer to detect spec areas from the source tree (interactive only).
  _install_offer_specs_bootstrap "$parent" "$target"

  local doctor_cmd
  if [[ "$target" == "./.llm" || "$target" == ".llm" ]]; then
    doctor_cmd="llm doctor"
  else
    doctor_cmd="DOT_LLM_DIR=$target llm doctor"
  fi
  cat <<EOF

Next steps:
  1. Edit $target/index.md — replace the placeholder Multi-component table
     with your project's actual components.
  2. Edit $target/schema.yaml — under apps.values, add one entry per
     component your project ships. Keep platform and meta as reserved.
  3. Run health checks:
       $doctor_cmd

The CLAUDE.md hook ensures every Claude session in this repo loads
$target/index.md automatically (via @import). Open the project in your
client and the framework is wired in.
EOF
}

# Print the dot-llm hook block to stdout. Argument: rel_index (e.g. ".llm/index.md").
_install_print_hook_block() {
  local rel_index="$1"
  cat <<EOF
<!-- BEGIN DOT-LLM-HOOK -->
## \`.llm/\` framework

This project uses the \`.llm/\` framework — a spec-driven, agent-friendly knowledge structure. Whenever you (the LLM) start a session in this repository, **read \`$rel_index\` first**. It carries the five pillars (intake / plans / archive / specs / exploring), the loading rule for what enters context, and the role definitions under \`$rel_index\`'s sibling \`roles/\`.

@$rel_index
<!-- END DOT-LLM-HOOK -->
EOF
}

# Offer (interactively) to run `llm specs bootstrap` (dry-run) so the user
# sees the areas the CLI would scaffold from their source tree. Skipped
# when stdin is not a TTY (e.g. piped install).
_install_offer_specs_bootstrap() {
  local parent="$1" target="$2"

  # Non-interactive context — skip silently.
  if [[ ! -t 0 ]]; then
    return 0
  fi

  echo ""
  local answer=""
  read -r -p "Detect spec areas from your source tree (light pass, no writes)? [Y/n] " answer

  case "${answer:-Y}" in
    [Yy]*) ;;
    *) return 0 ;;
  esac

  echo ""
  local target_name
  target_name=$(basename "$target")
  # Run bootstrap in a subshell rooted at the project parent so its scan
  # path detection (src/, app/, lib/) is relative to the adopter's project.
  ( cd "$parent" && DOT_LLM_DIR="$target_name" cmd_specs_bootstrap )

  echo ""
  say "  → If the areas above look right, write specs/<area>/bootstrap.md per area:"
  if [[ "$parent" == "." ]]; then
    say "    llm specs bootstrap --apply"
  else
    say "    (cd $parent && llm specs bootstrap --apply)"
  fi
}

# Copy slash commands from $COMMANDS_SRC into $parent/.claude/commands/.
# Walks recursively so subdirs (namespaces) are preserved: a source file
# at commands/llm/sync.md becomes <parent>/.claude/commands/llm/sync.md,
# exposing the slash command as /llm:sync. Idempotent: skips files
# already present at the destination.
_install_wire_claude_commands() {
  local parent="$1"

  if [[ ! -d "$COMMANDS_SRC" ]]; then
    return 0
  fi

  local cmds_dir="$parent/.claude/commands"
  local any_source=0
  local cmd_file
  while IFS= read -r -d '' cmd_file; do
    any_source=1
    break
  done < <(find "$COMMANDS_SRC" -type f -name '*.md' -print0)
  [[ $any_source -eq 0 ]] && return 0

  mkdir -p "$cmds_dir"

  local rel dest slash
  while IFS= read -r -d '' cmd_file; do
    rel="${cmd_file#"$COMMANDS_SRC"/}"
    dest="$cmds_dir/$rel"
    slash="${rel%.md}"
    slash="/${slash//\//:}"
    if [[ -f "$dest" ]]; then
      say "  · ${slash} command already present (skip)"
    else
      mkdir -p "$(dirname "$dest")"
      cp "$cmd_file" "$dest"
      green "  + ${slash} command added at $dest"
    fi
  done < <(find "$COMMANDS_SRC" -type f -name '*.md' -print0)
}

_install_wire_claude_md() {
  local parent="$1" target="$2"
  local claude_md="$parent/CLAUDE.md"
  # Compute the import path relative to CLAUDE.md (which lives at $parent).
  local rel_index
  rel_index="$(basename "$target")/index.md"

  if [[ -f "$claude_md" ]]; then
    if grep -q "BEGIN DOT-LLM-HOOK" "$claude_md"; then
      say "  · CLAUDE.md hook already present (skip)"
      return 0
    fi
    {
      echo ""
      _install_print_hook_block "$rel_index"
    } >> "$claude_md"
    green "  + CLAUDE.md hook appended at $claude_md"
  else
    {
      echo "# Project instructions"
      echo ""
      _install_print_hook_block "$rel_index"
    } > "$claude_md"
    green "  + CLAUDE.md created at $claude_md (with .llm/ hook)"
  fi
}

cmd_install_help() {
  cat <<'EOF'
llm install — install the framework starter into a project

Usage:
  llm install [TARGET] [--with <skill>...]

Arguments:
  TARGET           directory to create (default: ./.llm). Refuses to overwrite.

Options:
  --with <skill>   include an opt-in skill (looked up in skills/<skill>/SKILL.md
                   in the dot-llm checkout). Repeatable.

Available skills:
  git              unlock mutating git commands (commit/push/reset/...) under
                   the framework's skill-gated capability rule. Without this
                   skill, every role uses git only for reading.
  llm-cli          operate the llm CLI itself (rarely needed inside a project
                   — adopters typically install this skill globally in Claude).

Examples:
  llm install                       # default install at ./.llm (no skills)
  llm install --with git            # default install + the git skill
  llm install /path/.llm --with git # custom target + git skill
EOF
}
