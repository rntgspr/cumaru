---
name: <capability>-specification
description: "<one-line description of the implemented contract>"
type: project
status: proposed | implemented | superseded
version: <integer-or-contract-version>
---

# <Capability> specification

## Purpose

<What the capability does, who invokes it, and its boundary.>

## Public surface

```text
<commands, API calls, files, or entry points>
```

## Invariants

1. <Externally observable condition that must always hold.>
2. <Ownership, validation, compatibility, or non-mutation guarantee.>

## Inputs and ownership

| Input or surface | Owner | Contract |
|---|---|---|
| `<path-or-value>` | framework | <how it is consumed or replaced> |
| `<path-or-value>` | adopter | <how it is preserved or validated> |

## Execution

### Preflight

1. <Validation before source resolution or mutation.>
2. <Required dependencies and state.>

### Dry-run

1. <What is calculated and reported.>
2. <Explicit non-mutation guarantee.>

### Apply

1. <Exact mutation order.>
2. <Validation gate.>
3. <Publication and recovery behavior.>

## Failure contract

| Condition | Status | Mutation |
|---|---:|---|
| <validation failure> | `<code>` | none |
| <publication failure> | `<code>` | restored |

## Transaction and recovery

<Lock, staging, backup, publication order, rollback boundary, and what is not
atomic. Omit this section only when the capability is strictly read-only.>

## Implementation map

| Script or artifact | Responsibility |
|---|---|
| `<path>` | <single responsibility> |

## Principal methods

| Method | Contract |
|---|---|
| `<method>` | <inputs, output, side effects, and failure behavior> |

## Regression coverage

| Test | Covered behavior |
|---|---|
| `<test-path>` | <positive, negative, non-mutation, and recovery cases> |

## Verification

```bash
<focused test command>
<complete regression command>
```

## References

- `<canonical implementation path>`
- `<public documentation path>`
- `[[related-memory]]`
