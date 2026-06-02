# `cumaru update`

Steady-state update of an installed `.cumaru/` tree from a fresh framework source. Also replaces the installed **skills**, **hooks**, and **slash commands** from the source. In the general update, **adopter data inside `.cumaru/` is never overwritten** — frontmatter values are preserved, tag bodies are preserved, only prose around them takes updates from the source. The explicit `schema --apply` target is the destructive exception.

## Usage

```
cumaru update [<path>] [--from <src>] [--keep-prose] [--apply]
cumaru update skills [--from <src>] [--apply]
cumaru update hooks [--from <src>] [--apply]
cumaru update commands [--from <src>] [--apply]
cumaru update schema [--from <src>] [--apply]
```

| Argument / flag | Description |
|---|---|
| `<path>` | Scope to a directory or file inside `.cumaru/`. Omit for full tree. |
| `skills` | Preview or replace only installed framework skills. Does not update `.cumaru/` files, hooks, or commands. |
| `hooks` | Preview or replace only installed framework hooks in `.agents/hooks/`. Does not update `.cumaru/` files, skills, or commands. |
| `commands` | Preview or replace only installed slash commands. Does not update `.cumaru/` files, skills, or hooks. |
| `schema` | Diff or replace `.cumaru/schema.yaml`. The general update never merges the schema mechanically. |
| `--from <src>` | Source: a local dot-llm checkout path or a git URL. Default: the active checkout. |
| `--keep-prose` | Preserve local prose outside marker blocks (warns per file). Default: prose comes from source. |
| `--apply` | Apply the selected update. For the general flow, merges `.cumaru/` files and replaces skills/hooks/commands; for `schema`, replaces the local schema wholesale. |

## Domain detection

Update reads `domain:` from the installed `.cumaru/schema.yaml`, then selects the
matching domain under `<source>/frameworks/<domain>/`. The `base` domain
resolves to `<source>/frameworks/__base/`. If `domain:` is absent, update falls
back to `base`.

There is no `--domain` flag: update refreshes the domain already installed
in the project. To change domains, uninstall the current tree and install the
new domain.

### Agent hook (AGENTS.md / CLAUDE.md)

The `<!-- BEGIN/END CUMARU-HOOK -->` block that `@`-imports `.cumaru/index.md` into the agent's context is reconciled as the **first step**. If the file uses the legacy `DOT-LLM-HOOK` marker (pre-rename), update replaces it with `CUMARU-HOOK` on `--apply`. If no hook is found in either `.agents/AGENTS.md` or `CLAUDE.md`, it is created.

## What gets updated

### `.cumaru/` files — three regions per file

#### 1. Frontmatter

**Adopter values are kept verbatim.** Update only reports **key drift** — keys the source has that local lacks (and vice-versa) — so the LLM can reconcile against `schema.yaml`. **Never rewrites a frontmatter value.**

When update reports key drift, the LLM's job is:
- Source-only key → add it to the local file with a value inferred from what `schema.yaml` says the field means.
- Local-only key → either it's adopter-added (harmless), or schema declares it and source is stale (investigate), or it's a stale field from a prior framework version (consider removing).

#### 2. Tag bodies (`<!-- cumaru:NAME -->` blocks)

**v4: every tag body is a `[Link, Description]` markdown table.** The shape is hardcoded — schemas don't declare per-tag columns.

**Local body is preserved.** A marker present in source but absent locally is **added empty** (so new framework tags appear). The dry-run labels each tag:

| Label | Meaning |
|---|---|
| `[=]` | local body present and matches the table shape — preserved |
| `[?]` | local block is empty — populate with `[Link, Description]` rows |
| `[Δ]` | local body is NOT a markdown table — reshape into `\| Link \| Description \|` rows |
| `[+]` | source has it, local doesn't — empty block will be added on `--apply` |
| `[orphan]` | local has it, source doesn't — kept verbatim. Decide: keep (intentional extension), remove (stale), or **relocate** — when the same tag shows `[+]` on another file, the framework moved its host (e.g. `components`/`root` from `index.md` to `domain.md`); migrate the body and delete the orphan block. The `cumaru-update` skill carries the recipe. |

#### 3. Prose (everything else)

**Taken FROM SOURCE by default** — this is where framework updates land (new rules, refined explanations, documentation tweaks). `--keep-prose` opts out per invocation with a per-file warning that the tree may diverge from its spec.

### Skills, hooks, and slash commands (deterministic)

Skills, hooks, and slash commands are **framework-owned artifacts**, sourced from the domain (`frameworks/<domain>/{skills,hooks,commands}/`). Universal items (`cumaru-doctor`, `cumaru-update`, `cumaru-refs`, `hooks/context-loader.sh`, `/cumaru:doctor`, `/cumaru:update`, `/cumaru:resolve`, `/cumaru:refs`) live in `__base/` and are mirrored verbatim into every domain (drift-checked at install-script time; `cumaru-install` is domain-owned and exempt), so sourcing only from the domain is always complete.

