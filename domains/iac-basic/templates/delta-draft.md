---
human_revised: false
plan: <PLAN-ID>
status: draft
date: YYYY-MM-DD
summary: Framework guidance for Delta draft — <PLAN-ID> and its required workflow.
---

# Delta draft — <PLAN-ID>

Proposed changes to `topology/` resulting from this plan. **The Lead validates and finalizes** as `plans/<PLAN-ID>/delta-draft.md` during direct absorption. Do not edit `topology/` directly.

If no spec change is needed (e.g. the plan was a tooling fix that does not alter system behavior), replace the body below with a single line:

> No spec change required — &lt;one-line rationale&gt;.

---

Each section names a topology destination and records only changes to its
structure, interface, apply-order dependencies, decisions, or cost/security
posture. Do not introduce a Requirements section.

## topology/&lt;area&gt;/&lt;concern&gt;.md

### Added topology facts

- Interface: &lt;new input or output and its owner&gt;.

### Modified topology facts

- Dependencies: &lt;new apply-order relationship&gt;
  (was: &lt;previous relationship&gt;).

### Removed topology facts

- &lt;previous interface, dependency, decision, or constraint&gt; — &lt;reason&gt;.

## topology/&lt;another-area&gt;/index.md

### Added topology facts

- ...
