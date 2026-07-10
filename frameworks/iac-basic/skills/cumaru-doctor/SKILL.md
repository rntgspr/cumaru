---
human_revised: false
version: 1
name: cumaru-doctor
description: Use this skill whenever the user wants to validate the `.cumaru/` tree of a cumaru project — confirm the schema matches the disk, find orphan files/rows, surface tag/path contract violations. Trigger on phrases like "validate .cumaru/", "check the framework health", "rodar o doctor", "is .cumaru/ healthy?", "audit the project", "check for orphans", "find stray files in .cumaru/", "align the indexes", or any task that needs a health snapshot before another operation. `cumaru doctor` is the **default** subcommand — bare `cumaru` runs it.
---

# `cumaru doctor` — health checks (v5 schema-driven)

Runs end-to-end validation of the `.cumaru/` tree. **Pillar-agnostic**: structural checks read the schema and walk what it declares; generic marker and tool checks scan the tree without hardcoded pillar names.

## Invocation

```bash
cumaru                       # default subcommand = doctor
cumaru doctor
cumaru doctor --quiet        # suppress [✓] pass lines (warnings + errors + summary still print)
```

Exit codes: `0` ok (warnings allowed), `1` errors present, `2` usage.

## The 6 checks

Each emits exactly one line: `[✓] label` ok, `[⚠] label \n detail` warning, or `[✗] label \n detail` error. Final `Summary: X error(s), Y warning(s), Z ok`.

### [1] Schema conformance

Sub-passes (only details surface on error; clean runs collapse to one `[✓]`):

| Sub-pass | What it checks |
|---|---|
| `[0]` Universal markdown | H1 heading + `human_revised` frontmatter on every `.md` |
| `[1]` index.md frontmatter | `generated` + `apps`; `apps:` values must come from `meta.apps.values` |
| `[2]` Pillar index | `generated-at` + any pillar-specific extras (e.g. `tracker!` on intake) |
| `[3]` Entity frontmatter | Schema-driven walk of `root.entities`; validates each entity's `frontmatter:` |
| `[4]` pattern rules | Warning-only on bullets under declared requirements or scenario sections |

Cross-pass: `framework-version:` in `.cumaru/index.md` must equal `version:` in `schema.yaml`.

### [2] Orphan check (raiz + pilares)

Walks every `index.md` declared by the schema (raiz + each pillar key under `root.entities`), shows every markdown-table tag found, lists orphans in **both** directions:

- `✗ <label> — orphan row` — a row points at a path that doesn't exist on disk.
- `⚠ <name> — orphan file` — something on disk inside a pillar dir isn't claimed by any row (the reverse check runs for pilares only — raiz tables hold project-general entities, so reverse scope is too broad).

Bash is **mechanical** here: discovers and reports. **The LLM (you) reconciles** — apply the per-row guidance:

| Finding | How to reconcile |
|---|---|
| `✗ X — orphan row` (row but no file) | (a) row's path stale (typo/renamed) → fix the row via `cumaru tag set <pillar>/index.md <pillar>`; OR (b) entity was removed and row leaked → drop the row; OR (c) entity should still exist → recreate it. Ask the user when intent is unclear. |
| `⚠ Y — orphan file` (file but no row) | (a) new entity added but table not updated → add a row; OR (b) file is stray/debris → confirm before deleting. **Never delete adopter data without consent.** |
| Missing `index.md` for a pillar | Pillar declared in schema but index gone — likely interrupted uninstall or manual delete. Reinstall or recreate from the template. |
| `Orphan check skipped` (no pilares) | The schema has no `root.entities` — either the `base` domain (no pillars by design) or a pre-v3 tree. Apply the migration first if it's the latter. |

### [3] Stale work-marker files

Detects any `*.delete-me.md` anywhere under `.cumaru/` — work files an LLM recipe was supposed to clean up. Reports the file and points the LLM at the recipe that owns it (e.g. the archive recipe in the domain-specific `cumaru-archive` skill, when present).

### [4] Unrefined RAW blocks

Detects any Markdown file containing `<!-- BEGIN RAW`. The marker means source content still needs LLM refinement and must be deleted after refinement.

### [5] File references resolve on disk

v5: only `default` tag bodies are path-resolved `[Link, Description]` tables. Custom table tags are checked for their declared columns; `prose`, `mixed`, and `other` bodies are preserved but not path-resolved. Root `index.md` and `domain.md` links resolve from the project root. Template placeholders (`<KEY>`, `<area>`), external URLs (`http(s)://`, `mailto:`), and in-page anchors (`#…`) are skipped. Exception: `reference` rows resolve from the **project root** and must target repository source files — a row pointing inside `.cumaru/`, at a directory, an absolute path, or a URL reports as **invalid** (fix per the `cumaru-refs` skill).

### [6] External tools available

`curl`, `jq`, `git` on PATH. Some subcommands depend on them (intake needs curl+jq; sync via git URL needs git).

## What doctor does NOT check (LLM's job)

- **Workflow integrity** (tasks done without handoff, orphan delta-drafts after archive). Audited as part of recipe execution in the domain-specific recipe skills (e.g. `cumaru-archive` for sdlc).
- **Cross-file semantic links** (every `scope:` path resolves, every `depends-on:` references a real entity). Not enforced by `cumaru doctor`.
- **The schema's intent vs file content** — e.g. requirements quality, prose accuracy. These are author judgment, not validation.

## Workflow

When the user asks "is .cumaru/ healthy?" / "verifica isso" / "diagnose":

1. Run `cumaru doctor`.
2. Read the output line by line.
3. For each `[⚠]` and `[✗]`, surface what it means and propose the concrete fix (use the per-row table above for orphan check).
4. Apply fixes only with explicit confirmation, then re-run `cumaru doctor` to verify.

Pair with the other CLI skills: `cumaru-install` for re-installing a corrupted tree. For marker-block manipulation use the `cumaru tag` command and for raw file ops use `cumaru flow` (both are CLI-only — see `cumaru <cmd> --help`).
