---
name: lua-development
description: Use when editing tthblock.lua or its offline Lua tests.
---

# Lua development

Read [the runtime contracts](../../../docs/architecture.md) and
[primary references](../../../docs/references.md) for the affected API.

- Keep Lua source at most 100 characters per line; indent with tabs and preserve
  the existing spaces before argument lists and table indexes.
- Keep the deployed script self-contained. Required `Main`, `UnLoad`, and
  `VH_*` callbacks remain global. Prefer local helpers and state otherwise.
- Preserve Lua 5.1-compatible syntax; use `table.unpack or unpack` in portable
  tooling. LuaSocket must match the Lua ABI used to build Verlihub.
- Treat `0` and empty strings as truthy. Normalize APIs that return booleans,
  numbers, strings, or `(success, value)` pairs according to the actual binding.
- Preserve byte-oriented NMDC parsing, CRLF and pipe framing. A TTH is 39
  uppercase base32 characters; `$SR` fields use byte 5, not a printable space.
- Use explicit callback returns: `1` continues processing; `0` consumes/drops.
- Copy SQL results before making another query or invoking other scripts.
  Keep affected-row checks; `SQLQuery` success alone does not prove a write.
- Keep externally supplied text out of shell commands and SQL syntax. Existing
  source-level `conf.list`/path values are trusted administrator configuration.
- Extract a helper for a distinct responsibility, not to meet a line-count quota.

Run `make check`. For a changed protocol branch, add an offline callback
regression that asserts its observable event, frame, permission, or stored state.
Do not execute the real blocklist downloader from tests.
