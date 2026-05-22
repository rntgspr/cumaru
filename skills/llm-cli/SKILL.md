---
human_revised: false
name: llm-cli
description: Use this skill whenever the user wants to operate the `dot-llm` or `llm` CLI of the .llm/ framework — to install the framework into a project, uninstall / remove it, fetch a Jira issue into the intake mirror, validate the .llm/ tree, bootstrap or deepen spec areas, sync .llm/ with a fresh framework source, or bootstrap the CLI itself when it is not yet on the PATH. Trigger on phrases like "fetch JET-1234", "pull this ticket into intake", "install the framework", "uninstall the framework", "remove .llm/", "validate .llm/", "bootstrap specs", "deepen the auth spec", "update / sync the framework", "set up the llm CLI", or any mention of running an `llm` subcommand. Also use when the user describes a workflow in terms of the framework's pillars (intake, plans, specs, archive, exploring) and the right next step is a CLI invocation. For reading/writing or auditing `<!-- llm:NAME -->` marker blocks specifically, prefer the dedicated `llm-tag` skill. If the `llm` command is not found, **bootstrap it first** following the section below — do not give up; do not ask the user to install it manually unless bootstrap fails.
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

### `llm uninstall [TARGET] [--yes]`

The exact reverse of `install` — removes only what install created, in reverse order. Use when the user wants to take the framework out of a project, or to reset the bench to a clean slate before re-installing.

**What it removes:**
1. **Slash commands** under `<parent>/.claude/commands/` — but **only** those byte-identical to the source in the dot-llm checkout (`cmp -s`). A command the user edited is **kept** and reported (`· keeping (modified, …)`), mirroring install's skip-if-exists. Empty command dirs and `.claude/` are pruned only if nothing else lives there.
2. **The `<!-- BEGIN/END DOT-LLM-HOOK -->` block** in `<parent>/CLAUDE.md`, plus the single blank line install inserted before it. If only install-created boilerplate remains (empty, or just a `# Project instructions` header), the whole file is removed; otherwise the user's other content is preserved.
3. **The TARGET tree** (`.llm/`, default `./.llm`).

**Flags & safety:**
- `-y` / `--yes` skips the confirmation prompt. **Required for non-interactive runs** (agent / CI): without a TTY and without `--yes`, it refuses rather than guessing.
- **Idempotent** — running it again when nothing is installed prints `Nothing to uninstall …` and exits 0.
- It prints a summary of what will be removed before acting; review it.

**When the bench is involved:** the documented test cycle starts with `llm uninstall <target> --yes` to guarantee a clean slate, then re-installs. A real adopter project's `.llm/` is usually committed — confirm before removing if the user might want it back from git.

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

### `llm sync [<path>] [--from <path|git-url>] [--keep-prose] [--apply]`

Steady-state update of the project's `.llm/` tree from a fresh framework source. **Does not** update the `llm` script itself or `src/*.sh` modules — those are tooling, updated by re-running the install one-liner (`curl -fsSL https://pixelpunk.works/dot-llm/install.sh | bash`), which does `git pull --ff-only` on `~/.dot-llm`.

**The command enforces a version gate.** It reads `version:` in the source `schema.yaml` and `framework-version:` in `.llm/index.md`. If they differ it **refuses to run** and tells you this is a *migration*, not a sync — follow the **v2 → v3 migration** procedure below. Steady-state sync only operates when both versions match.

**`<path>`** (optional) scopes the sync, relative to `.llm/`. It may be a **directory** (`templates`, `specs`, …) to limit to that subtree, or a **single file** (`intake/index.md`) to review just one file — useful for migrating/upgrading in defined chunks. A path with no framework-source counterpart (adopter-created entities like `specs/<area>/`, `plans/<PLAN-ID>/`) is **rejected** with a clear message; only files shipped in the starter are syncable.

**Source resolution:** `--from <path>` (local checkout), `--from <git-url>` (shallow clone, cleaned up), or none (the checkout this `llm` was sourced from).

**Per-file model — three regions, mostly mechanical:**
- **Frontmatter** — adopter **values are kept verbatim**. The command only reports *key drift* (keys the source has that local lacks, and vice-versa) so you can reconcile against `schema.yaml`. It never rewrites frontmatter.
- **Tag bodies** (`<!-- llm:NAME --> … <!-- /llm:NAME -->`) — local body is **preserved**. A marker present in source but absent locally is added **empty**. A *table* tag whose column header drifted is flagged `[Δ]` (reshape the body, keep the rows). A *string/prose* tag is flagged `[?]` for you to verify it still matches the schema subject. Local markers with no source counterpart are flagged `[orphan]`.
- **Prose** (everything else) — taken **FROM SOURCE** by default; framework rule updates land here.

**Default (no `--apply`)** is a structured per-file review: frontmatter key drift, the tag analysis above, and a unified diff of *local → the actual merge result* (so the diff shows what `--apply` would do — prose changes, bodies/frontmatter preserved). The summary lists each file as `[merge]` or `[new]`, and prints the `schema.yaml` path to reconcile against. **`--apply`** performs the merge mechanically. **`--keep-prose`** keeps the adopter's prose instead of taking it from source, printing a per-file warning that framework updates are skipped and the tree may diverge from its spec.

After applying anything touching `index.md` or `schema.yaml`, bump `framework-version:` in `.llm/index.md` to match the source `version:`. The validator enforces equality.

#### v2 → v3 migration (existing projects)

