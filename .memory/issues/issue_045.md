---
name: grounded-intelligent-search
description: Explore ranked retrieval and optional grounded answers over Cumaru knowledge before defining a public search contract
status: open
priority: medium
---

# Issue 045: Explore grounded intelligent search

Cumaru currently exposes deterministic structural navigation through `tree` and
heading discovery through `map`. An agent can also run raw `rg`, but that loses
Cumaru's bounded path handling, stable output, structural signals, and explicit
stopping contract. We want to explore a search surface that accepts a natural
language question, retrieves the most relevant Cumaru evidence, and may
optionally synthesize a grounded answer.

This issue is deliberately exploratory. It does not yet approve a public CLI,
retrieval engine, model runtime, index format, dependency, or distribution
strategy.

## Starting hypotheses

The handover proposed two composable operations:

```bash
rg "term" docs/
```

This is an index-free literal retrieval baseline. It is fast and inspectable,
but does not rank concepts, use Cumaru structure, bridge vocabulary, or decide
which surrounding evidence deserves the context budget.

```bash
echo "Context: $(rg -A5 -B5 'term' docs/)
Question: your question" | ./Qwen3.5-0.8B-Q8_0.llamafile -p
```

This adds local generation over retrieved text. It is only a sketch: the final
design must avoid shell interpolation hazards, bound context size, treat
retrieved Markdown as untrusted data, use the runtime's supported CLI mode,
make generation settings visible, and require evidence citations.

Candidate directions to compare:

1. Index-free lexical retrieval using `rg`, enriched with Cumaru-native path,
   `summary:`, heading, tag, and semantic-link signals.
2. Ranked chunk retrieval using BM25 or an external local engine such as
   CodeRAG/Locus, with index ownership and freshness made explicit.
3. Two-stage retrieval: deterministic candidate generation followed by a
   bounded reranker or local model.
4. Retrieval-only CLI output, leaving synthesis to the active agent that already
   understands Cumaru's loading rule.
5. Optional local answer generation through llamafile or a provider-neutral
   interface, without making model execution part of basic navigation.

## Risk

- A built-in LLM can blur Cumaru's current boundary: the CLI performs
  deterministic mechanics while the active agent owns relevance judgment.
- Pure literal search can produce confident but incomplete evidence when the
  query and authored knowledge use different vocabulary or languages.
- A persistent index can become stale, create adopter-visible state, or make a
  read-only command mutate the project on first use.
- Unbounded snippets can exceed process argument or model context limits and
  crowd out higher-value evidence.
- Retrieved Markdown can contain instructions; passing it directly to a model
  creates a prompt-injection boundary.
- A small local model can synthesize unsupported claims. Fluent output must not
  be mistaken for successful retrieval.
- Bundling or downloading model weights would materially change Cumaru's size,
  install, licensing, platform, and upgrade contracts.
- Adding a code-oriented AST retriever may be the wrong abstraction for
  Markdown whose useful units are summaries, headings, sections, tags, and
  semantic links.

## Provisional invariant

Any eventual search surface must remain read-only, bounded, explainable, and
grounded. It must expose the source path and line range for every retrieved or
asserted fact, distinguish no evidence from runtime failure, never silently use
network access, and never require model execution for deterministic retrieval.

This invariant remains provisional until the exploration resolves corpus,
ranking, output, and provider boundaries.

## Questions to resolve

1. What is the searchable corpus: only `.cumaru/**/*.md`, selected pillars,
   mounted pillars, repository docs, source code, or an explicit combination?
2. Is the retrieval unit a file, Markdown section, paragraph, semantic tag
   body, or a hierarchy of those units?
3. Which signals should affect ranking: exact phrase, individual terms, path,
   `summary:`, headings, `depends-on`, `relates`, tag type, active role, domain,
   or recency?
4. Must search bridge Portuguese questions to English artifacts? If yes, should
   this come from query expansion, multilingual embeddings, or a local model?
5. Should the public surface be `cumaru search`, an installed skill, an MCP tool,
   an agent recipe over existing commands, or some composition of these?
