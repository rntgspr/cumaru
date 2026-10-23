---
human_revised: false
version: 1
name: cumaru-discipline
description: Apply a named installed Cumaru discipline to a selected project file, organizing corrections under one task in the current or a dedicated plan when the domain supports plans. Use for requests such as "Cumaru Discipline solid path/to/file.md". Review-only requests remain read-only; this skill does not create or import disciplines.
summary: Apply an installed discipline to a selected file and organize corrections under one owning plan task when the domain supports plans.
---

# Apply a Cumaru discipline

Universal: use the current project's installed disciplines after its normal
Cumaru bootstrap. The requested discipline supplies the rules; this skill
supplies the scoped application workflow.

## Arguments

```text
cumaru-discipline <discipline-name> <file-path> [<plan-id>]
```

For example, invoke the skill as `$cumaru-discipline solid ".meu/caminho/de/arquivo.md"`.
Natural-language requests such as
`Cumaru Discipline solid .meu/caminho/de/arquivo.md` select the same workflow.
Generic launchers use `/cumaru:discipline`; OpenCode uses `/cumaru/discipline`.
These are agent skill invocations, not a `cumaru discipline` CLI subcommand.

The discipline name is its exact lowercase filename stem, using letters,
digits, and hyphens. Resolve it only as
`.cumaru/disciplines/<discipline-name>.md`; `index` is not a discipline.
The target is one existing regular text file, relative to the project root,
including hidden paths or paths outside `.cumaru/`. Preserve spaces in paths;
do not interpret the arguments as shell code or expand globs. Reject symlink
components and paths resolving outside the project. Missing or ambiguous
arguments, absent disciplines, and unreadable targets require a diagnostic
before editing; do not invent rules or install a different domain.

## Plan ownership

After identifying actionable violations, resolve one owning task before making
corrections. Read the installed domain's plan contract and `cumaru-plan` skill
when available; use their templates, acceptance sources, dependencies, role
permissions, and handoff rules rather than inventing a parallel task format.

- Honor an explicit plan ID. Otherwise inspect the current plan and task from
  the session; if none is identified, use bounded plan discovery and read the
  relevant candidates' scope and status. Do not select a plan by recency alone.
  Do not reopen a closed plan or silently substitute a different destination
  when an explicitly named plan is missing or incompatible.
- Keep all discipline corrections in exactly one task. Reuse a compatible open
  task or add one to the current open plan when the work serves its accepted
  scope. Do not spread the findings across unrelated tasks or rewrite their
  criteria to make the discipline work fit.
- If the current plan is unsuitable, choose a specific compatible open plan or
  create a focused maintenance plan with one task under the domain's contract.
  With no open plan, use that maintenance route. Explain the choice briefly;
  this invocation authorizes routine plan/task selection and authoring within
  the requested correction scope without repeated confirmation. Role permissions
  and genuinely new scope or authority still apply.
- When transferring work already recorded or partially implemented, reconcile
  its ownership, dependencies, remaining work, and verification evidence in the
  destination task. Preserve existing edits, source-plan criteria, and evidence;
  reference the origin and update its routing without copying acceptance text,
  deleting records, resetting files, or leaving duplicate active ownership.
- If the installed domain has no plan lifecycle, apply directly within the
  requested scope and report that boundary. Do not create an unsupported pillar.
  Review-only, compliant, or inapplicable requests create no task or plan.

## Apply

1. Read the discipline in full, including `applies-when`, `strictness`, its
   gate, any cycle, and red flags. Follow the installed discipline index's
   interpretation; explicit selection does not raise strictness or suspend
   other applicable disciplines, role boundaries, or repository instructions.
2. Read the complete target and enough relevant callers, contracts, and tests
   to judge the actual concern. Use normal repository tools for source files;
   `cumaru fs` does not edit their content. If the discipline does not apply,
   explain why and leave the file unchanged. A compliant file needs no edit.
3. Identify concrete violations, resolve plan ownership, and make the smallest
   corrections starting from the named file. Include additional files only when
   required by that same task's concrete correction, recording them under its
   normal file-scope and handoff contract. An explicit apply request authorizes
   those corrections without another confirmation. A request only to inspect,
   evaluate, or review authorizes a
   report, not edits. Preserve behavior, public contracts, unrelated edits,
   and adopter-owned content; do not add annotations merely to mark compliance.
4. If a correction exceeds the owning task's authorized scope, changes a public
   contract or behavior, requires destructive work, or needs authority the active
   role lacks, describe the needed change and stop that correction until resolved.
   Do not force an incomplete refactor into one file or distribute it across tasks
   merely to bypass that boundary.
5. Verify the changed behavior or content with the applicable checks and inspect
   the final diff. Use `cumaru doctor` for affected installed Cumaru structure;
   it cannot prove semantic compliance. Report unavailable checks and unresolved
   findings instead of declaring them passed. Do not commit or push implicitly.

## Result

Report the discipline and target, changes with file/line references, checks
actually performed, the owning plan/task and selection rationale, and remaining
violations or scope blockers. Record actual progress and handoff evidence under
the domain contract; one completed task does not close or absorb its whole plan.
If work was only scheduled, report `planned`, not `adjusted`. Otherwise distinguish
`adjusted`, `already compliant`, `not applicable`, and `blocked`; none persists
an active-discipline state, changes its definition, or certifies the project.
