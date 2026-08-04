```



▄████ ██ ██ ███▄███▄  ▀▀█▄ ████▄ ██ ██
██    ██ ██ ██ ██ ██ ▄█▀██ ██ ▀▀ ██ ██
▀████ ▀██▀█ ██ ██ ██ ▀█▄██ ██    ▀██▀█


```

# `.cumaru/` framework

Cumaru is a structured context-driven framework for AI-assisted work.

It gives a text-based project a durable, navigable knowledge layer: the
filesystem is the structural source of truth, concise summaries make selective
loading possible, and domain workflows separate durable knowledge from
transient work.

It is useful for software delivery, infrastructure, QA, research, design
systems, and custom domains. Specs are one possible durable artifact; they are
not the boundary of the framework.

> **Load only the context that is relevant. Keep durable project knowledge discoverable.**

## Why Cumaru

AI agents do not need the whole repository in context. They need a reliable way
to discover what matters for the task at hand.

Cumaru makes that discovery explicit:

- Every non-hidden directory has an `index.md` that explains its purpose and rules.
- Every Markdown file has a concise `summary:` for relevance-based selection.
- `cumaru tree` projects filesystem candidates without loading their full bodies.
- The agent starts shallow, follows relevant summaries and semantic links, and
  only then reads deeper material.
- Plans, explorations, and archive entries are transient; the durable pillar
  records what is true now.

This is not a giant prompt and not a flat collection of notes. It is an
operational memory system that stays close to the project it describes.

## The model

The `.cumaru/` directory is the project's knowledge layer:

```text
.cumaru/
├── index.md      framework kernel and loading rule
├── domain.md     domain workflow and project-specific context
├── config.yaml   domain contract
├── roles/        agent role definitions
├── templates/    entity templates
└── <pillar>/     domain-defined areas of knowledge and work
    ├── index.md
    └── …
```

`config.yaml` defines the domain contract: pillars, frontmatter, semantic tags,
and entity shapes. The filesystem defines the current structure. `cumaru tree`
bridges both by listing shallow candidates and their summaries.

Semantic tags remain adopter-owned. They describe relationships such as
code references, touched files, components, and other domain facts; they never
duplicate the directory inventory.

## Domains

Cumaru ships self-contained domains. Install one domain per project; domains do
not compose.

| Domain | Durable knowledge | Workflow focus |
|---|---|---|
| `sdlc-full` *(default)* | `specs/` | Intake, issues, plans, exploration, archive, and software delivery |
| `sdlc-light` | `specs/` | A lean plan → spec lifecycle |
| `iac-basic` | `topology/`, `runbooks/` | Infrastructure changes, apply-order dependencies, and operations |
| `qa-basic` | `coverage/`, `standards/` | Test strategy and coverage |
| `vault-memory` | `memories/` | Personal or team memory as a typed graph |
| `base` | Custom | Minimal kernel for a new domain |

A music-production domain could use the same model: durable pillars for sonic
identity, arrangement, mix decisions, and references; transient areas for
sketches, experiments, and session notes. Cumaru supplies the navigation and
lifecycle model, not a fixed vocabulary.

## Install

