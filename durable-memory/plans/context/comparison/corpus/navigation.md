# Safe Markdown navigation

`Walk` enumerates visible Markdown files inside `.cumaru/`. It rejects symlinks
and escaping paths. `tree` reads summaries; `map` emits literal headings.
Neither command loads an inference model or changes files.
