---
name: cce-maintenance
description: Use when discovering repository context, checking CCE health, or refreshing changed paths.
---

# CCE maintenance

Resolve the Git root before using a persistent index. Use the matching local
MCP server or `bash scripts/ai/cce.sh`; never borrow another project's index.
The wrapper pins the root and local FastEmbed; `.context-engine.yaml` places
storage under ignored `.cce/storage`. Do not configure remote embeddings/Ollama.

Use `context_search`, then `related_context` or `expand_chunk` for relevant
relationships/exact source. Use `session_recall` for durable repository memory.
An exact known literal is usually better retrieved with `rg`.

Refresh modified/new paths with `bash scripts/ai/cce.sh index --path <path>`.
Serialize writers. Incremental `index` reconciles tracked changes including
deletions; preserve the index and inspect status when results are unexpected.
An explicit first initialization may index the new repository. Do not use
`--full`, clear, prune, or purge to repair a stale transport.

Verify `index_status` and one harmless relevant search separately from code
tests. Record transport failure independently of persistent index health.
Read [local tooling setup](../../../docs/ai/README.md) when reconnecting an agent.
