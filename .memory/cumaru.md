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
├── domains/                 ← self-contained domains copied by `cumaru install`
├── skills/<name>/SKILL.md   ← opt-in skills
├── tests/                   ← shell regression suite
└── .cumaru/                 ← dogfood entry point when present
```

**CLI subcommands** (current surface; see `cumaru help`):
- `doctor [--quiet]` — default; v6-only navigation, summary, marker, reference, tool, and agent-integration checks; older trees must migrate first
- `domains` — list installable domains discovered from `domains/`
- `install [--domain <name>] [--with <skill>...]` / `uninstall [--yes]` — fixed `.cumaru/` target
- `intake <KEY> [--tracker <name>]` — fetch tracker issue at the installed domain's schema-declared path (jira, linear, clickup)
- `tree [<directory-or-md>] [--deep] [--rows] [--pillars <names>] [--domain <name>]` — read-only filesystem-backed navigation with schema pillar filters and an installed-domain guard
- `update [<path>] [--from <src>] [--keep-prose] [--apply]` plus `update skills|hooks|commands|schema` — same-major steady-state refresh
- `migrate [--apply]` / `migrate v6 [--from <src>] [--apply]` — legacy rename or transactional major migration
- `tag` / `tag <file>` / `tag get|set <file> <tag>` — schema-validated semantic marker operations
- `coverage [--refs|--gaps|--rows] [--strict]` — reference coverage over repository source files
- `flow <src> <verb> [<dst>]` — guarded file ops inside `.cumaru/`
- `upgrade` — reruns install.sh and performs the distribution integrity check

**Env vars:**
- `CUMARU_DIR` is fixed to `.cumaru` in `src/common.sh`.
- `.env` at the project root is auto-loaded by `cumaru intake` only.

**Key v6 conventions:**
- The filesystem is structural truth. `index.md` explains a directory; `cumaru tree` lists children by `summary:`. Structural marker inventories no longer exist.
- Every non-hidden directory has `index.md`; every Markdown file has a trimmed 32–256 character `summary:`.
- Marker blocks are semantic adopter data. Their schema-declared types are `default`, custom columns, `prose`, `mixed`, or `other`.
- Framework-owned Markdown is refreshed from source by same-major update while marker bodies are preserved; local-only files remain adopter-owned.
- Every md under `.cumaru/` carries `human_revised`; required schema keys use a `!` suffix.
- `cumaru doctor` warns for lingering RAW blocks; `cumaru flow` resolves symlinked parents canonically and refuses escapes.
- `temp-archive-flow.delete-me.md` is the transient work file under `archive/<PLAN-ID>/` between archive Phase 1 and Phase 2.
- Every domain's `domain.md` carries an ASCII flow diagram showing the lifecycle (`intake`/`exploring` → `plans` → `archive` → absorb into durable pillar) with explicit cleanup of all transient entries after absorb. See [[frameworks_layout]].
- `.env`, `CLAUDE.md`, `AGENTS.md`, `.claude`, `.agents`, `.cumaru`, and `**/*.bkp.*` are gitignored.
- Current model details live in [[v6_virtual_tree]]. v4/v5 memories remain historical design records.

**Pilot adopter:**

**Brew formula** (planned, not implemented): `Formula/cumaru.rb` in a tap repo. Auto-bump via `mislav/bump-homebrew-formula-action` on release tags.

**Skill-gated capabilities:** git mutations require `.agents/skills/git/SKILL.md`; without it, roles use git for reading only.
