# `.llm/` framework

A spec-driven, agent-friendly knowledge structure for any project that can
be version-controlled or stored as text — codebases, design systems, research
notes, legal docs, or any other discipline. Lives at `.llm/` in any repo or
folder that adopts it. This repository hosts the framework definition, the
`llm` CLI, and the published skills.

## Installing the `llm` CLI

> The dot-llm repo is currently private; access requires an SSH key authorized for `rntgspr/dot-llm`.

```bash
curl -fsSL https://pixelpunk.works/dot-llm/install.sh | bash
```

Installs to `~/.dot-llm` and symlinks `llm` into `~/.local/bin`. **The same command updates in place** — re-run it any time and the script does `git pull --ff-only` on `~/.dot-llm` if it already exists.

Alternatively, clone the repo and symlink `llm` onto your PATH — then `git pull` to update.

## Why

The original Apache HTTP server had a simple idea: each directory could carry an `index.html` that described its contents — navigable without prior knowledge of what was inside. Without one, the server generated a listing. Either way, the directory was *self-describing*.

`.llm/` brings that convention to any version-controlled tree and extends it for agents. Every directory in the tree carries an `index.md` that declares its contents, its loading rules, and what an agent must pull before acting. The agent reads only what is declared; everything else stays on disk, version-controlled, but out of context.

> **Load only what is declared. Everything else stays on disk but out of context.**

`schema.yaml` describes the whole tree as one recursive node under `root:`. Every folder is a node; every node can have children. Adding a new area or pillar is a schema edit — no code change, no special tooling. The starter ships a default set of five pillars suited for execution work, but the model is not bound to any discipline — software, design, research, legal, or anything else that lives in a folder.

## Framework layout

Every `.llm/` tree shares the same skeleton: a root `index.md` (front door), a `schema.yaml` (the node contract), and any number of pillar directories — each with its own `index.md` shallow index. The pillars are **schema-defined**, not hardcoded; adding or renaming one is a schema edit.

```
.llm/
├── index.md      ← front door: components, load rules, framework-version
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

Every pillar directory **must** contain an `index.md` — it is the shallow index the agent reads before deciding whether to drill deeper. Without it, the pillar is invisible to the loading rules.

Two starting points ship with this repository:

- **`frameworks/__base/`** — the minimal kernel: `index.md`, `schema.yaml` with an empty `entities:` map, and `templates/any-index.md`. No pillars, no roles. Start here to build a custom domain from scratch.
- **`frameworks/sdlc-it-project-basic/`** — a ready-made flavor for software delivery workflows (SDLC). Its five pillars:

```
intake/     ← tracker-agnostic mirror of work items (jira / linear / clickup / …)
plans/      ← active execution plans (plan + tasks/handoffs/delta-draft)
archive/    ← completed plans + finalized deltas — never loaded by default
specs/      ← living spec, updated on plan close via delta absorption
exploring/  ← pre-plan ideas — never loaded by default
```

A different flavor — research notes, legal matter management, design system documentation — would declare different pillars in its own `schema.yaml` while the skeleton stays identical.

## What the framework is

A recursive node tree where every node is a directory with an `index.md`. The root node is `.llm/` itself; its direct children are the **pillars** — the top-level categories of knowledge for that project. `schema.yaml` declares everything: which pillars exist, what frontmatter each `index.md` carries, what columns each shallow index renders, and which nodes are never loaded by default.

Two structural fixtures ship with every installation regardless of flavor:

- **`roles/`** — agent role definitions: who reads what, who writes where, and under what conditions.
- **`templates/`** — entity templates used when creating new nodes.

Everything else — pillars, entity shapes, loading rules — is defined by the flavor's `schema.yaml`. The minimal base (`frameworks/__base/`) ships no pillars; the SDLC flavor (`frameworks/sdlc-it-project-basic/`) ships five pillars and a Lead/Dev/Ghost role set; its full descriptions and loading rules are in [`frameworks/sdlc-it-project-basic/index.md`](frameworks/sdlc-it-project-basic/index.md).

## How it compares

The framework grew out of the web development / software tooling space, so the closest reference points are tools from that ecosystem — but the structural differences hold for any discipline that adopts it:

- **vs. OpenSpec** — OpenSpec keeps specs monolithic per capability. `.llm/` splits by concern, supports per-component divergence, allows plans alongside ticket IDs, and keeps pre-plan ideation separate from the active work tree.
- **vs. GitHub Spec Kit** — Spec Kit recreates intake locally and grows verbose; the archive becomes context noise. `.llm/` mirrors the work tracker instead of duplicating it (tracker-agnostic: jira / linear / clickup / …), and curates the archive so it never loads by default.
- **vs. Kiro / EARS notation** — `.llm/` adopts EARS for acceptance criteria as a **warning**, not a blocker. Narrative sections (overview, decisions, history, notes) stay free prose. EARS is encouraged where the requirement is testable, not enforced everywhere.
- **vs. memory bank (Cline / Roo)** — memory bank focuses on session state. `.llm/` focuses on durable project state: a living spec, an operational plan, a curated archive, and a space for pre-plan ideas — independent of any single session.

## Adopting it in a project

```bash
# Inside the project that will adopt the framework:
llm install                                      # SDLC flavor (default)
llm install --framework base                     # minimal kernel — build your own pillars
llm install --framework sdlc-it-project-basic    # explicit SDLC flavor

