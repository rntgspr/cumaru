# cmd_install.sh — install the framework starter into a project's .llm/.
#
# Expects from the entry-point:
#   FRAMEWORK_SRC  — path to dot-llm-framework/ (the default starter)
#   SKILLS_SRC     — path to skills/ (top-level published skills)
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
    red "✗ target $target already exists; refusing to overwrite"
    return 1
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

  # Apply opt-in skills.
  for skill in "${with_skills[@]+"${with_skills[@]}"}"; do
    src="$SKILLS_SRC/${skill}/SKILL.md"
    mkdir -p "$target/skills/${skill}"
    cp "$src" "$target/skills/${skill}/SKILL.md"
    green "  + skill: $skill"
  done

  # Wire CLAUDE.md so the LLM auto-loads .llm/index.md on every session.
  _install_wire_claude_md "$parent" "$target"

  local validate_cmd
  if [[ "$target" == "./.llm" || "$target" == ".llm" ]]; then
    validate_cmd="llm validate"
  else
    validate_cmd="DOT_LLM_DIR=$target llm validate"
  fi
  cat <<EOF

Next steps:
  1. Edit $target/index.md — replace the placeholder Multi-component table
     with your project's actual components.
  2. Edit $target/schema.yaml — under apps.values, add one entry per
     component your project ships. Keep platform and meta as reserved.
  3. Validate the result:
       $validate_cmd

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

This project uses the \`.llm/\` framework — a spec-driven, agent-friendly knowledge structure. Whenever you (the LLM) start a session in this repository, **read \`$rel_index\` first**. It carries the four pillars (intake / plans / archive / specs / exploring), the loading rule for what enters context, and the role definitions under \`$rel_index\`'s sibling \`roles/\`.

@$rel_index
<!-- END DOT-LLM-HOOK -->
EOF
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
  cat <<EOF
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
