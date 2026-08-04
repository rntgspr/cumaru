---
human_revised: false
name: <standard title>
summary: <one-line summary, used by cumaru tree>
apps: "[unit] | [integration] | [e2e] | [all]   # levels this convention applies to"
relates: []              # coverage/<area> slices this standard governs
---

# Standard: <title>

## Rule

The convention, stated prescriptively — something an author can comply with and a reviewer can check. One or a few clear directives, not loose prose.

## Rationale

Why this rule exists — the failure mode it prevents (flaky tests, slow suites, false confidence, unreviewable diffs).

## Scope

Where it applies (which levels, which areas) and where it does **not**. Reference the `relates:` coverage areas it governs.

## Do / Don't

**Do**

```
<short, concrete example of the convention applied correctly>
```

**Don't**

```
<the anti-pattern this standard rules out>
```

## Exceptions

- The narrow cases where deviating is acceptable, and how to flag them (e.g. an inline annotation, a note in the case's handoff). "None" is a valid answer.
