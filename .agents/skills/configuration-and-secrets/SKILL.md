---
name: configuration-and-secrets
description: Use when changing Lua defaults, saved settings, dependency setup, MCP configuration, or ignore rules.
---

# Configuration and secrets

Read [the repository laws](../../../RULES.md). Never commit credentials, keys,
real hub data, logs, production settings, or private machine data. Use synthetic
fixtures. Never put confidential values in shell arguments, output, URLs, or
public CI configuration. Run `make secrets`; inspect intended and staged files.
An ignore rule does not remove sensitive data already tracked in Git.

Trace source defaults, Ledokol auto values, saved SQL values, and effective
runtime classes separately. Only `feed` and `logclass` are persisted by this
script. Changing defaults does not overwrite saved settings on reload.
Keep range checks and fail-closed settings behavior; verify a rejected write
leaves both runtime and SQL state unchanged.

Treat source-level shell URL/path values as administrator-owned. Do not turn
them into user-controlled command parameters. Do not introduce credentials,
hub dumps, real history, or production configuration into fixtures or indexes.
Preserve `.gitignore` and `.cceignore` protections.

MCP servers stay local stdio, launch from the Git root, and use repo-local
storage. Preserve unrelated client configuration. Back up important existing
configuration before changing it. Do not inspect global config or outside
paths unless the user explicitly requests the exact path.
