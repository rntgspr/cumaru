# `cumaru doctor`

Run health checks on a `.cumaru/` tree end-to-end. The default `cumaru` command — running `cumaru` with no args is equivalent to `cumaru doctor`.

`doctor` is **pillar-agnostic**. Structural checks read `schema.yaml` and walk what it declares; generic marker and tool checks scan the tree without hardcoded pillar names. Adding or removing a pillar in the schema doesn't require touching this code.

## Usage

```
cumaru doctor [--quiet]
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

## The 6 checks

| # | Check | On issue |
|---|---|---|
| 1 | **Schema conformance** — sub-passes [0]..[4] over the `.cumaru/` tree against `schema.yaml` (universal markdown, index.md frontmatter, pillar index extras, entity frontmatter via schema-driven walk of `root.entities`, EARS pattern). Cross-pass: `framework-version` ≡ `version:`. | **fail** on any error |
| 2 | **Orphan check** — walks the root `index.md`, `domain.md` (hosts the components table; anchored at the project root), and each pillar's `index.md` declared in `root.entities`; shows every markdown-table tag found, reports both directions: rows pointing at missing paths, and files/dirs on disk not claimed by any row (the reverse check runs for pillars only). | rows: **fail**; files: warn |
| 3 | **Stale work-marker files** — any `*.delete-me.md` lingering anywhere under `.cumaru/`. | warn |
| 4 | **Unrefined RAW blocks** — any Markdown file containing `<!-- BEGIN RAW`. The marker means source content still needs LLM refinement. | warn |
| 5 | **File references** — links reported by `cumaru tag all --rows` resolve on disk. Template placeholders, external URLs, and in-page anchors are skipped by status. `reference` rows resolve from the project root and must target repository source files; rule-breaking rows report as `invalid` (see [`cumaru coverage`](coverage.md)). | warn for missing/invalid |
| 6 | **External tools** — `curl`, `jq`, `git` available on PATH. Some subcommands depend on them (intake needs curl+jq; update from a git URL needs git; coverage needs git). | warn for missing |

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

The `archive/` pillar uses an ephemeral-directory model — see the `cumaru-archive` skill. v4 doctor tolerates the post-prune steady state: a row in `archive/index.md` whose Link points at a missing `archive/<KEY>/` directory is **expected** (it was pruned in archive flow Phase 4) and emits no warning. The Description column carries the absorbed commit SHA, so `git show <sha>` retrieves the change wording.

The archive entity's `delta:` frontmatter is optional, because it's only meaningful while the directory exists.

Reverse check (dir on disk not claimed by any row) still warns — unattributed `archive/<KEY>/` directories are unusual whether or not the ephemeral model is in use.

## What doctor does NOT check (LLM's job)

- **Workflow integrity** (tasks done without handoff, orphan delta-drafts after archive). Audited as part of recipe execution in the domain's recipe skills (e.g. `cumaru-archive` for sdlc).
- **Cross-file semantic links** (every `scope:` path resolves, every `depends-on:` references a real entity). Listed in `schema.yaml > meta.cross_file_checks.deferred`.
- **Schema intent vs. file content** — e.g. EARS quality, prose accuracy. These are author judgment, not validation.

## Exit codes

- `0` — no errors (warnings allowed).
- `1` — at least one error.
- `2` — usage error (unknown flag).

## When to use

- Right after `cumaru install` (sanity check the starter copied cleanly).
- After editing schema or any `.cumaru/` file.
- Before/after a structural change (archive close, update).
- As a CI check on adopter projects.
- When something feels off and you want a holistic snapshot.

## Examples

```bash
cumaru                                       # equivalent to cumaru doctor (default)
cumaru doctor --quiet                        # hide pass lines; show warnings + errors
```

## Related

- [`cumaru tag`](tag.md) — re-emit a marker block body (used to fix orphan rows surfaced by check 2).
- [`cumaru flow`](flow.md) — file ops to delete a stale `*.delete-me.md` (check 3) or fix a missing file reference (check 5).
- `/cumaru:doctor` slash command — orchestrates doctor + remediation walk with user confirmation.
