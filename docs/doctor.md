# `cumaru doctor`

Run health checks on a `.cumaru/` tree end-to-end. The default `cumaru` command — running `cumaru` with no args is equivalent to `cumaru doctor`. Complete configuration validation is a preflight: invalid config state stops before the eight health checks.

For version 7 trees, `doctor` is **pillar-agnostic** and navigation-first. It reads the filesystem, summary frontmatter, config-declared semantic tags, and agent integration without hardcoded pillar names.

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

## The 8 v7 checks

| # | Check | On issue |
|---|---|---|
| 1 | **Navigation, summaries, and discipline metadata** — requires a real `index.md` in every non-hidden directory, validates every Markdown `summary:`, and requires each discipline except its index to declare `strictness: 0/10` through `10/10`. Missing strictness is reported as invalid and treated as `0/10`. | **fail** |
| 2 | **Tag contracts** — derives known tags from the validated config, reports undeclared tags as preserved opaque bodies, and warns with the host path when valid tags are nested. Balanced nesting remains valid and queryable; retired tags such as `absorptions` remain visible for migration adjudication. | warn |
| 3 | **Stale work-marker files** — any `*.delete-me.md` lingering anywhere under `.cumaru/`. | warn |
| 4 | **Unrefined RAW blocks** — any Markdown file containing `<!-- BEGIN RAW`. The marker means source content still needs LLM refinement. | warn |
| 5 | **Retained file references** — only declared semantic tags (`files`, `touched`, `reference`) are path-resolved. `touched` accepts explicitly removed files; `reference` must target a repository source file. Unknown tags stay opaque. | warn for invalid |
| 6 | **External tools** — `curl`, `jq`, `yq`, and `git` available on PATH. | warn for missing |
| 7 | **Agent instructions** — reports green when at least one complete Claude, Codex, or OpenCode instruction set is installed. Skills, commands, and hooks are outside doctor's scope. | warn when none is complete |
| 8 | **Configuration drift** — compares the validated config with the current global schema and selected domain defaults, then gives the agent the source paths needed for deliberate reconciliation. | warn for agent review |

`cumaru tree --deep` is the companion diagnostic for check 1: it keeps walking after defects, reports them on stderr, and returns nonzero at the end.

## Version gate

Doctor validates only framework v7 trees. A fresh installation already uses
v7. When an existing tree declares an older config version, doctor stops and
directs the user to [`cumaru migrate`](migrate.md), which prints the migration
instructions for the LLM to execute.

## Archive integrity

In domains where `archive/` is transient staging, its directory entries exist only while close-out is in flight. After absorption the recipe removes the archive entity, and the updated durable pillar is the whole record — there is no ledger. `git log --all --grep=<KEY> --name-only` is the cross-reference back to the plan.

The archive entity's `delta:` frontmatter is optional because it is only meaningful while the directory exists.

## What doctor does NOT check (LLM's job)

- **Workflow integrity** (tasks done without handoff, orphan delta-drafts after archive). Audited as part of recipe execution in the domain's recipe skills (e.g. `cumaru-archive` for sdlc).
- **Cross-file semantic links** (every `scope:` path resolves, every `depends-on:` references a real entity). Not enforced by `cumaru doctor`.
- **Every document satisfying every schema-declared content rule** — preflight
  validates the schema itself and its cross-field contract; the eight checks do
  not enforce every declared frontmatter field or prose pattern on every file.
- **Rejecting malformed tags during doctor** — tag reads and update merges fail closed on malformed structure; check 2 currently reports retained/retired contracts and valid nesting rather than promoting every parser failure into its own doctor result.
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
- [`cumaru update`](update.md) — install or clear explicit agent artifacts (check 7).
- `/cumaru:doctor` slash command — forwards its arguments to the canonical
  `cumaru-doctor` skill, which orchestrates diagnosis and remediation.
