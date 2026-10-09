# Primary references

Checked on 2026-10-08. Use generic public queries and never include repository
code, filenames, diffs, logs, hub history, or secrets. Fetch relevant sections
through local CTX when revisiting a source.

## Verlihub

The GitHub API returned latest release
[`1.6.0.0`](https://github.com/Verlihub/verlihub/releases/tag/1.6.0.0), published
2025-08-23. Source was inspected at master commit
`0f33cddf160ba658abdf2a2f884b0448863f9979`. Match the actual deployment build.

- [Repository](https://github.com/Verlihub/verlihub)
- [Release history](https://github.com/Verlihub/verlihub/releases)
- [Installation](https://github.com/Verlihub/verlihub/wiki/Installation)
- [Setup and deployment](https://github.com/Verlihub/verlihub/wiki/Setup-and-Deployment)
- [Lua events](https://github.com/Verlihub/verlihub/wiki/API-Lua-Events):
  callbacks, main/unload/timer, search, command arguments and return values.
- [Lua methods](https://github.com/Verlihub/verlihub/wiki/API-Lua-Methods):
  VH signatures, classes, IP/config, messages, SQL and script events.
- [Lua binding](https://github.com/Verlihub/verlihub/blob/0f33cddf160ba658abdf2a2f884b0448863f9979/plugins/lua/callbacks.cpp):
  `SQLQuery`, `SQLFetch`, `SendPMToAll`, `ScriptCommand`, support flags.
- [Callback dispatch](https://github.com/Verlihub/verlihub/blob/0f33cddf160ba658abdf2a2f884b0448863f9979/plugins/lua/cluainterpreter.cpp):
  Lua return values and interpreter lifecycle.
- [Script console](https://github.com/Verlihub/verlihub/blob/0f33cddf160ba658abdf2a2f884b0448863f9979/plugins/lua/cconsole.cpp):
  `!lualist`, `!luaload`, `!luareload`, `!luaunload`, paths and class gate.
- [Plugin startup](https://github.com/Verlihub/verlihub/blob/0f33cddf160ba658abdf2a2f884b0448863f9979/plugins/lua/cpilua.cpp):
  config-relative `scripts/`, startup loading and shared SQL query object.
- [Lua build](https://github.com/Verlihub/verlihub/blob/0f33cddf160ba658abdf2a2f884b0448863f9979/plugins/lua/CMakeLists.txt):
  linked Lua library/ABI.

The wiki can lag implementation. Use binding source and an installed-build
test for SQL error handling and return-type claims.

## Ledokol and TTHBlock data

The GitHub API returned latest release tag
[`3.0.0`](https://github.com/Verlihub/ledokol/releases/tag/3.0.0), published
2025-04-27, labeled `3.0.0.146` on the release page. Handlers were inspected at
master commit `2b2f26f35b6a3da375e58ff30066e78df869a2af`.

- [Repository](https://github.com/Verlihub/ledokol)
- [Releases](https://github.com/Verlihub/ledokol/releases)
- [Wiki](https://github.com/Verlihub/ledokol/wiki)
- [Pinned source](https://github.com/Verlihub/ledokol/blob/2b2f26f35b6a3da375e58ff30066e78df869a2af/ledokol.lua):
  search `VH_OnScriptCommand`, `sefi_user_block`, `avdb_user_detect`,
  `enablesearfilt`, `avdetaction`, `scanbelowclass`, `classnotisefi`.
- [Publisher](https://ledo.feardc.net): linked by Ledokol's repository.
- [Original script](https://ledo.feardc.net/other/tthblock.lua) and
  [original distribution page](https://ledo.feardc.net/other/): origin supplied by
  the repository owner. The direct script could not be fetched by the web tool
  on 2026-10-08; this is attribution, not a claim of verified current contents.
- [Maintained fork](https://github.com/wiejakp/verlihub-tthblock): version 0.0.3.8
  builds on the supplied 0.0.3.7 file.
- [Configured TTH list](https://te-home.net/tthblock.php?do=load): `conf.list`,
  expected one 39-character hash per line. It is a runtime data source, not a
  destination for repository contents or hub history.

Ledokol's enabled features, protection, actions and feed settings determine
its response to events. TTHBlock already drops matched search/passive frames.

## Lua, LuaSocket, curl and SQL

- [Lua downloads](https://www.lua.org/download.html): listed Lua 5.5.1 when checked.
- [Lua 5.1 manual](https://www.lua.org/manual/5.1/manual.html): portable syntax
  baseline, truthiness, patterns, pcall, environments and modules.
- [Lua 5.4 manual](https://www.lua.org/manual/5.4/manual.html): tested local
  runtime family, integer conversion and loadfile environments.
- [Lua versions](https://www.lua.org/versions.html): compatibility history.
- [LuaSocket repository](https://github.com/lunarmodules/luasocket)
- [LuaSocket UDP](https://lunarmodules.github.io/luasocket/udp.html): binding,
  timeouts, receivefrom and closing.
- [LuaSocket installation](https://lunarmodules.github.io/luasocket/installation.html):
  module paths and compiled Lua ABI.
- [Curl manual](https://curl.se/docs/manpage.html): redirects/retries, timeouts,
  output paths and user agents.
- [MySQL ROW_COUNT](https://dev.mysql.com/doc/refman/8.4/en/information-functions.html#function_row-count):
  affected-row behavior.
- [MySQL REPLACE](https://dev.mysql.com/doc/refman/8.4/en/replace.html):
  INSERT/DELETE privileges and replacement behavior.

Newest releases are reference material. Compatibility depends on the linked
Lua library, LuaSocket ABI, database server and installed VH APIs.

## HTTP user agent

- [Statcounter 2025 browser share](https://gs.statcounter.com/browser-market-share#yearly-2025-2025):
  browser-family context for the Chrome default, not a ranking of full UA strings.
  Its December 2025 browser CSV was checked on 2026-10-08 and lists Chrome first.
- [Chrome 143 release notes](https://developer.chrome.com/release-notes/143):
  stable release date 2025-12-02.
- [Chrome User-Agent Client Hints](https://developer.chrome.com/docs/privacy-security/user-agent-client-hints):
  reduced legacy UA format and Windows platform examples.

The configurable default is a conventional late-2025 Windows Chrome 143 UA.
It is not asserted to be the uniquely most common full string in every market.

## Coverage and GitHub workflow

- [LuaCov 0.17.0 source](https://github.com/lunarmodules/luacov/tree/b1f9eae400da976b93edb7f94cf5d05f538a0655):
  complete-script line measurement; the local installer verifies the archive hash.
- [PyYAML](https://pypi.org/project/PyYAML/6.0.3/): pinned local YAML parsing.
- [Pinned checkout action](https://github.com/actions/checkout/tree/d23441a48e516b6c34aea4fa41551a30e30af803):
  v6 tag resolved on 2026-10-08; read-only permission and credential persistence disabled.
- [GitHub workflow badges](https://docs.github.com/en/actions/monitoring-and-troubleshooting-workflows/monitoring-workflows/adding-a-workflow-status-badge):
  actual test status instead of a fixed passing label.

See [testing](testing.md) for the enforced metric and local report paths.

## Local agent tooling

- [Agent Skills specification](https://agentskills.io/specification)
- [Codex skills](https://developers.openai.com/codex/skills)
- [Codex configuration](https://developers.openai.com/codex/config-advanced):
  trusted project `.codex/config.toml` scope.
- [Claude Code skills](https://code.claude.com/docs/en/skills): `.claude/skills`.
- [Gemini CLI skills](https://geminicli.com/docs/cli/skills/): `.agents/skills` alias.
- [CCE](https://github.com/elara-labs/code-context-engine): local retrieval,
  CLI/MCP, embeddings and storage. Installed CCE was 0.4.26.
- [CCE config source](https://github.com/elara-labs/code-context-engine/blob/main/src/context_engine/config.py):
  `storage.path` and compression/backend configuration.
- [Context Mode](https://github.com/mksglu/context-mode): local MCP, host-specific
  hooks and `CONTEXT_MODE_DIR` storage isolation.
- [Context Mode package](https://www.npmjs.com/package/context-mode): pins 1.0.169,
  the registry version when checked; requires Node 22.5+.
- [No AI Slop source](https://github.com/petergyang/no-ai-slop/tree/000650b156983f5159695b441477f4e63b25dc85):
  rules/checklist copied from app_hublist with its pinned revision and MIT notice.

[The skill map](ai/skill-map.md) routes tasks to local instructions.
[Provenance](ai/provenance.json) distinguishes verbatim copies from adaptations.
