# Project bootstrap

Historical bootstrap record. The later [repository laws](../../RULES.md)
prohibit further agent publication; this record is not authorization to push.

Requested on 2026-10-08. GitHub destination: `wiejakp/verlihub-tthblock`, public.
Code width: at most 100 characters per line. Work stays in this repository;
`app_hublist` is the explicitly authorized, read-only reference project.

The existing single-file Verlihub script remains the installable artifact.
Shared instructions and Markdown skills are canonical in `AGENTS.md` and
`.agents/skills/`. Provider adapters point there. Local tools and tests do not
need a running hub, credentials, or an external code-analysis service.

## Deliverables and acceptance

- [x] Update `tthblock.lua` to credit Rolex & PWiAM, include installation and
  every supported command, and wrap code at 100 characters without changing
  blocking, retained settings, SQL checks, or export permissions.
- [x] Verify help, command permissions, TTH search/result handling, retention,
  and failure behavior with an offline Lua harness. Run syntax checks.
- [x] Write `README.md` installation, configuration, usage, troubleshooting,
  and update instructions. Keep runtime help and README commands consistent.
- [x] Preserve the relevant app_hublist coding, writing, privacy, debugging,
  verification, CCE, and delegation decisions as portable project skills.
  Copy its pinned no-ai-slop rules and evaluation with the MIT notice intact.
- [x] Record the Verlihub/Ledokol/Lua contracts and primary links, including
  source revisions and checked dates. Mark live deployment checks separately.
- [x] Configure local stdio CCE/CTX for Codex, Claude, and Gemini, isolate CCE
  storage inside this Git root, and prove retrieval and execution work.
- [x] Validate the skills, links, adapters, and copied-source hashes; inspect
  the final diff, commit, and publish the authorized public GitHub repository.

## Ownership and verification

The main agent owns edits, integration, and publication. No worker pipeline
or artificial task fan-out is needed. An independent read-only review is useful
only after concrete artifacts exist and within the available authorization.
Use `make check` for local checks and `make test` for callback behavior.

Review denied users and mid-export demotions, numeric versus boolean API
returns, shared SQL result replacement, missing DB permissions, a missing UDP
socket, and state retained across reloads. Do not exercise the real blocklist
endpoint or send private hub data while testing.

## Verified on 2026-10-08

`make check` passed syntax checks, all 14 offline callback tests on Lua 5.4.7,
and validation of 13 skills, local links, provider adapters, copied-source
hashes, JSON/TOML, and the 100-character code limit. The same checks passed
with `LUA=.tools/lua-5.1.5/src/lua LUAC=.tools/lua-5.1.5/src/luac`.

`make ai-check` passed local stdio initialization, CCE status and retrieval,
and CTX execution, persistent indexing, and search. All four shell scripts
passed `bash -n`. The CCE index excludes local runtime downloads, secrets,
and the large copied writing references.

The destination already contained initial commit
`486ab885d9b1d201942c2e25140a5a5f4ba99513` with a GPLv3 `LICENSE` file.
That commit and license are preserved through a merge; no remote history is
replaced. The README records GPLv3 and the writing references' MIT notices.

The project was published to
[wiejakp/verlihub-tthblock](https://github.com/wiejakp/verlihub-tthblock), public,
on branch `main`. Generated runtimes, indexes, and machine-local data are
excluded from Git. Both initialization history and the existing license commit
remain in the published history.

The local harness uses mocks. A running Verlihub/Ledokol installation, real
SQL permissions, network binding, and hub moderation actions require live
deployment checks. Provider clients need a restart to load their MCP
configuration; automatic CTX capture also requires the installed host plugin
and trusted hooks. No global agent configuration was edited.
