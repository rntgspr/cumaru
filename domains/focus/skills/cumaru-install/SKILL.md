---
human_revised: false
version: 1
name: cumaru-install
description: Use this skill whenever the user wants to adopt the focus domain, set up priority directives over incoming work signals, or bootstrap directives/threads/outcomes for directive-driven triage.
summary: Install the focus domain and bootstrap directives, threads, and area-based outcomes.
---

# `cumaru install` — adopt focus

`cumaru install --domain focus` is the deterministic copy step. The LLM work
starts after installation: declare the signal sources and priority policy, then
write the first directive.

## Install

```bash
cumaru install --domain focus
cumaru install --domain focus agent claude
```

The copy brings `directives/`, `sources/`, `threads/`, and `outcomes/` with
their contracts, the Admin role, the directive, source, thread, and outcome
templates, and the `cumaru-directives`, `cumaru-sources`, `cumaru-thread`,
`cumaru-outcome`, and `cumaru-zoom` workflows.

## Bootstrap

Run `cumaru bootstrap` and follow the printed steps in order. It prints the
universal rules and the focus steps from the CLI checkout; the document is
never installed into `.cumaru/`.

## What this skill does NOT do

- Read or mutate any external source system. Collection is the adopter's concern,
  declared in the root tag, and any external action is presented for review first.
- Rank work on its own, or invent a directive, an area, or a priority order that
  the user did not state.
- Publish or render anything. A derived presentation is an adopter choice, built
  by an adopter workflow that reads the threads' frontmatter and content.
