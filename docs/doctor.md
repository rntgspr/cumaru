# `cumaru doctor`

Run health checks on a `.cumaru/` tree end-to-end, offline and without writes.
It is the default command: running `cumaru` with no arguments is equivalent to
`cumaru doctor`. Configuration validation is a preflight: invalid config state
stops before the health checks run.

Doctor is **pillar-agnostic** and navigation-first. It reads the filesystem,
frontmatter, config-declared semantic tags, and agent instructions without
hardcoded pillar names.

## Usage

```text
cumaru doctor [--quiet]
```

| Flag | Description |
|---|---|
| `--quiet` | Suppresses `[ok]` pass lines. Warnings, errors, and the summary still print. |

## Preflight

The preflight stops with status `1` on stderr, before any check, when:

- The config version is below 9; doctor directs you to
  [`cumaru migrate`](migrate.md).
- The `.cumaru/` root or `config.yaml` is a symlink, or the config is malformed
  or invalid against the embedded schema.
- A declared entry is unsafe or missing, or wildcard contracts conflict.
- A configured workflow has invalid dependencies, a cycle, or a step whose skill
  is not installed in a supported adapter's skill directory.

## Output

Each check emits one line, followed by its diagnostics:

- `[ok]` pass
- `[warn]` soft issue (never fails the run)
- `[error]` hard issue (exits 1)

A summary line follows: `Summary: X error(s), Y warning(s), Z ok`. It counts
checks, not individual defects.

## The 10 checks

| # | Check | On issue |
|---|---|---|
| 1 | **Configured v9 tree contracts** — required frontmatter fields, declared `targets` vocabulary, the configured H1 heading, and required tags for each host, resolved through the config's selectors and path overrides. | **error** |
| 2 | **Navigation, summaries, and discipline metadata** — closed single-mapping frontmatter, a real `index.md` in every non-hidden directory, a valid `summary:` on every Markdown file, and `strictness: 0/10` through `10/10` on every discipline except its index. Symlinks and unsafe entries are blocking. | **error** |
| 3 | **Balanced semantic tags** — missing closers, crossing delimiters, and unmatched closers, with the host path and diagnostic. | **error** |
| 4 | **Unknown and nested tags** — balanced undeclared tags remain preserved opaque bodies; valid nesting remains queryable. | warn |
| 5 | **Stale work markers** — any `*.delete-me.md` under `.cumaru/`. | warn |
| 6 | **Unrefined RAW blocks** — any Markdown file containing `<!-- BEGIN RAW`. | warn |
| 7 | **Retained file references** — only declared `files`, `touched`, and `reference` tags are path-resolved. `touched` accepts explicitly removed files; `reference` follows the [coverage](coverage.md) source-file rule. | warn |
| 8 | **External tools** — `git` and `curl` on PATH, checked without running them. | warn |
| 9 | **Agent instructions** — at least one complete Generic, Claude, Codex, or OpenCode instruction set with the installed discipline bodies. Skills, commands, and hooks are outside this check. | warn |
| 10 | **Configuration drift** — missing domain defaults, by JSON Pointer, compared with the defaults embedded in this binary. Formatting, order, and additive local entries are ignored. | warn |

Check 10 makes no claim about freshness against `main`: new source defaults
require a newer binary. Use `cumaru version` or `cumaru update config` for the
main-HEAD comparison.

`cumaru tree --deep` is the companion diagnostic for check 2: it keeps walking
after defects, reports them on stderr, and returns nonzero at the end.

## What doctor does NOT check (LLM's job)

- **Workflow integrity** (tasks done without handoff, unfinished delta drafts at close-out). Audited as part of recipe execution in the domain's `cumaru-absorb` skill.
- **Cross-file semantic links** (every `scope:` path resolves, every `depends-on:` references a real entity).
- **Schema intent vs. file content** — e.g. requirements quality and prose accuracy. These are author judgment, not validation.
- **Remote freshness** — doctor never reads the network.

Malformed semantic tags make doctor exit `1` and block lifecycle cleanup. A
successful result establishes structural health, not completed implementation
or satisfied acceptance criteria; domain recipes require that evidence separately.

## Exit codes

- `0` — no errors (warnings allowed).
- `1` — preflight failure or at least one error.
- `2` — usage error (unknown flag).

## When to use

- Right after `cumaru install`.
- After editing config or any `.cumaru/` file.
- Before/after a structural change (plan absorption, update). `update --apply`
  and `--clear` already run it in quiet mode after publication.
- As a CI check on adopter projects.

## Examples

```bash
cumaru                                       # equivalent to cumaru doctor (default)
cumaru doctor --quiet                        # hide pass lines; show warnings + errors
```

## Related

- [`cumaru tree`](tree.md) — inspect the affected directory (check 2).
- [`cumaru tag`](tag.md) — inspect or repair semantic tag bodies (checks 1, 3, 4).
- [`cumaru fs`](fs.md) — file ops to delete a stale `*.delete-me.md` (check 5) or fix a missing file reference (check 7).
- [`cumaru update`](update.md) — install or clear explicit agent artifacts (check 9) and report config reconciliation (check 10).
- `cumaru-doctor` skill — orchestrates diagnosis and remediation; Generic and
  OpenCode also expose it through the `/cumaru:doctor` launcher.
