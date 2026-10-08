# Agent setup

`AGENTS.md` is shared policy. `.agents/skills/` is canonical; use
[the skill map](skill-map.md) and load only relevant instructions. Skills are
portable Markdown/frontmatter. An agent without native skills can read them directly.

| Client | Instructions | Local MCP configuration |
| --- | --- | --- |
| Codex | `AGENTS.md`, `.agents/skills` | `.codex/config.toml` |
| Claude | `CLAUDE.md`, `.claude/skills` symlink | `.mcp.json` |
| Gemini | `GEMINI.md`, `.agents/skills` alias | `.gemini/settings.json` |
| Copilot | `.github/copilot-instructions.md` | Import local stdio definitions. |
| Cursor | `.cursor/rules/project.mdc` | Import local stdio definitions. |
| Other | `AGENTS.md`, skill map | CLI wrapper if MCP is unavailable. |

Start clients from the Git root so relative wrapper paths resolve. Codex loads
project config only for a trusted project. Native discovery depends on the
installed client; the Markdown policy is readable without that integration.

## Bootstrap

These development dependencies are optional for the production Lua plugin.
Local AI tooling requires Node 22.5+, npm, and CCE with local FastEmbed.
CCE documents `uv tool install "code-context-engine[local]"`; install it only
where permitted by the user's filesystem policy. Bootstrap uses an existing
`cce` on PATH and does not change global agent configuration.

```sh
make ai-init
make cce-status
```

Bootstrap installs pinned CTX 1.0.169 under ignored `.context-mode/runtime`,
with npm cache inside the repository, and indexes new/changed files incrementally.
It does not clear memory, force `--full`, or invoke CCE's global hook initializer.
Restart the agent to load the checked-in project MCP definitions.

`scripts/ai/cce.sh` derives the Git root, pins local FastEmbed and loopback-only
Ollama, and runs from that root. `.context-engine.yaml` stores the index in
`.cce/storage`. CTX's wrapper sets absolute `CONTEXT_MODE_DIR` inside
`.context-mode/data`; content/session/stats databases remain ignored.
Explicit `indexer.ignore` patterns also exclude generated runtimes and the
large copied writing references from CCE versions that do not honor `.cceignore`.

```sh
bash scripts/ai/cce.sh index --path tthblock.lua
bash scripts/ai/cce.sh search 'TTHBlock command permissions'
```

`make cce-refresh` reconciles changed files incrementally. A stale transport
is separate from index health; do not clear an index to repair a client restart.

## Verify MCP and hooks separately

Check CCE `index_status` and a relevant `context_search` against the exact root.
Check CTX with a harmless `ctx_execute`, then `ctx_index`/`ctx_search` for a
non-secret local document. `make ai-check` runs a local stdio smoke test.

MCP availability does not prove hook enforcement or automatic memory capture.
The repository has a Claude SessionStart CCE status hook. Codex project config
enables `hooks`/`plugin_hooks`; an installed/trusted Context Mode plugin and
client support are still required for its automatic hooks. Gemini hooks depend
on its client/plugin. Follow CTX routing in `AGENTS.md` even without hooks.

A versioned optional post-commit hook refreshes the local incremental index.
Enable it when the project has no unrelated hook setup:

```sh
git config --local core.hooksPath scripts/ai/git-hooks
```

## Proportional work

Work inline unless an authorized independent worker materially helps. Group
setup, docs and checks with their deliverable. Avoid mandatory pipelines,
nested workers, shared-file writers and trivial delegated edits. A worker gets
a bounded objective/ownership/check packet; CCE supplies source and CTX supplies
applicable decisions. The main agent owns integration and completion.

`make check` validates runtime and instruction artifacts. Copied no-ai-slop
rules/evaluation retain the pinned wrapper and MIT notice; hashes are checked
locally. [Provenance](provenance.json) lists adapted app_hublist practices.
PHP/Symfony/frontend-only skills were not ported into this Lua project.
