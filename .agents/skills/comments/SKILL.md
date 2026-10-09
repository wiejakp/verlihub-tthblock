---
name: comments
description: Use when adding or reviewing Lua comments, help text, or operational explanations.
---

# Comments

Follow [the repository laws](../../../RULES.md). Never remove the source's
copyright, modification credit, or GPLv3 header. Keep the header version in
agreement with runtime metadata. Do not place secrets or private hub data in comments.

Use [public writing](../public-writing/SKILL.md). Explain a concrete invariant,
decision, compatibility condition, permission boundary, or operational hazard.
Name its condition and consequence. Do not narrate assignments, announce
routine work, or promise uninterrupted service from a catch/fallback.

Keep the source header's complete installation and command reference current.
Document why SQL rows are copied before another script runs, why affected-row
checks are required, why feed muting leaves logs active, and which callback
return value suppresses forwarding. Verify comments against the code and tests.
Keep authored comments within the 100-character source width.