v3 reshaped the tree: a single recursive node model, **flat tracker-agnostic intake**, lean indexes, and tag markers named by their path through the node tree. A v2 project cannot be steady-state-synced into v3 — the structure moved. Run this as an **LLM-orchestrated, multi-phase** procedure: bash does the mechanical swaps and prints diffs; **you** adjudicate every discrepancy against the v3 `schema.yaml` model. Detect first, apply second — never rename a marker before its old form has been recorded in the plan.

**Preconditions (you check before starting):**
- `git status` must be clean. Abort and tell the user if there are uncommitted changes — the phases below rewrite the tree in place.
- This migration **does** mutate git, via the explicit `git mv` calls in Phase 2 (rename detection keeps intake history through the move). That is a one-shot, user-authorized reshape — distinct from the ambient git mutation the project rule forbids. **Confirm authorization with the user before starting**; if they decline `git mv`, fall back to plain `mv` and have them stage the moves themselves.
- `framework-version:` stays `2` until **every** phase below succeeds. A half-done migration must leave the project at `2` (a known state) so it can be re-run.

**Phase 1 — schema first.** The new schema is the reference for everything after, so swap it before touching structure. Replace `.llm/schema.yaml` with the v3 source, **carrying over the project's component list**: copy the body of the old `<!-- llm:custom:apps-values -->` block into the new `<!-- llm:framework:apps:values -->` block (both markers live in `.llm/schema.yaml` — the marker was renamed, the host file is the same). Keep `platform` + `meta` reserved.

**Phase 2 — folder structure (read from the new schema's `root.entities`).** v2 nested intake by issuetype; v3 is flat. Plan and show the moves, then `git mv`:
- `intake/tickets/<KEY>/` , `intake/stories/<KEY>/` , `intake/epics/<KEY>/` → `intake/<KEY>/` (flatten — every item becomes a sibling).
- `roles/`, `templates/`, `reviews/` stay on disk but have **no node-tree index tag** in v3; leave their dirs, their old `<!-- llm:roles -->` / `<!-- llm:templates -->` / `<!-- llm:reviews -->` index markers are simply no longer schema-tracked (harmless — remove them only if you regenerate those indexes).

**Phase 3 — frontmatter per node.** For each `index.md` and entity file, diff its actual frontmatter keys against the schema's declared list for that node. Bash prints the delta; **you** apply, taking the schema as ground truth on any discrepancy:
- intake items: `jira:` → `key:`; add `type:` (the tracker issuetype: epic | story | task | bug) and `relates:` (was hierarchy, now many-to-many links).
- `intake/index.md`: add `tracker:` (jira | linear | clickup | …) — required in v3.
- plans/archive: `jira:` → `key:` (now optional — slug-based plans have none).
- specs areas: add `relates:` where a soft cross-link exists (alongside the existing `depends-on:`).
- all pillar indexes: remove `count:` (the table's row count is the count).

**Phase 4 — tags.** Tag **body content is always preserved** across the whole project — never discard a table or prose body. Only marker **names** change (the v3 path-joined convention):
- `<!-- llm:files:touched -->` → `<!-- llm:plans:plan:handoff:files -->` (in every `handoff-t<N>.md`).
- `<!-- llm:custom:apps-values -->` → `<!-- llm:framework:apps:values -->` (already handled in Phase 1).
Bash does the in-place rename and prints a diff. If a tag's body differs from what the schema's value-type now expects (e.g. a table whose columns changed), **show the diff and decide** — reshape the body to the new contract while preserving its data; never drop rows.

**Phase 5 — finalize.** Only after Phases 1–4 succeed: bump `framework-version:` to `3` in `.llm/index.md`, then run `llm doctor` to confirm the tree validates against the v3 schema.

This is LLM-orchestrated from the skill — there is **no** `--migrate` subcommand. The bash you run is ordinary `git mv`, `grep`, `diff`, and in-place marker rewrites; the skill is the orchestrator that sequences the phases and adjudicates discrepancies.

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

### `llm specs bootstrap [--path <dir>] [--apply]`

**Light pass** — the first step in seeding the `specs/` pillar from an existing codebase. Discovers top-level areas under the scan path (`src/`, `app/`, `lib/`, or `--path <dir>`) and, with `--apply`, writes a persistent `specs/<area>/bootstrap.md` per area.

- **Default is dry-run** — prints the areas it would scaffold; nothing is written. Use it to preview the area split before committing.
- **With `--apply`** — creates `specs/<area>/bootstrap.md` for each detected area. Each carries discovery output plus instructions for **you** (the LLM) to draft `specs/<area>/index.md` and populate a `## Topics` list of things worth deepening later.

**Your job after `--apply`:** open each `bootstrap.md`, follow its instructions to author the area's `index.md` (Overview + EARS Requirements), and list candidate topics. `bootstrap.md` is **persistent** — it grows across deep passes; do not delete it unless asked.

This is also offered interactively at the end of `llm install` (TTY only), as a dry-run, so the adopter sees the proposed area split immediately.

### `llm specs deep <area> [--topic <slug>] [--apply]`

**Incremental pass** — deepens an area that already has a `bootstrap.md`. Appends a new `## Discovery (deep pass <ISO>) — <scope>` section to that file. Scope is `all topics` by default, or a single `topic: <slug>` with `--topic`.

- **Default is dry-run**; `--apply` appends the section.
- **Your job after `--apply`:** read the appended discovery section and use it to refine `specs/<area>/index.md` (add Requirements, split concerns into `<concern>.md` files or `<subarea>/` when they outgrow the index).

Run `deep` repeatedly as understanding of an area grows — each pass stacks another dated `## Discovery` section onto `bootstrap.md`.

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
