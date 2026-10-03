# `cumaru bootstrap`

Print the post-install bootstrap steps for this project. **Read-only**: the
command writes nothing. The LLM executes the steps, asking the user for every
answer.

## Usage

```text
cumaru bootstrap
```

The command takes no arguments. It resolves HEAD of `main` and reads both
documents from that one commit; there is no `--from`, local checkout, or
snapshot source.

## The model

```text
domains/__base/bootstrap.md      universal rules (ask, do not assume; CLI use; report)
domains/<domain>/bootstrap.md    optional; the domain's ordered steps
```

The command resolves the installed domain from `.cumaru/config.yaml`, strips
frontmatter, and prints the base body followed by the domain body. A domain
without `bootstrap.md` prints only the base body plus a note. An unknown domain,
a missing or symlinked configuration, or a network failure exits `1` with a
diagnostic on stderr, empty stdout, and no writes.

Like `migration.md`, the document is source-only: `cumaru install` and
`cumaru update` never copy it into `.cumaru/`. Do not confuse it with
`templates/bootstrap.md` in some domains, an unrelated per-area discovery log.

## See also

- [`cumaru install`](install.md)
- [`cumaru migrate`](migrate.md), the same delivery model for migrations.
