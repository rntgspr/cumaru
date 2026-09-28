---
human_revised: false
summary: Read-only access descriptions for the data sources that feed threads.
targets: [meta]
---

# Sources

- Store each source as `sources/<name>.md`, one file per data source, named by
  a lowercase slug matching `[a-z0-9]+(-[a-z0-9]+)*`, such as `jira-platform`.
- Required frontmatter: `summary`, the source's one-line description, and
  `status`, either `active` (read by collection) or `paused` (kept, not read).
- The body declares, in this order: `System` (the external system and scope),
  `Access` (the authenticated tool or command used to read it), `Filters`
  (the query, filters, or selection rules), `Window` (the time range or
  cadence), `Thread mapping` (how a record becomes or updates a thread), and
  `Limitations` (known coverage gaps and access failures).
- Sources are read-only by contract. A source file never authorizes an
  external write; external actions follow the domain's "Acting on a subject"
  rules. Never store credentials, tokens, or secrets in a source file.
- Record coverage honestly: a paused, unavailable, or partially read source is
  stated as such in the affected thread, never presented as complete.

Use [the source template](../templates/source.md) for new entries and
`cumaru tree sources` for discovery.
