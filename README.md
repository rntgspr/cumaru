```



▄████ ██ ██ ███▄███▄  ▀▀█▄ ████▄ ██ ██
██    ██ ██ ██ ██ ██ ▄█▀██ ██ ▀▀ ██ ██
▀████ ▀██▀█ ██ ██ ██ ▀█▄██ ██    ▀██▀█


```

# `.cumaru/` framework

A spec-driven, agent-friendly knowledge framework for any project that can be version-controlled or stored as text—codebases,
design systems, research notes, legal docs, or any other discipline. It lives at `.cumaru/` in any repo or folder that adopts it.
This repository hosts the framework definition, the `cumaru` CLI, and the published skills.

## Installing the `cumaru` CLI

```bash
curl -fsSL https://pixelpunk.works/cumaru/install.sh | bash
```

Installs to `~/.cumaru` and symlinks `cumaru` into `~/.local/bin`. To update the tool later, run **`cumaru upgrade`** — it re-runs this same script, which replaces `~/.cumaru` wholesale (wipe + fresh shallow clone) and verifies the snapshot's kernel integrity (every domain's `index.md` byte-identical to `__base`'s) before linking.

Alternatively, clone the repo and symlink `cumaru` onto your PATH — then `git pull` to update.

## Why

The original Apache HTTP server had a simple idea: each directory could carry an `index.html` that described its contents — navigable without prior knowledge of what was inside. Without one, the server generated a listing. Either way, the directory was *self-describing*.

`.cumaru/` brings that convention to any version-controlled tree and extends it for agents. Every directory in the tree carries an `index.md` that declares its contents, its loading rules, and what an agent must pull before acting. The agent reads only what is declared; everything else stays on disk, version-controlled, but out of context.

> **Load only what is declared. Everything else stays on disk but out of context.**

`schema.yaml` describes the whole tree as one recursive node under `root:`. Every folder is a node; every node can have children. Adding a new area or pillar is a schema edit — no code change, no special tooling. The default domain ships five pillars suited for execution work, but the model is not bound to any discipline — software, design, research, legal, or anything else that lives in a folder.

## Framework layout

Every `.cumaru/` tree shares the same skeleton: a root `index.md` (front door), a `schema.yaml` (the node contract), and any number of pillar directories — each with its own `index.md` shallow index. The pillars are **schema-defined**, not hardcoded; adding or renaming one is a schema edit.

```
.cumaru/
├── index.md      ← framework kernel: load rules, node model — byte-identical across domains
├── domain.md     ← domain hook: pillars, roles, entry points + the adopter's components/root blocks
├── schema.yaml   ← canonical contract: one recursive node tree (root)
├── roles/        ← agent role definitions
├── templates/    ← entity templates
├── <pillar>/     ← any pillar declared in schema.yaml
│   ├── index.md  ← pillar's shallow index (required)
│   └── …
└── <pillar>/
    ├── index.md  ← every pillar must have one
    └── …
```

The front door splits in two: `index.md` is the **kernel** — the loading rule, the node model, conduct and language rules — identical in every domain and updated from source. `domain.md` is the **domain hook**, declared as the kernel's `depends-on`: it carries everything domain-specific (pillars, roles, how work enters) plus the two adopter-owned marker blocks — the `<!-- cumaru:components -->` table and the `<!-- cumaru:root -->` project-context prose.

Every pillar directory **must** contain an `index.md` — it is the shallow index the agent reads before deciding whether to drill deeper. Without it, the pillar is invisible to the loading rules.

Four starting points ship with this repository:

- **`frameworks/__base/`** — the minimal kernel: no pillars, an empty `entities:` map. Start here to build a custom domain from scratch.
- **`frameworks/sdlc-it-project-basic/`** *(default)* — software delivery workflows. Pillars: `intake`, `plans`, `archive`, `specs`, `exploring`.
- **`frameworks/iac-basic/`** — tool-agnostic infrastructure-as-code. Pillars: `intake`, `plans`, `archive`, `topology`, `exploring`, `runbooks`; the `apps:` axis enumerates environments.
- **`frameworks/qa-basic/`** — test strategy & coverage. Pillars: `intake`, `plans`, `archive`, `coverage`, `exploring`, `standards`.
- **`frameworks/vault-memory/`** — memory-vault workflow. Pillars: `inbox`, `drafts`, `memories`, `attachments`; durable memories are typed graph nodes.

