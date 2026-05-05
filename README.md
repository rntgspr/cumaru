# `.llm/` framework

A spec-driven, agent-friendly knowledge structure for codebases. Lives at `.llm/` in any project that adopts it. This repository hosts the framework definition, the `llm` CLI, and the published skills.

## Installing the `llm` CLI

> The dot-llm repo is currently private; access requires an SSH key authorized for `rntgspr/dot-llm`.

```bash
curl -fsSL https://pixelpunk.works/dot-llm/install.sh | bash
```

Installs to `~/.dot-llm` and symlinks `llm` into `~/.local/bin`. To update, run `llm update` or re-run the curl command.

Alternatively, clone the repo and symlink `llm` onto your PATH — then `llm update` or `git pull` to update.

## Why

Two opposite trade-offs show up across current spec-driven approaches:

1. **Frameworks like GitHub Spec Kit and OpenSpec lean toward loading a lot.** Specs and change files often land in the prompt by default; on bigger projects the context window fills quickly.
2. **Without any framework, the LLM tends to re-explore the codebase each session** — which can be slow and inconsistent across runs.

`.llm/` splits durable context into **four pillars** plus an ideation space, with explicit declaration rules for what loads. The LLM reads only what the active task points to; the rest stays on disk, version-controlled, but out of context.

> **Load only what is declared. Everything else stays on disk but out of context.**

## Framework layout

Once installed, a project's `.llm/` looks like this:

```
.llm/
├── index.md         ← front door: component table, load rules, framework-version
├── schema.yaml      ← canonical contract (frontmatter fields, apps enum, EARS, sync config)
├── intake/          ← issue-tracker mirror (Jira today; tracker-agnostic by design)
├── plans/           ← active execution plans (EARS criteria, scope, DAG of tasks)
├── archive/         ← completed plans — never loaded by default
├── specs/           ← living spec, updated on plan close via delta absorption
├── exploring/       ← pre-plan ideas — never loaded by default
├── reviews/         ← review artifacts
├── roles/           ← lead, dev, ghost role definitions
└── templates/       ← entity templates (plan, task, spec, delta, handoff, intake, ...)
```

## What the framework is

Four pillars + one ideation space, each loaded only on demand:

- **`intake/`** — issue-tracker mirror, synced mechanically (today: Jira; the structure is tracker-agnostic and could mirror Linear, Basecamp, GitHub Issues, etc.).
- **`plans/<PLAN-ID>/`** — execution plans (with EARS criteria, scope, DAG of tasks).
- **`archive/<PLAN-ID>/`** — completed plans, never loaded by default.
- **`specs/<area>/`** — living spec, kept current via delta absorption on plan close.
- **`exploring/<slug>/`** — pre-plan ideas, never loaded by default.

Roles are lean: **Lead** (authors `.llm/`, runs archive flow), **Dev** (implements code, writes hand-off and delta-draft inside the active plan only), **Ghost** (IDE-pair, read-only by default).

The full structure, universal rules, and instructions are in `dot-llm-framework/index.md`.

## How it compares

- **vs. OpenSpec** — OpenSpec keeps specs monolithic per capability. `.llm/` splits by concern, supports per-component divergence, allows slug-based plans alongside ticket IDs, and separates pre-plan ideas in `exploring/`.
- **vs. GitHub Spec Kit** — Spec Kit recreates intake locally and grows verbose; the archive becomes context noise. `.llm/` mirrors the issue tracker instead of duplicating it (Jira today, any tracker in principle), and curates the archive so it never loads by default.
- **vs. Kiro / EARS notation** — `.llm/` adopts EARS for acceptance criteria as a **warning**, not a blocker. Narrative sections (overview, decisions, history, notes) stay free prose. EARS is encouraged where the requirement is testable, not enforced everywhere.
- **vs. memory bank (Cline / Roo)** — memory bank focuses on session state. `.llm/` focuses on durable system state (living spec) plus operational plan plus curated archive plus pre-plan ideation.

## Adopting it in a project

```bash
# Inside the project that will adopt the framework:
llm install              # creates ./.llm/ from dot-llm-framework/

# Optional skills (opt-in at install time):
llm install --with git   # also unlocks mutating git commands
```

Skills live under `skills/<name>/SKILL.md` in this repo (Anthropic format) and are **not** part of the framework starter. They are copied into `.llm/skills/<name>/SKILL.md` only when requested via `--with <name>` at install time. Without them, the corresponding capability stays read-only across all roles (e.g. without `--with git`, roles use git only for `status`, `log`, `diff`, `blame`, `show`).

