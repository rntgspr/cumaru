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
    reconcile [<pillar>] [--apply]          align each pillar's index table with disk (schema-driven)
    sync [<path>] [--from <src>] [--keep-prose] [--apply]  steady-state update of .llm/ from the framework source
                                            (<path> = a dir or single file under .llm/; version mismatch ⇒ migration, see llm-cli skill)

  help                                      this message

Working on `specs/` (bootstrap, deepen, consolidate) is LLM-driven in v3 — no
subcommand; use the `llm-specs` skill.

Examples
  llm                                  doctor ./.llm (default)
  llm install                          install the starter to ./.llm
  llm install path/to/.llm             install the starter to a custom path
  llm install --with git               install + unlock mutating git commands
  llm intake JET-1234                  pull a ticket into intake
  llm archive JET-1234                 prepare a plan for closure
  llm archive finalize JET-1234        finalize after the LLM absorbs deltas
  llm reconcile                        diff every pillar index vs disk
  llm reconcile --apply                rewrite drifted index tag bodies
  DOT_LLM_DIR=path/to/.llm llm         operate on a non-default tree
EOF
}
