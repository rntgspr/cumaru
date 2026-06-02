# `llm doctor`

Run health checks on a `.llm/` tree end-to-end. The default `llm` command — running `llm` with no args is equivalent to `llm doctor`.

`doctor` is **schema-driven and pillar-agnostic**: every check reads `schema.yaml` and walks what it declares. Adding or removing a pillar in the schema doesn't require touching this code.

## Usage

```
llm doctor [--quiet]
```

| Flag | Description |
|---|---|
| `--quiet` | Suppresses `[✓]` pass lines. Warnings, errors, and the summary still print. |

## Output

Each top-level check emits exactly one line:

- `[✓]` pass
- `[⚠]` soft issue (warning; never fails the run)
- `[✗]` hard issue (error; exits 1)

Followed by a summary line: `Summary: X error(s), Y warning(s), Z ok`.

## The 5 checks

| # | Check | On issue |
|---|---|---|
| 1 | **Schema conformance** — sub-passes [0]..[4] over the `.llm/` tree against `schema.yaml` (universal markdown, index.md frontmatter, pillar index extras, entity frontmatter via schema-driven walk of `root.entities`, EARS pattern). Cross-pass: `framework-version` ≡ `version:`. | **fail** on any error |
| 2 | **Orphan check** — walks every `index.md` declared by the schema (root + each pillar in `root.entities`), shows every markdown-table tag found, reports both directions: rows pointing at missing paths, and files/dirs on disk not claimed by any row (the reverse check runs for pillars only). | rows: **fail**; files: warn |
| 3 | **Stale work-marker files** — any `*.delete-me.md` lingering anywhere under `.llm/`. | warn |
| 4 | **File references** — paths inside any path-list tag block (detection is by **body shape**, not marker name — works for nested marker names like `plans:plan:handoff:files`) resolve on disk relative to the repo root. Template placeholders (`<KEY>`, `<area>`) are skipped. | warn for missing |
| 5 | **External tools** — `curl`, `jq`, `git`, `rsync` available on PATH. Some subcommands depend on them (intake needs curl+jq; sync via git URL needs git). | warn for missing |

### Sub-passes inside check 1 (schema conformance)

| Pass | What |
|------|------|
| `[0]` | Universal markdown — H1 heading + `human_revised` frontmatter on every `.md` (`rules.markdown`). |
| `[1]` | `index.md` universal frontmatter — `generated`, `apps`; `apps:` values must come from `meta.apps.values`. |
| `[2]` | Pillar `index.md` — `generated-at` + any pillar-specific extras (e.g. `tracker!` on `intake/index.md` for sdlc). |
| `[3]` | Entity frontmatter — schema-driven walk of `root.entities`; validates each entity's declared `frontmatter:`. |
| `[4]` | EARS pattern — `WHEN .+ THE SYSTEM SHALL .+`. Warning-only on bullets under `## Acceptance Criteria` / `## Requirements`. Marker is anchored to `^##` so prose that cites the section name (in backticks) doesn't trigger the toggle. |

The schema-pass output is captured into a single `[✓]` / `[✗]` line at the orchestrator level — drilling into sub-pass detail only happens when there are errors.

## Archive integrity tolerance

The `archive/` pillar (SDLC flavor) uses an ephemeral-directory model — see the `llm-archive` skill. Doctor's orphan check (check #2) recognizes four combinations of row + directory state:

| Row in `archive/index.md` | `archive/<KEY>/` on disk | Doctor verdict |
|---|---|---|
| Row carries `Absorbed-in: <sha>` | Directory absent | **OK** — expected post-prune state. Not an orphan. |
| Row has no `Absorbed-in:` | Directory present | **OK** — in-flight archive, between Phase 1 and Phase 4. |
| Row has no `Absorbed-in:` | Directory absent | **Error** — pruned without recording absorption. Investigate the missing SHA. |
| Row carries `Absorbed-in: <sha>` | Directory present | **Warning** — recorded as absorbed but directory still on disk; expected pruned. |

A separate frontmatter consequence: the archive entity's `delta:` frontmatter is optional (since v3) because it's only meaningful while the directory exists. A row with `Absorbed-in:` populated and no surviving directory will naturally have no `delta:` frontmatter to validate.

Reverse check (dir on disk not claimed by any row) still warns — unattributed `archive/<KEY>/` directories are unusual whether or not the ephemeral model is in use.

## What doctor does NOT check (LLM's job)

- **Workflow integrity** (tasks done without handoff, orphan delta-drafts after archive). These moved out of doctor in v3 — they're audited as part of recipe execution in the flavor's recipe skills (e.g. `llm-archive` for sdlc).
- **Cross-file semantic links** (every `scope:` path resolves, every `depends-on:` references a real entity). Listed in `schema.yaml > meta.cross_file_checks.deferred`.
- **Schema intent vs. file content** — e.g. EARS quality, prose accuracy. These are author judgment, not validation.

## Exit codes

- `0` — no errors (warnings allowed).
- `1` — at least one error.
- `2` — usage error (unknown flag).

## When to use

- Right after `llm install` (sanity check the starter copied cleanly).
- After editing schema or any `.llm/` file.
- Before/after a structural change (archive close, sync).
- As a CI check on adopter projects.
- When something feels off and you want a holistic snapshot.

## Examples

```bash
llm                                       # equivalent to llm doctor (default)
llm doctor --quiet                        # hide pass lines; show warnings + errors
DOT_LLM_DIR=path/to/.llm llm doctor       # operate on a non-default tree
```

## Related

- [`llm tag`](tag.md) — re-emit a marker block body (used to fix orphan rows surfaced by check 2).
- [`llm flow`](flow.md) — file ops to delete a stale `*.delete-me.md` (check 3) or fix a missing path-list reference (check 4).
- `/llm:doctor` slash command — orchestrates doctor + remediation walk with user confirmation.
