---
human_revised: false
version: 1
name: cumaru-update
description: Use this skill whenever the user wants to update an installed `.cumaru/` tree — pull a fresher version of templates, roles, pillar starter prose, schema rules from the dot-llm source while keeping the adopter's tag bodies + frontmatter values intact, AND replace the installed skills, hooks, and slash commands. **Also the source of truth for framework migrations between major versions** (v2 → v3, v3 → v4, …): when `cumaru update` reports a version mismatch, the step-by-step procedure lives in the `## v3 → v4 migration` section (and any future `## vN → vN+1 migration` section) of this file — do NOT search for it elsewhere. Trigger on phrases like "update the framework", "update .cumaru/ from the source", "atualizar o framework instalado", "pull the latest framework changes", "diff .cumaru/ against the source", "migrate v3 → v4", "migrate framework version", "version mismatch", "update skills", "update hooks", "replace slash commands". Never use it for adopter content updates — this is for framework-owned files only.
---

# `cumaru update` — steady-state update of `.cumaru/`, skills, hooks, and slash commands

Updates three surfaces from the dot-llm source (the active checkout, or a git URL):

1. **Framework files inside `.cumaru/`** — adopter content (tag bodies, frontmatter values) is never overwritten; only the prose around them is taken from source.
2. **Skills** (under `.agents/skills/`) — framework-owned `cumaru-*` skills are replaced wholesale from the source; deprecated `cumaru-*` mirrors are pruned.
3. **Hooks** (`.cumaru/hooks/`) — replaced wholesale from the source. Deprecated hooks listed but not removed.
4. **Slash commands** (under `.agents/commands/`) — replaced wholesale from the source. Deprecated commands listed but not removed.

## Usage

```bash
cumaru update                                        # dry-run: review .cumaru/ changes
cumaru update --apply                                # apply merge + replace skills/hooks/commands
cumaru update templates                              # scope .cumaru/ review to a dir
cumaru update intake/index.md                        # scope to one file
cumaru update --keep-prose --apply                   # apply but keep local prose (warns per file)
cumaru update --from /path/to/dot-llm                # source from a local checkout
cumaru update --from https://github.com/rntgspr/dot-llm.git
cumaru update skills [--apply]                       # list or replace only framework skills
cumaru update hooks [--apply]                        # list or replace only framework hooks
cumaru update commands [--apply]                     # list or replace only slash commands
cumaru update schema [--apply]                       # diff or destructively replace schema
```

## Per-file model for `.cumaru/` — three regions

### 1. Frontmatter
**Adopter values are kept verbatim.** `cumaru update` only reports **key drift** — keys the source has that local lacks (and vice-versa) — so the LLM can reconcile against `schema.yaml`. **It never rewrites a frontmatter value.**

When update reports key drift, your job:
- Source-only key → add it to the local file, populated based on what `schema.yaml` says the field means.
- Local-only key → either it's adopter-added (and harmless), the schema declares it and source got out of date (rare; investigate), or it's a stale field from a prior framework version (consider removing).

### 2. Tag bodies (`<!-- cumaru:NAME -->` blocks)
**v4: every tag body is a `[Link, Description]` markdown table.** The shape is hardcoded in the parser, doctor, update, and the `cumaru tag` CLI — there are no per-tag kinds anymore, no column drift to reshape, no string/path-list/number variants.

**Local body is preserved.** A marker present in source but absent locally is **added empty** (so new framework tags appear). The dry-run review labels each tag:

| Label | Meaning | Your job |
|---|---|---|
| `[=]` | local body present and matches the table shape | nothing — preserved |
| `[?]` | local block is empty | populate it with `[Link, Description]` rows the project has accumulated |
| `[Δ]` | local body is NOT a markdown table | reshape into `\| Link \| Description \|` rows; **never invent extra columns**. Use `cumaru tag get` + `cumaru tag set` to round-trip |
| `[+]` | source has it, local doesn't | empty block will be added on `--apply`; populate after |
| `[orphan]` | local has it, source doesn't | kept verbatim on `--apply`. Decide: keep (intentional extension), remove (stale), or **relocate** (see below) |