Then customize:
1. **`.llm/index.md`** — replace the placeholder Multi-component table with your project's actual components.
2. **`.llm/schema.yaml`** — under `apps.values`, add one entry per component. Keep `platform` and `meta` as reserved.
3. **Run `llm`** (or `llm validate`) to validate the structure.

## Skills (Claude integration)

Skills live under `skills/<name>/SKILL.md` and follow the official Anthropic format. They are **not** part of the framework starter — the starter only contains schema, roles, templates, and indexes. Skills are published separately so they can be:

- Added per project at install time: `llm install --with <name>` copies `skills/<name>/SKILL.md` into `.llm/skills/<name>/SKILL.md`.
- Loaded globally into Claude (Code or claude.ai) so any chat — even outside an adopting project — knows how to operate the tooling.

**Published skills:**
- [`skills/llm-cli/SKILL.md`](skills/llm-cli/SKILL.md) — operating the `llm` CLI itself (bootstrap from scratch + all subcommands). Recommended as a global skill in your Claude.
- [`skills/git/SKILL.md`](skills/git/SKILL.md) — unlocks mutating git commands (commit/push/reset/...) under the framework's skill-gated capability rule. Add per project with `llm install --with git`.

**Using with Claude Code:** clone this repo and point Claude Code at the `skills/` directory (project skills, or `~/.claude/skills/` if you want it global). `git pull` updates the skills in place.

**Using with claude.ai:** upload `SKILL.md` via the custom skills UI, or automate via the Skills API. claude.ai does not watch the repo — re-upload (or trigger an API call from CI) when a skill changes.

## Versioning

The schema declares a `version:` (currently `1`). Each project that adopts the framework copies the schema and declares `framework-version: <N>` in its `.llm/index.md`. The validator enforces equality — version drift between the schema and the project's declaration surfaces as an explicit error.

When the framework introduces a breaking change, bump `schema.yaml` `version:` and document the migration in this repo. Adopting projects bump `framework-version:` in their `.llm/index.md` after applying the migration.

## CLI subcommands

Run `llm help` (or `llm <cmd> --help`) for full usage. Summary:

| Subcommand | Purpose |
|---|---|
| `validate` *(default)* | Tier 1+2 schema checks against `.llm/` |
| `install [DIR] [--with <skill>...]` | Copy `dot-llm-framework/` into a project's `.llm/`; opt-in skills |
| `intake <JIRA-KEY>` | Fetch a Jira issue and mirror it under `.llm/intake/` (epic / story / ticket) |
| `framework sync [filter] [--apply]` | Update `.llm/` from a fresh framework source; preserves `BEGIN/END PROJECT-CUSTOM` blocks |
| `archive <PLAN-ID>` / `archive finalize` | Two-phase plan closure: copy to `archive/`, absorb deltas into specs, then drop `plans/<ID>/` |
| `regen index [pillar]` / `regen <JIRA-KEY>` | Regenerate shallow pillar indexes; chain-check (intake → plan → archive → specs) |
| `specs bootstrap / deep / consolidate` | Spec area discovery (light → incremental → heavy delta absorption) |
| `doctor` | Aggregate health check (validate + index drift + missing handoffs + external tools) |
| `update [--ref <branch\|tag>]` | Update the CLI checkout itself, plus skills and framework source |

`llm intake` requires `ATLASSIAN_DOMAIN`, `ATLASSIAN_EMAIL`, and `ATLASSIAN_API_TOKEN` (auto-loaded from `.env`).

## Validator (`llm validate`)

Tier 1 + 2 checks, hardcoded in bash (the schema is the canonical doc; the bash mirrors it):

- Every `.md` has at least one H1 heading.
- Every `index.md` carries `generated`, `apps` in frontmatter.
- Plans, tasks, spec areas, archive, exploring entries each have their required fields.
- `apps:` values are in the schema's `apps.values` enum.
- `framework-version:` in the project's `.llm/index.md` matches the schema's `version:`.
- EARS warning on acceptance criteria not matching `WHEN ... THE SYSTEM SHALL ...`.

Cross-file checks (scope path resolution, depends-on resolution, files-list verification, deltas references) are listed in `schema.yaml` under `cross_file_checks_deferred` and will land in a future version.

## Status

Framework version: **1** (initial extraction).
