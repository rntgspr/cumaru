```



▄████ ██ ██ ███▄███▄  ▀▀█▄ ████▄ ██ ██
██    ██ ██ ██ ██ ██ ▄█▀██ ██ ▀▀ ██ ██
▀████ ▀██▀█ ██ ██ ██ ▀█▄██ ██    ▀██▀█


```

# `.cumaru/` framework

Cumaru is a structured context-driven framework for AI-assisted work.

Use the compiled `cumaru` CLI to install a project knowledge layer, discover
relevant content, and run the framework's commands. No Rust toolchain or Python
installation is required to use the binary.

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
- Plans and explorations are transient; the durable pillar
  records what is true now.

This is not a giant prompt and not a flat collection of notes. It is an
operational memory system that stays close to the project it describes.

## Install the CLI

Use the precompiled binary for your platform. The download installer selects
macOS or Linux and ARM64 or x86_64, installs `cumaru` in `/usr/local/bin`, and
may request sudo for that destination.

Download the compiled assets from [GitHub Releases](https://github.com/rntgspr/cumaru/releases),
or use the installer below. Linux ARM64 requires FP16 CPU instruction support.

```bash
curl -fsSL https://raw.githubusercontent.com/rntgspr/cumaru/main/rust/install.sh | bash
cumaru --version
cumaru help
```

The installer needs Bash, cURL, and Git. Source-reading commands use cURL;
coverage and release checks use Git. Ordinary Markdown navigation and ranking
need no runtime jq, yq, rg, Python, server, or GPU.

Contributing or running a checkout locally? See [HOW_TO_DEV.md](HOW_TO_DEV.md)
for repository setup, architecture, compilation, and verification.

## Domains

Cumaru ships self-contained domains. Install one domain per project; domains do
not compose.

| Domain | Durable knowledge | Workflow focus |
|---|---|---|
| `sdlc-full` | `specs/` | Intake, issues, plans, exploration, and software delivery |
| `design-as-code` | `specs/`, `assets/` | Briefs, research, concepts, reviewed design evidence, and direct absorption |
| `sdlc-light` | `specs/` | A lean plan → spec lifecycle |
| `iac-basic` | `topology/`, `runbooks/` | Infrastructure changes, apply-order dependencies, and operations |
| `qa-basic` | `coverage/`, `standards/` | Test strategy and coverage |
| `vault-memory` | `memories/` | Personal or team memory as a typed graph |
| `focus` | `directives/`, `threads/`, `outcomes/` | Priority directives over captured work threads and their results |
| `base` *(default)* | Custom | Minimal kernel for a new domain |

A music-production domain could use the same model: durable pillars for sonic
identity, arrangement, mix decisions, and references; transient areas for
sketches, experiments, and session notes. Cumaru supplies the navigation and
lifecycle model, not a fixed vocabulary.

## Start a project

Inside your project directory, choose a domain and agent adapter:

```bash
cumaru install                                      # default: base
cumaru install agent codex                          # Codex adapter
cumaru install agent claude                         # Claude adapter
cumaru install agent opencode                        # OpenCode adapter
cumaru install --domain iac-basic                    # infrastructure workflow
cumaru install --domain vault-memory                 # memory-vault workflow
cumaru install --domain focus                        # directive-driven threads and outcomes
cumaru install --domain base                         # build a custom domain
cumaru update skills codex --with git --apply         # add an opt-in after adoption
```

Install creates `.cumaru/` and the selected agent artifacts. Run `cumaru doctor`
to check the installation and `cumaru bootstrap` for the domain's post-install
steps. An existing installation is refreshed with `cumaru update`, not reinstalled.

## Find relevant knowledge

```bash
cumaru tree
cumaru context "how are refresh tokens rotated?"
cumaru map
```

`context` returns file paths and scores without generating text. It works with
the lightweight scorer immediately; an optional encoder can improve semantic
matching. Install a supported model explicitly:

```bash
cumaru model list
cumaru model push bge-micro-v2
```

Models live under `~/.cumaru/<name>/`, outside the binary and project knowledge.
After download, queries work offline. See [context](docs/context.md) and
[model management](docs/model.md) for limits and score interpretation.

## Core commands

| Command | Purpose |
|---|---|
| `cumaru install` | Install a domain and an explicit agent-adapter target |
| `cumaru uninstall` | Remove Cumaru-owned project and shared adapter artifacts under explicit confirmation |
| `cumaru doctor` | Validate structural health and discover complete agent instructions; also the default command |
| `cumaru tag` | Inspect or update config-declared semantic tags |
| `cumaru coverage` | Report source files covered by durable-specification references |
| `cumaru tree` | List filesystem-backed candidates and their summaries |
| `cumaru map` | List literal H1-H6 headings with markers and source lines under a selected scope |
| `cumaru context "query"` | Rank local Markdown offline with a cached encoder or lightweight fallback; [guide](docs/context.md) |
| `cumaru model list` / `cumaru model push <name>` | Read the closed GitHub catalog or download an optional model into `~/.cumaru/<name>/`; [guide](docs/model.md) |
| `cumaru fs` | Perform guarded file operations inside `.cumaru/` |
| `cumaru update` | Preview or directly refresh framework content at the installed integer version |
| `cumaru upgrade` | Replace the native binary; `--check` only compares build identity with the latest GitHub tag |
| `cumaru migrate` | Print the current read-only, LLM-executed migration instructions |
| `cumaru bootstrap` | Print the read-only post-install bootstrap steps for the installed domain |
| `cumaru version` | Print binary identity and installed/latest domain config version and drift against main HEAD; read-only |
| `cumaru help` | Show the complete command catalog |
| `cumaru help domains` | List installable domains; this is not a `domains` subcommand |

Run `cumaru help` (or `cumaru help domains` to list installable domains) or `cumaru <command> --help` for full usage.

## Skills and adapters

Cumaru installs native project artifacts for Generic, Claude, Codex, and
OpenCode. Each command targets an adapter explicitly; multiple adapter surfaces
may coexist, and adapter choice is not persisted in config. A target receives
durable instructions, the appropriate skills, supported commands, and a
session-start candidate projection where the client supports it.

Universal skills cover health checks, updates, explicit `.cumaru` `summary:`
frontmatter curation, role switching, and specification-to-code references.
General requests to summarize text or conversation do not select summary
curation. Domains add workflows such as planning,
exploration, intake, topology, coverage, and memory distillation. Opt-in skills
provide tool-specific mechanics such as Git, Terraform, Pulumi, and test
runners.

Domain skills and their slash-command launchers are agent surfaces, not CLI
subcommands: for example, `cumaru-intake` may be installed as a skill while
`cumaru intake` remains invalid.

The [agent adapter documentation](docs/agent-adapters.md) is the canonical
artifact matrix. The [installation guide](docs/install.md) lists every shipped
domain, skill, and command.

## Versioning and updates

Each installed tree has an integer framework version that acts as a migration
boundary. `cumaru update --apply` writes framework-owned content directly after
the Git recovery check when source and local versions match, while preserving
adopter-owned tag bodies and local-only files.

Project source commands (`install`, `update`, `bootstrap`, `migrate`, `version`
inside a project, and `help domains`) read HEAD of `main`, pinned to one commit
per invocation. Binary release checks and `cumaru upgrade` use release tags
instead. The CLI version (for example `0.10.0`) and the installed config integer
(for example `9`) are independent: `cumaru upgrade` replaces only the global
binary, while `cumaru update` refreshes one project's framework files. Neither
implies the other.

For major changes, `cumaru migrate` prints a rolling migration document. The
command is read-only; the LLM performs the documented, detection-first steps.
Migration has no transactional rollback. Require a clean affected worktree and
tracked `.cumaru/` inside Git. Outside Git, disclose the missing recovery point;
Cumaru does not initialize Git or create a backup.

Read [updates](docs/update.md), [migration](docs/migrate.md), and
[doctor](docs/doctor.md) before changing an existing installation.

## Documentation

- [Development setup and architecture](HOW_TO_DEV.md)
- [Native Rust CLI](docs/rust.md)
- [Architecture](docs/architecture.md)
- [Install](docs/install.md)
- [Agent adapters](docs/agent-adapters.md)
- [`cumaru tree`](docs/tree.md)
- [`cumaru map`](docs/map.md)
- [`cumaru context`](docs/context.md)
- [`cumaru model`](docs/model.md)
- [`cumaru doctor`](docs/doctor.md)
- [`cumaru coverage`](docs/coverage.md)
- [`cumaru tag`](docs/tag.md)
- [`cumaru fs`](docs/fs.md)
- [`cumaru update`](docs/update.md)
- [`cumaru migrate`](docs/migrate.md)
- [`cumaru bootstrap`](docs/bootstrap.md)
- [`cumaru uninstall`](docs/uninstall.md)
- [`cumaru upgrade`](docs/upgrade.md)

## License

Cumaru is licensed under the [MIT License](LICENSE).
