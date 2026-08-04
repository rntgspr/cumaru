# cmd_migrate.sh — deliver the current migration instructions to the agent.
#
# Cumaru ships one rolling `migration.md` per release: domains/__base/migration.md
# carries the universal content, and domains/<domain>/migration.md extends it with
# domain nuance when there is any. This command resolves the installed domain,
# strips frontmatter from both, and prints the bodies.
#
# It is READ-ONLY by design. There is no --apply: the LLM executes the migration,
# including the deterministic steps, so that every irreversible decision is
# adjudicated with full context instead of guessed by a script.
#
# Legacy configuration names are resolved here only; runtime v7 uses CONFIG.

cmd_migrate_help() {
  cat <<'EOF'
cumaru migrate — print the current migration instructions for this project

Usage:
  cumaru migrate [--from <source>]

Options:
  --from <source>  Cumaru checkout providing domains/<installed-domain>/
                   (default: the active CLI checkout)

Reads domains/__base/migration.md plus the installed domain's optional
migration.md, strips their frontmatter, and prints the bodies. The document is
never copied into .cumaru/ — it is resolved from the CLI checkout at runtime and
replaced wholesale on every upgrade.

This command performs no migration. It has no --apply. The instructions it
prints are executed by the LLM, which also dispatches the deterministic steps.
Commit or stash before starting: git is the only rollback.
EOF
}

# Prints a Markdown body with any leading YAML frontmatter block removed.
_migrate_strip_frontmatter() {
  awk '
    NR == 1 && $0 == "---" { in_fm = 1; next }
    in_fm && $0 == "---"   { in_fm = 0; started = 1; next }
    in_fm                  { next }
    { if (!started && $0 == "") next; started = 1; print }
  ' "$1"
}

# Resolve the installed domain from config.yaml or the legacy schema.yaml.
_migrate_installed_domain() {
  local domain="" contract=""
  if [[ -f "$CUMARU_DIR/config.yaml" ]]; then
    contract="$CUMARU_DIR/config.yaml"
  elif [[ -f "$CUMARU_DIR/schema.yaml" ]]; then
    contract="$CUMARU_DIR/schema.yaml"
  else
    return 1
  fi
  domain=$(awk '/^domain:[[:space:]]/ {print $2; exit}' "$contract" 2>/dev/null || true)
  [[ -n "$domain" ]] || domain=$(awk '/^flavor:[[:space:]]/ {print $2; exit}' "$contract" 2>/dev/null || true)
  [[ -n "$domain" ]] || return 1
  printf '%s\n' "$domain"
}

cmd_migrate() {
  local from="" arg
  while [[ $# -gt 0 ]]; do
    arg="$1"
    case "$arg" in
      --from)
        [[ -n "${2:-}" ]] || { red "--from requires a source"; return 2; }
        from="$2"; shift 2 ;;
      --from=*) from="${arg#--from=}"; shift ;;
      -h|--help|help) cmd_migrate_help; return 0 ;;
      --apply)
        red "✗ cumaru migrate has no --apply — the LLM executes the printed instructions"
        return 2 ;;
      *) red "unexpected arg: $arg"; cmd_migrate_help; return 2 ;;
    esac
  done

  local source domain base_doc domain_doc
  source="${from:-$SCRIPT_DIR}"
  base_doc="$source/domains/__base/migration.md"
  [[ -f "$base_doc" ]] || { red "✗ no migration.md in $source/domains/__base/"; return 1; }

  if ! domain=$(_migrate_installed_domain); then
    red "✗ no installed .cumaru/config.yaml or legacy schema.yaml — run this inside an adopted project"
    return 1
  fi
  [[ "$domain" == base ]] && domain="__base"
  domain_doc="$source/domains/$domain/migration.md"

  cat <<EOF
# Migration — $domain

> **You (the LLM) execute this.** \`cumaru migrate\` only delivers these
> instructions; it changes nothing and has no \`--apply\`. Dispatch every step
> yourself, including the deterministic commands.
>
> **Commit or stash first.** There is no transactional rollback — the adopter's
> git history is the only safety net.
>
> Steps are detection-first and idempotent: check whether each applies, skip the
> ones that do not, and re-running the whole document must be a no-op. On any
> blocker, STOP and ask rather than guess.

EOF

  _migrate_strip_frontmatter "$base_doc"

  if [[ -f "$domain_doc" && "$domain" != "__base" ]]; then
    printf '\n'
    _migrate_strip_frontmatter "$domain_doc"
  fi
}
