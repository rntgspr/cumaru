# cmd_install.sh — install a domain into a project's .cumaru/.
#
# Each domain is self-contained (its own schema + starter files):
#   --domain base                    → domains/__base/   (minimal kernel)
#   --domain sdlc-full               → domains/sdlc-full/   (default)
#   --domain <other>                 → domains/<other>/  (future domains)
#
# Expects from the entry-point:
#   BASE_DOMAIN_SRC     — path to domains/__base/
#   DOMAINS_DIR         — path to domains/
#   DEFAULT_DOMAIN      — default domain name
#   _resolve_domain_src — function to resolve domain name → source dir
#   SKILLS_SRC          — path to skills/ (opt-in skills sourced via --with)

cmd_install() {
  local target="$CUMARU_DIR"
  local with_skills=()
  local domain="$DEFAULT_DOMAIN"
  local agent="generic"
  local previous_agent=""
  local CUMARU_AGENT_OVERRIDE=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      agent)
        [[ -n "${2:-}" ]] || { red "✗ agent requires one of: none, claude, codex, opencode"; return 2; }
        agent=$(_agent_normalize "$2") || {
          red "✗ unknown agent: $2 (expected none, claude, codex, or opencode)"
          return 2
        }
        shift 2 ;;
      --domain)
        [[ -n "${2:-}" ]] || { red "✗ --domain requires a name (e.g. sdlc-full, base)"; return 2; }
        domain="$2"; shift 2 ;;
      --domain=*)
        domain="${1#--domain=}"; shift ;;
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
        red "unexpected arg: $1"; cmd_install_help; return 2 ;;
    esac
  done

  # Resolve domain → source dir.
  local domain_src
  domain_src=$(_resolve_domain_src "$domain") || return 1
  if [[ ! -d "$domain_src" ]]; then
    red "✗ domain not found at $domain_src"
    return 1
  fi

  if [[ -f "$SCHEMA" ]]; then
    previous_agent=$(_agent_current) || {
      red "✗ existing $SCHEMA has an invalid agent value"
      return 1
    }
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
  if [[ "$agent" == "opencode" ]] && ! command -v jq >/dev/null 2>&1; then
    red "✗ jq is required for the opencode adapter"
    return 1
  fi

  local parent
  parent=$(dirname "$target")
  mkdir -p "$parent"

  # Copy the chosen domain wholesale, then drop the skills/ and commands/
  # subdirs — those are framework-owned artifacts that live exclusively
  # under the selected adapter. The cp -R is kept (atomic, simpler than per-entry
  # filtering); the immediately-after rm -rf is the explicit declaration that
  # none of these subdirs belongs inside the adopter's .cumaru/ tree.
  cp -R "$domain_src" "$target"
  rm -rf "$target/skills" "$target/commands"
  green "✓ installed domain '$domain' to $target"

  # Install framework skills (domain-shipped cumaru-* + universal cumaru-* +
  # opt-ins) into the selected adapter's skill directory.
  CUMARU_AGENT_OVERRIDE="$agent"
  _framework_install_skills "$parent" "$domain_src" "0" "${with_skills[@]+"${with_skills[@]}"}" || return 1

  # Wire the selected agent's native instruction surface.
  _agent_wire_instructions "$parent" "$agent" || return 1

  # Install native slash commands where the selected agent supports them.
  _framework_copy_commands "$parent" "$domain_src" "0" || return 1

  if [[ -n "$previous_agent" && "$previous_agent" != "$agent" ]]; then
    _agent_remove_adapter "$parent" "$previous_agent" "$agent" || return 1
  fi

  # Persist state last so doctor never observes a selected but partial adapter.
  _agent_set "$agent" || return 1
  unset CUMARU_AGENT_OVERRIDE

  cat <<EOF

Next steps:
  1. Edit $target/domain.md — replace the placeholder components table with
     your project's actual components.
  2. Edit $target/schema.yaml — under meta.apps.values, list one entry per
     component your project ships. Keep platform and meta as reserved.
  3. Run health checks:
       cumaru doctor

The '$agent' adapter is active. Open the project in that client to load the
Cumaru instructions, skills, and supported commands.
EOF
}

# --- shared helpers (used by cmd_install and cmd_update) -------------------

