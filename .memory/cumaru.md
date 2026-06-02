---
name: cumaru framework project
description: What cumaru is, repo layout, the CLI subcommands, and key conventions
type: project
originSessionId: 507d571c-f4de-4425-8d7c-cb5b12395a28
---
**Repo:** `/Users/gaspar/workspace/cumaru` locally; remote still uses the historical GitHub repository slug observed via `git remote -v`.

**What it is:** spec-driven, agent-friendly knowledge structure for codebases. Lives at `.cumaru/` in any project that adopts it. Distilled from the pilot project.

**Layout:**
```
cumaru/
├── cumaru                   ← bash CLI entry point (resolves symlinks via _resolve_self)
├── src/cmd_*.sh             ← subcommand modules sourced by cumaru
├── frameworks/              ← self-contained domains copied by `cumaru install`
├── skills/<name>/SKILL.md   ← published skills in Anthropic format (git, cumaru-cli)
└── .cumaru/                    ← dogfood (mostly empty)
```

**CLI subcommands** (current surface; see `cumaru help`):
- `doctor [--quiet]` — default; tree-wide health check with RAW and marker guards
- `install [--with <skill>...]` / `uninstall [--yes]` — fixed `.cumaru/` target, no custom target path
- `intake <KEY> [--tracker <name>]` — fetch tracker issue → `.cumaru/intake/<KEY>/` (adapters: jira, linear, clickup; Basecamp TODO)
- `update [<path>] [--from <src>] [--keep-prose] [--apply]` plus `update skills|commands|schema` — steady-state framework update; refuses on version mismatch; schema uses a dedicated destructive path
- `tag` / `tag <file>` / `tag get|set <file> <tag>` — `<!-- cumaru:NAME -->` block ops (schema reader — see [[v3_deferred]])
- `flow <src> <verb> [<dst>]` — guarded file ops inside `.cumaru/`
- `upgrade` — reruns install.sh and performs the distribution integrity check

**Env vars:**
- `CUMARU_DIR` is fixed to `.cumaru` in `src/common.sh`.
- `.env` at the project root is auto-loaded by `cumaru intake` only.

**Key v4 conventions:**
- Marker blocks: `<!-- cumaru:NAME -->` ... `<!-- /cumaru:NAME -->`. Marker NAME = path through the schema's node tree, colon-joined (`plans:plan:handoff:files`). **v4: every block body is a `[Link, Description]` markdown table — hardcoded shape, no per-tag column declarations.**
- Tag bodies + frontmatter values = adopter-owned; prose = framework-owned. See [[feedback_update_design]].
- Every md under `.cumaru/` carries `human_revised: false`; flip to `true` after a human pass. Schema declares required FM keys with a `!` suffix.
- `cumaru doctor` warns for lingering RAW blocks; `cumaru flow` resolves symlinked parents canonically and refuses escapes.
- `temp-archive-flow.delete-me.md` is the transient work file under `archive/<PLAN-ID>/` between archive Phase 1 and Phase 2.
- Every domain's `domain.md` carries an ASCII flow diagram showing the lifecycle (`intake`/`exploring` → `plans` → `archive` → absorb into durable pillar) with explicit cleanup of all transient entries after absorb. See [[frameworks_layout]].
- `.env`, `CLAUDE.md`, `AGENTS.md`, `.claude`, `.agents`, `.cumaru`, and `**/*.bkp.*` are gitignored.
- v4 model details (recursive node tree, tracker-agnostic intake, universal `[Link, Description]` tag shape) live in [[v4_model]].

**Pilot adopter:**

**Brew formula** (planned, not implemented): `Formula/cumaru.rb` in a tap repo. Auto-bump via `mislav/bump-homebrew-formula-action` on release tags.

**Skill-gated capabilities:** git mutations require `.cumaru/skills/git/SKILL.md` present; without it, every role uses git for reading only.
