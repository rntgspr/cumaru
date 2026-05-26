---
human_revised: false
version: 1
name: llm-update
description: Use this skill whenever the user wants to update an installed `.llm/` tree — pull a fresher version of templates, roles, pillar starter prose, schema rules from the dot-llm source while keeping the adopter's tag bodies + frontmatter values intact, AND replace the installed skills and slash commands. Trigger on phrases like "update the framework", "update .llm/ from the source", "atualizar o framework instalado", "pull the latest framework changes", "diff .llm/ against the source", "migrate v2 → v3" (update refuses migrations — points the user at the right procedure), "update skills", "replace slash commands". Never use it for adopter content updates — this is for framework-owned files only.
---

# `llm update` — steady-state update of `.llm/`, skills, and slash commands

Updates three surfaces from the dot-llm source (the active checkout, or a git URL):

1. **Framework files inside `.llm/`** — adopter content (tag bodies, frontmatter values) is never overwritten; only the prose around them is taken from source.
2. **Skills** (`target/.llm/skills/`) — replaced wholesale from the source (framework-owned; no adopter customisation expected). Deprecated skills (locally present, absent from source) are listed but not removed.
3. **Slash commands** (`parent/.claude/commands/`) — replaced wholesale from the source. Deprecated commands listed but not removed.

## Usage

```bash
llm update                                        # dry-run: review .llm/ changes
llm update --apply                                # apply merge + replace skills/commands
llm update templates                              # scope .llm/ review to a dir
llm update intake/index.md                        # scope to one file
llm update --keep-prose --apply                   # apply but keep local prose (warns per file)
llm update --from /path/to/dot-llm                # source from a local checkout
llm update --from https://github.com/rntgspr/dot-llm.git
```

## Per-file model for `.llm/` — three regions

### 1. Frontmatter
**Adopter values are kept verbatim.** `llm update` only reports **key drift** — keys the source has that local lacks (and vice-versa) — so the LLM can reconcile against `schema.yaml`. **It never rewrites a frontmatter value.**

When update reports key drift, your job:
- Source-only key → add it to the local file, populated based on what `schema.yaml` says the field means.
- Local-only key → either it's adopter-added (and harmless), the schema declares it and source got out of date (rare; investigate), or it's a stale field from a prior framework version (consider removing).

### 2. Tag bodies (`<!-- llm:NAME -->` blocks)
**Local body is preserved.** A marker present in source but absent locally is **added empty** (so new framework tags appear).

For **table tags** (body shaped as markdown table): if the column header drifted between local and source, update flags `[Δ]` with both headers. Your job: reshape the body to match the source's header, **keep the rows**. Use `llm tag get` + `llm tag set` to round-trip.

For **string tags** (body is free prose with a schema description): flagged `[?]` for you to verify the prose still matches the schema subject. Often no change needed.

For **path-list / number / empty**: bodies preserved as-is; the kind is reported for context.

**Orphan tags** (local markers with no source counterpart) flagged as `[orphan]` — decide: keep (intentional adopter extension) or remove (stale).

### 3. Prose (everything else)
**Taken FROM SOURCE by default** — this is where framework updates land (new rules, refined explanations, documentation tweaks). `--keep-prose` opts out per invocation with a per-file warning that the tree may diverge.

## Skills and commands model (deterministic)

Skills and slash commands are **framework-owned artifacts** — adopters are not expected to edit them locally. On `--apply`:
- Every `llm-*` skill in the source `skills/` replaces its local counterpart (or is added if new).
- Every slash command in the source `commands/` replaces its local counterpart (or is added if new).
- Items present locally but absent from the source are reported as **deprecated** — listed with a warning, but NOT deleted. Remove them manually after confirming they are no longer needed.

Dry-run (without `--apply`) does **not** show skills/commands changes — they are always deterministic and need no review. They are replaced silently on `--apply`.

## Version gate

Before doing anything, `llm update` compares `version:` in source `schema.yaml` against `framework-version:` in `.llm/index.md`. **Mismatch = MIGRATION, not update** — the command refuses and points at the appropriate migration procedure. Steady-state update only runs when the two versions match.

## File-presence triage (mechanical)

| Case | Action |
|---|---|
| **Source-only** (framework added a file) | Whole-copy on `--apply` |
| **Local-only** (adopter-created entity, e.g. `intake/JET-X/`, `plans/<ID>/`) | Never touched |
| **Both sides** (framework-shipped + present locally) | Per-file three-region model |

Passing an adopter-owned path as `<path>` arg is rejected.

## Default vs `--apply`

**Default (dry-run)** prints a structured per-file review for `.llm/` files: frontmatter key drift, tag analysis (table column diff, kind labels, orphans), and a unified diff of `local → what --apply would produce`. Summary lists each changed file as `[merge]` or `[new]` and notes that skills/commands will also be replaced on `--apply`.

**`--apply`** performs the full update: `.llm/` file merge + skills replace + commands replace.

## When the LLM (you) gets involved

The `.llm/` portion is mostly mechanical, but **you adjudicate the ambiguous cases**:

1. **Frontmatter key drift** — add/remove keys against `schema.yaml`.
2. **Table tag column drift** (`[Δ]`) — reshape body rows to match the new headers, preserving every row.
3. **String tag drift** (`[?]`) — read both versions, decide if the local prose still matches the source's schema description.
4. **Orphan tags** (`[orphan]`) — confirm with the user before removing.
5. **Deprecated skills/commands** — inform the user; suggest removal only when you are confident the item is no longer needed.

## Patterns

| User says | You do |
|---|---|
| "Update the framework" / "atualizar o framework" | `llm update` (dry-run) → walk the per-file review → `llm update --apply` if clean, or hand-reconcile drift first |
| "Update only templates" | `llm update templates --apply` |
| "Just preview the diff" | `llm update` without `--apply` |
| "Keep my custom prose in this file" | `llm update --keep-prose --apply` (warns per-file that framework prose updates are skipped) |
| "Migrate v2 → v3" | Update refuses on version mismatch — use the migration procedure |

## Why this design

The "script reports, LLM adjudicates" split for `.llm/` files is load-bearing:
- **Tag bodies are adopter data** (the components table, pillar entries, `apps.values`, project-context prose). Overwriting = silent data loss.
- **Frontmatter values are adopter data** (`apps:`, `status:`, `key:`). The schema declares the contract (which keys); the adopter owns the values.
- **Prose comes from source** because that's where framework rule updates live.
- **Skills/commands are framework data** — deterministic replace is safe and correct. Deprecation reporting gives the user visibility without silent deletions.

Use `llm tag get/set` (CLI, no skill) for the round-trip when reshaping table bodies; pair with `llm-doctor` to verify the merged tree is still healthy.
