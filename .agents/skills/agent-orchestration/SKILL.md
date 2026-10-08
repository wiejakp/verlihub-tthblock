---
name: agent-orchestration
description: Use when considering subagents or coordinating a change with multiple deliverables.
---

# Agent orchestration

Work inline by default. Copying a skill, wrapping a line, editing a README, or
running one check does not justify a separate worker. A compact checklist may
track multiple deliverables; group setup/docs/tests with the deliverable they
support. Do not require an explorer/architect/implementer/reviewer/tester chain.

Delegation needs authorization from the current user or an applicable skill.
Use at most two workers unless a larger fan-out is explicitly authorized.
Every worker needs an independent result worth its setup/context cost. Its
packet states the objective, exact allowed paths, read/write ownership,
constraints, acceptance checks, and the required handoff. Supply focused CCE
chunks and relevant CTX decisions rather than copying the entire conversation.

Keep shared-file edits, architecture, permissions, integration, and publication
with the main agent. Writers must own disjoint files or an authorized isolated
worktree. Serialize package operations, Git writes, shared-state tests and index
writers. Forbid nested delegation; a worker returns a blocker instead of expanding
scope. Continue useful main-agent work while an authorized worker runs.

Handoffs report changed paths, reasoning, tests with exit status, unresolved
issues, and any required integration. Review the actual artifacts. Reuse a
worker for corrections rather than spawning a new chain. The main agent runs
combined checks and reconciles every requested outcome before reporting completion.

For a tiny change, the correct output is the completed edit and its check,
with no task ledger or worker. For this bootstrap, the bounded checklist is
[bootstrap-plan.md](../../../docs/ai/bootstrap-plan.md).
