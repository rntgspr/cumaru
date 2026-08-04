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

The copy brings `directives/`, `threads/`, and `outcomes/<area>/` with their
contracts, the Admin role, the thread and outcome templates, and the
`cumaru-directives`, `cumaru-thread`, `cumaru-outcome`, and `cumaru-zoom`
workflows.

## Bootstrap (ask, do not assume)

The copy leaves this domain deliberately empty of judgement: it ships no
directive, no outcome area, and no input policy. Bootstrap fills those by asking
the user, one topic at a time, and writing only what they answer. Never seed a
plausible default and never infer a priority from the repository, the tickets, or
the conversation so far. An unanswered topic stays empty and is reported as such.

1. **Priority directives.** Ask what the user's current directions are, and for
   each one: its purpose, what is inside and outside its scope, and the benefit
   it pursues with how a contribution to that benefit is recognized — that answer
   becomes the value scope every outcome serving the directive is measured
   against. Then ask which of them are actually active and in what order. Record
   an order only where the user stated one; anything else stays `proposed` and
   explicitly unranked. Write each answer with `cumaru-directives`.
2. **Outcome areas.** Ask which areas results should be grouped into, and which
   one absorbs a result that fits no other. Add each one as a named key under
   `outcomes` in `config.yaml`, shaped `<area>: {"*.md": {tags: [threads]}}`, add
   its name to `meta.targets.values`, and create its `index.md` from
   `templates/any-index.md`. Never use a `"*"` wildcard there: it matches the
   area's own `index.md` and demands the `threads` tag from it. Do not propose an
   area set of your own.
3. **Input.** Ask which external systems feed this project, on what window, and
   by which workflow, then write that in the `root` tag of `.cumaru/domain.md`.
   The domain fixes no name for this surface: use the user's own word for it.
   How signals arrive is the adopter's concern by design.
4. **Boundaries.** Ask where the line sits between work the user acts on
   personally and work they only monitor downstream, and which external actions
   may ever be performed on their behalf. Record both in the `root` tag. Every
   external action still gets presented in the terminal for review before it
   runs, whatever the answer.
5. **Role name.** The domain has exactly one role. Ask whether `Admin` fits or
   the project prefers another name for it; rename `roles/admin.md` and its index
   entry if so. Do not add a second role.
6. **Components.** Fill the `components` tag when a local stack or contract
   document applies. Leave it as shipped when none does.
7. Run `cumaru doctor`, then report which topics the user answered and which
   remain empty.

The canonical prose outside the tags defines the mechanics and is
framework-owned; never edit it to record a local fact.

## What this skill does NOT do

- Read or mutate any external source system. Collection is the adopter's concern,
  declared in the root tag, and any external action is presented for review first.
- Rank work on its own, or invent a directive, an area, or a priority order that
  the user did not state.
- Publish or render anything. A derived presentation is an adopter choice, built
  by an adopter workflow that reads the threads' frontmatter and content.
