# `cumaru install`

Install a domain into a project's `.cumaru/`, then materialize one requested
agent adapter. Without an explicit agent, the generic `none` adapter is used.

## Prerequisites

The native `cumaru` binary needs cURL on `PATH` to read domain sources from
GitHub. Navigation and config/Markdown parsing need no runtime `jq`, `yq`, or
`rg`.

- cURL is required by `install`, `update`, `bootstrap`, `migrate`,
  `help domains`, and `version` inside a project.
- Git is required by `upgrade` and `upgrade --check` (release tags) and by
  `cumaru coverage`, whose source inventory comes from `git ls-files` in a Git
  work tree. `update --apply` and `--clear` use Git, when present, for the
  recovery check.
- Bash runs the binary installer and installed session hooks.

See the [README](../README.md#install-the-cli) for compiled CLI installation.
Contributor setup and build instructions live in [HOW_TO_DEV.md](../HOW_TO_DEV.md).

## Usage

```text
cumaru install [agent <none|claude|codex|opencode>] [--domain <name>]
```

| Option | Default | Description |
|---|---|---|
| `agent <name>` | `none` | Materialize one native agent integration without changing config.yaml. |
| `--domain <name>` (or `--domain=<name>`) | `base` | Which domain to install from main HEAD. `base` aliases `__base`. List names with `cumaru help domains`. |

There is no `--with` and no local or `--from` source. Opt-in skills are added
after adoption with `cumaru update skills <agent> --with <skill> --apply`.

The install location is always `.cumaru/` at the project root. Instructions,
skills, and supported commands use the paths in
[`agent-adapters.md`](agent-adapters.md).

## What it does

1. **Pre-checks** — validates the domain name and adapter, and refuses any
   existing `.cumaru` entry (including files and broken symlinks), before any
   network access. Refresh belongs to `cumaru update`.
2. **Resolves the source** — reads HEAD of `main` through GitHub, fetches its
   recursive tree, and pins every download to that commit. Truncated
   inventories, unsafe paths, symlinks, and unsupported entry modes fail.
3. **Plans the complete install** — validates the remote config as version 9
   for the selected domain, selects only the structure and files that config
   describes, downloads everything into memory, and prepares adapter merges.
   Source-only skills, commands, and bootstrap/migration prose never land in
   `.cumaru/`. Malformed adopter JSON or instruction blocks fail here, before
   any project write.
4. **Publishes `.cumaru/`** — creates the tree exclusively.
5. **Installs skills** — copies the domain's `cumaru-*` skills into the
   selected adapter's native skill directory, keeping existing skill folders.
6. **Wires durable instructions** — `.cumaru/index.md`, `.cumaru/domain.md`, the
   discipline index, and every installed discipline. Claude receives explicit
   imports, Generic and Codex receive materialized discipline bodies in their
   managed block, and OpenCode receives its native instructions glob. Existing
   files are merged, never overwritten.
7. **Registers the session hook** — Claude and Codex only. See
   [`agent-adapters.md`](agent-adapters.md#context-bootstrap).
8. **Installs command launchers** — Generic and OpenCode only, when absent.
   Claude and Codex invoke the skills directly.
9. **Prints next steps** — points at `domain.md`, `config.yaml`, and
   `cumaru doctor`. It does not run doctor or bootstrap.

The adapter is never persisted in `.cumaru/config.yaml`. Install has no
multi-file transaction or automatic rollback: an I/O failure after publication
starts may leave a partial installation.

## Available Domains

`cumaru help domains` lists the domains at main HEAD.

- **`base`** *(default)* — minimal kernel (resolves to `domains/__base/`): no pillars, only the rules + meta sections of the config. Start here to build a custom domain from scratch.
- **`sdlc-full`** — software delivery lifecycle: `intake/`, `issues/`, `plans/`, `specs/`, `exploring/` pillars; Lead/Dev/Ghost roles; ships six domain-specific skills (`cumaru-intake`, `cumaru-issue`, `cumaru-explore`, `cumaru-plan`, `cumaru-specs`, `cumaru-absorb`).
- **`design-as-code`** — [design delivery](design-as-code.md): transient intake, research, concepts, and plans feed durable specs and an asset catalog through direct absorption.
- **`sdlc-light`** — simplified SDLC with 3 pillars (`plans/`, `specs/`, `exploring/`), single lead role, direct plans→specs absorb. Ships four domain-specific skills (`cumaru-plan`, `cumaru-specs`, `cumaru-explore`, `cumaru-absorb`).
- **`iac-basic`** — tool-agnostic infrastructure-as-code workflow: durable `topology/` (apply-order DAG) + `runbooks/` pillars alongside the lifecycle pillars (`intake/`, `plans/`, `exploring/`); `targets:` enumerates environments; Lead/Dev roles; ships six domain-specific skills (`cumaru-intake`, `cumaru-explore`, `cumaru-plan`, `cumaru-topology`, `cumaru-absorb`, `cumaru-arch`).
- **`qa-basic`** — test-strategy & coverage workflow: durable `coverage/` + `standards/` pillars alongside the lifecycle pillars; `targets:` enumerates test levels; ships five domain-specific skills (`cumaru-intake`, `cumaru-explore`, `cumaru-plan`, `cumaru-coverage`, `cumaru-absorb`).
- **`vault-memory`** — personal/team memory-vault workflow: transient `inbox/`, rough `drafts/`, durable graph-shaped `memories/`, and retained `attachments/`; ships four domain-specific skills (`cumaru-capture`, `cumaru-draft`, `cumaru-distill`, `cumaru-link`).
- **`focus`** — directive-driven triage workflow: `directives/` declare priority scope, `threads/` retain source context with a dated state history and yearly archival, and `outcomes/` group results by adopter-declared area with cumulative value/work/policy views, and `sources/` describe read-only access to each data source; single Admin role; ships five domain-specific skills (`cumaru-directives`, `cumaru-sources`, `cumaru-thread`, `cumaru-outcome`, `cumaru-zoom`). Intake is declared per source in `sources/`; adopter intake policy stays in the `root` tag.

A domain is discoverable once `domains/<name>/config.yaml` exists on `main`;
`help domains` uses the H1 of its `domain.md` as the one-line summary.

## Available skills

**Universal** (authored in `__base/skills/`, mirrored verbatim into every domain):
- `cumaru-search` — discover relevant knowledge when its owning file is unknown;
  [the canonical recipe](../domains/__base/skills/cumaru-search/SKILL.md) owns search routing and evidence selection.
- `cumaru-doctor`, `cumaru-flow`, `cumaru-update`, `cumaru-summarize`, and `cumaru-role` —
  multi-step orchestration carried by `SKILL.md`.
- `cumaru-refs` — spec↔code reference coverage: closes the gaps `cumaru coverage` reports by wiring source files into spec `reference` tables.

`cumaru-summarize` is limited to explicit `.cumaru` `summary:` frontmatter
maintenance. General requests to summarize text, documentation, or conversation
do not select it; its canonical trigger scenarios remain in the skill contract.

**Domain-owned but shipped by every domain:**
- `cumaru-install` — adopt the framework, then bootstrap the domain's durable pillar; the post-install recipe hands off to `cumaru-specs` / `cumaru-topology` / `cumaru-coverage`, so each domain tunes its copy (exempt from the kernel drift-check).

**Domain-shipped** (live in `domains/<domain>/skills/` alongside the universal copies):
- `sdlc-full` adds `cumaru-intake`, `cumaru-issue`, `cumaru-explore`, `cumaru-plan`, `cumaru-specs`, `cumaru-absorb`.
- `design-as-code` adds `cumaru-intake`, `cumaru-concept`, `cumaru-plan`, `cumaru-specs`, `cumaru-absorb`.
- `sdlc-light` adds `cumaru-plan`, `cumaru-specs`, `cumaru-explore`, `cumaru-absorb`.
- `iac-basic` adds `cumaru-intake`, `cumaru-explore`, `cumaru-plan`, `cumaru-topology`, `cumaru-absorb`, `cumaru-arch`.
- `qa-basic` adds `cumaru-intake`, `cumaru-explore`, `cumaru-plan`, `cumaru-coverage`, `cumaru-absorb`.
- `vault-memory` adds `cumaru-capture`, `cumaru-draft`, `cumaru-distill`, `cumaru-link`.
- `focus` adds `cumaru-directives`, `cumaru-sources`, `cumaru-thread`, `cumaru-outcome`, `cumaru-zoom`.

**Opt-in** (sourced from top-level `skills/`; added after adoption with
`cumaru update skills <agent> --with <name> --apply`):
- `git` — unlocks mutating git commands (`commit`, `push`, `reset`, ...) under the framework's skill-gated capability rule.
- `terraform`, `pulumi` — IaC tool mechanics plus the iac-basic safety discipline (the plan/preview diff IS the blast radius; environments along the promotion path).
- `pytest`, `vitest`, `cypress`, `playwright` — test-runner mechanics; companions to the qa-basic domain.
- `skill-to-discipline` — convert an explicitly selected external skill into a
  Cumaru execution discipline with source attribution.

Opt-ins combine with any domain. Update validates every requested name against
main HEAD before mutation.

## Available slash commands

Generic (`none`) and OpenCode receive command launchers; Claude and Codex invoke
the skills directly.

**Universal** (authored in `__base/commands/cumaru/`, mirrored verbatim into every domain):
- `/cumaru:doctor`, `/cumaru:flow`, `/cumaru:update`, `/cumaru:refs`, `/cumaru:search`, `/cumaru:summarize`, `/cumaru:role <role>` — universal launchers with no domain-specific recipe content. In OpenCode, use `/cumaru/role <role>`.

Every command requires `skills/cumaru-<name>/SKILL.md`. Its body places
`$ARGUMENTS` before the skill invocation and contains no workflow recipe;
domains with a command but no namesake skill are invalid.

**Domain-specific** (live in `domains/<domain>/commands/cumaru/`):
- `sdlc-full` ships `/cumaru:absorb`, `/cumaru:explore`, `/cumaru:intake`, `/cumaru:issue`, `/cumaru:plan`, `/cumaru:specs`.
- `design-as-code` ships `/cumaru:intake`, `/cumaru:concept`, `/cumaru:plan`, `/cumaru:specs`, `/cumaru:absorb`.
- `sdlc-light` ships `/cumaru:plan`, `/cumaru:specs`, `/cumaru:explore`, `/cumaru:absorb`.
- `iac-basic` ships `/cumaru:absorb`, `/cumaru:explore`, `/cumaru:intake`, `/cumaru:plan`, `/cumaru:topology` (the `cumaru-arch` skill has no command — it triggers on conversation).
- `qa-basic` ships `/cumaru:absorb`, `/cumaru:explore`, `/cumaru:intake`, `/cumaru:plan`, `/cumaru:coverage`.
- `vault-memory` ships `/cumaru:capture`, `/cumaru:draft`, `/cumaru:distill`, `/cumaru:link`.
- `focus` ships `/cumaru:directives`, `/cumaru:thread`, `/cumaru:outcome`, `/cumaru:zoom`, `/cumaru:sources`.

## CLI primitives (no skill needed)

[`cumaru tag`](tag.md) (read/write `<!-- cumaru:NAME -->` tags; config-validated), [`cumaru fs`](fs.md) (4 verbs: `move`/`copy`/`create`/`remove`, with guardrails), and [`cumaru coverage`](coverage.md) (read-only spec↔code coverage report) are mechanical primitives — composed by recipe skills, documented in `cumaru <cmd> --help`.

To inspect all canonical tag bodies:

```bash
cumaru tag all --body
```

## When to use

Run once per project, at adoption time. An existing `.cumaru/` is never
overwritten by install. Use [`cumaru update`](update.md) for framework refresh
or opt-in skills; replace a domain only by uninstalling deliberately first.

## Examples

```bash
cumaru install                                   # base domain, generic adapter
cumaru install agent claude                      # Claude-native project files
cumaru install agent codex                       # Codex-native instructions and skills
cumaru install agent opencode                    # OpenCode config, skills, and commands
cumaru install --domain sdlc-full                # explicit domain
cumaru install agent claude --domain iac-basic   # explicit adapter and domain
cumaru install --domain vault-memory             # memory vault domain
cumaru install --domain focus                    # directive-driven threads and outcomes
cumaru update skills claude --with git --apply   # opt-in skill, after adoption
```

## Related

- [`cumaru doctor`](doctor.md) — first thing to run after install.
- [`cumaru bootstrap`](bootstrap.md) — read-only post-install steps for the domain.
- [`cumaru update`](update.md) — refresh an installed `.cumaru/` at the same config version, or add opt-ins.
- [`cumaru uninstall`](uninstall.md) — reverse of install.