6. Should the default return evidence only? If answer generation exists, is it
   a flag, a separate command, or exclusively the active agent's responsibility?
7. If BM25 or another index is used, where does the index live, who refreshes
   it, how is freshness proven, and how is project mutation avoided?
8. If generation is supported, should Cumaru target llamafile directly or a
   provider-neutral local command/API contract?
9. Is an ephemeral model process per query acceptable, or do repeated queries
   justify an explicitly managed warm local server despite its lifecycle cost?
10. What context budget, result limit, response-token cap, temperature, and
    grounding policy are safe defaults? How are those values shown to the user?
11. Which stable output forms are required for agents and humans: Markdown,
    TSV rows, JSON, prompt bundle, or more than one?
12. How should search compose with `--pillars`, `--domain`, mounted pillars,
    symlink rejection, hidden paths, and future navigation filters?
13. What evaluation set demonstrates that the added complexity beats
    `tree` + `map` + targeted `rg`?

## Exploration work

1. Build a small representative query set covering exact terms, synonyms,
   cross-language questions, semantic links, and questions with no answer.
2. Record expected evidence paths and acceptable line ranges before prototyping
   retrieval, so evaluation does not move with the implementation.
3. Prototype outside the public CLI: raw `rg`, Cumaru-aware lexical scoring,
   BM25/CodeRAG-style chunking, and optional local reranking or synthesis.
4. Compare retrieval quality, latency, cold-start cost, steady-state latency,
   peak memory, dependency weight, index freshness, context size, citation
   accuracy, and macOS/Bash 3.2 fit. For optional local generation, compare an
   ephemeral CLI process with an explicitly started warm localhost server.
5. Threat-model retrieved-content prompt injection and test that the answerer
   treats all corpus text as data rather than instructions.
6. Decide whether intelligent search belongs in the deterministic kernel or in
   an agent-native skill that composes existing primitives.
7. Only after the comparison, replace the provisional invariant with a final
   contract and define implementation, documentation, and migration scope.

## Evaluation scenarios

- An exact phrase ranks the containing section first and reports stable
  `path:line` evidence.
- A conceptual query with different wording finds the expected section without
  flooding the context with unrelated term matches.
- A Portuguese query can find an English artifact if cross-language retrieval
  is selected as a requirement.
- A question whose answer is absent returns an explicit insufficient-evidence
  result rather than a generated guess.
- Instructions embedded in retrieved Markdown do not change the answerer's
  task or grounding rules.
- A changed Markdown file cannot be served from a silently stale index.
- Retrieval works without a model, network request, or project mutation.
- Any optional generation path declares its model/runtime, temperature, context
  limit, response-token cap, and grounding policy in observable output or
  diagnostics.
- Optional generation measurements distinguish first-query model loading from
  repeated-query latency and report peak memory for both ephemeral and warm
  server execution.

## Non-decisions

- No `cumaru search` syntax is approved yet.
- No model, model size, quantization, or download flow is approved yet.
- No CodeRAG/Locus, BM25 library, embedding model, vector store, or MCP
  dependency is approved yet.
- No persistent `.cumaru/` index or cache is approved yet.
- No claim is made yet that generated answers are more useful than returning a
  compact evidence bundle to the active agent.

## References

- [`../../docs/architecture.md`](../../docs/architecture.md)
- [`../../docs/tree.md`](../../docs/tree.md)
- [`../../docs/map.md`](../../docs/map.md)
- [`../specs/navigation.md`](../specs/navigation.md)
- [`../../src/cmd_tree.sh`](../../src/cmd_tree.sh)
- [`../../src/cmd_map.sh`](../../src/cmd_map.sh)
- [CodeRAG/Locus repository](https://github.com/SylphxAI/coderag)
- [CodeRAG search design](https://github.com/SylphxAI/coderag/blob/main/docs/guide/how-search-works.md)
- [llamafile CLI usage](https://github.com/mozilla-ai/llamafile/blob/main/docs/running_llamafile.md)
- [llamafile quickstart](https://github.com/mozilla-ai/llamafile/blob/main/docs/quickstart.md)
