---
name: testing-and-verification
description: Use when changing callback behavior, fixing a bug, or verifying Lua and agent-tooling changes before completion.
---

# Testing and verification

Run `make syntax` for syntax, `make test` for offline runtime contracts, and
`make validate` for skill/config/link/copy integrity. `make check` combines them.
Use CTX for substantial output. Print exit status and relevant failures.

Add a regression before a behavioral fix when feasible. Assert observable
frames, events, access denial, stored classes, history limits, or failure state;
avoid tests that duplicate implementation or only compare prose headings.
Preserve every failure, repair its cause, then rerun the smallest relevant
check. Broaden testing only when a new failure or concern justifies it.

Exercise the deployment Lua version when available. The portable harness uses
isolated environments and fake VH, SQL, socket, clock, curl and file operations.
Keep it offline. No production credentials or external payloads belong in fixtures.

Before completion, review the diff, run fresh checks, refresh changed CCE
paths, and reconcile the user's deliverables. Name unavailable checks plainly.
Only an authorized live hub test proves database permissions, LuaSocket ABI,
UDP reachability, and actual Ledokol action/notification policy.
