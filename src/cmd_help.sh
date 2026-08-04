# cmd_help.sh — top-level `cumaru help` text, plus per-topic pages.

cmd_help() {
  local topic="${1:-}"

  if [[ -n "$topic" ]]; then
    case "$topic" in
      domains|domain)
        _cmd_help_domains
        return 0
        ;;
      *)
        red "Unknown help topic: $topic" >&2
        red "Available topics: domains" >&2
        return 1
        ;;
    esac
  fi

  cat <<'EOF'
cumaru — CLI for the .cumaru/ framework

Subcommands

  Setup
    install [agent <name>] [--domain <name>] [--with <skill>...]  install core + agent adapter
    uninstall [--yes]                       reverse install: remove .cumaru/, agent instructions, commands
    doctor [--quiet]                        run health checks on the .cumaru/ tree (default subcommand)

  Marker blocks
    tag                                      list the tags declared in config.yaml
    tag all [--body|--rows|--tables|--prose|--mixed]  list tag blocks in every .cumaru/*.md
    tag <file>                               audit a file's blocks against the schema
    tag get <file> <tag>                     print the <!-- cumaru:NAME --> block body
    tag set <file> <tag>                     replace the block body (stdin)

  Spec coverage
    coverage [--refs|--gaps|--rows] [--strict]  report which repository source files are
                                            referenced by the specification pillar

  Navigation
    tree [<path>] [--deep] [--rows] [--pillars <names>] [--domain <name>]
                                            list filtered filesystem-backed candidates and summaries
    map [<path>] [--rows] [--pillars <names>] [--domain <name>]
                                            list level-two Markdown headings with source lines

  State maintenance
    update [<path>] [--from <src>] [--apply]  update .cumaru/ files from source
                                            (<path> = a dir or single file under .cumaru/; major-version apply is blocked)
    update agent [<name>] [--apply|--clear]  install or clear one/all agent instruction sets
    update skills|commands [<name>] [--apply|--clear]  install or clear explicit adapter artifacts
    upgrade                                 update the cumaru tool itself (re-runs the install script; replaces ~/.cumaru)
    flow <src> <verb> [<dst>]               safe file ops inside .cumaru/ (verbs: move | copy | create | remove)

  Migration
    migrate [--from <src>]                  print the current migration instructions (read-only; the LLM executes them)

help [<topic>]                            this message; `help domains` lists available domains

Examples
  cumaru                               doctor ./.cumaru (default)
  cumaru help domains                  list installable domains
  cumaru install                       install the starter to ./.cumaru
  cumaru install agent opencode        install with OpenCode-native integration
  cumaru update agent codex --apply    install Codex artifacts
  cumaru update agent --clear          clear every Cumaru adapter artifact
  cumaru install --with git            install + unlock mutating git commands
  cumaru doctor                        validates navigation, summaries, tags, and hook wiring
  cumaru flow plans/AAA-1234/delta-draft.md move archive/AAA-1234/delta.md
EOF
}

# `cumaru help domains` — list every installable domain with its one-line
# summary. Same discovery as `cumaru install --help` (via _install_list_domains);
# the standalone `cumaru domains` subcommand was retired 2026-08-08.
_cmd_help_domains() {
  cat <<'EOF'
Available domains (install one with `cumaru install --domain <name>`):

EOF
  _install_list_domains | awk -F'\t' '{ printf "  %-22s %s\n", $1, $2 }'
}
