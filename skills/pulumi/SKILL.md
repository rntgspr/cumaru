---
human_revised: false
version: 1
name: pulumi
description: Use this skill whenever the work involves Pulumi — writing or reading Pulumi programs (TypeScript/Python/Go/…), running preview/up/destroy, managing stacks and state, reading stack outputs, or reviewing a preview for blast radius. Opt-in companion to the iac-basic domain (`cumaru install --with pulumi`); the tool mechanics are general, the integration notes assume the `.cumaru/` IaC pillars (topology/, plans/) when present. Trigger on Pulumi programs (`Pulumi.yaml`, `index.ts`/`__main__.py`), `pulumi` commands, "preview this change", "what will up do", "read this stack's outputs".
---

# Pulumi

How to operate Pulumi safely inside the IaC workflow. Pulumi describes infrastructure in a real language (TS/Python/Go/.NET) — but the discipline is the same as any IaC: **never `up` what you have not read in a `preview`.** The program is the executable spec; `topology/` carries intent, not a copy of it.

## The core loop

```bash
pulumi stack select <env>      # pick the target environment (= a Pulumi stack)
pulumi preview                 # compute + show the change — READ it
pulumi up                      # apply; review the same diff once more, then confirm
```

- `preview` is read-only; `up`/`destroy` mutate.
- In automation, `pulumi up --diff` (and `--yes` only in a gated pipeline) — interactively, always read the diff and confirm.

## Reading the preview — this IS the blast radius

Pulumi shows per-resource ops: `+ create`, `~ update`, `+- replace`, `- delete`. As with any IaC:
- `replace` / `delete` on **stateful** resources (DB, volume, bucket, DNS) are **potentially irreversible** — Pulumi prints the replacement reason; treat it as a red flag.
- **If the preview shows an unintended replace/delete or drifts from the task — STOP, don't `up`, surface it.** Map destroys/replaces into the plan's `## Blast radius`; irreversible ones into `## Rollback`.

## Environments (the `apps` axis)

A **Pulumi stack = an environment** (`dev`/`staging`/`prod`). `pulumi stack select <env>`; config per stack via `Pulumi.<stack>.yaml` (`pulumi config set …`, secrets with `--secret`). Promote along the plan's `## Promotion path`: `preview`→review→`up` per stack, honoring each gate. Never `up` straight to prod.

## State & secrets

- State lives in a **backend** (Pulumi Cloud, or self-managed S3/GCS/Azure Blob). Locking is automatic on the service backend.
- Secrets are encrypted in stack config; never commit plaintext. `pulumi stack export`/`import` is surgical — gated, recorded in the handoff.
- `pulumi refresh` reconciles drift between state and reality.

## Rollback reality

No literal "undo". Rollback = run `up` against a prior known-good program/config (e.g. a previous git revision), or a targeted fix — and some deletes have no rollback. State the real answer in `## Rollback` before `up`, not after. `pulumi stack history` shows prior updates.

## Within the `.cumaru/` iac domain

- **`topology/<area>/## Interface`** ← the stack's config inputs and **`pulumi stack output`** (what downstream stacks consume, e.g. via `StackReference`). Record inputs/outputs in the area; don't paste the program.
- **`depends-on` = apply order** — a stack consuming another's outputs (`StackReference`) must be provisioned after it; mirrors the topology DAG.
- **Handoff** — record the actual preview summary and any `--target` used. `--target` is a scalpel; note it.

## "The code is the spec" still holds

Pulumi programs are imperative-looking but declarative in effect. `topology/` documents intent, topology, and decisions — never a paraphrase of the program, which drifts. Keep them distinct.
