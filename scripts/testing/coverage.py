#!/usr/bin/env python3
"""Install pinned LuaCov locally and enforce whole-script executable-line coverage."""

import argparse
import hashlib
import os
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys
import tarfile
import urllib.request

ROOT = Path(__file__).resolve().parents[2]
VERSION = "0.17.0"
REVISION = "b1f9eae400da976b93edb7f94cf5d05f538a0655"
ARCHIVE_SHA256 = "29e688efd84fba20a76f16525516f6cafdf41cc7b4bc95c631966a666f4ed3a0"
TOOLS = ROOT / ".tools"
RUNTIME = TOOLS / "luacov"
OUTPUT = TOOLS / "coverage"


def setup() -> None:
    """Verify the dependency archive before extracting regular files inside .tools."""
    archive = TOOLS / f"luacov-{VERSION}.tar.gz"
    if not archive.exists():
        url = f"https://codeload.github.com/lunarmodules/luacov/tar.gz/{REVISION}"
        with urllib.request.urlopen(url, timeout=30) as response:
            data = response.read(5_000_001)
        if len(data) > 5_000_000:
            raise ValueError("LuaCov archive exceeds the dependency size limit")
        archive.write_bytes(data)
    if hashlib.sha256(archive.read_bytes()).hexdigest() != ARCHIVE_SHA256:
        raise ValueError("LuaCov archive checksum mismatch; no files were extracted")
    with tarfile.open(archive, "r:gz") as package:
        for member in package.getmembers():
            parts = PurePosixPath(member.name).parts
            if not parts or parts[0] != f"luacov-{REVISION}" or ".." in parts:
                raise ValueError("Unsafe dependency archive path")
            if not member.isfile():
                continue
            target = RUNTIME.joinpath(*parts[1:])
            relative = target.relative_to(ROOT)
            if target.is_symlink() or any(
                (ROOT / p).is_symlink() for p in relative.parents if str(p) != "."
            ):
                raise ValueError("Dependency extraction cannot follow symlinks")
            target.parent.mkdir(parents=True, exist_ok=True)
            with package.extractfile(member) as source:
                target.write_bytes(source.read())
    print(f"PASS pinned LuaCov {VERSION}, verified SHA256, repository-local install")


def measure(lua: str) -> int:
    """Discard prior measurements and require a complete, nonempty script report."""
    if not (RUNTIME / "src/luacov.lua").is_file():
        print("LuaCov is missing; run make coverage-setup", file=sys.stderr)
        return 1
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for name in ("luacov.stats.out", "luacov.report.out"):
        (OUTPUT / name).unlink(missing_ok=True)
    environment = dict(os.environ)
    environment["LUA_PATH"] = str(RUNTIME / "src/?.lua")
    environment["LUA_CPATH"] = ""
    result = subprocess.run(
        [lua, "-lluacov", "tests/tthblock_test.lua"], cwd=ROOT, env=environment, check=False
    )
    if result.returncode:
        return result.returncode
    report = OUTPUT / "luacov.report.out"
    if not report.is_file():
        print("FAIL coverage report was not generated", file=sys.stderr)
        return 1
    text = report.read_text()
    match = re.search(r"^tthblock\.lua\s+(\d+)\s+(\d+)\s+([\d.]+)%$", text, re.M)
    if not match:
        print("FAIL complete tthblock.lua coverage summary is missing", file=sys.stderr)
        return 1
    hits, missed = int(match[1]), int(match[2])
    total = hits + missed
    if not hits or missed:
        source = (ROOT / "tthblock.lua").read_text().splitlines()
        rows = text.splitlines()
        start = next((i for i, row in enumerate(rows) if row.endswith(source[0])), -1)
        uncovered = [
            str(i + 1) for i in range(len(source))
            if start >= 0 and re.match(r"\*+0\s", rows[start + i])
        ]
        print(f"FAIL coverage: {hits}/{total} executable lines; {missed} uncovered")
        print("Uncovered tthblock.lua lines: " + ", ".join(uncovered))
        return 1
    print(f"PASS tthblock.lua coverage: {hits}/{total} executable lines, 100%; no exclusions")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--setup", action="store_true")
    parser.add_argument("--lua", default=os.environ.get("LUA", "lua"))
    args = parser.parse_args()
    if TOOLS.is_symlink() or RUNTIME.is_symlink() or OUTPUT.is_symlink():
        raise ValueError("Coverage tooling must stay inside the repository")
    TOOLS.mkdir(exist_ok=True)
    if args.setup:
        setup()
        return 0
    return measure(args.lua)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, tarfile.TarError) as error:
        print(f"FAIL coverage tooling: {error}", file=sys.stderr)
        sys.exit(1)
