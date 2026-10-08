---
name: security-review
description: Use when reviewing permissions, SQL, NMDC framing, external inputs, or data retention in a requested change.
---

# Security review

Trace the changed input through its class gate, parser, SQL/shell boundary,
protocol framing, Ledokol event and resulting action. Use local source and
offline fixtures. Review the changed boundary without expanding into an
unrequested repository audit.

Check master-only setting writes, independent log permission, mid-export
demotions, private batch bounds, cooldown/reader limits, retention, SQL hex
literals, shared cursors, NMDC escaping, and UDP sender-IP validation as relevant.
Keep default feed muting distinct from blocking/log persistence. Verify a
storage error cannot reopen notifications or access.

Report a concrete path and evidence. Use primary source references for API
claims, and distinguish a modeled risk from a validated deployment behavior.
Never upload code/logs to a hosted scanner or populate tests with secrets.
