# `llm sync`

Steady-state update of an installed `.llm/` tree from a fresh framework source. **Adopter data is never overwritten** — frontmatter values are preserved, tag bodies are preserved, only prose around them takes updates from the source.

## Usage

```
llm sync [<path>] [--from <src>] [--framework <name>] [--keep-prose] [--apply]
```

| Argument / flag | Description |
|---|---|
| `<path>` | Scope to a directory or file inside `.llm/`. Omit for full tree. |
| `--from <src>` | Source: a local dot-llm checkout path or a git URL. Default: the active checkout. |
| `--framework <name>` | Which flavor to sync against (must match the installed flavor). Default: `sdlc-it-project-basic`. |
| `--keep-prose` | Preserve local prose outside marker blocks (warns per file). Default: prose comes from source. |
| `--apply` | Apply the merge. Default is dry-run with a structured per-file review. |

## Per-file model — three regions

### 1. Frontmatter

**Adopter values are kept verbatim.** Sync only reports **key drift** — keys the source has that local lacks (and vice-versa) — so the LLM can reconcile against `schema.yaml`. Sync **never rewrites a frontmatter value**.

When sync reports key drift, the LLM's job is:
- Source-only key → add it to the local file with a value inferred from what `schema.yaml` says the field means.
- Local-only key → either it's adopter-added (harmless), or schema declares it and source is stale (investigate), or it's a stale field from a prior framework version (consider removing).

### 2. Tag bodies (`<!-- llm:NAME -->` blocks)

**Local body is preserved.** A marker present in source but absent locally is **added empty** (so new framework tags appear).

- **Table tags** (body shaped as markdown table): if column headers drifted between local and source, sync flags `[Δ]` with both headers. The LLM reshapes the body to match the source's header, keeping every row. Use `llm tag get` + `llm tag set` to round-trip.
- **String tags** (body is free prose with a schema `description:`): flagged `[?]` for verification. Often no change needed.
- **Path-list / number / empty**: bodies preserved as-is; the kind is reported for context.
- **Orphan tags** (local markers with no source counterpart): flagged `[orphan]` — decide to keep (intentional extension) or remove (stale).

### 3. Prose (everything else)

**Taken FROM SOURCE by default** — this is where framework updates land (new rules, refined explanations, documentation tweaks). `--keep-prose` opts out per invocation with a per-file warning that the tree may diverge from its spec.

## Version gate

Before doing anything, sync compares `version:` in the source `schema.yaml` against `framework-version:` in `.llm/index.md`. **Mismatch = MIGRATION, not sync** — the command refuses and points at the migration procedure. Steady-state sync only runs when the two versions match.

## File-presence triage

| Case | Action |
|---|---|
| **Source-only** (framework added a file) | Whole-copy on `--apply` |
| **Local-only** (adopter-created entity, e.g. `intake/JET-X/`, `plans/<ID>/`) | Never touched |
| **Both sides** (framework-shipped + present locally) | Per-file three-region model |

Passing an adopter-owned path as `<path>` is rejected with "no framework source exists for this path".

## Dry-run output (default)

For each file that needs attention, prints:
- Frontmatter key drift (source-only, local-only).
- Tag analysis (table column diff, kind labels, orphans).
- Unified diff of local → what `--apply` would produce.

Summary line lists each changed file as `[merge]` or `[new]`, plus the path to `schema.yaml` for reconciliation.

## `--apply` path

Performs the merge mechanically: prose from source, frontmatter + bodies preserved, missing markers added empty. The version gate already ensured both sides match, so no version-bump is needed after.

## What it does NOT do

Updates to the `llm` script itself and `src/*.sh` are **not** this command's responsibility — they live outside `.llm/`. To update those, re-run the install one-liner: `curl -fsSL https://pixelpunk.works/dot-llm/install.sh | bash`. The install script replaces `~/.dot-llm` wholesale (drops `.git/`) on every run.

## Examples

```bash
llm sync                                                       # dry-run from active checkout
llm sync --apply                                               # apply the mechanical merge
llm sync templates                                             # scope to a dir
llm sync intake/index.md                                       # scope to one file
llm sync --keep-prose --apply                                  # apply but keep local prose
llm sync --from /path/to/dot-llm                               # source from a local checkout
llm sync --from https://github.com/rntgspr/dot-llm.git         # source from git
llm sync --framework sdlc-it-project-basic                     # explicit flavor
```

## Related

- [`llm tag`](tag.md) — used to round-trip table bodies when column headers drift.
- [`llm doctor`](doctor.md) — run after sync to verify the merged tree.
- `/llm:sync` slash command — orchestrates sync + per-file review + confirmation before `--apply`.
