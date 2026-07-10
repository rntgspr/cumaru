# cmd_help.sh — top-level `cumaru help` text.

cmd_help() {
  cat <<'EOF'
cumaru — CLI for the .cumaru/ framework

Subcommands

  Setup
    install [--domain <name>] [--with <skill>...]  install a domain at .cumaru/
    uninstall [--yes]                       reverse install: remove .cumaru/, agent hooks, commands
    domains                                 list available domains
    doctor [--quiet]                        run health checks on the .cumaru/ tree (default subcommand)

  Ticket lifecycle
    intake <KEY> [--tracker <name>]         fetch a tracker issue, mirror under .cumaru/intake/<KEY>/ (jira | linear | clickup)

  Marker blocks
    tag                                      list the tags declared in schema.yaml
    tag all [--body|--rows|--tables|--prose|--mixed]  list tag blocks in every .cumaru/*.md
    tag <file>                               audit a file's blocks against the schema
    tag get <file> <tag>                     print the <!-- cumaru:NAME --> block body
    tag set <file> <tag>                     replace the block body (stdin)

  Spec coverage
    coverage [--refs|--gaps|--rows] [--strict]  report which repository source files are
                                            referenced by the specification pillar

  State maintenance
    update [<path>] [--from <src>] [--keep-prose] [--apply]  update .cumaru/ files, skills, hooks, and slash commands from source
                                            (<path> = a dir or single file under .cumaru/; version mismatch is a migration review)
    upgrade                                 update the cumaru tool itself (re-runs the install script; replaces ~/.cumaru)
    flow <src> <verb> [<dst>]               safe file ops inside .cumaru/ (verbs: move | copy | create | remove)

  Migration
    migrate [--apply]                       migrate a project tree from llm (legacy) to cumaru

  help                                      this message

Examples
  cumaru                               doctor ./.cumaru (default)
  cumaru install                       install the starter to ./.cumaru
  cumaru install --with git            install + unlock mutating git commands
  cumaru intake AAA-1234               pull a tracker issue into intake
  cumaru doctor                        includes the orphan check (tables vs disk)
  cumaru flow plans/AAA-1234/delta-draft.md move archive/AAA-1234/delta.md
EOF
}
