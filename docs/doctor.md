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

## The 7 checks

| # | Check | On issue |
|---|---|---|
| 1 | **Schema conformance** — sub-passes [0]..[4] over the `.cumaru/` tree against `schema.yaml` (universal markdown, index.md frontmatter, pillar index extras, entity frontmatter via schema-driven walk of `root.entities`, pattern rules via schema-driven `rules.*`). Cross-pass: `framework-version` ≡ `version:`. | **fail** on any error |
| 2 | **Orphan check** — walks the root `index.md`, `domain.md` (hosts the components table; anchored at the project root), and each pillar's `index.md` declared in `root.entities`; shows every markdown-table tag found, reports both directions: rows pointing at missing paths, and files/dirs on disk not claimed by any row (the reverse check runs for pillars only). | rows: **fail**; files: warn |
| 3 | **Stale work-marker files** — any `*.delete-me.md` lingering anywhere under `.cumaru/`. | warn |
| 4 | **Unrefined RAW blocks** — any Markdown file containing `<!-- BEGIN RAW`. The marker means source content still needs LLM refinement. | warn |
| 5 | **File references** — links reported by `cumaru tag all --rows` resolve on disk. Only `default` tag tables (`Link`, `Description`) are path-resolved. Template placeholders, external URLs, and in-page anchors are skipped by status. `reference` rows resolve from the project root and must target repository source files; rule-breaking rows report as `invalid` (see [`cumaru coverage`](coverage.md)). Custom/prose/mixed/other tags are not path-resolved. `cumaru tag all --tables` also checks expected vs actual column counts for custom deterministic table tags. | warn for missing/invalid |
| 6 | **External tools** — `curl`, `jq`, `git` available on PATH. Some subcommands depend on them (intake needs curl+jq; update from a git URL needs git; coverage needs git). | warn for missing |
| 7 | **Agent hook** — `CUMARU-HOOK` block in `.agents/AGENTS.md` or `CLAUDE.md` present and matching the canonical prose; warns if missing or drifted. | warn for missing/drift |

### Sub-passes inside check 1 (schema conformance)

| Pass | What |
|------|------|
| `[0]` | Universal markdown — H1 heading + `human_revised` frontmatter on every `.md` (`rules.markdown`). |
| `[1]` | `index.md` universal frontmatter — `generated`, `apps`; `apps:` values must come from `meta.apps.values`. |
| `[2]` | Pillar `index.md` — `generated-at` + any pillar-specific extras (e.g. `tracker!` on `intake/index.md` for sdlc). |
| `[3]` | Entity frontmatter — schema-driven walk of `root.entities`; validates each entity's declared `frontmatter:`. |
| `[4]` | Pattern rules — **schema-driven** from `rules.*` (`ears`, `gherkin`, etc.). Each rule declares a `pattern:`, an `applies_to:` list, and a `severity:`. The doctor scans every `.md` for bullets under matching section headings and flags non-matching lines. Anchored to `^##` so prose that cites the section name (in backticks) doesn't toggle the scanner. |

The schema-pass output is captured into a single `[✓]` / `[✗]` line at the orchestrator level — drilling into sub-pass detail only happens when there are errors.

## Archive integrity

In domains where `archive/` is transient staging (for example SDLC basic), a row in `archive/index.md` must point at an existing in-flight `archive/<KEY>/` directory. After absorption, the recipe removes both the directory and the row; durable absorption history lives in the domain's durable pillar (for SDLC, `specs/index.md` `cumaru:absorptions`).

The archive entity's `delta:` frontmatter is optional because it is only meaningful while the directory exists.

## What doctor does NOT check (LLM's job)

- **Workflow integrity** (tasks done without handoff, orphan delta-drafts after archive). Audited as part of recipe execution in the domain's recipe skills (e.g. `cumaru-archive` for sdlc).
- **Cross-file semantic links** (every `scope:` path resolves, every `depends-on:` references a real entity). Not enforced by `cumaru doctor`.
- **Schema intent vs. file content** — e.g. requirements quality, prose accuracy. These are author judgment, not validation.

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
- [`cumaru update`](update.md) — reconcile agent hook drift (check 7) from the framework source.
- `/cumaru:doctor` slash command — orchestrates doctor + remediation walk with user confirmation.