Each domain is **self-contained** (its own `schema.yaml` + starter files + skills); you install one, they don't compose. A different domain — research notes, legal matter management, design system documentation — would declare different pillars in its own `schema.yaml` while the skeleton stays identical.

## What the framework is

A recursive node tree where every node is a directory with an `index.md`. The root node is `.cumaru/` itself; its direct children are the **pillars** — the top-level categories of knowledge for that project. `schema.yaml` declares everything: which pillars exist, what frontmatter each `index.md` carries, what columns each shallow index renders, and which nodes are never loaded by default.

Two structural fixtures ship with every installation regardless of domain:

- **`roles/`** — agent role definitions: who reads what, who writes where, and under what conditions.
- **`templates/`** — entity templates used when creating new nodes.

Everything else — pillars, entity shapes, domain conventions — is defined by the domain's `schema.yaml` and described in its `domain.md`. The minimal base (`frameworks/__base/`) ships no pillars; the SDLC domain ships five pillars and a Lead/Dev/Ghost role set (see [`frameworks/sdlc-it-project-basic/domain.md`](frameworks/sdlc-it-project-basic/domain.md)); IaC and QA ship their own pillar sets and role pairs. The loading rule itself lives in the kernel [`frameworks/__base/index.md`](frameworks/__base/index.md), shared verbatim by all domains.

## How it compares

The framework grew out of the web development / software tooling space, so the closest reference points are tools from that ecosystem — but the structural differences hold for any discipline that adopts it:

- **vs. OpenSpec** — OpenSpec keeps specs monolithic per capability. `.cumaru/` splits by concern, supports per-component divergence, allows plans alongside ticket IDs, and keeps pre-plan ideation separate from the active work tree.
- **vs. GitHub Spec Kit** — Spec Kit recreates intake locally and grows verbose; the archive becomes context noise. `.cumaru/` mirrors the work tracker instead of duplicating it (tracker-agnostic: jira / linear / clickup / …), and curates the archive so it never loads by default.
- **vs. Kiro / EARS notation** — `.cumaru/` adopts EARS for acceptance criteria as a **warning**, not a blocker. Narrative sections (overview, decisions, history, notes) stay free prose. EARS is encouraged where the requirement is testable, not enforced everywhere.
- **vs. memory bank (Cline / Roo)** — memory bank focuses on session state. `.cumaru/` focuses on durable project state: a living spec, an operational plan, a curated archive, and a space for pre-plan ideas — independent of any single session.

## Adopting it in a project

```bash
# Inside the project that will adopt the framework:
cumaru install                                      # SDLC domain (default)
cumaru install --domain base                        # minimal kernel — build your own pillars
cumaru install --domain iac-basic                   # infrastructure-as-code domain
cumaru install --domain qa-basic                    # test strategy & coverage domain
cumaru install --domain vault-memory                # personal/team memory vault domain

# Opt-in skills (added on top of the domain-shipped set):
cumaru install --with git                           # unlocks mutating git commands
cumaru install --domain iac-basic --with terraform --with pulumi
```

Install copies the domain into `.cumaru/`, then installs operating skills and slash commands into `.agents/`. Every domain ships the universal set (`cumaru-doctor`, `cumaru-update`, `cumaru-refs`), its own tuned `cumaru-install`, plus one skill per pillar that needs orchestration (SDLC: `cumaru-intake`, `cumaru-explore`, `cumaru-plan`, `cumaru-specs`, `cumaru-archive`). Mechanical primitives `cumaru tag`, `cumaru flow`, and `cumaru coverage` are CLI-only — no skill needed; the recipe skills compose them. Opt-in skills like `git` only ship when explicitly added via `--with` (without `git`, roles stay read-only on the repo: `status`, `log`, `diff`, `blame`, `show`).

The post-install work is **LLM-driven via the installed skills**:
1. **Components** — the `cumaru-install` skill walks the user through editing `.cumaru/domain.md`'s components table and `meta.apps.values` in `.cumaru/schema.yaml`.
2. **Spec bootstrap** — the `cumaru-specs` skill (SDLC domain) walks the user through identifying functional areas and seeding `specs/<area>/index.md` skeletons.
3. **Validate** — run `cumaru` (or `cumaru doctor`) any time to check schema conformance, orphans, and file refs.

