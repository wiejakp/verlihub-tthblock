#!/usr/bin/env python3
"""Local sensitive-data guard; findings never include the matched value."""

import argparse
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
FORBIDDEN = re.compile(
    r"(^|/)(\.env(?:\..*)?|credentials\.json|secrets\.ya?ml|id_(rsa|ed25519)|"
    r"[^/]*\.(pem|key|p12|pfx|log|tth|sqlite|sqlite3|db)|[^/]*dump\.sql)$", re.I
)
PATTERNS = {
    "private-key": r"-----BEGIN (?:RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----",
    "github-token": r"\b(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{40,})\b",
    "aws-access-key": r"\b(?:AKIA|ASIA)[A-Z0-9]{16}\b",
    "api-token": r"\bsk-[A-Za-z0-9_-]{20,}\b",
    "slack-token": r"\bxox[baprs]-[A-Za-z0-9-]{20,}\b",
    "credential-in-url": r"https?://[^\s/:'\"]+:[^\s/@'\"]+@",
    "machine-private-path": r"/(?:Users|home)/[^/\s]+/",
    "literal-credential": (
        r"(?i)\b(?:password|passwd|api_key|client_secret|access_token)\b\s*[:=]\s*"
        r"['\"][A-Za-z0-9_+/=-]{12,}['\"]"
    ),
}


def forbidden_path(name: str) -> bool:
    parts = PurePosixPath(name).parts
    return bool(
        not parts or ".." in parts or PurePosixPath(name).is_absolute()
        or parts[0] in {".git", ".cce", ".context-mode", ".tools"}
        or FORBIDDEN.search(name)
    )


def inspect(name: str, data: bytes) -> list[str]:
    """Return rule names only; do not echo a credential into logs or model context."""
    if forbidden_path(name):
        return ["forbidden-private-file"]
    if len(data) > 2_000_000:
        return ["oversized-file-needs-review"]
    if b"\0" in data:
        return ["binary-file-needs-review"]
    text = data.decode("utf-8", errors="replace")
    return [rule for rule, pattern in PATTERNS.items() if re.search(pattern, text)]


def git(*args: str) -> bytes:
    result = subprocess.run(
        ["git", *args], cwd=ROOT, capture_output=True, check=True
    )
    return result.stdout


def scan(staged: bool) -> int:
    if Path(git("rev-parse", "--show-toplevel").decode().strip()) != ROOT:
        raise ValueError("Sensitive-data guard repository identity mismatch")
    if staged:
        names = git("diff", "--cached", "--name-only", "--diff-filter=ACMR", "-z")
    else:
        names = git("ls-files", "--cached", "--others", "--exclude-standard", "-z")
    failed = 0
    files = {name.decode() for name in names.split(b"\0") if name}
    for name in sorted(files):
        if forbidden_path(name):
            findings = ["forbidden-private-file"]
        elif staged:
            findings = inspect(name, git("show", f":{name}"))
        else:
            path = ROOT / name
            # The portable Claude skill symlink is validated separately; never follow it.
            if path.is_symlink():
                continue
            if any((ROOT / p).is_symlink() for p in PurePosixPath(name).parents if str(p) != "."):
                findings = ["symlink-parent-needs-review"]
            elif not path.exists():
                continue
            else:
                findings = inspect(name, path.read_bytes())
        for rule in findings:
            print(f"FAIL sensitive-data guard: {name} [{rule}]", file=sys.stderr)
            failed += 1
    if not failed:
        scope = "staged" if staged else "intended repository"
        print(f"PASS sensitive-data guard: {len(files)} {scope} files; values redacted")
    return int(bool(failed))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--staged", action="store_true")
    args = parser.parse_args()
    try:
        sys.exit(scan(args.staged))
    except (OSError, ValueError, subprocess.CalledProcessError):
        print(
            "FAIL sensitive-data guard could not complete; no content was printed", file=sys.stderr
        )
        sys.exit(1)
