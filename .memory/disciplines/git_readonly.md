---
name: git is read-only by default
description: Do not use git for mutating operations unless the user explicitly asks
type: feedback
originSessionId: 507d571c-f4de-4425-8d7c-cb5b12395a28
---
**Rule:** in this repo, git commands are **read-only by default**. Only `git status`, `git diff`, `git log`, `git show`, `git ls-files`, `git rev-parse` are allowed without permission.

**Why:** declared in the project's `CLAUDE.md`: "do not use git, unless explicitly to read content".

**How to apply:**
- Never run `git mv`, `git rm`, `git commit`, `git push`, `git reset`, `git checkout`, `git add`, etc. unsolicited.
- For renames/moves, use plain `mv` / `rm` — git will pick up as add+delete on the user's next stage.
- Don't suggest commits proactively. The user commits when ready.