# Install framework skills into the active adapter's skill directory.
# Source: the domain's own skills/ subdir — universals live in __base/skills/
# and are mirrored verbatim into every domain (drift-checked at install-script
# time), so the domain dir alone is complete.
# Opt-ins (--with) are sourced from $SKILLS_SRC (top-level skills/).
# Install (replace=0): skip-if-exists for cumaru-*, never clobber adopter
# skills with the same name. Update (replace=1): always overwrite cumaru-*;
# opt-ins are not touched (opt-ins are adopter-owned post-install — update
# never receives a with_skills list).
# Args: parent framework_src replace(0|1) [with_skills...]
_framework_install_skills() {
  local parent="$1" framework_src="$2" replace="$3"; shift 3
  local with_skills=("$@")
  local agent="${CUMARU_AGENT_OVERRIDE:-}"
  [[ -n "$agent" ]] || agent=$(_agent_current) || return 1
  local skills_dir
  skills_dir=$(_agent_skills_dir "$parent" "$agent")
  mkdir -p "$skills_dir"

  local skill_dir name dest
  if [[ -d "$framework_src/skills" ]]; then
    for skill_dir in "$framework_src/skills"/cumaru-*/; do
      [[ -d "$skill_dir" ]] || continue
      name=$(basename "${skill_dir%/}")
      dest="$skills_dir/$name"
      if [[ "$replace" == "0" && -e "$dest" ]]; then
        say "  · $(_agent_rel_path "$parent" "$dest") already present (skip)"
        continue
      fi
      rm -rf "$dest"
      cp -R "${skill_dir%/}" "$dest"
      [[ "$replace" == "1" ]] && green "  ↺ $(_agent_rel_path "$parent" "$dest")" || green "  + $(_agent_rel_path "$parent" "$dest")"
    done
  fi

  local skill
  for skill in "${with_skills[@]+"${with_skills[@]}"}"; do
    rm -rf "$skills_dir/$skill"
    cp -R "$SKILLS_SRC/$skill" "$skills_dir/"
    green "  + $(_agent_rel_path "$parent" "$skills_dir/$skill") (opt-in)"
  done
}

# Remove active-adapter cumaru-* skill dirs that no longer exist
# in the framework domain source. Opt-ins (non-cumaru-* dirs) are never
# touched.
# Args: parent framework_src
_framework_prune_deprecated_cumaru_skills() {
  local parent="$1" framework_src="$2"
  local agent="${CUMARU_AGENT_OVERRIDE:-}"
  [[ -n "$agent" ]] || agent=$(_agent_current) || return 1
  local skills_dir
  skills_dir=$(_agent_skills_dir "$parent" "$agent")
  [[ -d "$skills_dir" ]] || return 0
  local skill_dir name
  for skill_dir in "$skills_dir"/cumaru-*/; do
    [[ -d "$skill_dir" ]] || continue
    name=$(basename "${skill_dir%/}")
    [[ -d "$framework_src/skills/$name" ]] && continue
    rm -rf "$skill_dir"
    yellow "  - removed deprecated: $(_agent_rel_path "$parent" "$skill_dir")"
  done
}

# Drop the legacy <target>/skills/ subdir if a prior install (pre-current
# layout) created one. Skills do not live inside .cumaru/ anymore — they live
# exclusively under an agent's project skills dir. Called by update to migrate
# adopters off the old layout.
# Args: target
_framework_prune_legacy_cumaru_skills() {
  local target="$1"
  [[ -d "$target/skills" ]] || return 0
  rm -rf "$target/skills"
  yellow "  - removed legacy: $target/skills (skills now live in agent project skill dirs)"
}

