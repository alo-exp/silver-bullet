#!/usr/bin/env python3
"""Merge graphify MCP, leanctx five-tool profile; remove lean-ctx-standalone."""
from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path


def main() -> int:
    mcp_path = Path.home() / ".cursor" / "mcp.json"
    data: dict = {}
    if mcp_path.is_file():
        with mcp_path.open(encoding="utf-8") as f:
            data = json.load(f)
    servers = data.setdefault("mcpServers", {})

    if "graphify" not in servers:
        servers["graphify"] = {
            "command": "graphify-mcp",
            "args": ["--transport", "stdio"],
        }

    removed = False
    if "lean-ctx-standalone" in servers:
        del servers["lean-ctx-standalone"]
        removed = True

    repo_root = os.environ.get("TOOLSTACK_REPO_ROOT", "")
    if repo_root:
        merge_py = Path(repo_root) / "scripts" / "lib" / "merge-leanctx-mcp-config.py"
        if merge_py.is_file():
            subprocess.run(
                [sys.executable, str(merge_py), "--host", "cursor"],
                check=False,
            )

    if mcp_path.is_file():
        with mcp_path.open(encoding="utf-8") as f:
            data = json.load(f)
        servers = data.setdefault("mcpServers", {})
        if "lean-ctx-standalone" in servers:
            del servers["lean-ctx-standalone"]
            removed = True

    with mcp_path.open("w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
        f.write("\n")

    lean = servers.get("leanctx", {})
    env = lean.get("env", {}) if isinstance(lean, dict) else {}
    cm_overlap = [
        "ctx_execute", "ctx_execute_file", "ctx_batch_execute", "ctx_search",
        "ctx_index", "ctx_fetch_and_index", "ctx_stats", "ctx_purge",
        "ctx_doctor", "ctx_upgrade",
    ]
    disabled = list(lean.get("disabledTools", [])) if isinstance(lean, dict) else []
    for tool in cm_overlap:
        if tool not in disabled:
            disabled.append(tool)
    if isinstance(lean, dict):
        lean["disabledTools"] = disabled
        lean.setdefault("env", {})
        lean["env"].update({
            "LEANCTX_MCP_TOOL_PREFIX": "lctx_",
            "LEANCTX_DISABLE_SHELL_MCP": "1",
            "LEANCTX_DISABLE_SANDBOX_MCP": "1",
            "LEANCTX_DISABLE_FETCH_MCP": "1",
            "LEANCTX_DISABLE_FTS": "1",
            "LEANCTX_PRIMARY_FTS": "context_mode",
        })
        servers["leanctx"] = lean
        with mcp_path.open("w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)
            f.write("\n")

    print(f"OK: mcp.json merged (standalone_removed={removed})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
