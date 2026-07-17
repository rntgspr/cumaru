---
name: tree-filters
description: "Implemented tree filters: restrict navigation candidates by pillar or guard the installed domain"
status: completed
---

# `cumaru tree` filters

Implemented follow-up to V6 virtual tree navigation.

## Scope

1. `--pillars <name[,name...]>` restricts root candidates to schema-declared
   pillars; explicit targets must live inside the selected set.
2. `--domain <name>` guards against an installed-domain mismatch and never
   switches the source contract.
3. Both filters compose with `--deep` and `--rows`; unfiltered behavior remains
   unchanged.
4. Invalid and unknown values fail on stderr before candidate output.
