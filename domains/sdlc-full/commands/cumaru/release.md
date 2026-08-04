---
version: 1
description: Narrate a release report from the GitLab compare between two refs. FROM = previous version, TO = current. Resolves the two heads (lists tags/branches when ambiguous and confirms), fetches the commit range via the cumaru-release skill, extracts tracker keys delivered, and writes a consistent prose report from templates/release-report.md as a standalone file.
allowed-tools: Bash, Read, Edit, Write
argument-hint: <FROM-ref> <TO-ref>
summary: Narrate a release report from the GitLab compare between two refs. FROM = previous version, TO = current. Resolves the two heads (lists tags/branches when ambiguous and confirms), fetches the commit range via the cumaru-release skill, extracts tracker keys delivered, and writes a consistent prose report from templates/release-report.md as a standalone file.
---

Arguments: `$ARGUMENTS`

Load the installed `cumaru-release` skill and follow its workflow using the
arguments above. The skill is the canonical source; do not duplicate or bypass
its recipe here.
