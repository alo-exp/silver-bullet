#!/usr/bin/env python3
"""Atomic in-memory merge for ~/.cursor/mcp.json — Graphify + LeanCTX five-tool profile.

Preserves unrelated MCP servers. Requires graphify-mcp stdio handshake before writing
Graphify when adding or upgrading that server entry.
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any

GRAPHIFY_MCP_HANDSHAKE_TIMEOUT = 15

CM_OVERLAP_TOOLS = [
    "ctx_execute",
    "ctx_execute_file",
    "ctx_batch_execute",
    "ctx_search",
    "ctx_index",
    "ctx_fetch_and_index",
    "ctx_stats",
    "ctx_purge",
    "ctx_doctor",
    "ctx_upgrade",
]

LEANCTX_ENV_CM_ACTIVE = {
    "LEANCTX_MCP_TOOL_PREFIX": "lctx_",
    "LEANCTX_DISABLE_SHELL_MCP": "1",
    "LEANCTX_DISABLE_SANDBOX_MCP": "1",
    "LEANCTX_DISABLE_FETCH_MCP": "1",
    "LEANCTX_DISABLE_FTS": "1",
    "LEANCTX_PRIMARY_FTS": "context_mode",
}

LEANCTX_ENV_BASE = {
    "LEANCTX_MCP_TOOL_PREFIX": "lctx_",
}


def load_json(path: Path) -> dict[str, Any]:
    if path.is_file():
        with path.open(encoding="utf-8") as handle:
            return json.load(handle)
    return {}


def normalize_mcp_config(data: dict[str, Any]) -> dict[str, Any]:
    """Canonical form for idempotent comparison (empty mcpServers ≡ missing key)."""
    normalized = json.loads(json.dumps(data))
    servers = normalized.get("mcpServers")
    if isinstance(servers, dict) and not servers:
        normalized.pop("mcpServers", None)
    return normalized


def graphify_mcp_installed() -> bool:
    return shutil.which("graphify-mcp") is not None


def graphify_mcp_handshake() -> tuple[bool, str | None]:
    if not graphify_mcp_installed():
        return False, "graphify-mcp not installed"
    try:
        proc = subprocess.run(
            ["graphify-mcp", "--transport", "stdio"],
            input="",
            capture_output=True,
            timeout=GRAPHIFY_MCP_HANDSHAKE_TIMEOUT,
            check=False,
        )
        if proc.returncode in (0, 1):
            return True, None
        return False, f"graphify-mcp exited {proc.returncode}"
    except subprocess.TimeoutExpired:
        print(
            "WARN: graphify-mcp handshake timed out; merging anyway (binary present)",
            file=sys.stderr,
        )
        return True, "handshake_timeout"
    except OSError as exc:
        return False, str(exc)


def merge_agentmemory(servers: dict[str, Any]) -> bool:
    if "agentmemory" in servers or "user-agentmemory" in servers:
        return False
    servers["agentmemory"] = {
        "command": "npx",
        "args": ["-y", "@agentmemory/mcp"],
        "env": {"AGENTMEMORY_URL": "http://localhost:3111"},
    }
    return True


def merge_graphify(servers: dict[str, Any], *, require_handshake: bool) -> bool:
    if "graphify" in servers:
        return False
    if require_handshake:
        ok, reason = graphify_mcp_handshake()
        if not ok:
            if reason:
                print(f"WARN: graphify merge skipped: {reason}", file=sys.stderr)
            return False
    servers["graphify"] = {
        "command": "graphify-mcp",
        "args": ["--transport", "stdio"],
    }
    return True


def context_mode_present(servers: dict[str, Any]) -> bool:
    return "context-mode" in servers or "user-context-mode" in servers


def merge_leanctx(servers: dict[str, Any]) -> bool:
    changed = False
    cm_active = context_mode_present(servers)

    if "lean-ctx-standalone" in servers:
        del servers["lean-ctx-standalone"]
        changed = True
    if "lean-ctx" in servers:
        del servers["lean-ctx"]
        changed = True

    lean = servers.get("leanctx")
    if not isinstance(lean, dict):
        lean = {"command": "lean-ctx", "args": ["mcp"]}
        servers["leanctx"] = lean
        changed = True

    desired_env = LEANCTX_ENV_CM_ACTIVE if cm_active else LEANCTX_ENV_BASE
    env = dict(lean.get("env", {})) if isinstance(lean.get("env"), dict) else {}
    for key, val in desired_env.items():
        if env.get(key) != val:
            env[key] = val
            changed = True
    lean["env"] = env
    if cm_active:
        disabled = list(lean.get("disabledTools", [])) if isinstance(lean.get("disabledTools"), list) else []
        for tool in CM_OVERLAP_TOOLS:
            if tool not in disabled:
                disabled.append(tool)
                changed = True
        lean["disabledTools"] = disabled

    servers["leanctx"] = lean
    return changed


def atomic_write_json(path: Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = json.dumps(data, indent=2) + "\n"
    with tempfile.NamedTemporaryFile(
        mode="w",
        encoding="utf-8",
        dir=path.parent,
        delete=False,
        prefix=".mcp-merge.",
    ) as tmp:
        tmp.write(payload)
        tmp_path = Path(tmp.name)
    tmp_path.replace(path)


def main() -> int:
    patch_graphify = os.environ.get("RT_PATCH_GRAPHIFY", "0") == "1"
    patch_leanctx = os.environ.get("RT_PATCH_LEANCTX", "0") == "1"
    patch_agentmemory = os.environ.get("RT_PATCH_AGENTMEMORY", "0") == "1"
    if not patch_graphify and not patch_leanctx and not patch_agentmemory:
        print("OK: mcp.json unchanged (no patch flags)")
        return 0

    mcp_path = Path.home() / ".cursor" / "mcp.json"
    original = load_json(mcp_path)
    original_normalized = normalize_mcp_config(original)
    data = json.loads(json.dumps(original))
    servers = data.setdefault("mcpServers", {})

    added_graphify = False
    leanctx_changed = False
    added_agentmemory = False
    if patch_graphify:
        added_graphify = merge_graphify(servers, require_handshake=True)
    if patch_leanctx:
        leanctx_changed = merge_leanctx(servers)
    if patch_agentmemory:
        added_agentmemory = merge_agentmemory(servers)

    if normalize_mcp_config(data) == original_normalized:
        print("OK: mcp.json unchanged (idempotent)")
        return 0

    atomic_write_json(mcp_path, data)
    print(
        f"OK: mcp.json merged atomically "
        f"(graphify_added={added_graphify}, leanctx_changed={leanctx_changed}, "
        f"agentmemory_added={added_agentmemory})"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
