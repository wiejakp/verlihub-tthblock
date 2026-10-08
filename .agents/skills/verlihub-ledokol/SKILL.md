---
name: verlihub-ledokol
description: Use when changing Verlihub callbacks, NMDC TTH handling, UDP probing, Ledokol events, classes, or SQL storage.
---

# Verlihub and Ledokol

Read [architecture and contracts](../../../docs/architecture.md), then only
the relevant [primary source links](../../../docs/references.md).
Match the installed release/commit and Lua ABI before using newer APIs.

Trace the affected path through `Main`, `getlist`, the callback, Ledokol's
`VH_OnScriptCommand`, notification delivery, and retained logs as applicable.
Preserve these boundaries:

- Forbidden search requests return `0` locally and emit `sefi_user_block`
  as `tell nick TTH`, or use `KickUser` in configured kick mode.
- Passive/verified active results emit `avdb_user_detect` as `nick IPv4 path`.
  Ledokol's protection, AVDB, action, and feed settings determine its response.
- `conf.skip` is an exclusive configured ceiling converted to inclusive in
  `Main`. Feed, command, and log classes are separate; only class 10 writes settings.
- Feed 11 mutes this script, while blocking and log writes continue. It does
  not silence Ledokol's independent notification paths.
- SQL cursors are shared; rows are zero-based. Validate `ROW_COUNT()` for writes.
  Failed settings mute notifications and restrict history to masters.
- Active UDP results require a loaded hash, eligible class, and matching hub IP.
  LuaSocket/listener failure leaves search/passive callbacks and log delivery running.

Use [offline verification](../testing-and-verification/SKILL.md). A mocked
event verifies the payload, not a live Ledokol deployment's chosen policy.
