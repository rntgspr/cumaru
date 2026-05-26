---
version: 1
description: Resolve in-flight git conflicts that fall inside `.llm/`. Diagnoses each file's class (shallow index / marker file / plain), proposes a fix, and asks before editing. Non-`.llm/` conflicts are listed but never touched.
allowed-tools: Bash, Read, Edit, Write
---

**Scope: this command only resolves conflicts inside `.llm/` (the active `DOT_LLM_DIR`, default `.llm/`). Conflicts outside that tree are listed at the end as out-of-scope and left for the user to handle.**

1. **Detect the in-flight op**. Check `git status` plus `.git/MERGE_HEAD`, `.git/rebase-merge/`, `.git/CHERRY_PICK_HEAD`, `.git/REVERT_HEAD`. If nothing is in flight, report "no conflict in progress" and exit. Otherwise note which op (merge / rebase / cherry-pick / revert) so the user sees the right `--continue` command later.

2. **List unmerged paths** with `git diff --name-only --diff-filter=U`. Split into two buckets:
   - **In-scope** — path starts with `.llm/` (or whatever `DOT_LLM_DIR` resolves to).
   - **Out-of-scope** — everything else. Keep the list; never edit these.

3. **Classify each in-scope file**:

   | Class | Detection | Default proposal |
   |---|---|---|
   | Shallow index | path matches a pillar's `index.md` (any direct child dir of `.llm/`) | Union both sides' rows then re-emit the pillar tag via `llm tag set <pillar>/index.md <pillar> <new body>` to canonicalize the marker block. |
   | Marker file | contains any `<!-- llm:NAME -->` block | Same heuristic as `/llm:update`: inside the marker → keep local (`ours`); outside the marker → take incoming (`theirs`); flag prose with project-specific content outside markers for manual review. |
   | Plain `.llm/` | neither of the above | Per-type heuristics below. |
   | **Marker-header anomaly** | the conflict markers cut across a `<!-- llm:NAME -->` opening/closing line, or the name differs between sides | **Out of scope.** Flag, skip, and tell the user `llm doctor` will surface the structural inconsistency afterwards. Do not attempt to repair marker structure here. |

   Per-type heuristics for **Plain `.llm/`**:
   - Plan / task frontmatter — for `status:`, prefer the more advanced state (`done > in_progress > todo`); for other scalars, ask.
   - Archive `delta.md` — propose a union by `##` section, preserving both sides' content; confirm before writing.
   - Body prose — show the chunk and ask.

4. **Synthesize** a one-paragraph report: in-flight op, total in-scope conflicts, count per class, and the out-of-scope list. State explicitly that out-of-scope files will not be touched.

5. **Ask the user how to proceed**:
   - `walk` — go file by file, confirming each fix. Same per-file confirmation rule as `/llm:update` and `/llm:doctor`.
   - `skip` — do nothing; exit with the report.

6. **Walk** processes files in this order: Shallow index → Marker file → Plain `.llm/`. For each:
   - Show the conflict markers (or the relevant chunk).
   - State the class and the proposed resolution.
   - Apply only after the user confirms.
   - For Shallow index, re-emit the pillar tag via `llm tag set <pillar>/index.md <pillar> <new body>` immediately after to keep the marker block canonical.

7. **Closure**. After the walk, summarize: what was resolved, what remains in-scope (if the user declined any), and the out-of-scope list. **Do not** run `git add`, `git merge --continue`, `git rebase --continue`, `git cherry-pick --continue`, or any abort. Git is read-only by default in this project. Print the exact commands the user should run themselves. If the project has the `git` skill enabled (`.llm/skills/git/SKILL.md` exists), the user may explicitly authorize the agent to run them in this turn — otherwise hands off.

Hard rules:

- Never edit a path outside `.llm/`.
- Never stage, continue, or abort the in-flight op without explicit user confirmation in this session **and** the `git` skill present.
- Marker-header anomalies are out of scope here; the structural fix belongs to a separate pass, and `llm doctor` will flag it.
- If `git diff --name-only --diff-filter=U` is empty, exit without action.
