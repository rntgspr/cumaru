# `cumaru install`

Install a domain into a project's `.cumaru/`. Copies the chosen domain wholesale, auto-installs the universal `cumaru-*` skills, optionally layers opt-in skills, wires the agent instruction file, installs the context hook into `.agents/hooks.json`, and copies slash commands into `.agents/commands/`.

## Usage

```
cumaru install [--domain <name>] [--with <skill>...]
```

| Option | Default | Description |
|---|---|---|
| `--domain <name>` | `sdlc-it-project-basic` | Which domain to install. `base` resolves to `frameworks/__base/`; any other name to `frameworks/<name>/`. |
| `--with <skill>` | none | Add an opt-in skill at install time. Repeatable. `cumaru-*` skills don't need `--with` — they ship automatically. |

The install location is always `.cumaru/` at the project root. Skills, commands, hooks, and config go under `.agents/`.

## What it does

1. **Pre-checks** — prompts before replacing an existing `.cumaru/` (refuses non-interactive overwrite) and verifies each requested `--with <skill>` exists at `skills/<skill>/SKILL.md`.
2. **Copies the chosen domain wholesale, then prunes framework-owned agent subdirs from `.cumaru/`** — `cp -R "frameworks/<domain>" .cumaru/` followed by `rm -rf .cumaru/{skills,commands}`. Brings the schema, starter indexes, templates, roles, and hooks. Skills and slash commands live under `.agents/`; they do NOT belong inside `.cumaru/`. Hooks also live under `.agents/hooks/` because the agent config points there.
3. **Installs framework skills** — for every `cumaru-*` directory under `frameworks/<domain>/skills/`, copies the dir to `.agents/skills/<name>/`. Universal skills (`cumaru-doctor`, `cumaru-update`, `cumaru-refs`) live in `__base/skills/` and are mirrored verbatim into every domain (drift-checked at install-script time), so sourcing only from the domain is complete. `cumaru-install` ships with every domain too, but is domain-owned (its post-install recipe targets the domain's durable pillar) and exempt from the drift-check.
4. **Applies opt-in skills** — for each `--with <name>`, copies the top-level `skills/<name>/` dir into `.agents/skills/`.
5. **Wires agent instructions** — creates or appends a `<!-- BEGIN CUMARU-HOOK --> ... <!-- END CUMARU-HOOK -->` block containing an `@.cumaru/index.md` import directive in `.agents/AGENTS.md`. Idempotent — skips if the marker is already present.
6. **Wires context hooks** — installs `.agents/hooks/context-loader.sh` and adds a `UserPromptSubmit` command hook to `.agents/hooks.json`. The JSON update is done with `jq`. On every prompt, the hook uses `cumaru tag all --rows` to read canonical `<!-- cumaru:* -->` tag bodies, resolves `[Link, Description]` rows, and injects root context plus linked files whose Link or Description matches the prompt subject.
7. **Installs slash commands** — recursively copies every `*.md` from `frameworks/<domain>/commands/` into `.agents/commands/`. A file at `frameworks/<domain>/commands/cumaru/doctor.md` becomes `.agents/commands/cumaru/doctor.md`, exposing the slash command as `/cumaru:doctor`.
8. **Prints next steps** — hints to edit the components table in `.cumaru/domain.md`, populate `meta.apps.values` in `.cumaru/schema.yaml`, and run `cumaru doctor`.

## Available Domains

- **`sdlc-it-project-basic`** *(default)* — software delivery lifecycle: `intake/`, `plans/`, `archive/`, `specs/`, `exploring/` pillars; Lead/Dev/Ghost roles; ships five domain-specific skills (`cumaru-intake`, `cumaru-explore`, `cumaru-plan`, `cumaru-specs`, `cumaru-archive`).
- **`iac-basic`** — tool-agnostic infrastructure-as-code workflow: durable `topology/` (apply-order DAG) + `runbooks/` pillars alongside the lifecycle pillars (`intake/`, `plans/`, `archive/`, `exploring/`); `apps:` enumerates environments; Lead/Dev roles; ships six domain-specific skills (`cumaru-intake`, `cumaru-explore`, `cumaru-plan`, `cumaru-topology`, `cumaru-archive`, `cumaru-arch`).
- **`qa-basic`** — test-strategy & coverage workflow: durable `coverage/` + `standards/` pillars alongside the lifecycle pillars; `apps:` enumerates test levels; ships five domain-specific skills (`cumaru-intake`, `cumaru-explore`, `cumaru-plan`, `cumaru-coverage`, `cumaru-archive`).
- **`vault-memory`** — personal/team memory-vault workflow: transient `inbox/`, rough `drafts/`, durable graph-shaped `memories/`, and retained `attachments/`; ships four domain-specific skills (`cumaru-capture`, `cumaru-draft`, `cumaru-distill`, `cumaru-link`).
- **`base`** — minimal kernel (resolves to `frameworks/__base/`): no pillars, only the rules + meta sections of the schema. Start here to build a custom domain from scratch.

The one-line summary shown by `cumaru install --help` per domain comes from each domain's `domain.md` H1.

Adding a new domain is a disk operation — create `frameworks/<name>/` with its own self-contained `schema.yaml` and starter files. Install's help text auto-discovers it.

## Available skills

**Universal** (authored in `__base/skills/`, mirrored verbatim into every domain):
- `cumaru-doctor`, `cumaru-update` — multi-step orchestration carried by SKILL.md.
- `cumaru-refs` — spec↔code reference coverage: closes the gaps `cumaru coverage` reports by wiring source files into spec `reference` tables.

**Domain-owned but shipped by every domain:**
- `cumaru-install` — adopt the framework, then bootstrap the domain's durable pillar; the post-install recipe hands off to `cumaru-specs` / `cumaru-topology` / `cumaru-coverage`, so each domain tunes its copy (exempt from the kernel drift-check).

**Domain-shipped** (live in `frameworks/<domain>/skills/` alongside the universal copies):
- `sdlc-it-project-basic` adds `cumaru-intake`, `cumaru-explore`, `cumaru-plan`, `cumaru-specs`, `cumaru-archive`.
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
- `/cumaru:doctor`, `/cumaru:update`, `/cumaru:resolve`, `/cumaru:refs` — pure mechanics, no domain-specific content.

**Domain-specific** (live in `frameworks/<domain>/commands/cumaru/`):
- `sdlc-it-project-basic` ships `/cumaru:archive`, `/cumaru:explore`, `/cumaru:intake`, `/cumaru:plan`, `/cumaru:specs`.
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
cumaru install --with git                                       # default domain + git skill
cumaru install --domain base                                    # minimal kernel
cumaru install --domain sdlc-it-project-basic                   # explicit domain
cumaru install --domain base --with git                         # base + git
cumaru install --domain iac-basic --with terraform              # IaC domain + tool skill
cumaru install --domain qa-basic --with pytest --with vitest    # QA domain + runners
cumaru install --domain vault-memory                            # memory vault domain
```

## Related

- [`cumaru doctor`](doctor.md) — first thing to run after install.
- [`cumaru update`](update.md) — keep an installed `.cumaru/` up to date with a newer framework version.
- [`cumaru uninstall`](uninstall.md) — reverse of install.
