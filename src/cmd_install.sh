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

  # Copy the chosen flavor wholesale.
  cp -R "$framework_src" "$target"

  green "✓ installed framework '$flavor' to $target"

  # Auto-install every UNIVERSAL `llm-*` skill from the dot-llm checkout's
  # top-level skills/ — these are the operating skills (doctor, install, tag,
  # flow, sync) every flavor needs. Flavor-specific skills (e.g. `llm-intake`
  # for sdlc flavors) live under `frameworks/<flavor>/skills/` and are already
  # copied by the wholesale `cp -R "$framework_src" "$target"` above.
  #
  # Skip-if-exists protects flavor overrides: if a flavor ships its own version
  # of a universal skill (or its own `llm-intake`), the wholesale copy got there
  # first and we don't clobber it.
  #
  # NB: strip the glob's trailing slash — BSD `cp -R src/ dest/` copies CONTENTS
  # (each iteration would overwrite the previous), not the dir as a subdir.
  mkdir -p "$target/skills"
  if [[ -d "$SKILLS_SRC" ]]; then
    local llm_skill clean name
    for llm_skill in "$SKILLS_SRC"/llm-*/; do
      [[ -d "$llm_skill" ]] || continue
      clean="${llm_skill%/}"
      name=$(basename "$clean")
      if [[ -e "$target/skills/$name" ]]; then
        say "  · skill: $name (flavor-shipped, kept)"
        continue
      fi
      cp -R "$clean" "$target/skills/"
      green "  + skill: $name (auto)"
    done
  fi

  # Apply opt-in skills (--with <name>) on top.
  for skill in "${with_skills[@]+"${with_skills[@]}"}"; do
    cp -R "$SKILLS_SRC/${skill}" "$target/skills/"
    green "  + skill: $skill (opt-in)"
  done

  # Wire CLAUDE.md so the LLM auto-loads .llm/index.md on every session.
  _install_wire_claude_md "$parent" "$target"

  # Install slash commands into $parent/.claude/commands/.
  _install_wire_claude_commands "$parent"

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

# Copy slash commands from $COMMANDS_SRC into $parent/.claude/commands/.
# Walks recursively so subdirs (namespaces) are preserved: a source file
# at commands/llm/sync.md becomes <parent>/.claude/commands/llm/sync.md,
# exposing the slash command as /llm:sync. Idempotent: skips files
# already present at the destination.
_install_wire_claude_commands() {
  local parent="$1"
  [[ -d "$COMMANDS_SRC" ]] || return 0

  # Single find pass: collect into an array (null-safe), then act.
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
    if [[ -f "$dest" ]]; then
      say "  · ${slash} command already present (skip)"
    else
      mkdir -p "$(dirname "$dest")"
      cp "$cmd_file" "$dest"
      green "  + ${slash} command added at $dest"
    fi
  done
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

# List available framework flavors (one per line): "<name>\t<one-line summary>".
# Reads from disk so adding a new flavor never requires touching the help text.
# `__base/` is exposed as the literal `base` (hardcoded first row); other dirs
# under frameworks/ are listed by their on-disk name. Dirs prefixed with `__`
# are skipped as "internal" (the convention for kernel / non-flavor entries).
_install_list_frameworks() {
  printf '%s\t%s\n' "base" "minimal kernel — rules + meta, no pillars."
  if [[ -d "$FRAMEWORKS_DIR" ]]; then
    local d name
    for d in "$FRAMEWORKS_DIR"/*/; do
      [[ -d "$d" ]] || continue
      name=$(basename "$d")
      [[ "$name" == __* ]] && continue   # skip kernel / internal entries
      # Try first non-blank line after the H1 in <flavor>/index.md as the summary.
      local summary=""
      if [[ -f "$d/index.md" ]]; then
        summary=$(awk '
          /^# / { h1=1; next }
          h1 && /^[^[:space:]]/ { print; exit }
        ' "$d/index.md")
      fi
      [[ -z "$summary" ]] && summary="framework flavor"
      # Truncate long descriptions for help layout (≈70 chars).
      [[ ${#summary} -gt 70 ]] && summary="${summary:0:67}..."
      printf '%s\t%s\n' "$name" "$summary"
    done
  fi
}

# List available skills (one per line): "<name>\t<description from frontmatter>".
# List opt-in skills (non-`llm-*`) for the `--with` flag. `llm-*` skills are
# auto-installed by cmd_install — they don't appear here.
_install_list_skills() {
  [[ -d "$SKILLS_SRC" ]] || return 0
  local d name desc
  for d in "$SKILLS_SRC"/*/; do
    [[ -d "$d" ]] || continue
    name=$(basename "$d")
    [[ "$name" == llm-* ]] && continue   # auto-installed; skip from --with listing
    [[ -f "$d/SKILL.md" ]] || continue
    # Extract the `description:` field from frontmatter. Handles inline scalars
    # AND multiline `>` / `|` forms (concatenates indented continuation lines).
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
    # Truncate long descriptions for help layout (≈70 chars).
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
