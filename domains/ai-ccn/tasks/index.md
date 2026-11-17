---
human_revised: false
targets: [meta]
summary: Organizes units of work for the network, manual or automatic, and the scripts they produce.
---

# Tasks

A pillar for **work the network has to do**, once or on a schedule. A task
states what must happen and how; it may or may not produce a script, and that
script may or may not run without a person.

## Rules

- **One directory per task.** `tasks/<task_slug>/index.md` from the
  [task template](../templates/task.md). The slug is kebab-case and names the
  outcome, such as `weekly-podcast-cut`.
- **`mode` says who runs it.** `manual` when a person or an agent performs the
  steps each time; `automatic` when a script runs them on a trigger.
- **`status` says where it is.** Use `draft`, `active`, `blocked`, `done`, or
  `canceled`. A recurring task stays `active` while it keeps running; a one-off
  task ends at `done`.
- **Scripts live outside `.cumaru/`.** Keep them in `scripts/<task_slug>/` at
  the repository root, under the same slug. The task links each script and
  records its trigger, inputs, and outputs. A task without a script says so.
- **Name the creator when there is one.** Set `creator` to the profile slug for
  work that belongs to one [creator](../creator/index.md). Leave it out for
  network-wide work.
- **Each entry is a directory** with `index.md` and any aux files, following
  the universal entity rules.

Use `cumaru tree tasks` to navigate current entries.

## When to use

- Work repeats and is worth describing once, such as publishing, clipping, or
  reporting.
- A script is about to be written; describe the task first, then the script.
- A manual routine needs written steps another person or agent can follow.

## When NOT to use

- Planning the content of one post → `posts/`.
- Describing who a creator is → `creator/`.
- Deciding a network-wide rule → `constitution.md`.
