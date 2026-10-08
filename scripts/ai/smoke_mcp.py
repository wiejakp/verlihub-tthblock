#!/usr/bin/env python3
"""Exercise project-local stdio MCP without an AI or hosted analysis service."""
import json
import os
from pathlib import Path
import queue
import subprocess
import threading


ROOT = Path(subprocess.check_output(
    ["git", "rev-parse", "--show-toplevel"], text=True
).strip())


class Client:
    def __init__(self, script, arguments=(), env=None):
        self.messages = queue.Queue()
        self.errors = []
        self.identifier = 0
        self.process = subprocess.Popen(
            ["bash", script, *arguments], cwd=ROOT, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
            stderr=subprocess.PIPE, text=True, env={**os.environ, **(env or {})}
        )
        threading.Thread(target=self.read, daemon=True).start()
        threading.Thread(target=self.read_errors, daemon=True).start()

    def read(self):
        for line in self.process.stdout:
            try:
                self.messages.put(json.loads(line))
            except json.JSONDecodeError:
                self.errors.append("Unexpected non-JSON server output")
        self.messages.put({"closed": True})

    def read_errors(self):
        for line in self.process.stderr:
            self.errors.append(line.strip())

    def request(self, method, params):
        self.identifier += 1
        request = {"jsonrpc": "2.0", "id": self.identifier, "method": method, "params": params}
        self.process.stdin.write(json.dumps(request) + "\n")
        self.process.stdin.flush()
        while True:
            response = self.messages.get(timeout=30)
            if response.get("closed"):
                raise RuntimeError("Server closed: " + " | ".join(self.errors[-6:]))
            if response.get("id") != self.identifier:
                continue
            if "error" in response:
                raise RuntimeError(str(response["error"]))
            result = response["result"]
            if result.get("isError"):
                raise RuntimeError(str(result.get("content", "tool error"))[:800])
            return result

    def initialize(self):
        self.request("initialize", {
            "protocolVersion": "2024-11-05", "capabilities": {},
            "clientInfo": {"name": "local-project-check", "version": "1"}
        })
        self.process.stdin.write('{"jsonrpc":"2.0","method":"notifications/initialized"}\n')
        self.process.stdin.flush()
        return self.request("tools/list", {})

    def tool(self, name, arguments):
        return self.request("tools/call", {"name": name, "arguments": arguments})

    def close(self):
        self.process.terminate()
        try:
            self.process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            self.process.kill()
            self.process.wait()


def content(result):
    return "\n".join(item.get("text", "") for item in result.get("content", []))


cce = Client("scripts/ai/cce.sh", ("serve",))
try:
    listing = cce.initialize()
    names = {tool["name"] for tool in listing["tools"]}
    assert {"index_status", "context_search"} <= names
    status = content(cce.tool("index_status", {}))
    assert "operational" in status.lower() or "indexed" in status.lower(), status[:300]
    found = content(cce.tool("context_search", {
        "query": "TTHBlock command permissions saved notification classes", "top_k": 2,
        "max_tokens": 400
    }))
    assert "tthblock" in found.lower(), "CCE returned no relevant indexed content"
    print("PASS CCE local stdio, index_status and relevant context_search")
finally:
    cce.close()

ctx = Client("scripts/ai/context-mode.sh", env={"CONTEXT_MODE_PLATFORM": "codex"})
try:
    listing = ctx.initialize()
    names = {tool["name"] for tool in listing["tools"]}
    assert {"ctx_execute", "ctx_index", "ctx_search"} <= names
    result = ctx.tool("ctx_execute", {
        "language": "javascript", "code": 'console.log("CTX_LOCAL_OK")'
    })
    assert "CTX_LOCAL_OK" in content(result)
    ctx.tool("ctx_index", {"path": str(ROOT / "README.md"), "source": "TTHBlock README"})
    result = ctx.tool("ctx_search", {
        "queries": ["TTHBlock commands logclass"], "source": "TTHBlock README", "limit": 1
    })
    assert "tthblock" in content(result).lower()
    print("PASS CTX local stdio, execution, persistent indexing and search")
finally:
    ctx.close()