# Opt-in skills (added on top of the auto-installed set):
llm install --with git                           # unlocks mutating git commands
```

Install always copies the **operating skills** the LLM needs to work in the tree — universal ones (`llm-doctor`, `llm-install`, `llm-sync`) and any the chosen flavor ships (SDLC adds `llm-intake`, `llm-explore`, `llm-plan`, `llm-specs`, `llm-archive`, one per pillar that needs orchestration). Mechanical primitives `llm tag` and `llm flow` are CLI-only — no skill needed; the recipe skills compose them. Opt-in skills like `git` only ship when explicitly added via `--with` (without `git`, roles stay read-only on the repo: `status`, `log`, `diff`, `blame`, `show`).

The post-install work is **LLM-driven via the installed skills**:
1. **Components** — the `llm-install` skill walks the user through editing `.llm/index.md`'s components table and `meta.apps.values` in `.llm/schema.yaml`.
2. **Spec bootstrap** — the `llm-specs` skill (SDLC flavor) walks the user through identifying functional areas and seeding `specs/<area>/index.md` skeletons.
3. **Validate** — run `llm` (or `llm doctor`) any time to check schema conformance, orphans, and file refs.

## Skills (Claude integration)

Skills follow the official Anthropic format (`SKILL.md` with frontmatter). They are organized in two tiers:

**Universal skills** at `skills/llm-*/` — auto-installed for every flavor (kernel or any flavor). These cover multi-step orchestration that doesn't fit in `--help`:

- [`skills/llm-doctor/SKILL.md`](skills/llm-doctor/SKILL.md) — run the health checks, interpret orphans, propose fixes.
- [`skills/llm-install/SKILL.md`](skills/llm-install/SKILL.md) — adopt the framework, then walk the user through the components edit.
- [`skills/llm-sync/SKILL.md`](skills/llm-sync/SKILL.md) — pull framework-file updates from the source; adjudicate frontmatter key drift and tag-body reshapes.

**Flavor-specific skills** at `frameworks/<flavor>/skills/llm-*/` — copied into `.llm/skills/` only when the flavor is installed. The SDLC flavor ships:

- [`frameworks/sdlc-it-project-basic/skills/llm-intake/SKILL.md`](frameworks/sdlc-it-project-basic/skills/llm-intake/SKILL.md) — mirror a tracker issue under `intake/<KEY>/` (Jira adapter today; ClickUp / Linear / Basecamp planned).
- [`frameworks/sdlc-it-project-basic/skills/llm-explore/SKILL.md`](frameworks/sdlc-it-project-basic/skills/llm-explore/SKILL.md) — bootstrap an exploration; promote it to a plan, or drop it.
- [`frameworks/sdlc-it-project-basic/skills/llm-plan/SKILL.md`](frameworks/sdlc-it-project-basic/skills/llm-plan/SKILL.md) — author the plan + tasks + handoffs + delta draft.
- [`frameworks/sdlc-it-project-basic/skills/llm-specs/SKILL.md`](frameworks/sdlc-it-project-basic/skills/llm-specs/SKILL.md) — bootstrap an area, deepen with EARS-style requirements, consolidate accumulated deltas.
- [`frameworks/sdlc-it-project-basic/skills/llm-archive/SKILL.md`](frameworks/sdlc-it-project-basic/skills/llm-archive/SKILL.md) — close a plan, finalize its delta, absorb into `specs/`, remove the plan tree.

**Opt-in skills** at `skills/<name>/` (no `llm-` prefix) — installed only with `--with <name>`:

- [`skills/git/SKILL.md`](skills/git/SKILL.md) — unlocks mutating git commands (`commit`/`push`/`reset`/…) under the framework's skill-gated capability rule.

**Mechanical primitives — no skill needed.** `llm tag` (read/write `<!-- llm:NAME -->` marker blocks; schema-validated) and `llm flow` (4 verbs: `move`/`copy`/`create`/`remove`, with 4 guardrails) are documented in `llm <cmd> --help`. Every recipe skill above composes calls to them.

**Using with Claude Code:** clone this repo and point Claude Code at the `skills/` directory (project skills, or `~/.claude/skills/` if you want it global). `git pull` updates the skills in place. The flavor-shipped skills only enter context once installed in an adopting project.

**Using with claude.ai:** upload `SKILL.md` via the custom skills UI, or automate via the Skills API. claude.ai does not watch the repo — re-upload (or trigger an API call from CI) when a skill changes.

## Versioning

The schema declares a `version:` (currently `3`). Each project that adopts the framework copies the schema and declares `framework-version: <N>` in its `.llm/index.md`. The validator enforces equality — version drift between the schema and the project's declaration surfaces as an explicit error.

When the framework introduces a breaking change, bump `schema.yaml` `version:` and document the migration in this repo. Adopting projects bump `framework-version:` in their `.llm/index.md` after applying the migration.

## CLI subcommands

Run `llm help` (or `llm <cmd> --help`) for full usage.

| Subcommand | Purpose |
|---|---|
| `doctor` *(default)* | Schema checks + tree-wide health (orphans both ways, stale work-marker files, file refs, external tools) |
| `install` `[DIR] [--framework <name>] [--with <skill>...]` | Install a framework flavor into a project's `.llm/`; default flavor: `sdlc-it-project-basic` |
| `uninstall` `[DIR] [-y]` | Reverse of install: strip the CLAUDE.md hook, drop `.llm/` |
| `intake` `<KEY>` | Fetch a tracker issue and mirror it as a flat item under `.llm/intake/<KEY>/` (Jira adapter today) |
| `tag` `[FILE] [<get\|set> <tag> [<content>]]` | Inspect / get / set `<!-- llm:* -->` marker blocks; schema-validated |
| `sync` `[<path>] [--from <src>] [--keep-prose] [--apply]` | Steady-state update of `.llm/` from the framework source; preserves frontmatter values + tag bodies. Refuses on version mismatch |
| `flow` `<src> <verb> [<dst>]` | Safe mechanical file ops inside `.llm/` (verbs: `move` \| `copy` \| `create` \| `remove`). Recipe skills compose calls to it |

Per-command details live in `llm <cmd> --help`.

Higher-level workflows — plan authoring, exploration, spec bootstrap/deepen/consolidate, plan archival — are **skill-driven**, not CLI subcommands. The flavor-shipped skills (`llm-plan`, `llm-explore`, `llm-specs`, `llm-archive`, …) carry the recipes; they compose `llm tag`, `llm flow`, `llm intake`, and direct file edits.

`llm intake` requires `ATLASSIAN_DOMAIN`, `ATLASSIAN_EMAIL`, and `ATLASSIAN_API_TOKEN` (auto-loaded from `.env`).

## Status

Framework version: **3** (recursive node tree, tracker-agnostic intake, lean indexes, multi-flavor layout). The base kernel (`frameworks/__base/`), the SDLC flavor (`frameworks/sdlc-it-project-basic/`), the `llm` CLI, and the eight published skills (3 universal + 5 SDLC-flavor) are all v3-shaped. The v2 → v3 migration procedure for an existing project is documented but has not yet been exercised against a real v2 tree — expect rough edges on first dogfooding.
