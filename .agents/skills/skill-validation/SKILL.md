---
name: skill-validation
description: Use when creating or changing shared agent skills, provider adapters, or their references.
---

# Skill validation

Keep `.agents/skills` canonical. A skill needs a lowercase hyphenated `name`,
a specific triggering `description`, and instructions that change a relevant
decision. Put details in linked references only when they have a clear use.
Do not copy Symfony/PHP/frontend requirements into this Lua project.

Update `docs/ai/skill-map.md` and `docs/ai/provenance.json` when the catalog
changes. Keep Claude/Gemini/Codex adapters as pointers; do not duplicate policy.
Retain the copied no-ai-slop sources, their recorded hashes, and MIT notice.
Update pinned external sources only after an authorized source-alignment check.

Run `make validate` for metadata, adapter consistency, local links, copy hashes,
and code width. Also reason through realistic requests: a typo stays inline;
a protocol fix retrieves the correct API and adds a regression; a stale CCE
transport does not cause a full rebuild; a denied external path stays inaccessible.
If authorized independent review adds confidence, keep it read-only and bounded.
