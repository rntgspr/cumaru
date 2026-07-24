# `cumaru install`

Install a domain into a project's `.cumaru/`, then install one schema-selected
agent adapter. Without an explicit agent, the existing generic `.agents/`
behavior remains active.

## Prerequisites

The CLI requires Bash, cURL, Git, `jq`, and **Mike Farah `yq` v4** on `PATH`.
The Python program also distributed as `yq` is not compatible: Cumaru depends
on Mike Farah-specific YAML and Markdown frontmatter operators.

Recommended macOS setup:

```bash
brew install git jq yq
```

Verify the commands before installation:

```bash
bash --version
curl --version
git --version
jq --version
yq --version # must identify mikefarah/yq v4
```

Dependency ownership:

- `jq` is required by JSON-based tracker intake adapters.
- `yq` is required by navigation, doctor, update, migration, and schema or
  frontmatter operations.
- Git is required by the installer and upgrade flow; `cumaru coverage` also
  requires a Git work tree because its source inventory comes from
  `git ls-files`.
- cURL is required by the remote installer and tracker intake adapters.

Linux users can install Bash, cURL, Git, and `jq` through their distribution,
then install Mike Farah `yq` v4 from the
[official installation options](https://github.com/mikefarah/yq#install).

## Usage

```
cumaru install [agent <none|claude|codex|opencode>] [--domain <name>] [--with <skill>...]
```

| Option | Default | Description |
|---|---|---|
| `agent <name>` | `none` | Select the native agent integration. `none` writes `agent: null`. |
| `--domain <name>` (or `--domain=<name>`) | `sdlc-full` | Which domain to install. `base` resolves to `domains/__base/`; any other name to `domains/<name>/`. |
| `--with <skill>` (or `--with=<skill>`) | none | Add an opt-in skill at install time. Repeatable. `cumaru-*` skills don't need `--with` — they ship automatically. |

The install location is always `.cumaru/` at the project root. Instructions,
skills, and supported commands use the paths in
[`agent-adapters.md`](agent-adapters.md).

## What it does

1. **Pre-checks** — prompts before replacing an existing `.cumaru/` (refuses non-interactive overwrite) and verifies each requested `--with <skill>` exists at `skills/<skill>/SKILL.md`.
2. **Copies the domain and prunes source-only artifacts** — skills and commands do not live inside `.cumaru/`.
3. **Installs skills** — copies domain `cumaru-*` skills and requested opt-ins into the selected adapter's native skill directory.
4. **Wires durable instructions** — uses a marked Markdown block for generic, Claude, and Codex; merges exact `instructions` entries into `opencode.json` for OpenCode.
5. **Installs supported commands** — generic, Claude, and OpenCode receive native command files. Codex uses repository skills and receives no unsupported command directory.
6. **Persists state last** — writes `agent: null`, `claude`, `codex`, or `opencode` only after the adapter succeeds.
7. **Prints next steps** — points at project metadata and `cumaru doctor`.

## Available Domains

- **`sdlc-full`** *(default)* — software delivery lifecycle: `intake/`, `plans/`, `archive/`, `specs/`, `exploring/` pillars; Lead/Dev/Ghost roles; ships five domain-specific skills (`cumaru-intake`, `cumaru-explore`, `cumaru-plan`, `cumaru-specs`, `cumaru-archive`).
- **`sdlc-light`** — simplified SDLC with 3 pillars (`plans/`, `specs/`, `exploring/`), single lead role, direct plans→specs absorb (no archive). Ships four domain-specific skills (`cumaru-plan`, `cumaru-specs`, `cumaru-explore`, `cumaru-absorb`).
- **`iac-basic`** — tool-agnostic infrastructure-as-code workflow: durable `topology/` (apply-order DAG) + `runbooks/` pillars alongside the lifecycle pillars (`intake/`, `plans/`, `archive/`, `exploring/`); `apps:` enumerates environments; Lead/Dev roles; ships six domain-specific skills (`cumaru-intake`, `cumaru-explore`, `cumaru-plan`, `cumaru-topology`, `cumaru-archive`, `cumaru-arch`).
- **`qa-basic`** — test-strategy & coverage workflow: durable `coverage/` + `standards/` pillars alongside the lifecycle pillars; `apps:` enumerates test levels; ships five domain-specific skills (`cumaru-intake`, `cumaru-explore`, `cumaru-plan`, `cumaru-coverage`, `cumaru-archive`).
- **`vault-memory`** — personal/team memory-vault workflow: transient `inbox/`, rough `drafts/`, durable graph-shaped `memories/`, and retained `attachments/`; ships four domain-specific skills (`cumaru-capture`, `cumaru-draft`, `cumaru-distill`, `cumaru-link`).
- **`base`** — minimal kernel (resolves to `domains/__base/`): no pillars, only the rules + meta sections of the schema. Start here to build a custom domain from scratch.

New domains are auto-discovered from disk. Create `domains/<name>/` with a self-contained `schema.yaml`, `domain.md`, starter files, and agent artifacts; `install --help` uses the domain's `domain.md` H1 as its one-line summary.

## Available skills

**Universal** (authored in `__base/skills/`, mirrored verbatim into every domain):
- `cumaru-doctor`, `cumaru-update`, `cumaru-summarize` — multi-step orchestration carried by SKILL.md.
- `cumaru-refs` — spec↔code reference coverage: closes the gaps `cumaru coverage` reports by wiring source files into spec `reference` tables.

**Domain-owned but shipped by every domain:**
- `cumaru-install` — adopt the framework, then bootstrap the domain's durable pillar; the post-install recipe hands off to `cumaru-specs` / `cumaru-topology` / `cumaru-coverage`, so each domain tunes its copy (exempt from the kernel drift-check).

**Domain-shipped** (live in `domains/<domain>/skills/` alongside the universal copies):
- `sdlc-full` adds `cumaru-intake`, `cumaru-explore`, `cumaru-plan`, `cumaru-specs`, `cumaru-archive`.
- `sdlc-light` adds `cumaru-plan`, `cumaru-specs`, `cumaru-explore`, `cumaru-absorb`.
- `iac-basic` adds `cumaru-intake`, `cumaru-explore`, `cumaru-plan`, `cumaru-topology`, `cumaru-archive`, `cumaru-arch`.
- `qa-basic` adds `cumaru-intake`, `cumaru-explore`, `cumaru-plan`, `cumaru-coverage`, `cumaru-archive`.
- `vault-memory` adds `cumaru-capture`, `cumaru-draft`, `cumaru-distill`, `cumaru-link`.

**Opt-in** (sourced from top-level `skills/`; require `--with <name>`):
- `git` — unlocks mutating git commands (`commit`, `push`, `reset`, ...) under the framework's skill-gated capability rule.
- `terraform`, `pulumi` — IaC tool mechanics plus the iac-basic safety discipline (the plan/preview diff IS the blast radius; environments along the promotion path).
- `pytest`, `vitest`, `cypress`, `playwright` — test-runner mechanics; companions to the qa-basic domain.

Opt-ins combine with any domain. `cumaru install --help` auto-discovers them from each `skills/<name>/SKILL.md` `description:`.

## Available slash commands

**Universal** (authored in `__base/commands/cumaru/`, mirrored verbatim into every domain):
- `/cumaru:doctor`, `/cumaru:update`, `/cumaru:resolve`, `/cumaru:refs`, `/cumaru:summarize` — universal launchers with no domain-specific recipe content.

**Domain-specific** (live in `domains/<domain>/commands/cumaru/`):
- `sdlc-full` ships `/cumaru:archive`, `/cumaru:explore`, `/cumaru:intake`, `/cumaru:plan`, `/cumaru:specs`.
- `sdlc-light` ships `/cumaru:plan`, `/cumaru:specs`, `/cumaru:explore`, `/cumaru:absorb`.
- `iac-basic` ships `/cumaru:archive`, `/cumaru:explore`, `/cumaru:intake`, `/cumaru:plan`, `/cumaru:topology` (the `cumaru-arch` skill has no command — it triggers on conversation).
- `qa-basic` ships `/cumaru:archive`, `/cumaru:explore`, `/cumaru:intake`, `/cumaru:plan`, `/cumaru:coverage`.
- `vault-memory` ships `/cumaru:capture`, `/cumaru:draft`, `/cumaru:distill`, `/cumaru:link`.

## CLI primitives (no skill needed)

`cumaru tag` (read/write `<!-- cumaru:NAME -->` marker blocks; schema-validated), `cumaru flow` (4 verbs: `move`/`copy`/`create`/`remove`, with guardrails), and [`cumaru coverage`](coverage.md) (read-only spec↔code coverage report) are mechanical primitives — composed by recipe skills, documented in `cumaru <cmd> --help`.

To inspect all canonical tag bodies:

```bash
cumaru tag all --body
```

## When to use

Run once per project, at adoption time. To re-install after deleting `.cumaru/`, just run `cumaru install` again. To upgrade an existing install with new framework files, see [`cumaru update`](update.md).

## Examples

```bash
cumaru install                                                  # install the SDLC domain at .cumaru/
cumaru install agent claude                                     # Claude-native project files
cumaru install agent codex                                      # Codex-native instructions and skills
cumaru install agent opencode                                   # OpenCode config, skills, and commands
cumaru install --with git                                       # default domain + git skill
cumaru install --domain base                                    # minimal kernel
cumaru install --domain sdlc-full                               # explicit domain
cumaru install --domain base --with git                         # base + git
cumaru install --domain iac-basic --with terraform              # IaC domain + tool skill
cumaru install --domain qa-basic --with pytest --with vitest    # QA domain + runners
cumaru install --domain vault-memory                            # memory vault domain
```

## Related

- [`cumaru doctor`](doctor.md) — first thing to run after install.
- [`cumaru update`](update.md) — keep an installed `.cumaru/` up to date with a newer framework version.
- [`cumaru uninstall`](uninstall.md) — reverse of install.
