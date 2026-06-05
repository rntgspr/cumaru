---
human_revised: false
version: 1
name: terraform
description: Use this skill whenever the work involves Terraform or OpenTofu — writing or reading HCL, running plan/apply/destroy, managing state and workspaces, reading module outputs, or reviewing a plan diff for blast radius. Opt-in companion to the iac-basic flavor (`llm install --with terraform`); the tool mechanics are general, the integration notes assume the `.llm/` IaC pillars (topology/, plans/) when present. Trigger on `*.tf` files, `terraform`/`tofu` commands, "plan this change", "what will apply do", "read this stack's outputs".
---

# Terraform / OpenTofu

How to operate Terraform (or OpenTofu — `tofu` is a drop-in; every command below works with either) safely inside the IaC workflow. The golden rule: **never `apply` what you have not read in a `plan`.**

## The core loop

```bash
terraform init                          # once per backend/module change
terraform plan -out=tfplan              # compute the change; SAVE it
#   → READ the diff (see below) before going further
terraform apply tfplan                  # apply the SAVED plan — no surprises between plan and apply
```

- **Never `apply` an unsaved plan in staging/prod.** Applying the saved `tfplan` guarantees what you reviewed is exactly what runs.
- `init` is safe/idempotent; `plan` is read-only; `apply`/`destroy` mutate.

## Reading the plan diff — this IS the blast radius

The summary line `Plan: N to add, M to change, K to destroy` is the headline. Scan for:
- `+ create` — new resources (usually safe).
- `~ update in-place` — usually safe.
- `-/+ destroy and then create (replace)` and `- destroy` — **potentially irreversible** on stateful resources (databases, volumes, buckets, DNS). A `forces replacement` on such a resource is a red flag.

**If the diff shows an unintended destroy/replace, or drifts from the task — STOP, do not apply, and surface it.** Map every destroy/replace into the plan's `## Blast radius`; if it can't be reversed, that belongs in `## Rollback` as "no clean rollback".

## Environments (the `apps` axis)

Each environment (`dev`/`staging`/`prod`) is an isolated state. Two common shapes:
- **Workspaces:** `terraform workspace select dev` then plan/apply; repeat per env.
- **Separate backends / var-files:** `terraform plan -var-file=prod.tfvars` against a per-env backend.

Promote a change along the plan's `## Promotion path` by re-running plan→review→apply in each environment, honoring the gate between them. Never apply straight to prod.

## State

- State lives in a **remote backend** (S3+DynamoDB, GCS, TF Cloud, …) with **locking**. Never hand-edit state.
- `state mv` / `state rm` / `import` are surgical operations — gated, deliberate, and recorded in the handoff `## Decisions`.
- `terraform refresh` (or `plan -refresh-only`) reconciles drift between state and reality.

## Rollback reality

Terraform has **no "undo apply"**. Rollback means: re-apply a prior known-good configuration, or a targeted revert — and some operations (a deleted database) have no rollback at all. State the real answer in the plan's `## Rollback` before applying, not after.

## Within the `.llm/` iac flavor

- **`topology/<area>/## Interface`** ← a stack's `variables` (inputs) and `outputs`. Use `terraform output` to capture what downstream stacks consume; record it in the area, don't paste the HCL.
- **`depends-on` = apply order** — provision a prerequisite stack (whose outputs you consume via `terraform_remote_state` / a data source) before its dependents. This mirrors the topology DAG.
- **Handoff** — record the actual `Plan: …` summary line and any `-target` you used. `-target` is a scalpel; note it, don't make it a habit.

## OpenTofu

Identical workflow with `tofu`. If the project standardized on OpenTofu, the topology area's `## Overview` should say so; commands and state semantics are the same.