**Relocated tags** — when the framework moves a tag to a different host file, the review shows the pair: `[orphan] <tag>` on the old host AND `[+] <tag>` on the new one (e.g. `components`/`root` moved from `index.md` to `domain.md`). After `--apply`, migrate the body: copy it from the old host's block (read the file directly — `cumaru tag get` refuses on the old host, since the schema no longer declares the tag there) into the new host via `cumaru tag set <new-host> <tag>`, then delete the orphan block (markers included) from the old host. Re-run `cumaru update` to confirm the file drops out of the review.

### 3. Prose (everything else)
**Taken FROM SOURCE by default** — this is where framework updates land (new rules, refined explanations, documentation tweaks). `--keep-prose` opts out per invocation with a per-file warning that the tree may diverge.

## Skills, hooks, and commands model (deterministic)

Skills, hooks, and slash commands are **framework-owned artifacts** — adopters are not expected to edit them locally. On `--apply`:
- Every `cumaru-*` skill in the source `skills/` replaces its local counterpart (or is added if new).
- Every hook file in the source `hooks/` replaces its local counterpart under `.cumaru/hooks/` (or is added if new). The existing agent config keeps pointing at `.cumaru/hooks/context-loader.sh`; update replaces the script, not the wiring.
- Every slash command in the source `commands/` replaces its local counterpart (or is added if new).
- Hook and command files present locally but absent from the source are reported as **deprecated** — listed with a warning, but NOT deleted. Remove them manually after confirming they are no longer needed.

Dry-run (without `--apply`) does **not** show skills/hooks/commands changes — they are always deterministic and need no review. They are replaced silently on `--apply`.

Use `cumaru update skills`, `cumaru update hooks`, or `cumaru update commands` when only one installed artifact class needs repair. Their dry-runs list what would be installed; `--apply` replaces only the selected class and does not merge `.cumaru/` files.

## Version drift

`cumaru update` compares `version:` in source `schema.yaml` against `framework-version:` in `.cumaru/index.md`. **Mismatch = MIGRATION** — the command reports the drift and points at the appropriate migration procedure, but it does not block the update. Dry-run remains a review; `--apply` applies the requested update so migration work can proceed.

## File-presence triage (mechanical)

| Case | Action |
|---|---|
| **Source-only** (framework added a file) | Whole-copy on `--apply` |
| **Local-only** (adopter-created entity, e.g. `intake/AAA-X/`, `plans/<ID>/`) | Never touched |
| **Both sides** (framework-shipped + present locally) | Per-file three-region model |

Passing an adopter-owned path as `<path>` arg is rejected.

## Default vs `--apply`

**Default (dry-run)** prints a structured per-file review for `.cumaru/` files: frontmatter key drift, tag analysis (`[=]` / `[?]` / `[Δ]` / `[+]` / `[orphan]`), and a unified diff of `local → what --apply would produce`. Summary lists each changed file as `[merge]` or `[new]` and notes that skills/hooks/commands will also be replaced on `--apply`.

**`--apply`** performs the full update: `.cumaru/` file merge + skills replace + hooks replace + commands replace.

## When the LLM (you) gets involved

The `.cumaru/` portion is mostly mechanical, but **you adjudicate the ambiguous cases**:

