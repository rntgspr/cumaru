---
human_revised: false
name: llm-sync
description: Use this skill whenever the user wants to update the framework files inside an installed `.llm/` tree — pull a fresher version of templates, roles, pillar starter prose, schema rules from the dot-llm source while keeping the adopter's tag bodies + frontmatter values intact. Trigger on phrases like "sync the framework", "update .llm/ from the source", "atualizar o framework instalado", "pull the latest framework changes", "diff .llm/ against the source", "migrate v2 → v3" (sync refuses migrations — points the user at the right procedure). Never use it for adopter content updates — sync is for framework files only.
---

# `llm sync` — steady-state update of `.llm/` from the framework source

Updates the framework-shipped files inside `.llm/` from a fresh source (the dot-llm checkout, or a git URL). **Adopter content is never overwritten** — tag bodies are preserved (your data); frontmatter values are preserved (your data); only the prose around them takes updates from source (the framework's rules).

## Usage

```bash
llm sync                                          # dry-run from active checkout
llm sync --apply                                  # apply the mechanical merge
llm sync templates                                # scope to a dir
llm sync intake/index.md                          # scope to one file
llm sync --keep-prose --apply                     # apply but keep local prose (warns per file)
llm sync --from /path/to/dot-llm                  # source from a local checkout
llm sync --from https://github.com/rntgspr/dot-llm.git
llm sync --framework <name>                       # explicit flavor (default: sdlc-it-project-basic)
```

## Per-file model — three regions

### 1. Frontmatter
**Adopter values are kept verbatim.** Sync only reports **key drift** — keys the source has that local lacks (and vice-versa) — so the LLM can reconcile against `schema.yaml`. **It never rewrites a frontmatter value.**

When sync reports key drift, your job:
- Source-only key → add it to the local file, populated based on what `schema.yaml` says the field means.
- Local-only key → either it's adopter-added (and harmless), the schema declares it and source got out of date (rare; investigate), or it's a stale field from a prior framework version (consider removing).

### 2. Tag bodies (`<!-- llm:NAME -->` blocks)
**Local body is preserved.** A marker present in source but absent locally is **added empty** (so new framework tags appear).

For **table tags** (body shaped as markdown table): if the column header drifted between local and source, sync flags `[Δ]` with both headers. Your job: reshape the body to match the source's header, **keep the rows**. Use `llm tag get` + `llm tag set` to round-trip.

For **string tags** (body is free prose with a schema description): flagged `[?]` for you to verify the prose still matches the schema subject. Often no change needed.

For **path-list / number / empty**: bodies preserved as-is; the kind is reported for context.

**Orphan tags** (local markers with no source counterpart) flagged as `[orphan]` — decide: keep (intentional adopter extension) or remove (stale).

### 3. Prose (everything else)
**Taken FROM SOURCE by default** — this is where framework updates land (new rules, refined explanations, documentation tweaks). `--keep-prose` opts out per invocation with a per-file warning that the tree may diverge from its spec.

## Version gate

Before doing anything, sync compares `version:` in source `schema.yaml` against `framework-version:` in `.llm/index.md`. **Mismatch = MIGRATION, not sync** — the command refuses and points at the v2 → v3 procedure (or whichever transition applies). Steady-state sync only runs when the two versions match.

## File-presence triage (mechanical)

Three cases the script classifies first:

| Case | Action |
|---|---|
| **Source-only** (framework added a file) | Whole-copy on `--apply` |
| **Local-only** (adopter-created entity, e.g. `intake/JET-X/`, `plans/<ID>/`) | Never touched |
| **Both sides** (framework-shipped + present locally) | Per-file three-region model |

Passing an adopter-owned path as `<path>` arg is rejected with "no framework source exists for this path".

## Default vs `--apply`

**Default (dry-run)** prints a structured per-file review: frontmatter key drift, tag analysis (table column diff, kind labels, orphans), and a unified diff of `local → what --apply would produce`. The summary lists each changed file as `[merge]` or `[new]`, plus the path to `schema.yaml` for reconciliation.

**`--apply`** performs the merge mechanically: prose from source, frontmatter + bodies preserved, missing markers added empty. The version-bump field doesn't need adjustment (the gate already ensured both sides match).

## When the LLM (you) gets involved

Sync is mostly mechanical, but **you adjudicate the ambiguous cases**:

1. **Frontmatter key drift** — add/remove keys against `schema.yaml`.
2. **Table tag column drift** (`[Δ]`) — reshape body rows to match the new headers, preserving every row.
3. **String tag drift** (`[?]`) — read both versions, decide if the local prose still matches the source's schema description.
4. **Orphan tags** (`[orphan]`) — confirm with the user before removing.

## Patterns

| User says | You do |
|---|---|
| "Sync the framework" / "atualizar o framework" | `llm sync` (dry-run) → walk the per-file review → `llm sync --apply` if clean, or hand-reconcile drift first |
| "Update only templates" | `llm sync templates --apply` |
| "Just preview the diff" | `llm sync` without `--apply` |
| "Keep my custom prose in this file" | `llm sync --keep-prose --apply` (warns per-file that framework prose updates are skipped) |
| "Migrate v2 → v3" | Sync refuses on version mismatch — use the migration procedure in your release notes / docs |

## Why this design

The "script reports, LLM adjudicates" split is load-bearing:
- **Tag bodies are adopter data** (the components table, pillar entries, `apps.values`, project-context prose). Overwriting = silent data loss.
- **Frontmatter values are adopter data** (`apps:`, `status:`, `key:`). The schema declares the contract (which keys); the adopter owns the values.
- **Prose comes from source** because that's where framework rule updates live. Without this, sync's main job (delivering framework updates) doesn't happen.

Use `llm tag get/set` (CLI, no skill) for the round-trip when reshaping table bodies; pair with `llm-doctor` to verify the merged tree is still healthy.
