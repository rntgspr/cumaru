```



▄████ ██ ██ ███▄███▄  ▀▀█▄ ████▄ ██ ██
██    ██ ██ ██ ██ ██ ▄█▀██ ██ ▀▀ ██ ██
▀████ ▀██▀█ ██ ██ ██ ▀█▄██ ██    ▀██▀█


```

# `.cumaru/` framework

A spec-driven, agent-friendly interactive knowledge framework for any project that can be version-controlled or
stored as text—codebases. Can be used to organize, track, and collaborate projects like: codebases, design systems,
research notes, legal docs, or any other discipline. It lives at `.cumaru/` in any repo or folder that adopts it.
This repository hosts the framework definition, the `cumaru` CLI, and the published skills.

## Installing the `cumaru` CLI

### Prerequisites

Cumaru is a Bash CLI and expects these commands on `PATH`:

| Tool | Used for |
|---|---|
| Bash | CLI and installed agent hooks |
| cURL | Installer and tracker intake |
| Git | Installer, updates, migrations, and source coverage |
| [`jq`](https://formulae.brew.sh/formula/jq) | Agent hook configuration and JSON APIs |
| [Mike Farah `yq`](https://formulae.brew.sh/formula/yq) v4 | Schema and Markdown frontmatter parsing; another program named `yq` is incompatible |

On macOS, install the non-system dependencies with Homebrew:

```bash
brew install git jq yq
```

macOS normally provides Bash and cURL. Verify everything before installing:

```bash
bash --version
curl --version
git --version
jq --version
yq --version # must identify mikefarah/yq v4
```

On Linux, install Bash, cURL, Git, and `jq` with the system package manager, then install Mike Farah `yq` v4 from its [official installation options](https://github.com/mikefarah/yq#install). Distribution packages named `yq` may provide a different, incompatible implementation.

```bash
curl -fsSL https://pixelpunk.works/cumaru/install.sh | bash
```

Installs to `~/.cumaru` and symlinks `cumaru` into `~/.local/bin`. To update the tool later, run **`cumaru upgrade`** — it re-runs this same script, which replaces `~/.cumaru` wholesale (wipe + fresh shallow clone) and verifies the snapshot's kernel integrity (every domain's `index.md` byte-identical to `__base`'s) before linking.

Alternatively, clone the repo and symlink `cumaru` onto your PATH — then `git pull` to update.

## Why

The original Apache HTTP server had a simple idea: each directory could carry an `index.html` that described its contents — navigable without prior knowledge of what was inside. Without one, the server generated a listing. Either way, the directory was *self-describing*.

`.cumaru/` brings that convention to any version-controlled tree and extends it for agents. Every non-hidden directory carries an `index.md` that explains its purpose and rules. The filesystem supplies navigation candidates, and each Markdown file carries a concise `summary:` so an agent can decide what to load without reading every body.

> **Load only what is declared. Everything else stays on disk but out of context.**

`schema.yaml` describes the domain contract as one recursive node under `root:`. The filesystem is the source of structural truth; `cumaru tree` projects its current candidates and summaries. Adding a new area remains a filesystem operation governed by the schema — no CLI code change or persisted child inventory.

## Framework layout

Every `.cumaru/` tree shares the same skeleton: a root `index.md` (front door), a `schema.yaml` (the domain contract), `domain.md` (domain and adopter context), and any number of schema-declared pillar directories. Every non-hidden directory has an `index.md`; `cumaru tree` is the live shallow index.

```
.cumaru/
├── index.md      ← framework kernel: load rules, node model — byte-identical across domains
├── domain.md     ← domain hook: pillars, roles, entry points + the adopter's components/root blocks
├── schema.yaml   ← canonical contract: one recursive node tree (root)
├── roles/        ← agent role definitions
├── templates/    ← entity templates
├── <pillar>/     ← any pillar declared in schema.yaml
│   ├── index.md  ← purpose and rules for the directory
│   └── …
└── <pillar>/
    ├── index.md  ← every pillar must have one
    └── …
```

The front door splits in two: `index.md` is the **kernel** — the loading rule, the node model, conduct and language rules — identical in every domain and updated from source. `domain.md` is the **domain hook**, declared as the kernel's `depends-on`: it carries everything domain-specific (pillars, roles, how work enters) plus the two adopter-owned marker blocks — the `<!-- cumaru:components -->` table and the `<!-- cumaru:root -->` project-context prose.

Every non-hidden directory **must** contain an `index.md`. The agent reads it, runs `cumaru tree <directory>`, prunes candidates by `summary:`, and only then loads relevant files or descends into selected directories.

Six starting points ship with this repository:

- **`domains/__base/`** — the minimal kernel: no pillars, an empty `entities:` map. Start here to build a custom domain from scratch.
- **`domains/sdlc-full/`** *(default)* — software delivery workflows. Pillars: `intake`, `plans`, `archive`, `specs`, `exploring`.
- **`domains/sdlc-light/`** — simplified software delivery. Pillars: `plans`, `specs`, `exploring`; direct plan-to-spec absorption, without `intake` or `archive`.
- **`domains/iac-basic/`** — tool-agnostic infrastructure-as-code. Pillars: `intake`, `plans`, `archive`, `topology`, `exploring`, `runbooks`; the `apps:` axis enumerates environments.
- **`domains/qa-basic/`** — test strategy & coverage. Pillars: `intake`, `plans`, `archive`, `coverage`, `exploring`, `standards`.
- **`domains/vault-memory/`** — memory-vault workflow. Pillars: `inbox`, `drafts`, `memories`, `attachments`; durable memories are typed graph nodes.

Each domain is **self-contained** (its own `schema.yaml` + starter files + skills); you install one, they don't compose. A different domain — research notes, legal matter management, design system documentation — would declare different pillars in its own `schema.yaml` while the skeleton stays identical.

## What the framework is

A recursive domain contract over a filesystem-backed tree. The root node is `.cumaru/`; its schema-declared children are the **pillars**. `schema.yaml` defines frontmatter, semantic tags, entity shapes, and validation rules. Directory children are discovered from disk through `cumaru tree`, not duplicated in marker tables.

Two structural fixtures ship with every installation regardless of domain:

- **`roles/`** — agent role definitions: who reads what, who writes where, and under what conditions.
- **`templates/`** — entity templates used when creating new nodes.

Everything else — pillars, entity shapes, domain conventions — is defined by the domain's `schema.yaml` and described in its `domain.md`. The minimal base (`domains/__base/`) ships no pillars; the SDLC domain ships five pillars and a Lead/Dev/Ghost role set (see [`domains/sdlc-full/domain.md`](domains/sdlc-full/domain.md)); IaC and QA ship their own pillar sets and role pairs. The loading rule itself lives in the kernel [`domains/__base/index.md`](domains/__base/index.md), shared verbatim by all domains.

## How it compares

The framework grew out of the web development / software tooling space, so the closest reference points are tools from that ecosystem — but the structural differences hold for any discipline that adopts it:

- **vs. OpenSpec** — OpenSpec keeps specs monolithic per capability. `.cumaru/` splits by concern, supports per-component divergence, allows plans alongside ticket IDs, and keeps pre-plan ideation separate from the active work tree.
- **vs. GitHub Spec Kit** — Spec Kit recreates intake locally and grows verbose; the archive becomes context noise. `.cumaru/` mirrors the work tracker instead of duplicating it (tracker-agnostic: jira / linear / clickup / …), and curates the archive so it never loads by default.
- **vs. Kiro / requirements notation** — `.cumaru/` accepts EARS and RFC 2119 for acceptance criteria as a **warning**, not a blocker. Narrative sections (overview, decisions, history, notes) stay free prose. Pick one dominant style per section; EARS fits event/state behavior, RFC 2119 fits constraints and invariants.
- **vs. memory bank (Cline / Roo)** — memory bank focuses on session state. `.cumaru/` focuses on durable project state: a living spec, an operational plan, a curated archive, and a space for pre-plan ideas — independent of any single session.

## Adopting it in a project

```bash
# Inside the project that will adopt the framework:
cumaru install                                      # SDLC domain (default)
cumaru install agent claude                         # Claude-native adapter
cumaru install agent codex                          # Codex-native adapter
cumaru install agent opencode                       # OpenCode-native adapter
cumaru install --domain base                        # minimal kernel — build your own pillars
cumaru install --domain sdlc-light                  # simplified software delivery domain
cumaru install --domain iac-basic                   # infrastructure-as-code domain
cumaru install --domain qa-basic                    # test strategy & coverage domain
cumaru install --domain vault-memory                # personal/team memory vault domain

# Opt-in skills (added on top of the domain-shipped set):
cumaru install --with git                           # unlocks mutating git commands
cumaru install --domain iac-basic --with terraform --with pulumi
```

Install copies the domain into `.cumaru/`, then installs one agent adapter. Without `agent`, `schema.yaml` keeps `agent: null` and the generic `.agents/` layout. Claude, Codex, and OpenCode use their native instruction, skill, and command surfaces; see [`docs/agent-adapters.md`](docs/agent-adapters.md). Every domain ships the universal set (`cumaru-doctor`, `cumaru-update`, `cumaru-refs`, `cumaru-summarize`), its own tuned `cumaru-install`, plus one skill per pillar that needs orchestration. Mechanical primitives remain CLI-only. Opt-in skills only ship through `--with`.

The post-install work is **LLM-driven via the installed skills**:
1. **Components** — the `cumaru-install` skill walks the user through editing `.cumaru/domain.md`'s components table and `meta.apps.values` in `.cumaru/schema.yaml`.
2. **Spec bootstrap** — the `cumaru-specs` skill (SDLC domain) walks the user through identifying functional areas and seeding `specs/<area>/index.md` skeletons.
3. **Validate** — run `cumaru` (or `cumaru doctor`) to check navigation, summaries, retained marker contracts and file references, tools, and agent hook wiring.

## Skills and agent integration

Skills follow the official Anthropic format (`SKILL.md` with frontmatter). They are organized in two tiers:

**Domain-shipped skills** at `domains/<domain>/skills/cumaru-*/` — installed into the selected agent skill dirs with the domain. Every domain carries the universal set:

- `cumaru-doctor` — run the health checks, interpret orphans, propose fixes.
- `cumaru-update` — pull framework-file updates from the source, replace skills and slash commands; adjudicate frontmatter key drift, tag-body reshapes, orphan/relocated tags.
- `cumaru-refs` — spec↔code reference coverage: adjudicate the gaps `cumaru coverage` reports and wire source files into spec `reference` tables.
- `cumaru-summarize` — curate missing or invalid `summary:` frontmatter without changing semantic content.

…plus `cumaru-install` (adopt the framework, then bootstrap the durable pillar) — shipped by every domain but **domain-owned**: its post-install recipe hands off to the domain's pillar skill (`cumaru-specs` / `cumaru-topology` / `cumaru-coverage`), so it is exempt from the kernel drift-check.

…plus its own orchestration skills, one per pillar that needs them:

- **SDLC**: `cumaru-intake` (mirror a tracker issue as `intake/<KEY>.md`), `cumaru-explore`, `cumaru-plan`, `cumaru-specs`, `cumaru-archive`.
- **IaC**: `cumaru-intake`, `cumaru-explore`, `cumaru-plan`, `cumaru-topology` (≈ specs for stacks; `depends-on` = apply order), `cumaru-archive`, plus `cumaru-arch` (render the topology graph as Mermaid/ASCII, read-only).
- **QA**: `cumaru-intake`, `cumaru-explore`, `cumaru-plan`, `cumaru-coverage`, `cumaru-archive`.
- **Vault Memory**: `cumaru-capture`, `cumaru-draft`, `cumaru-distill`, `cumaru-link`.

**Slash commands** at `domains/<domain>/commands/cumaru/*.md` — installed into the selected agent command dirs. Each is a user-invoked entry point (`/cumaru:plan`, `/cumaru:explore`, `/cumaru:topology`, …) that loads the matching skill and dispatches by intent. `/cumaru:summarize` launches the universal summary-curation skill. `cumaru-install` remains the bootstrap exception because slash commands do not exist before installation.

**Opt-in skills** at the top-level `skills/<name>/` (no `cumaru-` prefix) — installed only with `--with <name>`:

- [`git`](skills/git/SKILL.md) — unlocks mutating git commands (`commit`/`push`/`reset`/…) under the framework's skill-gated capability rule.
- [`terraform`](skills/terraform/SKILL.md) / [`pulumi`](skills/pulumi/SKILL.md) — IaC tool mechanics + the domain's safety discipline (never apply unread; the plan diff IS the blast radius).
- [`pytest`](skills/pytest/SKILL.md) / [`vitest`](skills/vitest/SKILL.md) / [`playwright`](skills/playwright/SKILL.md) / [`cypress`](skills/cypress/SKILL.md) — test-runner mechanics for the QA domain.

**Mechanical primitives — no skill needed.** `cumaru tag` (read/write `<!-- cumaru:NAME -->` marker blocks; schema-validated), `cumaru flow` (4 verbs: `move`/`copy`/`create`/`remove`, with guardrails), and `cumaru coverage` (read-only spec↔code coverage report over `reference` tables) are documented in `cumaru <cmd> --help`. Every recipe skill above composes calls to them.

**Agent selection:** `cumaru install agent <name>` installs the native adapter.
`cumaru update agent <name>` previews a switch; add `--apply` to perform it.
`cumaru update agent none --apply` restores generic `agent: null` behavior.
`cumaru doctor` reads the schema and validates the selected adapter automatically.

**Using with claude.ai:** upload `SKILL.md` via the custom skills UI, or automate via the Skills API. claude.ai does not watch the repo — re-upload (or trigger an API call from CI) when a skill changes.

## Navigation and semantic tags

Version 6 makes the filesystem the structural source of truth. `index.md` explains a directory; `cumaru tree` lists its current children from disk and reads their `summary:` frontmatter without loading Markdown bodies.

```markdown
| Path | Summary |
|---|---|
| plans/AAA-1234/ | Migrate authentication middleware to the new session API. |
```

Marker blocks remain adopter-owned semantic data. The schema declares each tag as a standard `Link | Description` table, a custom-column table, `prose`, or opaque `mixed`/`other` content. Tags express relations and durable records such as `reference`, `files`, `relations`, and `absorptions`; they never inventory directory children.

Navigation is also the bounded discovery mechanism for cross-cutting work. Empty `depends-on:` or `relates:` fields do not prove isolation: start from the relevant pillar, expand one directory at a time, follow only summaries or semantic links that match the task, and inspect selected `reference` tables before changing shared source. The result should identify affected consumers, durable knowledge outside the active scope, and uncovered gaps without bulk-loading the tree.

See [`docs/tree.md`](docs/tree.md) for navigation and [`docs/tag.md`](docs/tag.md) for semantic marker bodies.

## Versioning

The schema declares a `version:` (currently `6`). Each adopter declares the same `framework-version:` in `.cumaru/index.md`; doctor and update enforce equality.

Major-version changes use explicit, transactional migration adapters. For v5 adopters, run `cumaru migrate v6` for a dry-run and then repeat with `--apply`; steady-state `cumaru update --apply` refuses to cross a major version.

## CLI subcommands

Run `cumaru help` (or `cumaru <cmd> --help`) for full usage.

| Subcommand | Purpose |
|---|---|
| `doctor` *(default)* | Validate navigation, summaries, retained markers and file references, tools, and agent integration |
| `domains` | List installable domains discovered from `domains/` |
| `install` `[agent <name>] [--domain <name>] [--with <skill>...]` | Install a domain plus one agent adapter; default domain: `sdlc-full`, default agent: `none` |
| `uninstall` `[--yes]` | Reverse install: remove `.cumaru/` and the schema-selected adapter's Cumaru-owned artifacts |
| `intake` `<KEY> [--tracker <name>]` | Fetch a tracker issue and mirror it at the domain schema's intake item path (adapters: jira, linear, clickup) |
| `tag` `[FILE] [<get\|set> <tag> [<content>]]` | Inspect / get / set `<!-- cumaru:* -->` marker blocks; schema-validated |
| `coverage` `[--refs\|--gaps\|--rows] [--strict]` | Report which repository source files are referenced by the specification pillar's `reference` tables — covered / uncovered / stale / invalid |
| `tree` `[<path>] [--deep] [--rows] [--pillars <names>] [--domain <name>]` | List filesystem-backed candidates and their summaries; optionally restrict them to schema pillars or guard the installed domain |
| `update` `[<path>] [--from <src>] [--keep-prose] [--apply]` | Refresh same-major framework content and agent artifacts while preserving tag bodies; major-version apply is blocked |
| `update agent` `<name> [--apply]` | Preview or apply a native adapter switch; `none` restores YAML null |
| `upgrade` | Update the `cumaru` tool itself: re-runs the install script, replaces `~/.cumaru`, and verifies kernel integrity |
| `flow` `<src> <verb> [<dst>]` | Safe mechanical file ops inside `.cumaru/` (verbs: `move` \| `copy` \| `create` \| `remove`). Recipe skills compose calls to it |
| `migrate` `[v6] [--from <src>] [--apply]` | Migrate legacy naming or transactionally cross a supported framework major |

Per-command details live in `cumaru <cmd> --help`.

Higher-level workflows — plan authoring, exploration, spec bootstrap/deepen/consolidate, plan archival — are **skill-driven**, not CLI subcommands. The domain-shipped skills (`cumaru-plan`, `cumaru-explore`, `cumaru-specs`, `cumaru-archive`, …) carry the recipes; they compose `cumaru tag`, `cumaru flow`, `cumaru intake`, and direct file edits.

`cumaru intake` reads per-tracker credentials from `.env` (auto-loaded): `ATLASSIAN_DOMAIN`/`ATLASSIAN_EMAIL`/`ATLASSIAN_API_TOKEN` (jira), `LINEAR_API_KEY` (linear), `CLICKUP_API_TOKEN` (clickup). See `cumaru intake --help`.

## Status

Framework version: **6**. Filesystem-backed navigation, required summaries, `cumaru tree`, v6-aware doctor checks, a transactional v5→v6 migration, and same-major update gates are implemented across Base, SDLC Full, SDLC Light, IaC, QA, and Vault Memory. Intake adapters are wired for Jira, Linear, and ClickUp; Basecamp remains deferred.
