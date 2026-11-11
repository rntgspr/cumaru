# `cumaru doctor`

Run health checks on a `.cumaru/` tree end-to-end without editing adopter files.
Doctor may read GitHub main at most once per day for the
[drift reference](#configuration-drift-reference) and caches it under
`.cumaru/.cache/`. The other opt-in side effect: with `meta.doctor.after.warm: true`, a passing report
is followed by warming the `adopter` [vector cache](context.md#vector-cache);
a warm failure (such as a missing listed `meta.context.adopter` path) fails
doctor, while no enabled encoder only prints the "nothing to cache" notice.
Domains ship the flag as `false`.
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
| 10 | **Configuration drift** — missing domain defaults, by JSON Pointer, compared with the domain's `config.yaml` on GitHub main ([reference](#configuration-drift-reference)). Formatting, order, and additive local entries are ignored. Entries of the reference `meta.context.framework` / `meta.context.adopter` lists absent locally are named. | warn |

### Configuration drift reference

Check 10 compares against `domains/<domain>/config.yaml` on GitHub main, fetched
by the adopter's `domain` and cached as `.cumaru/.cache/config-<YYYY-MM-DD>.yaml`
(UTC calendar day; the `.cumaru/.cache/` `.gitignore` entry is added if absent):

1. Today's file with a matching `domain:` is used without network.
2. Otherwise main is downloaded, today's file is written atomically, and older
   `config-*.yaml` files are deleted. Delete today's file to force a refetch.
3. Offline with an older matching file: that file is used and a warning names
   its date.
4. Offline with no usable file, or a domain absent from main (custom domains):
   a warning says drift was not checked; doctor relies on schema validation
   and does not fail for this.

A reference `version` newer than this binary supports stops doctor with an
error asking for `cumaru migrate`. Symlinked cache paths are refused.
`meta.context.source` is not compared. Use `cumaru update config` to review the
full candidate.

`cumaru tree --deep` is the companion diagnostic for check 2: it keeps walking
after defects, reports them on stderr, and returns nonzero at the end.

## What doctor does NOT check (LLM's job)

- **Workflow integrity** (tasks done without handoff, unfinished delta drafts at close-out). Audited as part of recipe execution in the domain's `cumaru-absorb` skill.
- **Cross-file semantic links** (every `scope:` path resolves, every `depends-on:` references a real entity).
- **Schema intent vs. file content** — e.g. requirements quality and prose accuracy. These are author judgment, not validation.
- **Remote freshness beyond one day** — the drift reference is cached per calendar day.

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