1. **Frontmatter key drift** — add/remove keys against `schema.yaml`.
2. **Tag body in non-table shape** (`[Δ]`) — reshape the body into `[Link, Description]` rows, preserving every entry. Use `cumaru tag get` + `cumaru tag set` to round-trip.
3. **Empty local block** (`[?]`) — populate with one row per linked entity (path + one-line prose).
4. **Orphan tags** (`[orphan]`) — if the same tag shows `[+]` on another file, it was relocated: migrate the body, then remove the orphan. Otherwise confirm with the user before removing.
5. **Deprecated skills/hooks/commands** — inform the user; suggest removal only when you are confident the item is no longer needed.
6. **Schema drift** — `schema.yaml` is never auto-merged; the general `cumaru update` only flags the drift and points at `cumaru update schema`. Your job: read the `diff -u` it prints and hand-merge the source contract into the local file, **preserving the adopter-owned regions**:
   - `meta.apps.values` — the project's components list (typed by the adopter at install time and grown as the project evolves).
   - Adopter-added top-level pillars — any node the project added beyond the domain's defaults.
   - Locally-removed marker definitions — entries the adopter deleted on purpose (the source re-introducing them does **not** mean re-adding them).
   Bring in: new framework-owned contracts (frontmatter rules, marker definitions, pillar shape changes) from the source side of the diff. Edit `.cumaru/schema.yaml` directly; never run `cumaru update schema --apply` unless the user explicitly wants a brute overwrite (it discards every adopter-owned region above).

## Patterns

| User says | You do |
|---|---|
| "Update the framework" / "atualizar o framework" | `cumaru update` (dry-run) → walk the per-file review → `cumaru update --apply` if clean, or hand-reconcile drift first |
| "Update only templates" | `cumaru update templates --apply` |
| "Update only framework skills" | `cumaru update skills` → `cumaru update skills --apply` after confirmation |
| "Update only hooks" | `cumaru update hooks` → `cumaru update hooks --apply` after confirmation |
| "Update only slash commands" | `cumaru update commands` → `cumaru update commands --apply` after confirmation |
| "Reconcile schema with source" / "schema drifted" | `cumaru update schema` (dry-run diff) → hand-merge `.cumaru/schema.yaml` preserving adopter-owned regions. Avoid `--apply` unless brute overwrite is the intent. |
| "Just preview the diff" | `cumaru update` without `--apply` |
| "Keep my custom prose in this file" | `cumaru update --keep-prose --apply` (warns per-file that framework prose updates are skipped) |
| "Migrate v3 → v4" | Run `cumaru update` to review the version mismatch and file drift, then `cumaru update --apply` when the user asks to apply; follow the v3 → v4 migration section below for reconciliation |

## Why this design

The "script reports, LLM adjudicates" split for `.cumaru/` files is load-bearing:
- **Tag bodies are adopter data** (the components table, pillar entries, `apps.values`, project-context prose). Overwriting = silent data loss.
- **Frontmatter values are adopter data** (`apps:`, `status:`, `key:`). The schema declares the contract (which keys); the adopter owns the values.
- **Prose comes from source** because that's where framework rule updates live.
- **Skills/hooks/commands are framework data** — deterministic replace is safe and correct. Deprecation reporting gives the user visibility without silent deletions.

Use `cumaru tag get/set` (CLI, no skill) for the round-trip when reshaping table bodies; pair with `cumaru-doctor` to verify the merged tree is still healthy.

## Migration to v4 (from any earlier version)

> **This is the source-of-truth procedure for upgrading an `.cumaru/` tree of ANY earlier framework version (v2, v3, …) to v4.** When `cumaru update` reports a version mismatch, run the steps below in order. Do not look for the procedure elsewhere; if a v3-specific (or v2-specific) step doesn't apply to this tree, skip it and continue.

The single load-bearing v4 change: **every `<!-- cumaru:NAME -->` body is a markdown table with exactly two columns — `Link` and `Description`**. The shape is hardcoded in the parser, doctor, update, and the `cumaru tag` CLI. Per-tag column declarations, path-lists, string-prose tags, and number tags are gone — everything is `[Link, Description]`.

Anything not deterministically resolvable below — column fusion judgment, ambiguous body shape, an old construct nobody recognizes — **the LLM resolves with the user**. Ask before guessing.

### Steps (run in order; skip any that don't apply)

1. **Work on a clean branch.** The change touches every tag in the tree.

2. **Read the local schema first.** Open `.cumaru/schema.yaml` and note its `version:` and every declared tag (root, pillar, meta). That set is what you'll walk in step 4. If the tree is so old that the schema has no `version:` or no `root.entities`, treat it as pre-v3 — `cumaru doctor` will refuse the orphan check until step 5 lands.

