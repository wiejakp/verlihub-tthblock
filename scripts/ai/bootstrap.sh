#!/usr/bin/env bash
set -euo pipefail
task_repo_root="$(git -C "$(dirname -- "$0")" rev-parse --show-toplevel)"
cd "$task_repo_root"
command -v node >/dev/null
command -v npm >/dev/null
command -v cce >/dev/null
node -e 'const [m,n]=process.versions.node.split(".").map(Number);
if (m < 22 || (m === 22 && n < 5)) process.exit(1)'
task_package="$task_repo_root/.context-mode/runtime/node_modules/context-mode/package.json"
if [[ ! -f "$task_package" ]] || ! node -e \
    'process.exit(require(process.argv[1]).version === "1.0.169" ? 0 : 1)' "$task_package"; then
    npm install --prefix .context-mode/runtime --cache .context-mode/npm-cache \
        --no-audit --no-fund --ignore-scripts context-mode@1.0.169
fi
# Incremental indexing also creates the first index; preserve existing memory.
bash scripts/ai/cce.sh index
echo 'Local CCE and CTX are ready. Restart the agent to load project MCP configuration.'
