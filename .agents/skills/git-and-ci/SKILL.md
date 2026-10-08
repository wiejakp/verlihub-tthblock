---
name: git-and-ci
description: Use when preparing a commit, publishing this repository, or changing local verification and Git hooks.
---

# Git and local checks

Inspect status and the focused diff. Preserve unrelated user changes. Run
`make check`; review ignored runtime directories, logs, downloads and secrets
before staging. Stage intended files explicitly rather than private local data.

Use the existing remote and branch; create/push/publicize only with user
authorization. Do not force push, hard reset, clean untracked files, or change
visibility as a routine fix. Do not send GitHub comments or messages unless
explicitly instructed.

Verification is local. Hosted code-analysis or CI uploads need separate
authorization under this repository's privacy rules. CCE post-commit refresh
is optional and local; it is not a substitute for checking runtime behavior.
Report the actual commit, remote and check outcomes after publication.
