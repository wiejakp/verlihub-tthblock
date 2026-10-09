# Repository laws

These rules apply to every AI agent, including delegated agents and CI changes.
Read them before editing, staging, committing, or using a networked tool.

1. **Agents never publish code to GitHub.** Never run `git push`, create a remote
   repository or pull request, upload repository files through an API, or use
   another tool, worker, automation, or Git hook to publish changes. Prepare and
   verify work locally. The human owner handles GitHub publication.
2. **Never commit sensitive information.** Credentials, tokens, private keys,
   production configuration, private hub nicknames/IPs/history, database dumps,
   private logs, and machine-local data must not enter commits, fixtures, docs,
   issue text, artifacts, or indexes. Use clearly synthetic examples.
3. **Keep repository intelligence local.** CCE and CTX use local stdio and
   repository-local storage. Do not send code or derived private information to
   AI services other than the chosen assistant, scanners, telemetry, remote MCP,
   or public search. Sensitive values must remain redacted even for that assistant.
   Public documentation and necessary package downloads use generic requests.
4. **Review exactly what would be committed.** Inspect the intended files and
   staged diff, run the local sensitive-data check, and stage explicit paths.
   Report findings by file and rule; never print the sensitive value. A detector
   cannot prove the absence of secrets. A blocked check must be investigated,
   rather than bypassed with `--no-verify`, ignore comments, or hook removal.
5. **Write readable, documented code.** Use clear names and small coherent
   responsibilities. Keep authored code within 100 characters per line and Lua
   syntax compatible with 5.1. Explain API invariants and failure behavior.
   Keep identity, version, configuration, README, embedded help, and tests in
   agreement. Never remove the main script's copyright, modification-credit,
   or GPLv3 header. A version increment updates its version line and the runtime
   metadata together; it does not erase or replace attribution.
6. **Verify the complete script.** Every executable line in `tthblock.lua` must
   be exercised by the offline suite under the declared coverage gate. Do not
   exclude hard-to-test source lines, fabricate a percentage, or call line
   coverage branch coverage. Test observable behavior and failures, not merely
   whether a line runs. Live deployment checks remain a separate requirement.
7. **Use truthful badges and reports.** Label generated local results separately
   from GitHub CI status. Regenerate local badges from a fresh test/coverage run,
   clear stale passing values on failure, and publish them with the tested source.
   Coverage claims come from the enforced measurement. The CI badge reads actual
   GitHub workflow status; local tests do not change it. A new workflow is pending
   until the human publishes it and GitHub runs it.

The user's current instructions override earlier publication authorization.
These laws reinforce [AGENTS.md](AGENTS.md) and the
[shared skill map](docs/ai/skill-map.md).
