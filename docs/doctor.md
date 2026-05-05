# `llm doctor`

Run health checks on a `.llm/` tree end-to-end. The default `llm` command — running `llm` with no args is equivalent to `llm doctor`.

`doctor` runs **schema conformance** plus **tree-wide structural checks** in one pass.

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

## Checks performed

| # | Check | On issue |
|---|---|---|
| 1 | **Schema conformance** — sub-passes [0]..[5] over the `.llm/` tree against `schema.yaml` (frontmatter required fields, EARS pattern in AC/Requirements, `framework-version` ≡ `version:`) | **fail** on any error |
| 2 | **Shallow index drift** — compares each pillar's current `index.md` against what `llm regen index` would produce | warn if drifted |
| 3 | **Tasks done w/o handoff** — flags `t<N>.md` with `status: done` lacking a sibling `handoff-t<N>.md` | warn |
| 4 | **Orphan archive work files** — `temp-archive-flow.delete-me.md` lingering under `archive/` (Phase 2 pending) | warn |
| 5 | **Orphan delta-drafts** — `delta-draft.md` still in `plans/<ID>/` after `archive/<ID>/` exists | **fail** (inconsistent state) |
| 6 | **File references** — paths inside `<!-- llm:files:<tag> -->` blocks resolve on disk (relative to the repo root, parent of `.llm/`) | warn for missing |
| 7 | **External tools** — `curl`, `jq`, `git`, `rsync` available on PATH | warn for missing |

### Sub-passes inside check 1 (schema conformance)

| Pass | What |
|------|------|
| `[0]` | Every `.md` has at least one `# H1` heading |
| `[1]` | Every `index.md` has frontmatter `generated, apps`; `apps:` values are in `apps.values` |
| `[2]` | Plans: `index.md` requires `generated, apps, status, summary, scope`; tasks (`t<N>.md`) require `plan, task, depends-on, concerns, files, status, apps`. EARS pattern warned in `## Acceptance Criteria` |
| `[3]` | Spec areas (recursive — areas may nest as subareas at any depth): `index.md` requires `generated, name, summary, depends-on, apps, deltas`. EARS pattern warned in `## Requirements`. Concerns require `generated, apps` (skips `history.md` and `bootstrap.md`) |
| `[4]` | Archive: `index.md` requires `generated, status, summary, apps` |
| `[5]` | Exploring: `index.md` requires `generated, status, apps, summary` |
| Cross | `framework-version` in `.llm/index.md` must equal `version:` in `schema.yaml` (errors on mismatch) |

EARS pattern: `WHEN .+ THE SYSTEM SHALL .+`. Non-conforming bullets emit warnings, not errors. The schema-pass output is captured into a single `[✓]` / `[✗]` line at the orchestrator level — drilling into the sub-pass detail only happens when there are errors.

## What it does NOT check

Cross-file consistency (path resolution, `depends-on:` resolution, `## Files` existence on disk, `deltas:` references) is listed in `schema.yaml` under `cross_file_checks.deferred` and not yet enforced. The plan `maintenance-validator-parity` tracks the gap between the schema's declared required fields and the schema-pass coverage.

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
llm doctor --quiet                      # hide pass lines; show warnings + errors
DOT_LLM_DIR=path/to/.llm llm doctor     # operate on a non-default tree
```

## Related

- [`llm regen index`](regen.md) — fix shallow index drift surfaced by check 2.
- [`llm archive finalize`](archive.md) — clear lingering work files surfaced by checks 4 and 5.
