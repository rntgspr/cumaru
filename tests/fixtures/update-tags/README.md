# Update tag fixtures

Each valid scenario contains:

- `source.md`: canonical framework input.
- `local.md`: adopter input.
- `expected.md`: exact merged output.

Each rejected scenario contains `source.md`, `local.md`, and
`expected-error.txt`. A rejected merge must leave `local.md` byte-identical.

The invariant is: every local tag body appears exactly once and unchanged in
the result, or the merge writes nothing.

Tags may be nested when their markers are balanced. A lookup for the inner tag
returns its own body; a lookup for the outer tag returns its complete body,
including the nested tag and its markers. Closing markers must follow stack
order, so crossing tags remain invalid.

An opening marker is closed only by the exact matching name. A foreign closing
marker remains body content while the current tag is open; reaching EOF without
the exact pair reports that the open tag was never closed.

Canonical HTML comments inside a newly introduced tag are scaffolding, not an
empty body. They are installed verbatim when no local occurrence exists.

Duplicate top-level tags are folded into their first occurrence. Their bodies
are concatenated in document order with exactly two newline characters between
them, and every later occurrence is removed.

These fixtures are regression contracts. Do not change an expected file to
make a failing implementation pass. Change a fixture only when the ownership or
parsing contract is deliberately revised and reviewed.

`tests/test_update_tags.sh` executes every directory automatically, and
`tests/run.sh` includes it in the complete suite. Run `bash tests/run.sh` before
every push.
