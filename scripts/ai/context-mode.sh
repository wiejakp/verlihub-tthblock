#!/usr/bin/env bash
set -euo pipefail
task_repo_root="$(git -C "$(dirname -- "$0")" rev-parse --show-toplevel)"
cd "$task_repo_root"
task_server="$task_repo_root/.context-mode/runtime/node_modules/context-mode/server.bundle.mjs"
if [[ ! -f "$task_server" ]]; then
    echo 'The project CTX runtime is missing. Run make ai-init first.' >&2
    exit 1
fi
export CONTEXT_MODE_DIR="$task_repo_root/.context-mode/data"
exec node "$task_server" "$@"