## Skills (Claude integration)

Skills follow the official Anthropic format (`SKILL.md` with frontmatter). They are organized in two tiers:

**Domain-shipped skills** at `frameworks/<domain>/skills/cumaru-*/` — installed into the selected agent skill dirs with the domain. Every domain carries the universal set:

- `cumaru-doctor` — run the health checks, interpret orphans, propose fixes.
- `cumaru-update` — pull framework-file updates from the source, replace skills and slash commands; adjudicate frontmatter key drift, tag-body reshapes, orphan/relocated tags.
- `cumaru-refs` — spec↔code reference coverage: adjudicate the gaps `cumaru coverage` reports and wire source files into spec `reference` tables.

…plus `cumaru-install` (adopt the framework, then bootstrap the durable pillar) — shipped by every domain but **domain-owned**: its post-install recipe hands off to the domain's pillar skill (`cumaru-specs` / `cumaru-topology` / `cumaru-coverage`), so it is exempt from the kernel drift-check.

…plus its own orchestration skills, one per pillar that needs them:

- **SDLC**: `cumaru-intake` (mirror a tracker issue under `intake/<KEY>/`), `cumaru-explore`, `cumaru-plan`, `cumaru-specs`, `cumaru-archive`.
- **IaC**: `cumaru-intake`, `cumaru-explore`, `cumaru-plan`, `cumaru-topology` (≈ specs for stacks; `depends-on` = apply order), `cumaru-archive`, plus `cumaru-arch` (render the topology graph as Mermaid/ASCII, read-only).
- **QA**: `cumaru-intake`, `cumaru-explore`, `cumaru-plan`, `cumaru-coverage`, `cumaru-archive`.
- **Vault Memory**: `cumaru-capture`, `cumaru-draft`, `cumaru-distill`, `cumaru-link`.

**Slash commands** at `frameworks/<domain>/commands/cumaru/*.md` — installed into the selected agent command dirs. Each is a user-invoked entry point (`/cumaru:plan`, `/cumaru:explore`, `/cumaru:topology`, …) that loads the matching skill and dispatches by intent. Skills without lifecycle (e.g. `cumaru-arch`) have no command — they trigger on conversation.

**Opt-in skills** at the top-level `skills/<name>/` (no `cumaru-` prefix) — installed only with `--with <name>`:

- [`git`](skills/git/SKILL.md) — unlocks mutating git commands (`commit`/`push`/`reset`/…) under the framework's skill-gated capability rule.
- [`terraform`](skills/terraform/SKILL.md) / [`pulumi`](skills/pulumi/SKILL.md) — IaC tool mechanics + the domain's safety discipline (never apply unread; the plan diff IS the blast radius).
- [`pytest`](skills/pytest/SKILL.md) / [`vitest`](skills/vitest/SKILL.md) / [`playwright`](skills/playwright/SKILL.md) / [`cypress`](skills/cypress/SKILL.md) — test-runner mechanics for the QA domain.

**Mechanical primitives — no skill needed.** `cumaru tag` (read/write `<!-- cumaru:NAME -->` marker blocks; schema-validated), `cumaru flow` (4 verbs: `move`/`copy`/`create`/`remove`, with guardrails), and `cumaru coverage` (read-only spec↔code coverage report over `reference` tables) are documented in `cumaru <cmd> --help`. Every recipe skill above composes calls to them.

**Using with Claude Code or Codex:** `cumaru install` wires everything under `.agents/`. The instruction file is `.agents/AGENTS.md`. `cumaru update --apply` refreshes skills and commands for the detected installed agent target(s).

**Using with claude.ai:** upload `SKILL.md` via the custom skills UI, or automate via the Skills API. claude.ai does not watch the repo — re-upload (or trigger an API call from CI) when a skill changes.

## Index tables — the universal shape

v4 ships one canonical shape for every `<!-- cumaru:NAME -->` marker block in the tree: a markdown table with exactly two columns — **Link** and **Description**.

