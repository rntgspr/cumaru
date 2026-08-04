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

The CLI validates and copies the selected domain, installs its skills and
supported commands, and wires the requested adapter's instructions. Adapter
selection is stateless; install does not write an `agent` field to config.
The CLI refuses an existing tree. Use `cumaru update` for refresh or opt-in
skills; see `cumaru install --help` for fresh-install adapters and options.

## Configure project context

Read `.cumaru/index.md`, `.cumaru/domain.md`, and the installed disciplines.
Apply domain role routing before Design Lead work; this skill does not switch
roles. Lead identifies the product surfaces from project instructions, source,
and existing design material, using user-approved scope where already given.

Populate the `components` tag in `domain.md` with actual repository surfaces
(paths resolve from the project root). Align their keys with
`config.yaml > meta.targets.values`, retaining `platform` and `meta`. Do not set a
tracker registry on `intake/index.md`; `cumaru-intake` records the observed
tracker on each brief without configuring an integration. Run `cumaru doctor`.

Route initial foundations, components, or journey specifications to
`cumaru-specs` as needed. Use `cumaru-intake` for an existing tracker item and
`cumaru-concept` for a design direction; research and assets use their templates
listed in `templates/index.md`. Do not create speculative pillar entries.
