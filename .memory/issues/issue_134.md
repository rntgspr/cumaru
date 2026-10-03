---
name: native-version-adopter-contract
description: Report the installed domain and config contract version alongside the native CLI version
status: open
priority: medium
---

# Issue 134: Report the adopter config version in native version output

Native `cumaru version` currently prints only the build-time CLI version. It
does not identify an adopter or report the installed `.cumaru/config.yaml`
version, making the independent distribution and domain/config identities
easy to confuse.

## Risk

- A CLI version or release tag may be mistaken for the installed config contract.
- A binary upgrade may appear to have migrated domain/config state when it did not.

## Required invariant

`cumaru version` remains offline and read-only. Without an adopter it reports
the CLI version. With an adopter in the current directory it also identifies
the installed domain and reports the integer version from its config. CLI
and installed domain/config versions may differ; neither is inferred from
the other. Shipped domain configs initially remain at version 9, aligned with
`domains/__base/config.yaml`; this reporting change does not bump versions or
introduce a separate Markdown domain-version authority.

## Work

1. Detect the fixed `.cumaru/` adopter root and read `domain` and `version`
   from its regular, non-symlink `config.yaml` without network or writes.
2. Preserve the existing CLI `version:` field. Add clearly named `domain:`
   and `config:` fields only when an adopter exists. Keep `--version` as the
   package identity used by binary installer verification.
3. Validate metadata types and require a single YAML document. Do not require
   current-schema validity merely to report an older installed contract.
   Diagnose a present but malformed/unsafe adopter rather than silently treating
   it as absent; return 1 while retaining the CLI version report.
4. Keep the initial version 9 baseline for every shipped domain config in
   accordance with `__base`. Report the actual installed value, including an
   older version, instead of assuming 9 or copying the binary version.
5. Update the canonical Rust version contract and native guide; do not implement
   domain upgrades, config migration, or new version fields in this issue.

## Tests

- No adopter: status 0, existing CLI version output only, no network or writes.
- Valid adopter: status 0, CLI identity plus the installed domain and config 9;
  snapshot unchanged even when the CLI version differs.
- Older config metadata: actual installed integer reported without requiring
  compatibility with the current schema or migrating files.
- Malformed/multi-document YAML, missing/non-string domain, missing/non-integer
  version, linked root/config, or missing config in a present adopter: status 1,
  explicit diagnostic, no invented config version, unchanged files.
- `--version`: unchanged package identity, no adopter parsing or network.
- All shipped config versions start at 9 and match the base contract.

## References

- [Native version implementation](../../rust/src/commands/version.rs)
- [CLI dispatch and package version flag](../../rust/src/main.rs)
- [Configuration loading](../../rust/src/config.rs)
- [Base domain config](../../domains/__base/config.yaml)
- [Rust CLI specification](../specs/rust.md)
- [Configuration specification](../specs/configuration.md)