Cumaru requires Bash, cURL, Git, `jq`, and [Mike Farah `yq` v4](https://github.com/mikefarah/yq).
The Python program also named `yq` is incompatible.

| Tool | Used for |
|---|---|
| Bash | CLI and installed agent hooks |
| cURL | Remote installer |
| Git | Installer, upgrades, and source coverage |
| `jq` | JSON tracker payloads and hook configuration |
| Mike Farah `yq` v4 | Schema and Markdown frontmatter parsing |

```bash
# macOS prerequisites
brew install git jq yq

# Install the CLI
curl -fsSL https://pixelpunk.works/cumaru/install.sh | bash
```

The installer places the tool at `~/.cumaru` and links `cumaru` into
`~/.local/bin`. `cumaru upgrade` replaces that checkout wholesale; use it only
when intentionally updating the CLI itself.

Inside a project:

```bash
cumaru install                                      # default: sdlc-full
cumaru install agent codex                          # Codex adapter
cumaru install agent claude                          # Claude adapter
cumaru install agent opencode                        # OpenCode adapter
cumaru install --domain iac-basic                    # infrastructure workflow
cumaru install --domain vault-memory                 # memory-vault workflow
cumaru install --domain base                         # build a custom domain
cumaru install --with git                            # opt-in git mutation skill
```

See [installation details](docs/install.md) and the [agent adapter matrix](docs/agent-adapters.md).

## How an agent navigates a project

```text
index.md → domain.md → cumaru tree .
                         ↓
                select relevant summaries
                         ↓
              read selected files or directories
                         ↓
          repeat only where the task requires it
```

This keeps structure deterministic while relevance remains a judgment call. An
empty semantic relation does not prove isolation: for cross-cutting work, the
agent expands relevant branches, inspects selected code-reference tags, and
stops when new candidates add no relevant concern.

Read the [architecture](docs/architecture.md) and [`cumaru tree`](docs/tree.md)
documentation for the complete traversal contract.

## Core commands

| Command | Purpose |
|---|---|
| `cumaru doctor` | Validate navigation, summaries, retained references, tools, and the selected agent adapter |
| `cumaru install` | Install a domain and one agent adapter |
| `cumaru tree` | List filesystem-backed candidates and their summaries |
| `cumaru tag` | Inspect or update config-declared semantic tags |
| `cumaru flow` | Perform guarded file operations inside `.cumaru/` |
| `cumaru coverage` | Report source files covered by durable-specification references |
| `cumaru update` | Transactionally refresh framework content at the installed integer version |
| `cumaru migrate` | Print the current read-only, LLM-executed migration instructions |
| `cumaru upgrade` | Replace the CLI checkout and verify distribution kernel integrity |
| `cumaru uninstall --yes` | Remove Cumaru-owned project artifacts |

Run `cumaru help` (or `cumaru help domains` to list installable domains) or `cumaru <command> --help` for full usage.

## Skills and adapters

Cumaru installs native project artifacts for Generic, Claude, Codex, and
OpenCode. The selected adapter receives durable instructions, the appropriate
skills, supported commands, and a session-start candidate projection where the
client supports it.

Universal skills cover health checks, updates, summary curation, and
specification-to-code references. Domains add workflows such as planning,
exploration, intake, topology, coverage, and memory distillation. Opt-in skills
provide tool-specific mechanics such as Git, Terraform, Pulumi, and test
runners.

The [agent adapter documentation](docs/agent-adapters.md) is the canonical
artifact matrix. The [installation guide](docs/install.md) lists every shipped
domain, skill, and command.

## Versioning and updates

Each installed tree has an integer framework version that acts as a migration
boundary. `cumaru update --apply` transactionally refreshes framework-owned
content only when source and local versions match, while preserving
adopter-owned tag bodies and local-only files.

For major changes, `cumaru migrate` prints a rolling migration document. The
command is read-only; the LLM performs the documented, detection-first steps.
Migration has no transactional rollback. Require a clean affected worktree and
tracked `.cumaru/`, or explicitly accept a filesystem backup before execution.

Read [updates](docs/update.md), [migration](docs/migrate.md), and
[doctor](docs/doctor.md) before changing an existing installation.

## Documentation

- [Architecture](docs/architecture.md)
- [Install](docs/install.md)
- [Agent adapters](docs/agent-adapters.md)
- [`cumaru tree`](docs/tree.md)
- [`cumaru doctor`](docs/doctor.md)
- [`cumaru coverage`](docs/coverage.md)
- [`cumaru tag`](docs/tag.md)
- [`cumaru flow`](docs/flow.md)
- [`cumaru update`](docs/update.md)
- [`cumaru migrate`](docs/migrate.md)
- [`cumaru uninstall`](docs/uninstall.md)
