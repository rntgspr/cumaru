---
human_revised: false
version: 1
name: skill-to-discipline
description: Use when absorbing an external Claude Code / plugin skill into this framework as a "discipline" — distilling a SKILL.md (e.g. from obra/superpowers) into a modular disciplines/<name>.md (gate + cycle + red flags, MIT-attributed) and attaching it to the domain's domain.md. Trigger on "convert this skill into a discipline", "absorb <plugin> skill", "turn <skill> into a discipline", "import this skill as a practice". Repo-maintenance skill — not shipped to adopters.
---

# skill-to-discipline — distill an external skill into a dot-llm discipline

Convert a third-party skill (Claude Code / plugin `SKILL.md`) into a **discipline**: dot-llm's
artifact for *how work is done*. This is a recipe of judgment, not an automatic converter.

## What a discipline is (and why, not a skill or a directive)

A discipline is the third artifact type, between a slogan-directive and a Claude Code skill:

| | Enters context | Lives in | Detailed cycle? |
|---|---|---|---|
| Slogan-directive | eager, always-on (dilutes) | `domain.md` prose | no |
| **Discipline** | **eager index line + body by relevance** | **`disciplines/<name>.md`** | **yes, modular** |
| Skill | eager description + body by trigger | selected adapter's skill directory | yes |

A discipline file is declared in `domain.md` and pulled into context by the **loading rule**
when the task subject matches its `applies-when:` — never always-on. Same eager-index / lazy-body
profile as a skill, but native to `.cumaru/` (one mechanism, portable across harnesses).

## When to convert — and when to reject

- **Convert** a skill that carries *execution discipline* the framework lacks (TDD, debugging,
  verification, code review) and is mostly behavioral prose with no hard runtime dependency.
- **Reject** (do not convert) a skill that:
  - governs session-start / forces skill-discovery → conflicts with the loading-rule kernel;
  - overlaps an existing pillar or skill (plan authoring, ideation, spec writing);
  - only works by running a bundled server/binary, or auto-executes mutating git the project
    reserves to an opt-in skill.
  Lift isolated *techniques* from rejected skills (a gate phrasing, a checklist) into prose; don't import the skill.

## Recipe

1. **Read the source `SKILL.md` in full** (+ its support files). Note bundled scripts/servers — a
   discipline must stand as pure prose; drop runtime coupling.
2. **Classify: gate or process.** A *gate* is one invariant rule ("no X without Y"). A *process*
   is a loop/phases. This decides whether the `## Cycle` section carries weight or is skipped.
3. **Extract the invariant → `## Gate`** — one imperative line. Quote the source's load-bearing rule.
4. **Extract the steps → `## Cycle`** — only for a process; a pure gate may omit it or keep 2-3 lines.
5. **Lift the rationalization / red-flags table → `## Red flags`** — the signs you're violating it.
6. **Cut bloat** — persuasion stats, thrice-repeated anti-rationalization, stack-specific code
   samples (reskin to this project's stack or drop). Target ≤ ~50 lines.
7. **Write `disciplines/<name>.md`** in the target domain, using the frontmatter contract below.
8. **Attach** — add a row under `domain.md`'s `## Execution disciplines` table (`applies-when` + file).
9. **Verify** — `cumaru doctor` (each file needs an H1 + `human_revised`; disciplines aren't a pillar,
   so no orphan-check; the `domain.md` list of disciplines is prose, not a `<!-- cumaru:* -->` block).

## Discipline file contract

```yaml
---
human_revised: false
name: <discipline-name>
applies-when: <task subject that should pull this in — the loading-rule relevance cue>
source:
  plugin: <owner/repo>
  skill: <source skill name>
  url: <github blob URL to the source SKILL.md>
  license: <e.g. MIT — attribution is mandatory>
---
```

Body: `# <Title>` → `**Gate:** <one line>` → `## Cycle` (if a process) → `## Red flags`.

## Compliance

Always record `source.url` + `source.license`. Absorbing MIT text requires attribution; the
`source:` block IS the attribution. Never paste a source body verbatim — distill and reskin.
