---
human_revised: false
targets: [meta]
summary: Template for describing a manual or automatic task and the script it produces, if any.
status: "draft | active | blocked | done | canceled"
mode: "manual | automatic"
creator: <creator_slug>    # optional — omit for network-wide work
---

# <Task title — the outcome, short>

> Follow the [task index](../tasks/index.md) for slug, mode, and status rules. In the new task, replace `summary` with one sentence describing the outcome. Remove this note.

## Objective

State what this task accomplishes and for whom. Say whether it runs once or repeats, and how often.

## Steps

List the steps in order. For a manual task, write them so another person or agent can follow them without asking.

1. <Step>.
2. <Step>.

## Automation

Describe the script, or state that the task has none and why.

- **Script** — Link each file under `scripts/<task_slug>/`.
- **Trigger** — State what starts it: a schedule with time zone, an event, or a manual command.
- **Inputs** — List the files, credentials by environment variable name, and services it reads. Never write a secret here.
- **Outputs** — List what it produces and where, such as files under `assets/<creator_slug>/` or a draft in `posts/`.

## Done when

State the observable result that shows the task worked. For a recurring task, state how a failed run is noticed.