# Copy slash commands from $framework_src/commands/ into
# the active adapter's command directory. Walks recursively so namespaces are
# preserved. Universal commands live in __base/commands/ and are mirrored
# verbatim into every domain (drift-checked at install-script time), so
# the domain dir alone is complete.
# For install (replace=0): skip-if-exists per file.
# For update (replace=1): always overwrites.
# Args: parent framework_src replace(0|1)
_framework_copy_commands() {
  local parent="$1" framework_src="$2" replace="$3"
  local cmds_src="$framework_src/commands"
  [[ -d "$cmds_src" ]] || return 0

  local cmd_files=() cmd_file
  while IFS= read -r -d '' cmd_file; do
    cmd_files+=("$cmd_file")
  done < <(find "$cmds_src" -type f -name '*.md' -print0)
  [[ ${#cmd_files[@]} -eq 0 ]] && return 0

  local agent="${CUMARU_AGENT_OVERRIDE:-}"
  [[ -n "$agent" ]] || agent=$(_agent_current) || return 1
  local cmds_dir
  cmds_dir=$(_agent_commands_dir "$parent" "$agent")
  [[ -n "$cmds_dir" ]] || return 0
  mkdir -p "$cmds_dir"

  local rel dest slash
  for cmd_file in "${cmd_files[@]}"; do
    rel="${cmd_file#"$cmds_src"/}"
    dest="$cmds_dir/$rel"
    slash="${rel%.md}"
    if [[ "$agent" == "opencode" ]]; then
      slash="/$slash"
    else
      slash="/${slash//\//:}"
    fi
    if [[ "$replace" == "0" && -f "$dest" ]]; then
      say "  · ${slash} already present (skip)"
    else
      mkdir -p "$(dirname "$dest")"
      cp "$cmd_file" "$dest"
      [[ "$replace" == "1" ]] && green "  ↺ ${slash}" || green "  + ${slash}"
    fi
  done
}

# List active-adapter commands that no longer
# exist in the framework domain source. Prints one rel path per line.
# Args: parent framework_src
_framework_deprecated_commands() {
  local parent="$1" framework_src="$2"
  local agent="${CUMARU_AGENT_OVERRIDE:-}"
  [[ -n "$agent" ]] || agent=$(_agent_current) || return 1
  local cmds_dir
  cmds_dir=$(_agent_commands_dir "$parent" "$agent")
  [[ -n "$cmds_dir" ]] || return 0
  local cmds_src="$framework_src/commands"
  [[ -d "$cmds_dir" ]] || return 0
  [[ -d "$cmds_src" ]] || return 0
  local file rel
  while IFS= read -r -d '' file; do
    rel="${file#"$cmds_dir"/}"
    [[ -f "$cmds_src/$rel" ]] || echo "$rel"
  done < <(find "$cmds_dir" -type f -name '*.md' -print0)
}

# --- install-private helpers ------------------------------------------------

_agent_rel_path() {
  local parent="$1" path="$2"
  printf '%s\n' "${path#"$parent"/}"
}

# Print the cumaru hook block to stdout.
# Args: rel_index (e.g. ".cumaru/index.md"); created (1 if install is creating the
# instruction file fresh, 0/absent if appending to a pre-existing file). The `created`
# flag in the BEGIN marker is the provenance signal uninstall uses to decide
# whether it may delete the whole file or must only strip the block.
_install_wire_agent_hook() {
  local parent="$1"
  _agent_wire_markdown_hook "$parent" "generic"
}

# List available domains (one per line): "<name>\t<one-line summary>".
_install_list_domains() {
  printf '%s\t%s\n' "base" "minimal kernel — rules + meta, no pillars."
  if [[ -d "$DOMAINS_DIR" ]]; then
    local d name
    for d in "$DOMAINS_DIR"/*/; do
      [[ -d "$d" ]] || continue
      name=$(basename "$d")
      [[ "$name" == __* ]] && continue
      # Summary comes from the domain's domain.md H1 — NOT index.md, which is the
      # universal kernel (byte-identical across domains) and would yield the same
      # generic line for every domain. domain.md carries the domain's identity.
      local summary=""
      if [[ -f "$d/domain.md" ]]; then
        summary=$(awk '/^# / { sub(/^# /, ""); print; exit }' "$d/domain.md")
      fi
      [[ -z "$summary" ]] && summary="domain"
      [[ ${#summary} -gt 70 ]] && summary="${summary:0:67}..."
      printf '%s\t%s\n' "$name" "$summary"
    done
  fi
}

# List opt-in skills (non-cumaru-*) for the --with flag.
_install_list_skills() {
  [[ -d "$SKILLS_SRC" ]] || return 0
  local d name desc
  for d in "$SKILLS_SRC"/*/; do
    [[ -d "$d" ]] || continue
    name=$(basename "$d")
    [[ "$name" == cumaru-* ]] && continue
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
cumaru install — install a domain into a project's .cumaru/

Usage:
  cumaru install [agent <none|claude|codex|opencode>] [--domain <name>] [--with <skill>...]

Options:
  --domain <name>        which domain to install. Default: sdlc-full.
                         Available (discovered from domains/, including __base/):
EOF
  _install_list_domains | awk -F'\t' '{ printf "                           %-26s %s\n", $1, $2 }'
  cat <<'EOF'
  --with <skill>         include an opt-in skill (looked up in skills/<skill>/SKILL.md
                         in the dot-llm checkout). Repeatable.
                         Available (discovered from skills/; `cumaru-*` skills are
                         auto-installed and don't need --with):
EOF
  _install_list_skills | awk -F'\t' '{ printf "                           %-26s %s\n", $1, $2 }'
  cat <<'EOF'

Without `agent`, Cumaru keeps the generic `.agents/` integration and writes
`agent: null`. A selected agent uses its best native project surfaces.

Auto-installed skills (shipped by every domain; sourced from domains/__base/skills/):
EOF
  for d in "$BASE_DOMAIN_SRC"/skills/cumaru-*/; do
    [[ -d "$d" ]] || continue
    printf '  %s\n' "$(basename "$d")"
  done
  cat <<'EOF'

Examples:
  cumaru install                         generic `.agents/` integration
  cumaru install agent claude            CLAUDE.md + .claude/
  cumaru install agent codex             AGENTS.md + .agents/skills/
  cumaru install agent opencode          opencode.json + .opencode/commands/
  cumaru install                                       # default domain at .cumaru/
  cumaru install --with git                            # default domain + git skill
  cumaru install --domain base                         # minimal kernel only
  cumaru install --domain sdlc-full --with git
EOF
}
