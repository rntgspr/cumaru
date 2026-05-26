# cmd_install.sh — install a framework flavor into a project's .llm/.
#
# Each flavor is self-contained (its own schema + starter files):
#   --framework base                    → frameworks/__base/   (minimal kernel)
#   --framework sdlc-it-project-basic   → frameworks/sdlc-it-project-basic/   (default)
#   --framework <other>                 → frameworks/<other>/  (future flavors)
#
# Expects from the entry-point:
#   BASE_FRAMEWORK_SRC  — path to frameworks/__base/
#   FRAMEWORKS_DIR      — path to frameworks/
#   DEFAULT_FRAMEWORK   — default flavor name
#   _resolve_framework_src — function to resolve flavor name → source dir
#   SKILLS_SRC          — path to skills/ (top-level published skills)
#   COMMANDS_SRC        — path to commands/ (slash commands)

cmd_install() {
  local target=""
  local with_skills=()
  local flavor="$DEFAULT_FRAMEWORK"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --framework)
        [[ -n "${2:-}" ]] || { red "✗ --framework requires a name (e.g. sdlc-it-project-basic, base)"; return 2; }
        flavor="$2"; shift 2 ;;
      --framework=*)
        flavor="${1#--framework=}"; shift ;;
      --with)
        [[ -n "${2:-}" ]] || { red "✗ --with requires a skill name (e.g. --with git)"; return 2; }
        with_skills+=("$2"); shift 2 ;;
      --with=*)
        with_skills+=("${1#--with=}"); shift ;;
      -h|--help|help)
        cmd_install_help; return 0 ;;
      -*)
        red "unknown flag: $1"; cmd_install_help; return 2 ;;
      *)
        if [[ -z "$target" ]]; then target="$1"
        else red "unexpected arg: $1"; return 2; fi
        shift ;;
    esac
  done

  : "${target:=./.llm}"

  # Resolve flavor → source dir.
  local framework_src
  framework_src=$(_resolve_framework_src "$flavor") || return 1
  if [[ ! -d "$framework_src" ]]; then
    red "✗ framework not found at $framework_src"
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
      [Yy]*) rm -rf "$target" ;;
      *)     red "✗ aborted; target $target left untouched"; return 1 ;;
    esac
  fi

  # Pre-validate skills before any write — fail fast.
  local skill src
  for skill in "${with_skills[@]+"${with_skills[@]}"}"; do
    src="$SKILLS_SRC/${skill}/SKILL.md"
    [[ -f "$src" ]] || { red "✗ skill not found: $skill (looked for $src)"; return 1; }
  done

  local parent
  parent=$(dirname "$target")
  mkdir -p "$parent"

  # Copy the chosen flavor wholesale (includes flavor-specific skills/ if any).
  cp -R "$framework_src" "$target"
  green "✓ installed framework '$flavor' to $target"

  # Install universal llm-* skills + opt-in skills. Skip-if-exists so any
  # flavor-shipped version (already in $target/skills/ from the cp above) wins.
  _framework_copy_skills "$target" "0" "${with_skills[@]+"${with_skills[@]}"}"

  # Wire CLAUDE.md so the LLM auto-loads .llm/index.md on every session.
  _install_wire_claude_md "$parent" "$target"

  # Install slash commands into $parent/.claude/commands/ (skip-if-exists).
  _framework_copy_commands "$parent" "0"

  local doctor_cmd
  if [[ "$target" == "./.llm" || "$target" == ".llm" ]]; then
    doctor_cmd="llm doctor"
  else
    doctor_cmd="DOT_LLM_DIR=$target llm doctor"
  fi
  cat <<EOF

Next steps:
  1. Edit $target/index.md — replace the placeholder components table with
     your project's actual components.
  2. Edit $target/schema.yaml — under meta.apps.values, list one entry per
     component your project ships. Keep platform and meta as reserved.
  3. Run health checks:
       $doctor_cmd

The CLAUDE.md hook ensures every Claude session in this repo loads
$target/index.md automatically (via @import). Open the project in your
client and the framework is wired in.
EOF
}

# --- shared helpers (used by cmd_install and cmd_update) -------------------