3. **Pull the new schema from source** if the local one is more than one major behind, OR hand-merge:
   - `cumaru update schema` — prints the source-vs-local diff.
   - Hand-merge into `.cumaru/schema.yaml`, **preserving the adopter-owned regions** (`meta.apps.values`; any pillar the project added; deletions the adopter made on purpose). Bring in the framework-owned contract changes (frontmatter rules, marker definitions, pillar shape).
   - For a v4-target schema specifically: strip every `columns:`, `format:`, `description:`, `number:` from tag entries; keep only `host_file:` where it routes a meta tag.

4. **For every `<!-- cumaru:* -->` block in the tree**, regardless of its current shape, convert to `[Link, Description]`:

   | Old shape | How to convert |
   |---|---|
   | Old multi-column table (intake `[Key, Type, Title, Status, Relates]`, plans `[Key, Title, Tasks, Apps]`, archive `[Key, Type, Apps, Summary, Absorbed-in]`, specs/coverage/topology `[Path, Summary, Apps, Depends-on, Relates]`, exploring `[Idea, Apps, Summary]`, runbooks/standards/components/templates `[<Whatever>, …]`, etc.) | One row per old row. `Link` = `[<key-or-name>](<path>/index.md)`. `Description` = one sentence fusing every other column (type, status, apps, depends-on, absorbed-in commit SHA, …). **Nothing is thrown away** — squeeze it into prose. |
   | Old path-list (`<!-- cumaru:files -->`, `<!-- cumaru:files:touched -->`, anything bullets-of-paths) | One row per bullet. `Link` = `` [`<path>`](<path>) ``. `Description` = the bullet's trailing prose (`created/modified/removed — …`); if it has none, the LLM writes a one-line description from the file's nature. |
   | Old string-prose tag (e.g. `<!-- cumaru:root -->` carrying project context) | Default: keep prose only when the prose is genuinely free-form orientation that doesn't enumerate things. When it enumerates entities (areas, links, sub-projects), turn into a `[Link, Description]` table. For `<!-- cumaru:root -->`, the framework default is one row pointing at `.cumaru/` with a one-line project orientation; the adopter expands from there. |
   | Old number tag | Single-row table where Description carries the number plus its meaning (e.g. `\| .cumaru/ \| pipeline-throughput baseline: 4200 events/min \|`). |
   | Empty block | Leave empty under the new header (`\| Link \| Description \|`) until rows arrive. |
   | Block whose body shape you don't recognize | **Stop and ask the user.** Don't guess. |

   Use `cumaru tag get <file> <tag>` to read the old body, transform with the rules above, write back with `cumaru tag set <file> <tag>`. The CLI accepts any body content; doctor flags drift afterwards.

5. **Bump local `framework-version:` to 4** in `.cumaru/index.md` after the v4 shape is reconciled. This records that the installed tree has completed the migration.

6. **Run `cumaru doctor`.** Expect:
   - `[✓] Schema conformance` — frontmatter intact.
   - `[✓] Pillar tables aligned with disk` — orphan check happy with the new rows.
   - `[✓] File references resolve on disk` — every link in every block resolves.
   If any check fails, the fix is local to the rows you just rewrote — the LLM adjudicates.

7. **Run `cumaru update --apply`** to pull pending framework prose updates and replace skills + hooks + slash commands. If you already ran it before the manual reconciliation, run it again to confirm no framework-file drift remains.

### Anything else?

If the tree carries pre-v3 artifacts that even v3 considered legacy (`BEGIN/END PROJECT-CUSTOM:` blocks, v2 `intake/{epics,stories,tickets}/` subdirs, `schema.bkp.yaml` backups, etc.), surface them to the user with a one-line description and propose the cleanup; don't delete unilaterally. The principle holds throughout: **deterministic steps run mechanically, judgment calls go to the LLM, destructive moves wait for explicit consent.**
