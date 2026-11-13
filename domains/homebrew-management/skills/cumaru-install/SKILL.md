---
human_revised: false
version: 1
name: cumaru-install
description: Use this skill whenever the user wants to adopt the homebrew-management domain in a Homebrew tap, map its formulae and casks into Cumaru entities, or bootstrap the tap's package knowledge and bump procedure.
summary: Install the homebrew-management domain and bootstrap one entity per formula and cask with reference rows to the real Ruby.
---

# `cumaru install` — adopt homebrew-management

`cumaru install --domain homebrew-management` is the deterministic copy step.
The LLM work starts after installation: describe the tap, then create one
entity per package from the real `.rb` files.

## Install

```bash
cumaru install --domain homebrew-management
cumaru install --domain homebrew-management agent claude
```

The copy brings the empty `formulae/` and `casks/` pillars with their
contracts, the `release/` pillar with `bump.md`, the `formula.md` and
`cask.md` templates, the `package-change` discipline, and the Admin role.

## Bootstrap

Run `cumaru bootstrap` and follow the printed steps in order. It prints the
universal rules and the homebrew-management steps from main HEAD, pinned to
one commit; the document is never installed into `.cumaru/`.

## What this skill does NOT do

- Edit a `.rb` file. Package changes follow `release/bump.md` under the
  `package-change` discipline, as a separate request.
- Copy version strings or checksums into `.cumaru/`.
- Store a token or credential for a private package.
