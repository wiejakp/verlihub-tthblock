#!/usr/bin/env python3
"""Validate local skills, adapters, links, source width and licensed copies."""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tomllib


ROOT = Path(subprocess.check_output(
    ["git", "rev-parse", "--show-toplevel"], text=True
).strip())
errors = []


def check(condition, message):
    if not condition:
        errors.append(message)


def inside(path):
    return path == ROOT or ROOT in path.parents


def heading_ids(text):
    headings = re.findall(r"^#{1,6}\s+(.+)$", text, re.MULTILINE)
    return {
        re.sub(r"[^\w\s-]", "", item.replace("`", "").lower()).replace(" ", "-")
        for item in headings
    }


raw_paths = subprocess.check_output(
    ["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"], cwd=ROOT
)
paths = sorted({ROOT / p.decode() for p in raw_paths.split(b"\0") if p})
required = {
    ".mcp.json", ".codex/config.toml", ".gemini/settings.json", "AGENTS.md",
    "CLAUDE.md", "GEMINI.md", ".github/copilot-instructions.md", ".cursor/rules/project.mdc",
    "docs/ai/provenance.json", "docs/ai/skill-map.md",
    ".agents/skills/public-writing/references/no-ai-slop-rules.md"
}
for name in required:
    check(ROOT / name in paths, f"Required artifact missing or ignored: {name}")
if errors:
    print("\n".join("FAIL " + message for message in errors))
    sys.exit(1)
texts = {}
for path in paths:
    if path.is_symlink():
        target = Path(os.path.abspath(path.parent / os.readlink(path)))
        check(inside(target), f"External symlink: {path.relative_to(ROOT)}")
        continue
    if path.is_file():
        try:
            texts[path] = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            errors.append(f"Unexpected binary artifact: {path.relative_to(ROOT)}")

skills = sorted((ROOT / ".agents/skills").glob("*/SKILL.md"))
for path in skills:
    text = texts.get(path, "")
    match = re.match(r"\A---\n(.*?)\n---\n", text, re.DOTALL)
    check(match is not None, f"Missing skill frontmatter: {path.parent.name}")
    if not match:
        continue
    metadata = {}
    for line in match[1].splitlines():
        if ":" in line:
            key, value = line.split(":", 1)
            metadata[key.strip()] = value.strip().strip('"').strip("'")
    name = metadata.get("name", "")
    description = metadata.get("description", "")
    check(name == path.parent.name, f"Skill name mismatch: {path.parent.name}")
    check(bool(re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", name)) and len(name) <= 64,
          f"Invalid skill name: {path.parent.name}")
    check(0 < len(description) <= 1024, f"Invalid description: {path.parent.name}")
    check(f".agents/skills/{name}/SKILL.md" in texts[ROOT / "docs/ai/skill-map.md"],
          f"Skill absent from map: {name}")

manifest = json.loads(texts[ROOT / "docs/ai/provenance.json"])
check({item["name"] for item in manifest["skills"]} == {p.parent.name for p in skills},
      "Skill catalog and provenance differ")
for item in manifest["verbatim_copies"]:
    path = ROOT / item["path"]
    check(inside(path), "Copy path must remain in repository")
    if inside(path) and path.is_file():
        check(hashlib.sha256(path.read_bytes()).hexdigest() == item["sha256"],
              f"Pinned licensed copy changed: {item['path']}")
rules = texts[ROOT / ".agents/skills/public-writing/references/no-ai-slop-rules.md"]
check("MIT License" in rules and "Copyright (c) 2026 Peter Yang" in rules,
      "No-ai-slop MIT attribution is missing")

link_count = 0
for path, text in texts.items():
    if path.suffix != ".md":
        continue
    for target in re.findall(r"!?\[[^\]]*\]\(([^)]+)\)", text):
        target = target.strip().strip("<>")
        if re.match(r"^[a-zA-Z][a-zA-Z0-9+.-]*:", target):
            continue
        local, _, anchor = target.partition("#")
        destination = Path(os.path.abspath(path.parent / local)) if local else path
        check(inside(destination), f"External file link in {path.relative_to(ROOT)}")
        if not inside(destination):
            continue
        check(destination.exists(), f"Broken link in {path.relative_to(ROOT)}: {target}")
        if anchor and destination in texts and destination.suffix == ".md":
            check(anchor in heading_ids(texts[destination]),
                  f"Broken heading link in {path.relative_to(ROOT)}: {target}")
        link_count += 1

for path, text in texts.items():
    if path.suffix in {".lua", ".py", ".sh", ".json", ".toml", ".yaml"}:
        for number, line in enumerate(text.splitlines(), 1):
            check(len(line) <= 100,
                  f"Code width {len(line)}: {path.relative_to(ROOT)}:{number}")
    if path.suffix == ".json":
        try:
            json.loads(text)
        except json.JSONDecodeError as exc:
            errors.append(f"Invalid JSON: {path.relative_to(ROOT)}: {exc}")

codex = tomllib.loads(texts[ROOT / ".codex/config.toml"])
claude = json.loads(texts[ROOT / ".mcp.json"])["mcpServers"]
gemini = json.loads(texts[ROOT / ".gemini/settings.json"])["mcpServers"]
for name in ("context-engine", "context-mode"):
    expected = claude[name]
    for client, config in (("Codex", codex["mcp_servers"]), ("Gemini", gemini)):
        check(config[name]["command"] == expected["command"] == "bash",
              f"MCP command drift: {client}/{name}")
        check(config[name]["args"] == expected["args"], f"MCP args drift: {client}/{name}")
    check("url" not in expected, f"Remote MCP forbidden: {name}")
    check((ROOT / expected["args"][0]).is_file(), f"Missing MCP wrapper: {name}")

for adapter in ("CLAUDE.md", "GEMINI.md", ".github/copilot-instructions.md",
                ".cursor/rules/project.mdc"):
    check("AGENTS.md" in texts[ROOT / adapter], f"Adapter lost shared policy: {adapter}")
link = ROOT / ".claude/skills"
check(link.is_symlink() and os.readlink(link) == "../.agents/skills",
      "Claude skills must point to the canonical in-repository directory")

if errors:
    for error in errors:
        print("FAIL " + error)
    sys.exit(1)
print(f"PASS {len(skills)} skills, {link_count} local links, provider adapters, "
      "pinned copy hashes, JSON/TOML and 100-character code width")