On `--apply`:
- Every `<source>/frameworks/<domain>/skills/cumaru-*/` is copied to `.agents/skills/`. Opt-ins (non-`cumaru-*` skills the adopter installed via `--with`) are NOT touched — they become adopter-owned after install.
- Every `<source>/frameworks/<domain>/hooks/*` file is copied to `.agents/hooks/`. The existing hook configuration keeps pointing at `context-loader.sh`; update replaces the script, not the wiring.
- Every `<source>/frameworks/<domain>/commands/cumaru/<name>.md` is copied to `.agents/commands/cumaru/`.
- Installed `.agents/skills/cumaru-*/` dirs absent from the source are pruned (deprecated cleanup).
- Installed `.agents/hooks/*` files absent from the source are reported as deprecated — listed with a warning, but NOT deleted (review manually).
- Installed `.agents/commands/cumaru/*.md` files absent from the source are reported as deprecated — listed with a warning, but NOT deleted (review manually).
- If the adopter still has a legacy `<target>/skills/` dir (pre-current layout), it is removed.

The general dry-run (without `--apply`) does **not** preview skills/hooks/commands changes — they are deterministic and need no per-item review. Use the dedicated `skills`, `hooks`, or `commands` target to list what that artifact-only update would install.

## Dedicated targets

### `cumaru update skills`

Without `--apply`, lists the framework-owned `cumaru-*` skills that would be installed and reports a legacy `.cumaru/skills/` directory if present. With `--apply`, replaces installed framework skills, prunes deprecated `cumaru-*` skill mirrors, and removes the legacy directory. It does not touch `.cumaru/` content files, hooks, or slash commands.

### `cumaru update hooks`

Without `--apply`, lists the framework-owned hooks that would be installed in `.cumaru/hooks/` and reports deprecated local hook files. With `--apply`, replaces framework hook files and reports deprecated local hooks for manual review. It does not touch `.cumaru/` content files, skills, slash commands, or agent hook configuration.

### `cumaru update commands`

Without `--apply`, lists the slash commands that would be installed. With `--apply`, replaces framework slash commands and reports deprecated local commands for manual review. It does not touch `.cumaru/` files, skills, or hooks.

### `cumaru update schema`

The general update deliberately excludes `schema.yaml` because it mixes framework contracts with adopter-owned regions such as `meta.apps.values` and locally added pillars.

Without `--apply`, this target prints a raw source-versus-local diff and identifies adopter-owned regions to preserve during a hand merge. This is the recommended schema reconciliation path.

With `--apply`, it replaces the local schema wholesale. This is intentionally destructive and loses adopter customizations; use it only when a brute overwrite is explicitly desired.

## Version drift

Update compares `version:` in the source `schema.yaml` against `framework-version:` in `.cumaru/index.md`. **Mismatch = MIGRATION** — the command reports the drift and points at the migration procedure, but it does not block the update. Dry-run remains a review; `--apply` applies the requested update so migration work can proceed.

## File-presence triage

| Case | Action |
|---|---|
| **Source-only** (framework added a file) | Whole-copy on `--apply` |
| **Local-only** (adopter-created entity, e.g. `intake/AAA-X/`, `plans/<ID>/`) | Never touched |
| **Both sides** (framework-shipped + present locally) | Per-file three-region model |

Passing an adopter-owned path as `<path>` is rejected with "no framework source exists for this path".

## Dry-run output (default)

For each `.cumaru/` file that needs attention, prints:
- Frontmatter key drift (source-only, local-only).
- Tag analysis (`[=]` / `[?]` / `[Δ]` / `[+]` / `[orphan]` — see "Tag bodies" above).
- Unified diff of local → what `--apply` would produce.

Summary line lists each changed file as `[merge]` or `[new]`, plus a note that skills/hooks/commands will be replaced on `--apply`.

## `--apply` path

Performs the full update:
1. `.cumaru/` file merge: prose from source, frontmatter + bodies preserved, missing markers added empty.
2. Skills replace: every `frameworks/<domain>/skills/cumaru-*/` overwritten in detected installed agent skill dirs; deprecated `cumaru-*` mirrors pruned; legacy `<target>/skills/` removed.
3. Hooks replace: every `frameworks/<domain>/hooks/*` file overwritten in `.cumaru/hooks/`; deprecated hooks listed.
4. Commands replace: every `frameworks/<domain>/commands/cumaru/*.md` overwritten in detected installed agent command dirs; deprecated commands listed.

## What it does NOT do

Updates to the `cumaru` script itself and `src/*.sh` are **not** this command's responsibility — they live outside `.cumaru/`. For those, run [`cumaru upgrade`](upgrade.md), which re-runs the install script (replaces `~/.cumaru` wholesale on every run).

## Examples

```bash
cumaru update                                                     # dry-run from active checkout
cumaru update --apply                                             # apply merge + replace skills/hooks/commands
cumaru update templates                                           # scope .cumaru/ review to a dir
cumaru update intake/index.md                                     # scope to one file
cumaru update --keep-prose --apply                                # apply but keep local prose
cumaru update --from /path/to/dot-llm                             # source from a local checkout
cumaru update --from https://github.com/rntgspr/dot-llm.git       # source from git
cumaru update skills                                               # list framework skills to install
cumaru update skills --apply                                       # replace only framework skills
cumaru update hooks                                                # list framework hooks to install
cumaru update hooks --apply                                        # replace only framework hooks
cumaru update commands --apply                                     # replace only slash commands
cumaru update schema                                               # review schema diff for hand merge
cumaru update schema --apply                                       # destructively replace local schema
```

## Related

- [`cumaru tag`](tag.md) — used to round-trip table bodies when reshaping is needed.
- [`cumaru doctor`](doctor.md) — run after update to verify the merged tree.
- `/cumaru:update` slash command — orchestrates update + per-file review + confirmation before `--apply`.
