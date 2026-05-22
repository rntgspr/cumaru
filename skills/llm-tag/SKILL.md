---
human_revised: false
name: llm-tag
description: >
  Use this skill whenever you need to read, write, or audit the content of
  `<!-- llm:NAME -->` marker blocks inside any `.llm/` file.
  Trigger on phrases like "get the specs tag", "update the plans block",
  "read the contents of llm:intake", "set the files:touched block",
  "check this file's tags", "audit the marker blocks", "which tags does the
  schema declare", or any task that requires reading, writing, or validating
  a named marker region deterministically.
---

# `llm tag` — marker-block read / write / audit

A skill for operating `llm tag` — the deterministic interface to
`<!-- llm:NAME --> … <!-- /llm:NAME -->` blocks. Four forms:

| Form | Purpose |
|---|---|
| `llm tag` | list the tags the schema declares (the active set) |
| `llm tag <file>` | audit a file's blocks against the schema |
| `llm tag get <file> <tag>` | print a block body |
| `llm tag set <file> <tag>` | replace a block body (content from stdin) |

## When to use

- You need to **read** the current body of a marker block without parsing
  the file yourself.
- You need to **write** new content into a marker block without risk of
  touching surrounding prose.
- You need to **audit** a file — confirm every block it carries is declared,
  and that every block the schema expects there is present.
- You need to **discover** which tags the schema declares before authoring.
- You are regenerating or patching a named region inside a `.llm/` file
  (e.g. updating `plans/index.md`'s `<!-- llm:plans -->` table).

## Listing the declared tags

```bash
llm tag
```

Prints a table of every tag declared under `schema.yaml > tags:` with its
`host_file`, `placement`, and `format`. Use this to learn what tags exist
and where they belong before authoring or auditing.

## Auditing a file

```bash
llm tag <file>
```

Cross-references the file's actual blocks against the schema, computing the
file's path relative to the `.llm/` root and matching it against each tag's
`host_file`:

| Marker | Meaning |
|---|---|
| `[✓]` | block present and known to the schema (declared key or pattern like `files:*`) |
| `[+]` | the schema expects this tag here (its `host_file` matches) but it is **absent** → an empty block is **added** for you; fill it and review |
| `[✗]` | block present but **not declared** in `schema.yaml` → review: remove the block, or declare the tag |

Exit code is `1` when any `[+]` or `[✗]` finding occurs, `0` when clean.

**On `[✗]` (undeclared tag):** stop and decide with the user — either the
block is stray (remove it) or the tag should be added to `schema.yaml > tags:`
(declare its `host_file`/`placement`/`format`). Do not silently delete.

**On `[+]` (missing expected tag):** the empty block was already inserted at
the canonical position. Populate it with the correct content (consult the
tag's `format`/`columns` in the schema), then flag the file for human review.

## Tag name format

The tag NAME is the token between `llm:` and ` -->` in the file:

```
<!-- llm:specs -->      → tag is `specs`
<!-- llm:files:touched --> → tag is `files:touched`
```

Both forms are accepted by the CLI:

```bash
llm tag get ./specs/index.md specs
llm tag get ./specs/index.md llm:specs   # llm: prefix stripped automatically
```

Valid regex: `[a-z][a-z0-9_-]*(:[a-z][a-z0-9_*-]*)?`

An invalid name produces exit code 2 and no file mutation.

## Reading a block

```bash
llm tag get <file> <tag>
```

Output: the raw body between the markers, printed to stdout.

**If the block exists but is empty** (present markers, no content between them),
`get` prints nothing to stdout, exits `0`, and emits a hint to **stderr**
(`block '<tag>' is present but empty`). stdout stays clean, so `$(llm tag get …)`
capture is unaffected — the hint only helps a human distinguish "empty block"
from "command did nothing".

**If the tag is absent from the file:**

| Tag declared in `schema.yaml`? | Behaviour |
|---|---|
| Yes | Warning to stderr, empty block created in file, empty output, exit 0 |
| No  | Error to stderr, file unchanged, exit 1 |

When exit code is 1, the tag truly does not exist and is not expected by the
framework. Ask the user whether to create it with `set` before proceeding.

## Writing a block

```bash
echo "new content" | llm tag set <file> <tag>
printf '%s\n' "line 1" "line 2" | llm tag set <file> <tag>
```

Content is read from **stdin**. To write multi-line content safely, prefer
a heredoc or `printf`:

```bash
llm tag set ./plans/index.md plans <<'EOF'
| Plan | Title | Status |
|------|-------|--------|
| JET-1234 | My plan | in-progress |
EOF
```

**If the tag is absent from the file:**
The block is created at the canonical position (immediately after the YAML
frontmatter, before the `# H1`) and then populated with stdin content.

**If the tag is not declared in `schema.yaml`:**
A yellow warning is emitted to stderr but the operation proceeds. This is
intentional — custom / undeclared tags are allowed; the warning signals to the
user that they may want to declare the tag in `schema.yaml` if it will be
reused across the project. You may surface this warning to the user and ask
whether to add the declaration, but do not block on it.

## Combining get + set (patch workflow)

When you need to update only part of a block (e.g. add a row to a table):

```bash
# 1. Read the current body
current=$(llm tag get ./plans/index.md plans)

# 2. Compute the new body in the shell
new_body=$(printf '%s\n| JET-5678 | New plan | pending |\n' "$current")

# 3. Write it back
printf '%s\n' "$new_body" | llm tag set ./plans/index.md plans
```

## Exit codes

| Code | Meaning |
|------|---------|
| 0 | Success / clean audit |
| 1 | Audit found `[+]`/`[✗]` issues, tag absent+undeclared (get), file not found, or write failure |
| 2 | Usage error or invalid tag name |

## Constraints

- `tag set` reads **only from stdin** — there is no `-c` flag.
- `tag get`/`tag set` operate on **markdown files with YAML frontmatter**.
  Plain text or YAML-only files (like `schema.yaml`) can host marker blocks
  but block creation works only in frontmatter-fenced files; for non-fenced
  hosts use `fm_block_replace` directly in a shell script.
- The `llm:` namespace prefix in the file is **not** part of the tag NAME.
  Passing `llm:specs` and `specs` are equivalent.
- The audit form (`llm tag <file>`) computes the file path **relative to the
  `.llm/` root** (`DOT_LLM_DIR`) and matches it against each tag's `host_file`.
  Pattern tags (`files:*`, `placement: anywhere`) are valid in any file and
  never reported as missing.
- `llm tag` and `llm tag <file>` require `schema.yaml` to exist at the
  `.llm/` root; without it they error.
