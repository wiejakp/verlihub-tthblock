---
name: git-and-ci
description: Use when preparing local commits, CI workflows, verification, or Git hooks; agents never publish.
---

# Git and local checks

Read [the repository laws](../../../RULES.md). Never push or otherwise upload
code to GitHub. Do not delegate publication or create PRs, repository uploads,
or publication automations. The human owner publishes reviewed changes.

Inspect status and the focused diff. Preserve unrelated user changes. Run
`make check`; review ignored runtime directories, logs, downloads and secrets
before staging. Run `make secrets` and inspect the staged diff. Never commit
sensitive information or bypass the local pre-commit guard. Stage explicit paths.

Use the existing remote and branch for local work. Do not create/push/publicize
from an agent. Do not force push, hard reset, clean untracked files, or change
visibility as a routine fix. Do not send GitHub comments or messages unless
explicitly instructed.

Verification is local. Configure the requested GitHub test workflow locally;
only a human's publication activates it. Never upload to hosted code analysis.
`make test`, `make coverage`, or `make badges` regenerates local SVG badges.
Review them with the tested source; distinguish local results from GitHub CI.
CCE post-commit refresh
is optional and local; it is not a substitute for checking runtime behavior.
Report actual local checks and which changes remain for the human to publish.
