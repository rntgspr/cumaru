# `llm sync`

Update an installed `.llm/` tree from a fresh framework source. Preserves project-specific content inside `<!-- llm:NAME -->` markers; replaces everything outside them.

## Usage

```
llm sync [<filter>] [--from <src>] [--apply]
```

| Argument / flag | Description |
|---|---|
| `<filter>` | Limit to one top-level dir. One of `intake`, `plans`, `archive`, `specs`, `exploring`, `roles`, `templates`, `reviews`. |
| `--from <src>` | Source: a local dot-llm checkout path or a git URL. Default: the active checkout. |
| `--apply` | Apply changes. Default is dry-run. |

## What it does

Two file categories declared in `schema.yaml` under `sync:`:

- **`framework_files`** — replaced **wholesale** from source (templates, role definitions, `reviews/index.md`).
- **`marked_files`** — replaced **outside** `<!-- llm:NAME -->` blocks; content **inside** every such block in the target is preserved. Tags auto-detected per file. Includes the root `index.md` (with `llm:components`, `llm:root`), `schema.yaml` (with `llm:custom:apps-values`), and the 5 pillar shallow indexes (`llm:<pillar>`).

Anything not listed is **project-owned** and never touched.

## Dry-run output (default)

For each file that differs, prints:
- Category (A `framework_files`, B `marked_files`).
- Default strategy.
- Available strategies (`replace` / `merge` / `keep` / `llm-decide`).
- Full unified diff (local → source).

The LLM consumes this output and decides per file. Heuristic:

- Content inside `<!-- llm:NAME -->` blocks → **keep local**.
- Prose / headers / Rules / structure outside markers → **take from framework**.
- Outside-marker prose with project-specific content → **analyze**: keep what is project-local, integrate framework changes around it.

## `--apply` path

Applies the default per file (no analysis): wholesale for category A, marker-preserving merge for category B.

## What it does NOT do

Updates to the `llm` script itself and `src/*.sh` are **not** this command's responsibility — they live outside `.llm/`. To update those, re-run the install one-liner: `curl -fsSL https://pixelpunk.works/dot-llm/install.sh | bash`. It does `git pull --ff-only` on `~/.dot-llm` if it already exists.

## After applying

Bump `framework-version:` in `.llm/index.md` to match the source schema's `version:`. The validator enforces equality on the next run.

## Examples

```bash
llm sync                              # dry-run from active checkout
llm sync --apply                      # apply defaults
llm sync templates --apply            # only sync templates/
llm sync --from /path/to/dot-llm      # sync from a custom checkout
llm sync --from git@github.com:rntgspr/dot-llm.git --apply  # sync from git
```

## Related

- [`llm doctor`](doctor.md) — run after sync to verify the result.

To update the `llm` CLI itself (not a project's `.llm/`), re-run the install one-liner from the [README](../README.md#installing-the-llm-cli).
