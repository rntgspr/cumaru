---
version: 1
description: Run `cumaru update` (dry-run), summarize what would change in .cumaru/ files, and confirm before applying (--apply). Skills, hooks, and slash commands are replaced deterministically on --apply.
allowed-tools: Bash, Read, Edit, Write
---

Run `cumaru update` (no `--apply` — keep it a dry-run). Read its output:

- The **Summary** block at the end lists changed `.cumaru/` files as `[merge]` or `[new]` and notes that skills/hooks/commands will also be replaced on `--apply`.
- Each `─── [N/total] <path>` block above shows frontmatter key drift, tag analysis (`[=]` / `[?]` / `[Δ]` / `[+]` / `[orphan]` — v4: every tag body is a `[Link, Description]` table), and a unified diff of local → what `--apply` would produce.

Then:

1. **Synthesize a one-paragraph summary for the user** — counts, which files are merge vs new, which markers are preserved, whether `framework-version` drifted, and that skills/hooks/commands will be replaced.
2. **Ask the user how to proceed**, offering three paths:
   - `apply` — run `cumaru update --apply` (marker-preserving merge for .cumaru/ files; replace skills/hooks/commands). Fastest path when nothing controversial.
   - `walk` — walk the diffs file by file; for each, propose `replace` / `merge` / `keep` / `cumaru-decide` per the heuristic; edit the affected file directly with the chosen strategy; then apply skills/hooks/commands replacement.
   - `skip` — do nothing; report and exit.
3. **Act on the answer.**
4. After applying, check for any deprecated skills/hooks/commands listed in the output and inform the user — suggest removal only when you are confident they are no longer needed.

Heuristic for per-file decisions:

- Content **inside** `<!-- cumaru:NAME -->` markers → **keep local** (project-owned).
- Prose / headers / rules / structure **outside** markers → **take from framework**.
- Outside-marker prose with project-specific content → **analyze**: keep what is project-local, integrate framework changes around it.

Do not run `--apply` without explicit confirmation from the user.
