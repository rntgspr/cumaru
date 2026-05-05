---
human_revised: false
name: llm-cli
description: Use this skill whenever the user wants to operate the `dot-llm` or `llm` CLI of the .llm/ framework — to install the framework into a project, fetch a Jira issue into the intake mirror, validate the .llm/ tree, sync .llm/ with a fresh framework source, or bootstrap the CLI itself when it is not yet on the PATH. Trigger on phrases like "fetch JET-1234", "pull this ticket into intake", "install the framework", "validate .llm/", "update / sync the framework", "set up the llm CLI", or any mention of running an `llm` subcommand. Also use when the user describes a workflow in terms of the framework's pillars (intake, plans, specs, archive, exploring) and the right next step is a CLI invocation. If the `llm` command is not found, **bootstrap it first** following the section below — do not give up; do not ask the user to install it manually unless bootstrap fails.
---

# `llm` CLI

A skill for operating the `llm` CLI — the entry point for the .llm/ framework. The CLI lives at the dot-llm repo root and is typically symlinked into `~/.local/bin/llm` so it runs anywhere.

## Bootstrap (when `llm` is not on the PATH)

**Always check first:**

```bash
command -v llm
```

If the command returns a path, the CLI is installed — skip to the subcommands below. If it returns nothing (exit code 1), install it before doing anything else.

### One-liner (preferred)

```bash
curl -fsSL https://pixelpunk.works/dot-llm/install.sh | bash
```

Installs the checkout to `~/.dot-llm` and symlinks `llm` into `~/.local/bin`. **Re-run the same one-liner to update**: the script does `git pull --ff-only` on `~/.dot-llm` if it already exists, so install and update share one command.

If `~/.local/bin` is not on the user's PATH, instruct the user to add `export PATH="$HOME/.local/bin:$PATH"` to `~/.zshrc` (or `~/.bashrc`).

### Clone + symlink (fallback)

Use when the one-liner URL is unreachable, or when the user is developing dot-llm itself and wants the checkout in a known location.

The dot-llm repo lives at `git@github.com:rntgspr/dot-llm.git` (or `https://github.com/rntgspr/dot-llm.git` over HTTPS — the dot-llm repo is currently private; access requires an SSH key authorized for `rntgspr/dot-llm`).

```bash
# Pick a stable home for the checkout (default: ~/dot-llm)
DOT_LLM_HOME="${DOT_LLM_HOME:-$HOME/dot-llm}"

# Clone (or update if already there)
if [[ -d "$DOT_LLM_HOME/.git" ]]; then
  git -C "$DOT_LLM_HOME" pull --ff-only
else
  git clone git@github.com:rntgspr/dot-llm.git "$DOT_LLM_HOME"
fi

# Symlink the entry point onto the PATH (~/.local/bin is on macOS default PATH)
mkdir -p "$HOME/.local/bin"
ln -sf "$DOT_LLM_HOME/llm" "$HOME/.local/bin/llm"
chmod +x "$DOT_LLM_HOME/llm"
```

For a system-wide install, `sudo ln -s "$DOT_LLM_HOME/llm" /usr/local/bin/llm` instead.

### After bootstrap

Run `llm help` to confirm. Then proceed with the subcommands below — the rest of this skill applies as if the CLI had been installed all along.

## Subcommands

### `llm doctor` (default)


Validates the `.llm/` tree end-to-end — **schema conformance** plus **tree-wide structural checks**, in one pass. Run from any project root that has `.llm/` installed.

**Schema conformance** — frontmatter required fields, EARS pattern in `## Acceptance Criteria` and `## Requirements`, `framework-version` ≡ `version:` in `schema.yaml`. Sub-pass detail surfaces only when there are errors; otherwise compressed into a single `[✓]` line.

**Structural checks** — index drift vs disk, tasks marked done without a handoff, lingering archive work files, orphan delta-drafts, file references in `<!-- llm:files:<tag> -->` blocks resolve on disk, external tools (`curl`, `jq`, `git`, `rsync`) available on PATH.

Output: each check emits exactly one of `[✓]` ok, `[⚠]` warning, `[✗]` error, followed by a `Summary: X error(s), Y warning(s), Z ok` line.

- `--quiet` suppresses `[✓]` pass lines (warnings, errors, summary still print).
- Exit 0 on success (warnings OK), 1 on errors.
- Override target with `DOT_LLM_DIR=path/to/.llm llm doctor`.

### `llm install [TARGET] [--with <skill>...]`

Copies `dot-llm-framework/` into `TARGET` (default `./.llm`). Refuses to overwrite. Use when adopting the framework in a new project.

`--with <skill>` opts into a published skill (from `skills/<skill>/SKILL.md` in the dot-llm checkout). Repeatable. Currently available:
- `--with git` — installs `.llm/skills/git/SKILL.md`, unlocking mutating git commands (commit/push/reset/...) per the framework's skill-gated capability rule. Without this skill, every role uses git only for reading.

