---
name: testing-and-verification
description: Use when changing callback behavior, fixing a bug, or verifying Lua and agent-tooling changes before completion.
---

# Testing and verification

Apply [the repository laws](../../../RULES.md). Require measured 100%
executable-line coverage of the entire `tthblock.lua` file, without source-line
exclusions. Test startup, timers, protocol handling, commands, and failures.
State the metric and Lua versions; do not claim branch or live-hub coverage
from a line report. Run `make coverage` and `make secrets` before completion.

Run `make syntax` for syntax, `make test` for covered offline runtime contracts, and
`make validate` for skill/config/link/copy integrity. `make check` combines them.
`make test-tooling` exercises badge failure/freshness handling; `make badges`
reruns the callback suite and coverage to regenerate the local SVG results.
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