```markdown
<!-- cumaru:plans -->
| Link                          | Description                                       |
|-------------------------------|---------------------------------------------------|
| [AAA-1234](AAA-1234/index.md) | Migrate the auth middleware to the new session API |
| [maintenance-deps](maintenance-deps/index.md) | Bump runtime deps and refresh lockfiles   |
<!-- /cumaru:plans -->
```

Every tag in every domain renders this way — pillar indexes, the `<!-- cumaru:components -->` block in `domain.md`, the `<!-- cumaru:files -->` block in a handoff, the templates inventory. The shape is **hardcoded in the parser, doctor, update, and the `cumaru tag` CLI** — schemas no longer declare per-tag columns. Adding a new tag is just `host_file:` routing; the body shape is implicit.

The two columns are deliberate: a link the agent (or a human) can follow, and one line of prose that says what is on the other side — enough signal to prune by relevance under the loading rule, no more.

## Versioning

The schema declares a `version:` (currently `4`). Each project that adopts the framework copies the schema and declares `framework-version: <N>` in its `.cumaru/index.md`. The validator enforces equality — version drift between the schema and the project's declaration surfaces as an explicit error.

When the framework introduces a breaking change, bump `schema.yaml` `version:` and document the migration in this repo. Adopting projects bump `framework-version:` in their `.cumaru/index.md` after applying the migration.

## CLI subcommands

Run `cumaru help` (or `cumaru <cmd> --help`) for full usage.

| Subcommand | Purpose |
|---|---|
| `doctor` *(default)* | Schema checks + tree-wide health (orphans both ways, stale work-marker files, file refs, external tools) |
| `install` `[--domain <name>] [--with <skill>...]` | Install a domain into a project's `.cumaru/`; default domain: `sdlc-it-project-basic` |
| `uninstall` `[DIR] [-y]` | Reverse of install: strip agent hooks, drop `.cumaru/` |
| `intake` `<KEY> [--tracker <name>]` | Fetch a tracker issue and mirror it as a flat item under `.cumaru/intake/<KEY>/` (adapters: jira, linear, clickup) |
| `tag` `[FILE] [<get\|set> <tag> [<content>]]` | Inspect / get / set `<!-- cumaru:* -->` marker blocks; schema-validated |
| `coverage` `[--refs\|--gaps\|--rows] [--strict]` | Report which repository source files are referenced by the specification pillar's `reference` tables — covered / uncovered / stale / invalid |
| `update` `[<path>] [--from <src>] [--keep-prose] [--apply]` | Update `.cumaru/` files, skills, and slash commands from the source; preserves frontmatter values + tag bodies. Version mismatch is reported as a migration review, not blocked |
| `upgrade` | Update the `cumaru` tool itself: re-runs the install script (replaces `~/.dot-llm` wholesale, verifies kernel integrity across domains) |
| `flow` `<src> <verb> [<dst>]` | Safe mechanical file ops inside `.cumaru/` (verbs: `move` \| `copy` \| `create` \| `remove`). Recipe skills compose calls to it |

Per-command details live in `cumaru <cmd> --help`.

Higher-level workflows — plan authoring, exploration, spec bootstrap/deepen/consolidate, plan archival — are **skill-driven**, not CLI subcommands. The domain-shipped skills (`cumaru-plan`, `cumaru-explore`, `cumaru-specs`, `cumaru-archive`, …) carry the recipes; they compose `cumaru tag`, `cumaru flow`, `cumaru intake`, and direct file edits.

`cumaru intake` reads per-tracker credentials from `.env` (auto-loaded): `ATLASSIAN_DOMAIN`/`ATLASSIAN_EMAIL`/`ATLASSIAN_API_TOKEN` (jira), `LINEAR_API_KEY` (linear), `CLICKUP_API_TOKEN` (clickup). See `cumaru intake --help`.

## Status

Framework version: **4** (universal `[Link, Description]` shape for every marker block — pillar indexes, components table, handoff files, templates inventory; per-tag column declarations are gone from every schema). The base kernel plus three domains (SDLC, IaC, QA), the `cumaru` CLI, the domain-shipped skills and slash commands, and the seven opt-in skills are all v4-shaped. Intake adapters wired: jira, linear, clickup (Basecamp deferred). The v3 → v4 migration procedure (fuse extra columns into the Description prose) is documented but has not yet been exercised against a real v3 tree — expect rough edges on first dogfooding.
