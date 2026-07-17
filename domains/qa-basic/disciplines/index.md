---
human_revised: false
summary: Selection rules and triggers for framework-shipped quality execution disciplines.
apps: [meta]
---

# Execution disciplines

Framework-shipped conduct for how work is done. Run `cumaru tree disciplines`
to inspect candidate summaries, then read only disciplines whose `applies-when:`
matches the current task.

## Triggers

| Discipline | Applies when |
|---|---|
| dry | The same knowledge, rule, or decision risks living in more than one place. |
| kiss | A simpler implementation can fully solve the stated problem. |
| yagni | Work is proposed beyond a present, stated requirement. |
| solid | Responsibilities, extension, interfaces, or coupling shape a design or refactor. |
| blast-radius | A change reaches capabilities or flows the declared coverage graph does not yet describe. |
