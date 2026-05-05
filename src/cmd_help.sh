# cmd_help.sh — top-level `llm help` text.

cmd_help() {
  cat <<EOF
llm — CLI for the .llm/ framework

Subcommands

  Setup
    install [TARGET] [--with <skill>...]    install the framework starter (default: ./.llm)
    validate [--quiet]                      validate the .llm/ tree (default subcommand)

  Ticket lifecycle
    intake <JIRA-KEY>                       fetch a Jira issue, mirror under .llm/intake/
    archive <PLAN-ID>                       close a plan: prepare archive entry + work file
    archive finalize <PLAN-ID>              remove the plan tree after the LLM absorbs deltas

  State maintenance
    regen index [pillar]                    regenerate shallow pillar indexes (default: all 5)
    regen <JIRA-KEY>                        chain-check a ticket across all pillars
    specs bootstrap [--path <dir>] [--apply]  light pass: discover areas, write bootstrap.md per area
    specs deep <area> [--topic <slug>] [--apply]  deep pass: append discovery section to bootstrap.md
    specs consolidate <area> [--apply]      compact a spec area by absorbing its deltas
    framework sync [<filter>] [--from <src>] [--apply]
                                            update .llm/ from a fresh framework source
                                            (filter ∈ intake/plans/archive/specs/exploring/roles/templates/reviews)

  Diagnostics & tooling
    doctor                                  aggregate health checks across the tree
    update [--ref <branch|tag>]             update the llm CLI itself (git pull or DOT_LLM_ROOT)
    help                                    this message

Examples
  llm                                  validate ./.llm (default)
  llm install                          install the starter to ./.llm
  llm install path/to/.llm             install the starter to a custom path
  llm install --with git               install + unlock mutating git commands
  llm intake JET-1234                  pull a ticket into intake
  llm archive JET-1234                 prepare a plan for closure
  llm archive finalize JET-1234        finalize after the LLM absorbs deltas
  llm regen index                      regenerate all shallow indexes
  llm regen JET-1234                   chain-check the ticket
  llm doctor                           run all health checks
  DOT_LLM_DIR=path/to/.llm llm         operate on a non-default tree
EOF
}
