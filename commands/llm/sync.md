---
description: Run `llm sync` (dry-run), summarize what would change, and confirm before applying (--apply).
allowed-tools: Bash, Read, Edit, Write
---

Run `llm sync` (no `--apply` — keep it a dry-run). Read its output:

- The **Summary** block at the end gives counts (Total / Category A / Category B) and the file list per category, including which markers are preserved for each Category B file.
- Each `─── [N/total] <path>` block above shows the file's category, the markers preserved (Category B only), the default strategy, and a unified diff of local → source.

Then:

1. **Synthesize a one-paragraph summary for the user** from the Summary block — counts, which files are A vs B, which markers are preserved, and whether `framework-version` drifted.
2. **Ask the user how to proceed**, offering three paths:
   - `apply` — run `llm sync --apply` (defaults: replace for A, marker-preserving merge for B). Fastest path when nothing controversial.
   - `walk` — walk the diffs file by file; for each, propose `replace` / `merge` / `keep` / `llm-decide` per the heuristic; edit the affected file directly with the chosen strategy.
   - `skip` — do nothing; report and exit.
3. **Act on the answer.**
4. If the framework-version drifted, remind the user to bump `framework-version:` in `.llm/index.md` to match the source schema's `version:` after applying.

Heuristic for per-file decisions (Category B):

- Content **inside** `<!-- llm:NAME -->` markers → **keep local** (project-owned).
- Prose / headers / Rules / structure **outside** markers → **take from framework**.
- Outside-marker prose with project-specific content → **analyze**: keep what is project-local, integrate framework changes around it.

Do not run `--apply` without explicit confirmation from the user.
