---
human_revised: false
version: 1
name: git
description: Use this skill whenever a role would otherwise be blocked from running mutating git commands. The .cumaru/ framework gates `git commit`, `git push`, `git reset`, `git checkout`, and similar behind the presence of `.cumaru/skills/git/SKILL.md`. With this file present, mutating commands are allowed — but only following the policies below. Trigger on any task that involves committing, pushing, branching, or rewriting history.
---

# Git

Mutating git operations under the .cumaru/ framework. Without this file, every role uses git only for reading; its presence unlocks mutating commands subject to the policies below.

## Commit policy

- **Never run `git commit` without explicit user instruction.**
- **Always create new commits** rather than amending, unless the user explicitly asks for `--amend`. After a hook fails the commit didn't happen — `--amend` would modify the previous commit and risk losing work; fix the issue, re-stage, and create a NEW commit.
- **Never use** `--no-verify`, `--no-gpg-sign`, or any flag that bypasses hooks/signing unless the user explicitly asks.
- **Stage files by name** (`git add path/to/file`). Avoid `git add -A` or `git add .` unless the change set is small and you have verified there is no sensitive content (`.env`, credentials).
- **Multi-line commit messages** go via HEREDOC to preserve formatting.

## Branch policy

- **Never force-push to `main` or `master`.** Warn the user if they request it.
- **Never run destructive operations** (`reset --hard`, `push --force`, `branch -D`, `clean -f`, `checkout -- ...`) without an explicit user request.
- **Investigate before deleting** unfamiliar branches, files, or lock files — they may be in-progress work or active state.

## Workflow

1. **Inspect state first** — `git status`, `git diff`, `git log` (these are always allowed regardless of the skill).
2. **Surface the proposed change** to the user (a diff or short summary) before committing.
3. **After mutating, confirm** via `git status` / `git log` that the operation produced the expected state.

## What is always allowed (no skill required)

Reading operations don't require this skill — `git status`, `git log`, `git diff`, `git blame`, `git show`, `git ls-files` work in every role at all times.

## Out of scope

- Operations on remote services (GitHub, GitLab APIs — issues, PRs, releases) — those follow their own skills if available, otherwise they are off-limits.
- CI/CD pipeline modifications — out of scope unless the user explicitly directs.
