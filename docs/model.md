# `cumaru model`

Manage optional local encoders independently of projects and query commands.

```bash
cumaru model list
cumaru model push bge-micro-v2
```

`list` reads the closed `models/catalog.json` from GitHub main, pinned to one
commit, and prints names, total artifact bytes, and licenses. It works outside an
adopter and writes nothing. A missing catalog or network failure is an error,
not a fallback to invented remote availability. The catalog must be published
to main before live operations can use new entries.

`push` means download, not upload. Only names and exact package metadata supported
by this binary are accepted; arbitrary model IDs, URLs, and local imports are
not supported. The first catalog contains only `bge-micro-v2` from TaylorAI.
Catalog expansion or changed metadata requires corresponding binary support.

The command downloads pinned artifacts, verifies sizes and SHA-256, then stages
and publishes a complete package under `~/.cumaru/bge-micro-v2/`:

```text
model.safetensors
tokenizer.json
config.json
manifest.json
```

Its downloaded artifacts total 35,498,070 bytes, plus the local manifest. Weights
are not embedded in the CLI. An identical installed package is a no-op. Existing
invalid/different packages are rejected and preserved; push does not repair or
overwrite them. Download/verification failures create no cache state. Publication
failures may leave a newly created empty cache root; private staging is cleaned.

Cache symlinks, non-directory parents, and nonregular package files are refused.
Legacy `~/.cumaru` contents and other directories remain intact. No adopter files,
global binary, or `~/.config/cumaru.json` are changed. Concurrent destination creation
is checked before rename; these checks are not filesystem locks.

Model management needs cURL for public HTTPS reads. Normal queries use installed
packages offline; no Python, server, GPU, or external inference shared library
is needed. `HOME` must resolve to an absolute user home path.

Exit codes: `0` success/no-op; `1` network, compatibility, integrity, safety, or
publication failure; `2` malformed CLI invocation.

- [Context queries](context.md)
- [Closed catalog](../models/catalog.json)
- [TaylorAI model and license](https://huggingface.co/TaylorAI/bge-micro-v2)
