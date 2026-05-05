# `llm regen`

Regenerate derived state inside `.llm/`. Two subcommands.

## Usage

```
llm regen index [pillar]    # regenerate shallow indexes
llm regen <JIRA-KEY>        # chain-check a ticket
```

## `llm regen index [pillar]`

Rebuild the entries block of the 5 shallow pillar indexes by scanning the disk and replacing the contents inside `<!-- llm:<pillar> -->` markers (one of `intake`, `plans`, `archive`, `specs`, `exploring`). The header, Rules, and When-to-use sections (outside the markers) are preserved.

| Argument | Default | Description |
|---|---|---|
| `pillar` | (all) | Specific pillar to regenerate. One of `intake`, `plans`, `archive`, `specs`, `exploring`. |

**Per-pillar tables produced:**

- `intake/index.md` — for each `intake/{epics,stories,tickets}/<KEY>/index.md`: key, type, title, epic, story, status, synced-at.
- `plans/index.md` — for each `plans/<PLAN-ID>/index.md`: plan ID, title, scope, task count, status, apps, updated.
- `archive/index.md` — for each `archive/<PLAN-ID>/index.md`: plan ID, type, apps, story, epic, completed-at, summary.
- `specs/index.md` — for each `specs/<area>/index.md`: area, summary, apps, depends-on.
- `exploring/index.md` — for each `exploring/<slug>/index.md`: slug, status, apps, updated, summary.

**Run after:**
- `llm intake <KEY>` (intake stale).
- `llm archive finalize <PLAN-ID>` (plans + archive stale).
- Bootstrapping a new spec area or exploring slug.
- Ad-hoc to "resync everything".

## `llm regen <JIRA-KEY>`

Chain-check report on one ticket. Walks the canonical work cycle (`intake → plan → archive → specs`) and surfaces inconsistencies. **Read-only** — does not write.

**Checks performed:**
- **Intake** — present? `JIRA-RAW` block already removed?
- **Plan** — status, task progress (`done/total`).
- **Tasks vs handoffs** — flags tasks with `status: done` lacking a `handoff-t<N>.md`.
- **Archive** — present? `temp-archive-flow.delete-me.md` lingering?
- **Specs `deltas:` integrity** — for each path in the plan's `scope:`, checks that `<KEY>` is in the area's `deltas:` list.
- **EARS coverage** — every `WHEN ... THE SYSTEM SHALL ...` line in the intake should appear in `archive/<KEY>/delta.md`. Coarse text match, but catches forgotten criteria.

Use to:
- Verify a ticket after `llm archive finalize` finishes.
- Diagnose "what's broken" when something feels off.
- Onboard yourself to a half-finished plan picked up from another session.

## Examples

```bash
llm regen index            # all 5 pillars
llm regen index plans      # just plans/
llm regen JET-1234         # chain-check JET-1234
```

## Related

- [`llm doctor`](doctor.md) — wraps drift detection (compares disk vs current indexes) alongside the schema and other tree-wide checks.
