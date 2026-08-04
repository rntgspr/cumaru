---
human_revised: false
version: 1
name: cumaru-resolve
description: Diagnose and explicitly resolve in-flight Git conflicts inside `.cumaru/` while leaving every other conflict untouched.
summary: Diagnose and explicitly resolve in-flight Git conflicts inside `.cumaru/` while leaving every other conflict untouched.
---

# `cumaru-resolve` - resolve `.cumaru/` conflicts

This skill acts only on conflicts inside `.cumaru/`. Treat invocation arguments
as optional user context; they never expand the allowed path scope.

## Workflow

1. Check `git status` and `.git/MERGE_HEAD`, `.git/rebase-merge/`,
   `.git/CHERRY_PICK_HEAD`, and `.git/REVERT_HEAD`. If no operation is in
   flight, report `no conflict in progress` and stop. Record the operation so
   the correct continuation command can be shown later.
2. Run `git diff --name-only --diff-filter=U`. Split paths into `.cumaru/`
   conflicts and out-of-scope conflicts. List but never edit the latter.
3. Classify every in-scope file:

   | Class | Detection | Default proposal |
   |---|---|---|
   | Directory index | Path ends in `index.md` | Keep incoming framework prose, preserve adopter tag bodies, then validate the directory with `cumaru tree <directory> --deep`. |
   | Tagged file | Contains a `<!-- cumaru:NAME -->` block | Keep local content inside tag bodies and incoming content outside tags; flag project-specific outside-tag prose for review. |
   | Plain `.cumaru/` file | Neither case above | Apply the type-specific rules below. |
   | Tag-delimiter anomaly | Conflict cuts across a tag delimiter or changes its name | Skip as out of scope and report it for separate structural repair. |

4. For plain files, propose rather than guess:
   - Plan/task `status:` prefers the more advanced state
     (`done > in_progress > todo`); ask about every other scalar.
   - An archive `delta.md` proposes a union by `##` section.
   - Body-prose conflicts show the complete chunk and ask.
5. Summarize the operation, in-scope count by class, and all out-of-scope
   paths. State explicitly that out-of-scope files will remain untouched.
6. Ask for `walk` or `skip`. `walk` confirms each proposed fix; `skip` writes
   nothing.
7. Process confirmed fixes in order: directory indexes, tagged files, then
   plain files. Show the relevant conflict, classification, and proposal before
   each edit. Validate a resolved directory index with `cumaru tree`.
8. Report resolved and remaining conflicts. Print the exact staging and
   continuation commands, but do not execute them automatically.

## Hard rules

- Never edit outside `.cumaru/`.
- Never stage, continue, or abort the Git operation unless the user explicitly
  authorizes it in this session and the `git` skill is installed.
- Never repair tag-delimiter anomalies during this workflow.
- If no unmerged paths remain, stop without mutation.
