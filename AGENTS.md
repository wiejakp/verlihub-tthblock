# Agent instructions

These instructions apply to every AI agent working in this repository.
`CLAUDE.md`, `GEMINI.md`, and editor adapters point here. Shared skills live in
`.agents/skills/`; load only relevant skills using [the skill map](docs/ai/skill-map.md).

## Repository and context

Run `git rev-parse --show-toplevel` before persistent retrieval or recursive
discovery. Confirm that any CCE server belongs to that exact root. Use a matching
index or the repository's CLI wrapper when it does not. Never query another
project's index. On resume, search CTX session memory before asking the user to
repeat decisions. Current user instructions override conflicting old memory.

Read `docs/architecture.md` before changing callbacks, SQL, permissions, NMDC,
UDP, or Ledokol integration. `docs/references.md` records primary sources,
checked dates, and source revisions. Verify a different installed build's
contracts rather than assuming upstream master matches deployment.

## Privacy and filesystem boundaries

Keep code, diffs, logs, configuration, filenames, metadata, secrets, and derived
project information local except for the AI service explicitly chosen by the
user. Use local stdio CCE/CTX. Do not add remote MCP, hosted code analysis,
external detectors, remote embeddings, or remote Ollama. Public documentation
queries use generic terms and no repository data. Network access is for requested
public information or necessary dependencies. Publication needs authorization.

Do not read or index `.env`, keys, credentials, database dumps, or production
configuration. Filter sensitive output before it reaches context. Stay inside
the Git root unless the user explicitly names an external path. Skip external
symlinks. Never access cloud/File Provider storage or ask permission to it.
An external-path denial is permanent for the task.

## Retrieval and output

Use matching local CCE for semantic discovery and relationships. Use ast-grep
for syntax, `rg` for literals, ctags for definitions, and `fd` for paths.
Process large or unpredictable output in CTX `ctx_execute`, `ctx_execute_file`,
or `ctx_batch_execute`; print only findings and relevant evidence. Use focused
ordinary reads for exact files being edited. Avoid repeated broad searches and
unrelated runtime enumeration.

Refresh changed CCE paths after edits. Stale MCP transport is separate from index
health. First initialization may index the new repository; later full rebuilds
need an explicit request or demonstrated necessity. Never purge automatically.
Store durable decisions, not raw logs or secrets. `ctx stats` uses `ctx_stats`
once, without runtime diagnostics or invented token/cost metrics.

## Coding and verification

Use [Lua development](.agents/skills/lua-development/SKILL.md) for Lua edits.
Keep authored code at most 100 characters per line, use tabs in Lua, and preserve
the supplied `function (argument)` / `table [key]` style. Use Lua 5.1-compatible
syntax unless a supported runtime floor is deliberately changed. The newest
Lua release does not establish the hub's installed ABI.

Keep `tthblock.lua` self-contained. Export required callback names; keep helpers
local unless callers require otherwise. Preserve callback return values, class
boundaries, shared SQL cursor handling, affected-row checks, retained history,
and NMDC escaping. Make the smallest coherent edit. Split distinct responsibilities
when it improves readability; do not impose an invented function-length quota.

Use [public writing](.agents/skills/public-writing/SKILL.md) and its copied
no-ai-slop rules for documentation, help, skills, and comments. Keep README
commands, the Lua header, runtime help, and tests consistent. Comments explain
an invariant, compatibility condition, or concrete hazard.

Run `make check` for code/configuration changes before claiming completion.
Behavior changes need focused regressions; prose-only changes need `make validate`
and factual checks, rather than unchanged runtime tests or mirrored prose tests.
Route large test output through CTX. Report actual runtimes and checks.
Offline mocks do not establish live SQL permissions, LuaSocket ABI, NAT, or
Ledokol policy. Do not deploy, restart a hub, send messages, or delete retained
data without authorization. Preserve unrelated changes and use reversible operations.

## Task and subagent discipline

Use [agent orchestration](.agents/skills/agent-orchestration/SKILL.md).
Work inline by default. Multiple deliverables may need a compact plan; a typo
needs no plan document, worker, mandatory pipeline, or repeated approval.
Authorization to do the task persists across turns.

Delegate only when user authorization or an applicable skill explicitly covers
a useful independent task. Supply its objective, exact ownership, acceptance
checks, and minimal context. Do not parallelize dependent steps, split shared
files between writers, schedule nested workers, or manufacture subtasks. The
main agent owns integration, verification, outstanding requirements, and reporting.
Serialize builds, dependency installs, Git writes, index writers, and tests sharing state.
