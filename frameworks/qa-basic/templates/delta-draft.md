---
human_revised: false
plan: <PLAN-ID>
status: draft
date: YYYY-MM-DD
---

# Delta draft — <PLAN-ID>

Proposed changes to `coverage/` resulting from this campaign. **The Lead validates and finalizes** as `archive/<PLAN-ID>/delta.md` during the archive flow. Do not edit `coverage/` directly.

If no coverage change is needed (e.g. the campaign was a deflake with no new scenarios), replace the body below with a single line:

> No coverage change required — &lt;one-line rationale&gt;.

---

## coverage/&lt;area&gt;

### Added Scenarios

- GIVEN &lt;precondition&gt; WHEN &lt;action&gt; THEN &lt;outcome&gt; — at &lt;level&gt;.

### Modified Scenarios

- GIVEN &lt;precondition&gt; WHEN &lt;action&gt; THEN &lt;new outcome&gt;
  (was: THEN &lt;old outcome&gt;)

### Removed Scenarios

- (Quoted previous scenario, with reason for removal — e.g. behaviour dropped, merged into another area.)

### Levels / Gaps changed

- <e.g. promoted a flow from unit to e2e; closed the gap on empty-cart.>

## coverage/&lt;another-area&gt;

### Added Scenarios

- ...
