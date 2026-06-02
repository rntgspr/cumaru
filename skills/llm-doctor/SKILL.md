---
human_revised: false
version: 1
name: llm-doctor
description: Use this skill whenever the user wants to validate the `.llm/` tree of a dot-llm project — confirm the schema matches the disk, find orphan files/rows, surface any v3 contract violations. Trigger on phrases like "validate .llm/", "check the framework health", "rodar o doctor", "is .llm/ healthy?", "audit the project", "check for orphans", "find stray files in .llm/", "align the indexes", or any task that needs a health snapshot before another operation. `llm doctor` is the **default** subcommand — bare `llm` runs it.
---

# `llm doctor` — health checks (v3 schema-driven)

Runs end-to-end validation of the `.llm/` tree. **Pillar-agnostic**: every check reads the schema and walks what it declares — adding/removing a pillar in `schema.yaml` doesn't require touching this code.

## Invocation

```bash
llm                       # default subcommand = doctor
llm doctor
llm doctor --quiet        # suppress [✓] pass lines (warnings + errors + summary still print)
DOT_LLM_DIR=path/to/.llm llm doctor    # operate on a non-default tree
```

Exit codes: `0` ok (warnings allowed), `1` errors present, `2` usage.

## The 5 checks

Each emits exactly one line: `[✓] label` ok, `[⚠] label \n detail` warning, or `[✗] label \n detail` error. Final `Summary: X error(s), Y warning(s), Z ok`.

### [1] Schema conformance

Sub-passes (only details surface on error; clean runs collapse to one `[✓]`):

| Sub-pass | What it checks |
|---|---|
| `[0]` Universal markdown | H1 heading + `human_revised` frontmatter on every `.md` |
| `[1]` index.md frontmatter | `generated` + `apps`; `apps:` values must come from `meta.apps.values` |
| `[2]` Pillar index | `generated-at` + any pillar-specific extras (e.g. `tracker!` on intake) |
| `[3]` Entity frontmatter | Schema-driven walk of `root.entities`; validates each entity's `frontmatter:` |
| `[4]` EARS pattern | Warning-only on bullets under `## Acceptance Criteria` / `## Requirements` |

Cross-pass: `framework-version:` in `.llm/index.md` must equal `version:` in `schema.yaml`.

### [2] Orphan check (raiz + pilares)

Walks every `index.md` declared by the schema (raiz + each pillar key under `root.entities`), shows every markdown-table tag found, lists orphans in **both** directions:

- `✗ <label> — orphan row` — a row points at a path that doesn't exist on disk.
- `⚠ <name> — orphan file` — something on disk inside a pillar dir isn't claimed by any row (the reverse check runs for pilares only — raiz tables hold project-general entities, so reverse scope is too broad).

Bash is **mechanical** here: discovers and reports. **The LLM (you) reconciles** — apply the per-row guidance:

| Finding | How to reconcile |
|---|---|
| `✗ X — orphan row` (row but no file) | (a) row's path stale (typo/renamed) → fix the row via `llm tag set <pillar>/index.md <pillar>`; OR (b) entity was removed and row leaked → drop the row; OR (c) entity should still exist → recreate it. Ask the user when intent is unclear. |
| `⚠ Y — orphan file` (file but no row) | (a) new entity added but table not updated → add a row; OR (b) file is stray/debris → confirm before deleting. **Never delete adopter data without consent.** |
| Missing `index.md` for a pillar | Pillar declared in schema but index gone — likely interrupted uninstall or manual delete. Reinstall or recreate from the template. |
| `Orphan check skipped` (no pilares) | The schema has no `root.entities` (pre-v3 shape). Apply the v2 → v3 migration first. |

### [3] Stale work-marker files

Detects any `*.delete-me.md` anywhere under `.llm/` — work files an LLM recipe was supposed to clean up. Reports the file and points the LLM at the recipe that owns it (e.g. the archive recipe in the flavor-specific `llm-archive` skill, when present).

### [4] File references resolve on disk

Walks every marker block whose body is a path-list (`- \`path\``) and checks each path exists. **Marker-name-agnostic** — works for `plans:plan:handoff:files` or any other tag whose body is shaped as a path-list. Template placeholders (`<KEY>`, `<area>`) are skipped.

### [5] External tools available

`curl`, `jq`, `git`, `rsync` on PATH. Some subcommands depend on them (intake needs curl+jq; sync via git URL needs git).

## What doctor does NOT check (LLM's job)

- **Workflow integrity** (tasks done without handoff, orphan delta-drafts after archive). These moved out of doctor in v3 — they're audited as part of recipe execution in the flavor-specific recipe skills (e.g. `llm-archive` for sdlc).
- **Cross-file semantic links** (every `scope:` path resolves, every `depends-on:` references a real entity). Listed in `schema.yaml > meta.cross_file_checks.deferred`.
- **The schema's intent vs file content** — e.g. EARS quality, prose accuracy. These are author judgment, not validation.

## Workflow

When the user asks "is .llm/ healthy?" / "verifica isso" / "diagnose":

1. Run `llm doctor`.
2. Read the output line by line.
3. For each `[⚠]` and `[✗]`, surface what it means and propose the concrete fix (use the per-row table above for orphan check).
4. Apply fixes only with explicit confirmation, then re-run `llm doctor` to verify.

Pair with the other CLI skills: `llm-install` for re-installing a corrupted tree. For marker-block manipulation use the `llm tag` command and for raw file ops use `llm flow` (both are CLI-only — see `llm <cmd> --help`).
