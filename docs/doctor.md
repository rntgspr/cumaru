# `cumaru doctor`

Run health checks on a `.cumaru/` tree end-to-end. The default `cumaru` command — running `cumaru` with no args is equivalent to `cumaru doctor`.

For version 6 trees, `doctor` is **pillar-agnostic** and navigation-first. It reads the filesystem, summary frontmatter, the v6 migration manifest, retained semantic tags, and agent integration without hardcoded pillar names.

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

## The 7 v6 checks

| # | Check | On issue |
|---|---|---|
| 1 | **Navigation and summaries** — requires a real `index.md` in every non-hidden directory and validates the full `summary:` contract on every Markdown file. | **fail** |
| 2 | **Marker contracts** — fails on source-known retired structural inventories from `meta.migrations.v6.removable_tags`; reports unknown markers as preserved opaque bodies. | fail for retired; warn for unknown |
| 3 | **Stale work-marker files** — any `*.delete-me.md` lingering anywhere under `.cumaru/`. | warn |
| 4 | **Unrefined RAW blocks** — any Markdown file containing `<!-- BEGIN RAW`. The marker means source content still needs LLM refinement. | warn |
| 5 | **Retained file references** — only declared semantic tags (`files`, `touched`, `reference`) are path-resolved. `touched` accepts explicitly removed files; `reference` must target a repository source file. Unknown tags stay opaque. | warn for invalid |
| 6 | **External tools** — `curl`, `jq`, `yq`, and `git` available on PATH. | warn for missing |
| 7 | **Agent adapter** — reads `agent` from schema and validates native instructions, every expected `cumaru-*` skill, and supported commands. | fail for invalid state; warn for missing/drift |

`cumaru tree --deep` is the companion diagnostic for check 1: it keeps walking after defects, reports them on stderr, and returns nonzero at the end.

## Version gate

Doctor validates only framework v6 trees. A fresh installation already uses
v6. When an existing tree declares an older schema version, doctor stops and
directs the user to [`cumaru migrate v6`](migrate.md); the migration adapter is
independent and does not invoke doctor internally.

## Archive integrity

In domains where `archive/` is transient staging, its directory entries exist only while close-out is in flight. After absorption, the recipe removes the archive entity; durable absorption history lives in the domain's durable pillar through the `cumaru:absorptions` semantic tag.

The archive entity's `delta:` frontmatter is optional because it is only meaningful while the directory exists.

## What doctor does NOT check (LLM's job)

- **Workflow integrity** (tasks done without handoff, orphan delta-drafts after archive). Audited as part of recipe execution in the domain's recipe skills (e.g. `cumaru-archive` for sdlc).
- **Cross-file semantic links** (every `scope:` path resolves, every `depends-on:` references a real entity). Not enforced by `cumaru doctor`.
- **Complete schema conformance on v6 trees** — the current v6 path validates navigation contracts and retained marker semantics, not every schema-declared frontmatter field or prose pattern.
- **Schema intent vs. file content** — e.g. requirements quality and prose accuracy. These are author judgment, not validation.

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

- [`cumaru tag`](tag.md) — run `cumaru tree` to inspect the affected directory
- [`cumaru flow`](flow.md) — file ops to delete a stale `*.delete-me.md` (check 3) or fix a missing file reference (check 5).
- [`cumaru update`](update.md) — reconcile the active adapter or switch it (check 7).
- `/cumaru:doctor` slash command — orchestrates doctor + remediation walk with user confirmation.
