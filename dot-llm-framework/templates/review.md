---
human_revised: false
---

# Review: <PLAN-ID> — <Ticket title>

**Date:** YYYY-MM-DD
**Branch:** <branch-name>
**Reviewer:** <name or role>
**Ticket:** [<JIRA-ID>](https://<domain>.atlassian.net/browse/<JIRA-ID>)

---

## 1. Requirement (Jira)

> Summary of what the ticket asks for — extracted directly from Jira.
> Include acceptance criteria if present.

---

## 2. Plan vs. Requirement

> Does the plan in `plans/<PLAN-ID>/index.md` faithfully represent the requirement?

| Aspect | Status | Note |
|---|---|---|
| Correct scope | ✅ / ⚠️ / ❌ | ... |
| Criteria covered | ✅ / ⚠️ / ❌ | ... |
| Tasks unambiguous | ✅ / ⚠️ / ❌ | ... |

**Issues found:**
- (if any — reference the plan item)

---

## 3. Code review

> Analysis of changes in `git diff main...HEAD`.

### 3.1 Files changed

| File | Change type | Assessment |
|---|---|---|
| `path/to/file` | feat / fix / refactor / chore | ✅ / ⚠️ / ❌ |

### 3.2 Issues found

> List each issue with file and line reference. Severity:
> - 🔴 **Blocker** — prevents approval.
> - 🟡 **Caution** — must be fixed before merge but is not solely blocking.
> - 🔵 **Suggestion** — optional improvement.

- 🔴 `path/to/file:42` — issue description.
- 🟡 `path/to/file:87` — issue description.
- 🔵 `path/to/file:15` — issue description.

### 3.3 Highlights

> What was implemented well and worth calling out (only what genuinely matters).

---

## 4. Verdict

> **Approved** | **Approved with caveats** | **Rejected**

**Summary:** one or two sentences explaining the decision.

**Required actions before merge:**
- [ ] ...
- [ ] ...
