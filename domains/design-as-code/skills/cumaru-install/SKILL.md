---
human_revised: false
version: 1
name: cumaru-install
description: Install the design-as-code domain, identify project surfaces, and route initial design specification authoring to cumaru-specs.
summary: Adopt the design-as-code domain and configure its project surfaces before seeding durable experience specifications.
---

# Cumaru install — adopt Design as Code

## Install

```bash
cumaru install --domain design-as-code
cumaru install agent codex --domain design-as-code
```

The CLI materializes the files selected by the domain config from main HEAD,
installs its skills, and wires the requested adapter's instructions; only
Generic and OpenCode also receive command launchers. Adapter
selection is stateless; install does not write an `agent` field to config.
The CLI refuses an existing tree. Use `cumaru update` for refresh and
`cumaru update skills <agent> --with <skill>` for opt-in skills; see `cumaru install --help` for fresh-install adapters and options.

## Bootstrap

Run `cumaru bootstrap` and follow the printed steps in order. It prints the
universal rules and the design-as-code steps from main HEAD, pinned to one commit; the
document is never installed into `.cumaru/`.
