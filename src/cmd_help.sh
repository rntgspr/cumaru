# cmd_help.sh — top-level `cumaru help` text.

cmd_help() {
  cat <<'EOF'
cumaru — CLI for the .cumaru/ framework

Subcommands

  Setup
    install [agent <name>] [--domain <name>] [--with <skill>...]  install core + agent adapter
    uninstall [--yes]                       reverse install: remove .cumaru/, agent instructions, commands
    domains                                 list available domains
    doctor [--quiet]                        run health checks on the .cumaru/ tree (default subcommand)

  Ticket lifecycle
    intake <KEY> [--tracker <name>]         fetch a tracker issue at the schema-declared intake path (jira | linear | clickup)

  Marker blocks
    tag                                      list the tags declared in schema.yaml
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

  State maintenance
    update [<path>] [--from <src>] [--keep-prose] [--apply]  update .cumaru/ files, skills, and slash commands from source
                                            (<path> = a dir or single file under .cumaru/; major-version apply is blocked)
    update agent <name> [--apply]            dry-run or switch the native agent adapter
    upgrade                                 update the cumaru tool itself (re-runs the install script; replaces ~/.cumaru)
    flow <src> <verb> [<dst>]               safe file ops inside .cumaru/ (verbs: move | copy | create | remove)

  Migration
    migrate [--apply]                       migrate legacy llm naming to cumaru
    migrate v6 [--from <src>] [--apply]     transactionally migrate framework v5 to v6

  help                                      this message

Examples
  cumaru                               doctor ./.cumaru (default)
  cumaru install                       install the starter to ./.cumaru
  cumaru install agent opencode        install with OpenCode-native integration
  cumaru update agent codex            preview an adapter switch
  cumaru update agent codex --apply    apply an adapter switch
  cumaru install --with git            install + unlock mutating git commands
  cumaru intake AAA-1234               pull a tracker issue into intake
  cumaru doctor                        validates navigation, summaries, tags, and hook wiring
  cumaru flow plans/AAA-1234/delta-draft.md move archive/AAA-1234/delta.md
EOF
}
