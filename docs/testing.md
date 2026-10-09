# Testing and coverage

Run from the exact Git root with Python 3.11+, pip, make, and the desired Lua
interpreter. Production hubs only need the plugin's runtime dependencies.

```sh
make setup
make check
make check LUA=lua5.1 LUAC=luac5.1
make check LUA=lua5.4 LUAC=luac5.4
```

Setup installs LuaCov 0.17.0 from commit
`b1f9eae400da976b93edb7f94cf5d05f538a0655` and checks archive SHA256
`29e688efd84fba20a76f16525516f6cafdf41cc7b4bc95c631966a666f4ed3a0`
before extraction. PyYAML 6.0.3 validates the actual workflow structure.
Both dependencies and caches stay under ignored `.tools/`.

## Checks

- `make syntax`: compile the plugin and offline harness without executing them.
- `make test`: run behavioral tests without coverage instrumentation.
- `make coverage`: clear old measurements, run the entire offline suite, and
  require a nonempty `tthblock.lua` report with zero uncovered executable lines.
- `make validate`: verify skills, links, provider configuration, source-copy
  hashes, source width, protected header/version agreement, and GitHub workflow.
- `make secrets`: test the sensitive-data guard, then inspect intended files.
- `python3 scripts/ai/secret_scan.py --staged`: inspect Git's index before a commit.
- `make ai-check`: separately test the local CCE/CTX MCP servers.

`make check` combines syntax, coverage, validation, and sensitive-data checks.
Checks that write coverage state must run serially in one checkout.
The GitHub matrix uses separate runners for Lua 5.1 and 5.4.

## What 100% means

Coverage is **executable-line coverage of the complete `tthblock.lua` file**,
measured by LuaCov. No script lines are excluded and no previous run's statistics
are reused. The gate also fails if the script/report is missing or empty.
Tests and downloaded dependencies are outside this production-script metric.

Verified locally on 2026-10-08 for fork version 0.0.3.8:

| Interpreter | Offline callback tests | Covered executable lines |
| --- | --- | --- |
| Lua 5.1.5 | 33 passed | 553 / 553 (100%) |
| Lua 5.4.7 | 33 passed | 551 / 551 (100%) |

The interpreter/compiler determines which source lines are executable, hence
the different totals. The four sensitive-data guard tests also passed. These
are local verification results; the workflow badge records GitHub's own runs.

The suite uses synthetic, isolated VH/SQL/socket/clock/file/download implementations.
It asserts permission boundaries, retained state, protocol frames, events, shell
argument quoting, send failures, class changes during export, SQL errors and
affected-row checks, startup fallback, probe rotation, and refresh scheduling.
This tests behavior alongside coverage rather than merely calling each function.

Line coverage is not branch coverage, input-space exhaustion, or a live hub test.
Deployment still needs the actual Verlihub/LuaSocket ABI, SQL privileges, listener
reachability, and Ledokol action/protection policy checked on the target hub.
Tests never call the real curl downloader or send moderation actions to a hub.

Reports are local:

```text
.tools/coverage/luacov.stats.out
.tools/coverage/luacov.report.out
```

On failure, the gate prints uncovered source line numbers. Read the corresponding
code, add an observable regression for that path, and rerun the gate. Do not add
exclusions to manufacture a passing percentage.

## GitHub status and publication

The [test workflow](../.github/workflows/tests.yml) runs on pushes to `main`, pull
requests, and manual dispatch. Checkout is pinned to a full commit SHA; token
permissions are read-only and checkout does not retain credentials. It has no
source-upload or publication step and uses no production secrets.

The tests badge displays GitHub's actual workflow status. The coverage badge
names the enforced 100% gate; it does not invent a hosted coverage measurement.
A newly prepared workflow remains pending until the human publishes and runs it.
Under [the repository laws](../RULES.md), agents never perform that publication.
