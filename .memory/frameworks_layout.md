---
name: cumaru-frameworks-layout
description: Multi-domain framework layout — frameworks/__base kernel + frameworks/<name>/ variants; how install resolves them; universal vs domain-specific skills
metadata: 
  node_type: memory
  type: project
  originSessionId: ea685735-0853-461c-af23-330eda256308
---

> Historical layout. V6 renamed `frameworks/` to `domains/`, added
> `cumaru-summarize`, and installs agent artifacts under `.agents/`. See
> [[v6_virtual_tree]].

The cumaru repo is **multi-domain**. Each domain is **self-contained** (its own `schema.yaml` + starter files); the adopter picks one at install time. No merging, no inheritance.

## Repo layout

```
cumaru/
├── cumaru                                 # CLI entry
├── src/cmd_*.sh                        # universal CLI modules
├── frameworks/
│   ├── __base/                         # minimal kernel — universal rules + meta, no pillars
│   │   ├── schema.yaml
│   │   ├── index.md
│   │   └── templates/any-index.md
│   └── sdlc-it-project-basic/          # default domain
│       ├── schema.yaml
│       ├── index.md
│       ├── {intake,plans,archive,specs,exploring}/
│       ├── templates/
│       ├── roles/
│       └── skills/                     # domain-shipped skills (one per pillar that needs orchestration)
│           ├── cumaru-intake/SKILL.md    # mirror tracker issues into intake/
│           ├── cumaru-explore/SKILL.md   # bootstrap + promote/drop exploring/
│           ├── cumaru-plan/SKILL.md      # author plans, tasks, handoffs, delta-draft
│           ├── cumaru-specs/SKILL.md     # bootstrap + deepen + consolidate specs/
│           └── cumaru-archive/SKILL.md   # close+archive plans, absorb delta into specs/
└── skills/                             # UNIVERSAL skills (auto-installed for every domain) + opt-ins
    ├── cumaru-{doctor,install,sync}/      # 3 universal (auto) — multi-step orchestration
    └── git/                            # opt-in (--with git)
```

## Skill classification

**Skills exist only where there's real multi-step orchestration that can't fit in `--help`.** CLI primitives (mechanical, single-step, well-served by `--help`) ship without a skill.

- **Universal skills** (top-level `skills/cumaru-*/`, auto-installed everywhere): `cumaru-doctor`, `cumaru-install`, `cumaru-sync`. Each carries multi-step workflow (e.g. `cumaru-install`'s post-install Step 1, `cumaru-sync`'s key-drift adjudication, `cumaru-doctor`'s orphan-row reconciliation). `cumaru-install` Steps 2/3/4 (spec bootstrap/deepen/consolidate) were extracted into the sdlc-shipped `cumaru-specs` since they're sdlc-specific recurring work, not install-time work.
- **Domain-specific skills** (`frameworks/<domain>/skills/cumaru-*/`, ship via wholesale domain copy): five for sdlc — `cumaru-intake`, `cumaru-explore`, `cumaru-plan`, `cumaru-specs`, `cumaru-archive` — covering each pillar that needs orchestration (intake mirror, exploring lifecycle, plan authoring, spec maintenance, plan archival).
- **Opt-in skills** (non-`cumaru-*` at top-level `skills/`, via `--with <name>`): `git`.
- **CLI-only (no skill)**: `cumaru tag`, `cumaru flow`. Primitives whose semantics fit cleanly in `cumaru <cmd> --help`. Skills that compose them (intake, archive, install post-install) reference `cumaru tag get/set` and `cumaru flow move/copy/...` in their recipe bodies — no separate skill needed.

**Operational simplification note (2026-06-15):** the install target is fixed to `.cumaru/`; `cumaru update` gained dedicated `skills`, `commands`, and `schema` targets; `cumaru doctor` owns the RAW-block warning; `cumaru flow` now rejects dotted directory names and resolves paths canonically before every mutation.

**v4 note:** every `<!-- cumaru:* -->` body is `[Link, Description]` (hardcoded). Schema files no longer declare per-tag columns — only `host_file:` routing for meta tags. The same universal shape applies to domain-shipped pillar indexes and to opt-in skills' marker blocks alike.

**Why:** the dispatch cost of a skill (loading its full SKILL.md into context) is only earned when there's orchestration the LLM needs guidance for. Documenting 4 verbs + 4 guardrails is the help text's job, not a skill's.

## Install order (cmd_install.sh)

1. Wholesale `cp -R "$framework_src" "$target"` — brings the domain's `skills/` (and everything else) into target.
2. Auto-install loop over top-level `skills/cumaru-*/`: **skip-if-exists** (so domain overrides of a universal name are preserved).
3. Opt-in `--with <name>` skills layered last.

`cp -R "$framework_src/skills"/cumaru-*/` requires stripping the glob's trailing slash (BSD `cp -R src/ dest/` copies contents, not the dir as a subdir). Use `clean="${skill_dir%/}"`.

## CLI conventions

- `DEFAULT_DOMAIN="sdlc-it-project-basic"` in the entry script (`cumaru`).
- `_resolve_domain_src <name>` echoes the source dir: `base` → `frameworks/__base/`, anything else → `frameworks/<name>/`.
- `cumaru install --domain <name>` (default applied when flag absent).
- Help text is **dynamically generated** from disk. `_install_list_domains` walks `frameworks/` and skips dirs prefixed with `__` (internal/kernel convention). `_install_list_skills` parses each top-level `skills/*/SKILL.md` `description:` field, skipping `cumaru-*` (auto-installed) so only opt-ins are listed.
- **No per-domain `scripts/` extension** — removed when no domain needed it.

## Field conventions

- **Pillar-level `tracker:`** (on `intake/index.md` of sdlc-it-project-basic): **a list** like `[jira]` — the set of trackers this project pulls from.
- **Item-level `tracker:`** (on each `intake/<KEY>/index.md`): **scalar** — records which tracker that specific item came from. Required field per schema.

**Why:** unambiguous provenance per item even in multi-tracker projects.

## How to apply

- New domain → create `frameworks/<name>/` with its own self-contained `schema.yaml` + starter files. If the domain needs domain-specific skills, drop them under `frameworks/<name>/skills/cumaru-*/` — they'll auto-ship with install.
- New universal skill → drop under top-level `skills/cumaru-<name>/`. Auto-installed everywhere on next install.
- Changing the default domain → update `DEFAULT_DOMAIN` in the entry script.
- `cmd_intake.sh` reads templates from `$CUMARU_DIR/templates/` (adopter's installed copy) — decoupled from the source checkout.
