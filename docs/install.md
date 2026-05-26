# `llm install`

Install a framework flavor into a project's `.llm/`. Copies the chosen flavor wholesale, auto-installs the universal `llm-*` skills, optionally layers opt-in skills, wires a `CLAUDE.md` hook so the LLM auto-loads `.llm/index.md` on every session, and copies slash commands into `<parent>/.claude/commands/`.

## Usage

```
llm install [TARGET] [--framework <name>] [--with <skill>...]
```

| Argument | Default | Description |
|---|---|---|
| `TARGET` | `./.llm` | Directory to create. Refuses to overwrite an existing path. |
| `--framework <name>` | `sdlc-it-project-basic` | Which flavor to install. `base` resolves to `frameworks/__base/`; any other name to `frameworks/<name>/`. |
| `--with <skill>` | none | Add an opt-in skill at install time. Repeatable. `llm-*` skills don't need `--with` — they ship automatically. |

## What it does

1. **Pre-checks** — refuses if `TARGET` already exists (interactive prompt on TTY) and verifies each requested `--with <skill>` exists at `skills/<skill>/SKILL.md`.
2. **Copies the chosen flavor wholesale** — `cp -R "frameworks/<flavor>" TARGET/`. Brings the schema, starter indexes, templates, roles, and any **flavor-shipped skills** under `frameworks/<flavor>/skills/`.
3. **Auto-installs universal skills** — for every `llm-*` directory under `skills/` (top-level), copies into `TARGET/skills/`. **Skip-if-exists**: a flavor-shipped skill with the same name takes precedence (the wholesale copy got there first).
4. **Applies opt-in skills** — for each `--with <name>`, copies `skills/<name>/SKILL.md` into `TARGET/skills/<name>/SKILL.md`.
5. **Wires `CLAUDE.md`** — at the parent of `TARGET`, creates or appends a `<!-- BEGIN DOT-LLM-HOOK --> ... <!-- END DOT-LLM-HOOK -->` block containing an `@.llm/index.md` import directive. Idempotent — skips if the marker is already present.
6. **Installs slash commands** — recursively copies every `*.md` from the dot-llm checkout's `commands/` directory into `<parent>/.claude/commands/`. A file at `commands/llm/doctor.md` becomes `<parent>/.claude/commands/llm/doctor.md`, exposing the slash command as `/llm:doctor`. Idempotent.
7. **Prints next steps** — hints to edit the components table in `.llm/index.md`, populate `meta.apps.values` in `.llm/schema.yaml`, and run `llm doctor`. The flavor-shipped `llm-install` skill (now in `.llm/skills/llm-install/`) carries the post-install recipe.

## Available flavors

- **`sdlc-it-project-basic`** *(default)* — software delivery lifecycle: `intake/`, `plans/`, `archive/`, `specs/`, `exploring/` pillars; Lead/Dev/Ghost roles; ships five flavor-specific skills (`llm-intake`, `llm-explore`, `llm-plan`, `llm-specs`, `llm-archive`).
- **`base`** — minimal kernel (resolves to `frameworks/__base/`): no pillars, only the rules + meta sections of the schema. Start here to build a custom domain from scratch.

Adding a new flavor is a disk operation — create `frameworks/<name>/` with its own self-contained `schema.yaml` and starter files. Install's help text auto-discovers it.

## Available skills

**Universal** (auto-installed for every flavor):
- `llm-doctor`, `llm-install`, `llm-sync` — multi-step orchestration carried by SKILL.md.

**Flavor-shipped** (under `frameworks/<flavor>/skills/`, copied wholesale with the flavor):
- sdlc-it-project-basic ships `llm-intake`, `llm-explore`, `llm-plan`, `llm-specs`, `llm-archive`.

**Opt-in** (require `--with <name>`):
- `git` — unlocks mutating git commands (`commit`, `push`, `reset`, ...) under the framework's skill-gated capability rule.

## CLI primitives (no skill needed)

`llm tag` (read/write `<!-- llm:NAME -->` marker blocks; schema-validated) and `llm flow` (4 verbs: `move`/`copy`/`create`/`remove`, with guardrails) are mechanical primitives — composed by recipe skills, documented in `llm <cmd> --help`.

## When to use

Run once per project, at adoption time. To re-install after deleting `.llm/`, just run `llm install` again. To upgrade an existing install with new framework files, see [`llm sync`](sync.md).

## Examples

```bash
llm install                                                  # default at ./.llm with the SDLC flavor
llm install --framework base                                 # minimal kernel
llm install --with git                                       # SDLC + git skill
llm install /path/.llm --framework sdlc-it-project-basic     # explicit target + flavor
llm install --framework base --with git                      # base + git
```

## Related

- [`llm doctor`](doctor.md) — first thing to run after install.
- [`llm sync`](sync.md) — keep an installed `.llm/` up to date with a newer framework version.
- [`llm uninstall`](uninstall.md) — reverse of install.