# Copy universal llm-* skills (from $SKILLS_SRC) into target/skills/.
# For install (replace=0): skips skills already present (flavor-shipped wins).
# For update (replace=1): always overwrites.
# Opt-in skills (--with) are always copied at the end.
# Args: target replace(0|1) [with_skills...]
_framework_copy_skills() {
  local target="$1" replace="$2"; shift 2
  local with_skills=("$@")

  mkdir -p "$target/skills"

  if [[ -d "$SKILLS_SRC" ]]; then
    local llm_skill clean name
    for llm_skill in "$SKILLS_SRC"/llm-*/; do
      [[ -d "$llm_skill" ]] || continue
      clean="${llm_skill%/}"
      name=$(basename "$clean")
      if [[ "$replace" == "0" && -e "$target/skills/$name" ]]; then
        say "  · skill: $name (flavor-shipped, kept)"
        continue
      fi
      rm -rf "$target/skills/$name"
      cp -R "$clean" "$target/skills/"
      [[ "$replace" == "1" ]] && green "  ↺ skill: $name" || green "  + skill: $name (auto)"
    done
  fi

  local skill
  for skill in "${with_skills[@]+"${with_skills[@]}"}"; do
    rm -rf "$target/skills/$skill"
    cp -R "$SKILLS_SRC/${skill}" "$target/skills/"
    green "  + skill: $skill (opt-in)"
  done
}

