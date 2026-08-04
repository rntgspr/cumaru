---
version: 1
description: Resolve in-flight git conflicts that fall inside `.cumaru/`. Diagnoses each file's class (shallow index / marker file / plain), proposes a fix, and asks before editing. Non-`.cumaru/` conflicts are listed but never touched.
allowed-tools: Bash, Read, Edit, Write
summary: Resolve in-flight git conflicts that fall inside `.cumaru/`. Diagnoses each file's class (shallow index / marker file / plain), proposes a fix, and asks before editing. Non-`.cumaru/` conflicts are listed but never touched.
---

Arguments: `$ARGUMENTS`

Load the installed `cumaru-resolve` skill and follow its workflow using the
arguments above. The skill is the canonical source; do not duplicate or bypass
its recipe here.
