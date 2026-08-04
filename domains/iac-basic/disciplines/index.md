---
human_revised: false
summary: Eager delivery and application triggers for framework-shipped infrastructure execution disciplines.
apps: [meta]
---

# Execution disciplines

An execution discipline governs *how* work is performed, distinct from the
roles and skills that define authority and workflow and the pillars that hold
infrastructure knowledge. Every installed discipline is delivered at context
start; eager delivery does not mean universal application.

At task start and whenever the task changes materially, use `strictness:` to
decide how aggressively to evaluate each `applies-when:`. Apply every matching
discipline; do not choose only one.

| Strictness | Required consideration |
|---|---|
| `10/10` | Evaluate for every task and material transition; compliance is mandatory when applicable. |
| `7-9/10` | Evaluate whenever there is a reasonable signal of the trigger; deviation requires a concrete reason. |
| `4-6/10` | Evaluate on a direct trigger; apply by default but adapt when justified. |
| `1-3/10` | Consult when clearly useful; application is discretionary. |
| `0/10` | Optional reference with no operational obligation. |

Every discipline file except this index must declare `strictness:` from `0/10`
through `10/10`. A missing value is treated as `0/10` but is invalid framework
metadata. Evaluate `cumaru-first` first. Where installed, evaluate
`code-comments` before creating, preserving, changing, or removing a code
comment.

## Triggers

| Discipline | Applies when |
|---|---|
| cumaru-first | Repository work can benefit from a relevant Cumaru surface. |
| code-comments | Code, tests, scripts, configuration, or infrastructure definitions are written, edited, reviewed, refactored, or documented where comments may be affected. |
| dry | The same knowledge, rule, or decision risks living in more than one place. |
| kiss | A simpler implementation can fully solve the stated problem. |
| yagni | Work is proposed beyond a present, stated requirement. |
| solid | Responsibilities, extension, interfaces, or coupling shape a design or refactor. |
| blast-radius | A change reaches capabilities or flows the declared topology graph does not yet describe. |