# Copy slash commands from $COMMANDS_SRC into parent/.claude/commands/.
# Walks recursively so subdirs (namespaces) are preserved.
# For install (replace=0): skips files already present.
# For update (replace=1): always overwrites.
# Args: parent replace(0|1)
_framework_copy_commands() {
  local parent="$1" replace="$2"
  [[ -d "$COMMANDS_SRC" ]] || return 0

  local cmd_files=() cmd_file
  while IFS= read -r -d '' cmd_file; do
    cmd_files+=("$cmd_file")
  done < <(find "$COMMANDS_SRC" -type f -name '*.md' -print0)
  [[ ${#cmd_files[@]} -eq 0 ]] && return 0

  local cmds_dir="$parent/.claude/commands"
  mkdir -p "$cmds_dir"

  local rel dest slash
  for cmd_file in "${cmd_files[@]}"; do
    rel="${cmd_file#"$COMMANDS_SRC"/}"
    dest="$cmds_dir/$rel"
    slash="${rel%.md}"
    slash="/${slash//\//:}"
    if [[ "$replace" == "0" && -f "$dest" ]]; then
      say "  · ${slash} already present (skip)"
    else
      mkdir -p "$(dirname "$dest")"
      cp "$cmd_file" "$dest"
      [[ "$replace" == "1" ]] && green "  ↺ ${slash}" || green "  + ${slash}"
    fi
  done
}

# List deprecated skills: names in target/skills/ absent from both SKILLS_SRC
# and framework_src/skills/. Prints one name per line.
# Args: target framework_src
_framework_deprecated_skills() {
  local target="$1" framework_src="$2"
  [[ -d "$target/skills" ]] || return 0
  local skill_dir name
  for skill_dir in "$target/skills"/*/; do
    [[ -d "$skill_dir" ]] || continue
    name=$(basename "${skill_dir%/}")
    [[ -d "$SKILLS_SRC/$name" ]] && continue
    [[ -d "$framework_src/skills/$name" ]] && continue
    echo "$name"
  done
}

# List deprecated commands: .md files under parent/.claude/commands/ absent
# from $COMMANDS_SRC. Prints one rel path per line.
# Args: parent
_framework_deprecated_commands() {
  local parent="$1"
  local cmds_dir="$parent/.claude/commands"
  [[ -d "$cmds_dir" ]] || return 0
  [[ -d "$COMMANDS_SRC" ]] || return 0
  local file rel
  while IFS= read -r -d '' file; do
    rel="${file#"$cmds_dir"/}"
    [[ -f "$COMMANDS_SRC/$rel" ]] || echo "$rel"
  done < <(find "$cmds_dir" -type f -name '*.md' -print0)
}

# --- install-private helpers ------------------------------------------------

# Print the dot-llm hook block to stdout. Argument: rel_index (e.g. ".llm/index.md").
_install_print_hook_block() {
  local rel_index="$1"
  cat <<EOF
<!-- BEGIN DOT-LLM-HOOK -->
## \`.llm/\` framework

This project uses the \`.llm/\` framework — a spec-driven, agent-friendly knowledge structure. Whenever you (the LLM) start a session in this repository, **read \`$rel_index\` first**. It carries the schema, the pillars declared for this project, the loading rule for what enters context, and any role definitions present under \`$rel_index\`'s siblings.

@$rel_index
<!-- END DOT-LLM-HOOK -->
EOF
}

_install_wire_claude_md() {
  local parent="$1" target="$2"
  local claude_md="$parent/CLAUDE.md"
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

# List available framework flavors (one per line): "<name>\t<one-line summary>".
_install_list_frameworks() {
  printf '%s\t%s\n' "base" "minimal kernel — rules + meta, no pillars."
  if [[ -d "$FRAMEWORKS_DIR" ]]; then
    local d name
    for d in "$FRAMEWORKS_DIR"/*/; do
      [[ -d "$d" ]] || continue
      name=$(basename "$d")
      [[ "$name" == __* ]] && continue
      local summary=""
      if [[ -f "$d/index.md" ]]; then
        summary=$(awk '
          /^# / { h1=1; next }
          h1 && /^[^[:space:]]/ { print; exit }
        ' "$d/index.md")
      fi
      [[ -z "$summary" ]] && summary="framework flavor"
      [[ ${#summary} -gt 70 ]] && summary="${summary:0:67}..."
      printf '%s\t%s\n' "$name" "$summary"
    done
  fi
}

# List opt-in skills (non-llm-*) for the --with flag.
_install_list_skills() {
  [[ -d "$SKILLS_SRC" ]] || return 0
  local d name desc
  for d in "$SKILLS_SRC"/*/; do
    [[ -d "$d" ]] || continue
    name=$(basename "$d")
    [[ "$name" == llm-* ]] && continue
    [[ -f "$d/SKILL.md" ]] || continue
    desc=$(awk '
      /^---$/ { c++; if (c==2) exit; next }
      c==1 && /^description:/ {
        line=$0
        sub(/^description:[[:space:]]*[>|]?[+-]?[[:space:]]*/, "", line)
        if (length(line) > 0) acc = line
        in_desc = 1
        next
      }
      c==1 && in_desc && /^[[:space:]]+[^[:space:]]/ {
        line=$0; sub(/^[[:space:]]+/, "", line)
        acc = (acc == "" ? line : acc " " line)
        next
      }
      c==1 && in_desc && /^[a-zA-Z]/ { in_desc = 0 }
      END { print acc }
    ' "$d/SKILL.md")
    [[ ${#desc} -gt 70 ]] && desc="${desc:0:67}..."
    printf '%s\t%s\n' "$name" "${desc:-(no description)}"
  done
}

cmd_install_help() {
  cat <<'EOF'
llm install — install a framework flavor into a project's .llm/

Usage:
  llm install [TARGET] [--framework <name>] [--with <skill>...]

Arguments:
  TARGET                 directory to create (default: ./.llm). Refuses to overwrite.

Options:
  --framework <name>     which flavor to install. Default: sdlc-it-project-basic.
                         Available (discovered from frameworks/, including __base/):
EOF
  _install_list_frameworks | awk -F'\t' '{ printf "                           %-26s %s\n", $1, $2 }'
  cat <<'EOF'
  --with <skill>         include an opt-in skill (looked up in skills/<skill>/SKILL.md
                         in the dot-llm checkout). Repeatable.
                         Available (discovered from skills/; `llm-*` skills are
                         auto-installed and don't need --with):
EOF
  _install_list_skills | awk -F'\t' '{ printf "                           %-26s %s\n", $1, $2 }'
  cat <<'EOF'

Auto-installed skills (always copied with the framework, no --with needed):
EOF
  for d in "$SKILLS_SRC"/llm-*/; do
    [[ -d "$d" ]] || continue
    printf '  %s\n' "$(basename "$d")"
  done
  cat <<'EOF'

Examples:
  llm install                                       # default at ./.llm
  llm install --framework base                      # minimal kernel only
  llm install --with git                            # default flavor + git skill
  llm install /path/.llm --framework sdlc-it-project-basic --with git
EOF
}
