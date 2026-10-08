---
name: debugging-and-diagnostics
description: Use when reproducing a Lua error, failed command, missing history, unavailable UDP listener, or test failure.
---

# Debugging and diagnostics

Identify the failing callback and expected observable behavior before editing.
Use matching CCE to locate it, then reproduce with the smallest offline case.
Capture the failure and distinguish API, database, socket, protocol, class,
and Ledokol-policy causes. Change the cause and rerun that case.

Process logs in CTX and return only redacted relevant evidence. Do not load
hub dumps, real nick/IP history, credentials, or unrelated runtime inventories.
For deployment questions, use README troubleshooting and verify the installed
build's primary source in `docs/references.md`.

Typical distinctions: a muted feed still stores history; a SQL success flag
does not prove a write; an unavailable UDP socket stops active probes and list
refresh but not local search filtering or log batches; Ledokol can emit a
separate feed. Avoid hiding a failure behind a fallback that reopens permissions.