**Side effect: CLAUDE.md wiring.** Install also creates or appends to `<project-root>/CLAUDE.md` (the parent of the target) a block delimited by `<!-- BEGIN/END DOT-LLM-HOOK -->`. The block contains a textual instruction to read `.llm/index.md` first, plus an `@.llm/index.md` import (Claude Code syntax that auto-injects the file's contents into the system prompt). Idempotent — re-running install on the same project skips if the marker is already there.

After install, the user customizes:
1. `.llm/index.md` Multi-component table (between `BEGIN/END PROJECT-CUSTOM:multi-component`).
2. `.llm/schema.yaml` `apps.values` (between `BEGIN/END PROJECT-CUSTOM:apps-values`).

Then `llm doctor` confirms the tree is consistent. Open the project in any Claude client (Code or claude.ai) and the framework is wired in via the CLAUDE.md hook — `.llm/index.md` loads automatically.

### `llm intake <JIRA-KEY>`

Fetches a Jira issue and creates or refreshes its mirror under `.llm/intake/`.

**Required env** (auto-loaded from `.env` at the project root if present):
- `ATLASSIAN_DOMAIN` — subdomain in your `atlassian.net` URL
- `ATLASSIAN_EMAIL` — account email
- `ATLASSIAN_API_TOKEN` — from `id.atlassian.com/manage-profile/security/api-tokens`

Routing by Jira issuetype:
- Epic → `intake/epics/<KEY>/`
- Story → `intake/stories/<KEY>/`
- Anything else (Task / Bug / Spike / ...) → `intake/tickets/<KEY>/`

**Behavior:**

- **First run:** creates `index.md` from the matching template (`intake-epic.md` / `intake-story.md` / `intake-ticket.md`), fills frontmatter (`jira`, `type`, `epic`, `story`, `status`, `synced-at`, `apps: []`), sets H1 to the Jira summary, and appends a `<!-- BEGIN JIRA-RAW ... END JIRA-RAW -->` block at the bottom carrying the unedited Jira description plus step-by-step instructions for an LLM to refine the body and delete the block.
- **Re-sync** (file exists): refreshes only `status:` and `synced-at:`. If the JIRA-RAW block is still present, its description is updated with the latest from Jira. If it has already been removed (the issue was refined), the body is preserved untouched.

**Your job after `llm intake` runs:** read the file it created, follow the steps in the JIRA-RAW block (refine `## Overview` and `## Acceptance Criteria (EARS)` in English; if `type: bug`, also fill `## Reproduction`, `## Expected`, `## Actual`; set `apps:` in the frontmatter to the affected component(s) using keys from the project's `schema.yaml` `apps.values`), then delete the JIRA-RAW block. The block's instructions are tailored to the issuetype — follow them.

### `llm sync [<filter>] [--from <path|git-url>] [--apply]`

Updates the project's `.llm/` tree from a fresh framework source. **Does not** update the `llm` script itself or `src/*.sh` modules — those are tooling, updated by re-running the install one-liner (`curl -fsSL https://pixelpunk.works/dot-llm/install.sh | bash`), which does `git pull --ff-only` on `~/.dot-llm`.

**Optional filter** restricts the sync to a single dir of the framework starter:
`intake`, `plans`, `archive`, `specs`, `exploring`, `roles`, `templates`, or `reviews`. Without a filter, all paths are considered.

**Two categories** of files (declared in the source schema's `sync:` section):
- **A. framework_files** — replaced wholesale by default (templates, roles, reviews stub).
- **B. customizable_files** — replaced outside `BEGIN/END PROJECT-CUSTOM:<tag>` blocks; content inside markers is preserved. Includes the root `index.md` (Multi-component), `schema.yaml` (apps.values), and the five pillar shallow indexes (`intake`, `plans`, `archive`, `specs`, `exploring`) where the table of entries inside `BEGIN/END PROJECT-CUSTOM:entries` is kept.

**Source resolution:**
- `--from <path>` — local path to a dot-llm checkout.
- `--from <git-url>` — shallow clone into a tempdir (cleaned up on exit).
- Without `--from` — uses the dot-llm checkout the `llm` script itself was sourced from.

**Default (no `--apply`) — rich dry-run for the LLM (you).** For every file that differs, the output prints:
- Path, category (A or B), blocks (for B), default strategy, and the four available strategies.
- The full unified diff (local → source).

Then **you** apply the heuristic per file and edit the affected files using your standard tools. The four strategies:

| Strategy | What it does |
|---|---|
| `replace` | Overwrite local with source (loses local edits, including marker contents) |
| `merge` (B only) | Replace prose around markers; preserve marker contents (default for B) |
| `keep` | Do nothing (you intentionally diverge) |
| `llm-decide` | Read both versions and produce a semantic merge per the heuristic below |

**Heuristic — apply per file:**
- **Lists / tables / entries inside `BEGIN/END PROJECT-CUSTOM` markers → KEEP LOCAL.** These are project-owned data (apps values, multi-component table, pillar entries) and must not be overwritten.
- **Prose / headers / Rules / structure outside markers → take FROM FRAMEWORK.** This is the framework's rules; updates land here.
- **Outside-marker prose with project-specific content → ANALYZE:** keep what is project-local, integrate framework changes around it. This is the only case that needs your judgement; the rest is mechanical.

**`--apply`** — skips the LLM review and auto-applies the default strategy for every changed file (replace for A, merge for B). Good for routine updates with no project-specific drift expected.

After applying any path that touches `index.md` or `schema.yaml`, bump `framework-version:` in `.llm/index.md` to match the source schema's `version:`. The validator enforces equality on the next run.

### `llm archive <PLAN-ID>` / `llm archive finalize <PLAN-ID>`

Closes a plan: copies its files to `archive/<PLAN-ID>/`, prepares a work file with instructions for the LLM to refine the delta and absorb it into the affected specs, then (in Phase 2) removes the original `plans/<PLAN-ID>/` tree.

**Phase 1 — `llm archive <PLAN-ID>`:**
- Pre-checks: plan exists, every task has `status: done`, `delta-draft.md` is present, `archive/<PLAN-ID>/` does not yet exist.
- Creates `archive/<PLAN-ID>/` and copies: `index.md` (with frontmatter updated to `status: done`, `completed-at`, `delta: delta.md`), `delta-draft.md` renamed to `delta.md`, and any `handoff-t<N>.md`.
- Writes `archive/<PLAN-ID>/temp-archive-flow.delete-me.md` with step-by-step instructions and snapshots of every affected spec area (from the plan's `scope:`).

**Your job between phases:**
1. Refine `archive/<PLAN-ID>/delta.md` (drop `status: draft`, tighten wording, verify EARS coverage).
2. For each spec area in the plan's `scope:`, edit `specs/<area>/index.md`: update the body to reflect the new state and append `<PLAN-ID>` to the `deltas:` frontmatter list.
3. Delete `plans/<PLAN-ID>/delta-draft.md`.
4. Delete `archive/<PLAN-ID>/temp-archive-flow.delete-me.md`.

**Phase 2 — `llm archive finalize <PLAN-ID>`:**
- Verifies the work file is gone, the delta is no longer `status: draft`, and `delta-draft.md` was deleted.
- Removes `plans/<PLAN-ID>/` entirely.

The original `plans/` tree is preserved through Phase 1 — safe to retry. Only `archive finalize` removes it.

### `llm specs consolidate <area> [--apply]`

Prepares an LLM-driven **compaction** of a spec area. Over time, a `specs/<area>/` accumulates a long `deltas:` list as plans archive their changes into it. Without compaction, the spec body grows in layers and the loaded context bloats.

**Default is dry-run** — prints the target work file path, delta count, and plan IDs that would be absorbed; nothing is written. Pass `--apply` to create the work file.

**Behavior (with `--apply`):**
1. The CLI reads `specs/<area>/index.md` and the archive deltas its `deltas:` list references.
2. Writes `specs/<area>/history.md` with the current spec body, every delta in chronological order, and step-by-step instructions for an LLM to rewrite the spec compactly.
3. **You** (the LLM in this chat) open the work file, follow the instructions, rewrite `specs/<area>/index.md` into a single coherent spec, and replace the long `deltas:` list with a single `consolidated-at: <ISO date>` field in the frontmatter.

The `history.md` file is **persistent**, not temporary. It is the area's chronological history of absorbed deltas — leave it on disk after consolidation. Only delete it when the user explicitly asks (e.g. "drop the history for auth", "limpa o history").

Archive entries are **never deleted** — history is preserved on disk; only the frontmatter reference shape changes (long list → single date). After consolidation, drilling into archive still works for anyone who needs the verbose wording, and `history.md` provides the same view consolidated per area.

When to run:
- The user asks to "compact" / "consolidate" / "compactar" a spec area.
- A spec area's `deltas:` list has grown long (≥5 entries is a reasonable trigger), increasing the loaded context.

### `llm regen index [pillar]` / `llm regen <JIRA-KEY>`

Regenerates derived state inside `.llm/` from disk. Two modes:

**`llm regen index [pillar]`** — rebuilds the entries block of the 5 shallow indexes (`intake/`, `plans/`, `archive/`, `specs/`, `exploring/`). Without arg, regenerates all 5; with a pillar name, regenerates only that one. Replaces only the content between `BEGIN/END PROJECT-CUSTOM:entries` markers — the header, Rules, When-to-use sections are preserved.

Use after any change to entries:
- After `llm intake <KEY>` (intake/index.md is stale)
- After `llm archive finalize <PLAN-ID>` (plans/index.md and archive/index.md are stale)
- After bootstrapping a new spec area or exploring idea
- Ad-hoc to "resync everything"

**`llm regen <JIRA-KEY>`** — chain-check report on a ticket. Walks the canonical work cycle (intake → plan → archive → specs) and surfaces inconsistencies:

- **Intake** present and refined? (warns if JIRA-RAW block still there)
- **Plan** status and task progress (`done/total tasks`)
- **Tasks vs handoffs** — flags tasks with `status: done` lacking a `handoff-t<N>.md`
- **Archive** present and finalized? (warns if `temp-archive-flow.delete-me.md` lingers)
- **Specs `deltas:` integrity** — for each path in the plan's `scope:`, checks that `<JIRA-KEY>` is in the area's `deltas:` list (skipped step of the archive flow if missing)
- **EARS coverage** — every `WHEN ... THE SYSTEM SHALL ...` line in the intake should appear in `archive/<KEY>/delta.md`. Coarse (text matching), but catches forgotten criteria.

Use to:
- Verify a ticket after `llm archive` finishes (did everything land?).
- Diagnose "what's broken" when something feels off.
- Onboard yourself to a half-finished plan picked up from another session.

### Updating the `llm` CLI itself

There is no dedicated subcommand. **Re-run the install one-liner**:

```bash
curl -fsSL https://pixelpunk.works/dot-llm/install.sh | bash
```

The script does `git pull --ff-only` on `~/.dot-llm` if it already exists, so install and update share one command.

**Distinction from `llm sync`:**
- The install one-liner updates the **CLI tooling** globally (script + `src/*.sh` + `skills/` + `dot-llm-framework/` source).
- `llm sync` updates a **project's `.llm/`** tree per-project; needs an installed target.

**When to update the CLI:**
- The user says "update llm", "atualizar o llm", "atualiza", "mise à jour llm", "actualizar llm", "aggiorna llm", "llm güncelle", "llm güncellemesi", "обновить llm", "llm を更新", "llm를 업데이트", "llm güncellenmesi gerekli", "αναβάθμιση llm".
- Before running `llm sync` if the CLI itself might be stale.

## Patterns

| User says | You run | Then |
|---|---|---|
| "Fetch JET-1234 into intake" | `llm intake JET-1234` | Read the created file, follow the JIRA-RAW block instructions |
| "Pull this ticket / story into intake" (with a JIRA key) | Same as above | Same |
| "Set up the framework here" | `llm install` (or `llm install --with git`) | Point the user at the two customization spots |
| "Validate the .llm/ tree" | `llm doctor` (or `llm`) | If errors, surface them and propose fixes |
| "Update / sync the framework here" | `llm sync` (rich dry-run) | Walk the per-file output, apply the heuristic, edit files; or run `--apply` for the default strategies |
| "Sync only intake / plans / templates / ..." | `llm sync <filter>` | Same flow, scoped to one dir |
| "Update llm" / "atualiza o llm" | `curl -fsSL https://pixelpunk.works/dot-llm/install.sh \| bash` | Same command for install and update — does `git pull` if `~/.dot-llm` exists |
| "Regenerate the indexes" / "regen tudo" | `llm regen index` | Show row counts |
| "Is .llm/ healthy?" / "diagnose" / "health-check" / "verifica isso" | `llm doctor` (or just `llm`) | Walk through each ⚠/✗; suggest the fix command |
| "Check the chain for JET-1234" / "raio-x do JET-1234" | `llm regen JET-1234` | Surface ⚠ warnings if any |
| "Close the plan / archive JET-1234" | `llm archive JET-1234`, follow temp-archive-flow.delete-me, then `llm archive finalize JET-1234`, then `llm regen index` | Walk through phases, finish with regen |

## Defaults and overrides

- `DOT_LLM_DIR=path/to/.llm llm <cmd>` — operate on a tree in a non-default location.
- `.env` at the project root is auto-loaded by `llm intake` (and only by `llm intake`).
- All subcommands accept `help` / `-h` / `--help` (top-level: `llm help`; subcommand-specific: `llm sync --help`, `llm intake help`).

## When NOT to use this skill

- Authoring `.llm/` content (plan bodies, spec areas, refining intake Overviews) — that's Lead/Dev role work, performed with file tools, not the CLI.
- Discussion of the framework's structure, philosophy, or pillars — read `.llm/index.md` for that.
- Direct file edits inside `.llm/` — use file tools (Read/Edit/Write), not the CLI.
- Anything outside the four subcommands above — the CLI does only what is documented here.
