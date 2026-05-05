# `llm install`

Install the framework starter into a project's `.llm/`. Copies `dot-llm-framework/` to a target directory, optionally adds opt-in skills, and wires up a `CLAUDE.md` hook so the LLM auto-loads `.llm/index.md` on every session.

## Usage

```
llm install [TARGET] [--with <skill>...]
```

| Argument | Default | Description |
|---|---|---|
| `TARGET` | `./.llm` | Directory to create. Refuses to overwrite an existing path. |
| `--with <skill>` | none | Add an opt-in skill at install time. Repeatable. |

## What it does

1. **Pre-checks** — refuses if `TARGET` already exists or any requested `--with <skill>` is missing in the dot-llm checkout's `skills/<skill>/SKILL.md`.
2. **Copies the starter** — `cp -R dot-llm-framework/ TARGET/`.
3. **Adds requested skills** — for each `--with <name>`, copies `skills/<name>/SKILL.md` into `TARGET/skills/<name>/SKILL.md`.
4. **Wires `CLAUDE.md`** — at the parent of `TARGET`, creates or appends a `<!-- BEGIN DOT-LLM-HOOK --> ... <!-- END DOT-LLM-HOOK -->` block containing a textual instruction to read `.llm/index.md` first plus a `@.llm/index.md` import directive. Idempotent — skips if the marker is already present.
5. **Installs slash commands** — copies every `*.md` from the dot-llm checkout's `commands/` directory into `<parent>/.claude/commands/`. Idempotent — skips files already present at the destination. Currently ships `/sync` (orchestrates `llm sync` with summary + confirmation).
6. **Offers spec bootstrap** *(interactive only)* — prompts: *"Detect spec areas from your source tree (light pass, no writes)? [Y/n]"*. On "yes", runs `llm specs bootstrap` (dry-run) rooted at the parent of `TARGET` so the scan path detection (`src/`, `app/`, `lib/`) resolves relative to the adopter's project. Then prints the command to apply (`llm specs bootstrap --apply`). Skipped silently when stdin is not a TTY (piped install).
7. Prints next-steps hint (edit `index.md` Multi-component, edit `schema.yaml apps.values`, run `llm doctor`).

## Available skills

- **`git`** — unlocks mutating git commands (`commit`, `push`, `reset`, `checkout`, ...) under the framework's skill-gated capability rule. Without this skill, every role uses git only for reading.
- **`llm-cli`** — operate the `llm` CLI itself. Rarely needed inside a project — adopters typically install this skill globally in Claude.

## When to use

Run once per project, at adoption time. Re-run only when starting fresh (e.g. after deleting `.llm/`).

## Examples

```bash
llm install                            # default install at ./.llm (no skills)
llm install --with git                 # default install + the git skill
llm install /path/.llm --with git      # custom target + git skill
llm install --with git --with llm-cli  # multiple skills
```

## Related

- [`llm doctor`](doctor.md) — first thing to run after install.
- [`llm sync`](sync.md) — keep an installed `.llm/` up to date with a newer framework version.
