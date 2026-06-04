---
human_revised: false
generated: false
name: <stack / area>
summary: <one-line summary, used in topology/index.md>
depends-on: []           # paths under topology/ that must be provisioned FIRST (apply order)
apps: [dev] | [staging] | [prod] | [dev, staging] | [all]
deltas: []               # plan IDs whose deltas built the current state — drill into archive/<PLAN-ID>/ for the verbose record
---

# <Stack / area name>

## Overview

What this stack is, what it provisions, and how it fits the wider topology. Name the **tool** that owns it (Terraform / OpenTofu / Pulumi / CloudFormation / Helm / …) and where the code lives. 1-3 paragraphs. Do **not** paste the HCL/manifest — describe intent, not config.

## Interface

- **Inputs** — variables / parameters this stack consumes, and from where (other stacks' outputs, secrets, config).
- **Outputs** — what it exposes for downstream stacks (VPC IDs, endpoints, ARNs, …).

## Dependencies (apply order)

The stacks in `depends-on:` must exist first; this stack must exist before its dependents. State why each prerequisite is required.

## Decisions

- YYYY-MM-DD: short rationale and link to the originating change (e.g. `JET-1234`). Why this provider / region / sizing / topology over the alternatives.

## Cost & security

- Cost drivers and rough envelope.
- Trust boundaries, IAM / secrets posture, and the blast-radius constraints any change to this stack must respect.

## Files

- [<concern>.md](<concern>.md) — a concern within this stack (e.g. networking, iam), when it grows beyond a flat file.
- [<subarea>/](<subarea>/) — nested subarea (its own `index.md`), when a concern needs its own concerns.
- [<provider>.md](<provider>.md) — provider/account-specific spec (only when content meaningfully diverges).
