# cmd_bootstrap.sh — deliver the post-install bootstrap steps to the agent.
#
# Each domain may ship a source-only `bootstrap.md` at its root; the universal
# steps live in domains/__base/bootstrap.md. Like `cumaru migrate`, this command
# resolves the installed domain, strips frontmatter, and prints base then domain
# bodies. It is READ-ONLY: the LLM asks the user and writes the answers.
# Reuses _migrate_strip_frontmatter and _migrate_installed_domain.

cmd_bootstrap_help() {
  cat <<'EOF_HELP'
cumaru bootstrap — print the post-install bootstrap steps for this project

Usage:
  cumaru bootstrap [--from <source>]

Options:
  --from <source>  Cumaru checkout providing domains/<installed-domain>/
                   (default: the active CLI checkout)

Reads domains/__base/bootstrap.md plus the installed domain's optional
bootstrap.md, strips their frontmatter, and prints the bodies. The document is
never copied into .cumaru/; it is resolved from the CLI checkout at runtime.

This command writes nothing. The LLM executes the printed steps, asking the
user for every answer.
EOF_HELP
}

# Prints the base and installed-domain bootstrap bodies; fails without writes.
cmd_bootstrap() {
  local from="" arg
  while [[ $# -gt 0 ]]; do
    arg="$1"
    case "$arg" in
      --from)
        [[ -n "${2:-}" ]] || { red "--from requires a source"; return 2; }
        from="$2"; shift 2 ;;
      --from=*) from="${arg#--from=}"; shift ;;
      -h|--help|help) cmd_bootstrap_help; return 0 ;;
      *) red "unexpected arg: $arg"; cmd_bootstrap_help; return 2 ;;
    esac
  done

  local source domain base_doc domain_doc
  source="${from:-$SCRIPT_DIR}"
  base_doc="$source/domains/__base/bootstrap.md"
  [[ -f "$base_doc" ]] || { red "✗ no bootstrap.md in $source/domains/__base/"; return 1; }

  if ! domain=$(_migrate_installed_domain); then
    red "✗ no installed .cumaru/config.yaml — run this inside an adopted project"
    return 1
  fi
  [[ "$domain" == base ]] && domain="__base"
  [[ -d "$source/domains/$domain" ]] || {
    red "✗ unknown domain '$domain': no $source/domains/$domain/"
    return 1
  }
  domain_doc="$source/domains/$domain/bootstrap.md"

  printf '# Bootstrap — %s\n\n' "$domain"
  _migrate_strip_frontmatter "$base_doc"

  [[ "$domain" == "__base" ]] && return 0
  printf '\n'
  if [[ -f "$domain_doc" ]]; then
    _migrate_strip_frontmatter "$domain_doc"
  else
    printf '> Domain `%s` ships no bootstrap.md; only the universal steps apply.\n' "$domain"
  fi
}
