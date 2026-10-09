"""Write deterministic, offline SVG badges from the current verification run."""

import hashlib
from html import escape
from pathlib import Path

PASS = "#4c1"
FAIL = "#e05d44"
PENDING = "#9f9f9f"
LABELS = {"tests": "Lua tests (local)", "coverage": "Line coverage (local)"}
INPUTS = ("tthblock.lua", "tests/tthblock_test.lua", ".luacov")


class Badges:
    def __init__(self, root: Path):
        self.root = root
        self.directory = root / "docs/badges"
        digest = hashlib.sha256()
        for name in INPUTS:
            source = root / name
            self.require_local(source)
            digest.update(name.encode() + b"\0" + source.read_bytes() + b"\0")
        self.digest = digest.hexdigest()

    def require_local(self, path: Path) -> None:
        """Reject symlinks before reading inputs or writing published artifacts."""
        relative = path.relative_to(self.root)
        if any((self.root / part).is_symlink() for part in (*relative.parents, relative)):
            raise ValueError("Badge inputs and output must stay inside the repository")

    def write(self, name: str, message: str, color: str, detail: str = "") -> None:
        label = LABELS[name]
        target = self.directory / f"{name}.svg"
        self.require_local(target)
        self.directory.mkdir(parents=True, exist_ok=True)
        left = len(label) * 7 + 12
        right = len(message) * 7 + 12
        width = left + right
        title = escape(f"{label}: {message}")
        svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="20"
  viewBox="0 0 {width} 20" role="img" aria-labelledby="title description">
  <title id="title">{title}</title>
  <desc id="description">
    {escape(detail)}
    Script, suite and coverage configuration SHA256:
    {self.digest}
  </desc>
  <rect width="{width}" height="20" rx="3" fill="{color}"/>
  <path d="M3 0h{left - 3}v20H3a3 3 0 0 1-3-3V3a3 3 0 0 1 3-3" fill="#555"/>
  <g fill="#fff" text-anchor="middle" font-family="Verdana,Arial,sans-serif" font-size="11">
    <text x="{left / 2:g}" y="14">{escape(label)}</text>
    <text x="{left + right / 2:g}" y="14">{escape(message)}</text>
  </g>
</svg>
'''
        target.write_text(svg, encoding="utf-8")
