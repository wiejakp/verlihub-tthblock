---
name: performance-review
description: Use when changing timer work, UDP parsing, blocklist refresh, SQL retention, or log exports.
---

# Performance review

Read `docs/architecture.md` and measure the affected path with local synthetic
data before optimizing it. Preserve the timer's ten-datagram bound, rotating
hash probe, export reader/batch limits, and incremental retention.

`getlist` calls synchronous curl during load and refresh, so retries/timeouts
can stall the hub event loop. LuaSocket receive is nonblocking, but per-packet
sleeps and sequential sends still take time. Do not label the entire script
as asynchronous or invent a latency improvement without measurement.

Keep every detection logged even when feed notifications are throttled.
Avoid repeated broad index searches, full rebuilds for small edits, or heavy
tests unrelated to the changed behavior. Verify protocol and permission
invariants after any performance change.
