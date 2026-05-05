# `llm specs`

Operations on the `specs/` pillar. Three subcommands: `bootstrap` (light pass), `deep` (deep pass), `consolidate` (compact deltas).

## Usage

```
llm specs bootstrap [--path <dir>] [--apply]
llm specs deep <area> [--topic <slug>] [--apply]
llm specs consolidate <area> [--apply]
```

All three default to **dry-run**. Pass `--apply` to write.

## `llm specs bootstrap`

Light discovery pass: scans the project's source tree for top-level areas and writes `specs/<area>/bootstrap.md` per area. The bootstrap file is a persistent discovery log carrying CLI-collected metrics (file count, LOC, external imports, cross-area imports, TODO/FIXME) plus instructions for an LLM to draft `specs/<area>/index.md` and list "Topics" worth deepening later.

| Flag | Description |
|---|---|
| `--path <dir>` | Override scan path. Auto-detects `src/`, `app/`, `lib/`. |
| `--apply` | Write the bootstrap files. Default is dry-run (lists candidate areas). |

**Skips areas that already have `bootstrap.md`.**

## `llm specs deep <area>`

Deep discovery pass: appends a new `## Discovery (deep pass <ISO>) — <scope>` section to an existing `bootstrap.md`. Never edits prior sections.

| Flag | Description |
|---|---|
| `--topic <slug>` | Focus the pass on a specific topic listed under `## Topics`. Default: all topics. |
| `--apply` | Write the appended section. Default is dry-run. |

**Requires** `specs/<area>/bootstrap.md` to already exist (run `llm specs bootstrap --apply` first).

## `llm specs consolidate <area>`

Compact a spec area by absorbing its archive deltas into the body. Writes a persistent `specs/<area>/history.md` work file with:

1. The current spec body.
2. Each delta in chronological order (oldest first).
3. Step-by-step instructions for the LLM to rewrite `specs/<area>/index.md` compactly and replace the long `deltas:` list with a single `consolidated-at: <ISO date>` field.

| Flag | Description |
|---|---|
| `--apply` | Write the work file. Default is dry-run (prints target file, delta count, plan IDs). |

**Refuses if `history.md` already exists** — finish the previous consolidation first.

**Archive entries are NOT touched** — history is preserved on disk; only the spec frontmatter's reference shape changes (long list → single date).

## Why consolidate?

Over time, a spec area accumulates many `deltas:` and absorbed history. Consolidation keeps the loaded context lean: the LLM reads one compact spec instead of the body plus a chain of historical deltas.

## Examples

```bash
llm specs bootstrap                                # dry-run
llm specs bootstrap --apply                        # create bootstrap.md per area
llm specs deep auth --apply                        # append deep section, all topics
llm specs deep auth --topic mfa-flow --apply       # focused topic
llm specs consolidate auth                         # dry-run
llm specs consolidate auth --apply                 # write history.md + LLM rewrites the spec
```

## Related

- [`llm regen index specs`](regen.md) — refresh `specs/index.md` after bootstrap.
