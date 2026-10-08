#!/usr/bin/env bash
set -euo pipefail
task_repo_root="$(git -C "$(dirname -- "$0")" rev-parse --show-toplevel)"
cd "$task_repo_root"
export CCE_EMBED_BACKEND=fastembed
export CCE_OLLAMA_URL=http://127.0.0.1:11434
if ! command -v cce >/dev/null 2>&1; then
    echo 'Install local CCE: uv tool install "code-context-engine[local]"' >&2
    exit 1
fi
if [[ "${1:-}" == serve ]]; then
    shift
    exec cce serve --project-dir "$task_repo_root" "$@"
fi
exec cce "$@"
