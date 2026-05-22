# cmd_help.sh — top-level `llm help` text.

cmd_help() {
  cat <<'EOF'
llm — CLI for the .llm/ framework

Subcommands

  Setup
    install [TARGET] [--with <skill>...]    install the framework starter (default: ./.llm)
    uninstall [TARGET] [--yes]              reverse install: remove .llm/, CLAUDE.md hook, commands
    doctor [--quiet]                        run health checks on the .llm/ tree (default subcommand)

  Ticket lifecycle
    intake <JIRA-KEY>                       fetch a Jira issue, mirror under .llm/intake/
    archive <PLAN-ID>                       close a plan: prepare archive entry + work file
    archive finalize <PLAN-ID>              remove the plan tree after the LLM absorbs deltas

  Marker blocks
    tag                                      list the tags declared in schema.yaml
    tag <file>                               audit a file's blocks against the schema
    tag get <file> <tag>                     print the <!-- llm:NAME --> block body
    tag set <file> <tag>                     replace the block body (stdin)

  State maintenance
    regen index [pillar]                    regenerate shallow pillar indexes (default: all 5)
    regen <JIRA-KEY>                        chain-check a ticket across all pillars
    specs bootstrap [--path <dir>] [--apply]  light pass: discover areas, write bootstrap.md per area
    specs deep <area> [--topic <slug>] [--apply]  deep pass: append discovery section to bootstrap.md
    specs consolidate <area> [--apply]      compact a spec area by absorbing its deltas
    sync [<path>] [--from <src>] [--keep-prose] [--apply]  steady-state update of .llm/ from the framework source
                                            (<path> = a dir or single file under .llm/; version mismatch ⇒ migration, see llm-cli skill)

  help                                      this message

Examples
  llm                                  doctor ./.llm (default)
  llm install                          install the starter to ./.llm
  llm install path/to/.llm             install the starter to a custom path
  llm install --with git               install + unlock mutating git commands
  llm intake JET-1234                  pull a ticket into intake
  llm archive JET-1234                 prepare a plan for closure
  llm archive finalize JET-1234        finalize after the LLM absorbs deltas
  llm regen index                      regenerate all shallow indexes
  llm regen JET-1234                   chain-check the ticket
  DOT_LLM_DIR=path/to/.llm llm         operate on a non-default tree
EOF
}
