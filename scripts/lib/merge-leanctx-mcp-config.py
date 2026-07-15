#!/usr/bin/env python3
"""Merge LeanCTX MCP server into host configs with lctx_ prefix (conflict #1).

Targets:
  - ~/.cursor/mcp.json
  - ~/.codex/config.toml
  - ~/.config/opencode/opencode.json
  - ~/.claude.json (Claude MCP settings)

When Context Mode is already configured, overlapping LeanCTX surfaces are disabled
via env hints so CM retains ctx_* namespace ownership.
"""

from __future__ import annotations

import argparse
import json
import os
import pathlib
import re
import shutil
import sys


def load_json(path: pathlib.Path, default: dict | None = None) -> dict:
    if path.is_file():
        with path.open(encoding="utf-8") as handle:
            return json.load(handle)
    return default or {}


def save_json(path: pathlib.Path, data: dict, dry_run: bool) -> None:
    if dry_run:
        print(f"DRY-RUN: would write {path}")
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.is_file():
        shutil.copy2(path, path.with_suffix(path.suffix + ".bak"))
    with path.open("w", encoding="utf-8") as handle:
        json.dump(data, handle, indent=2)
        handle.write("\n")


def context_mode_present_cursor(mcp_path: pathlib.Path) -> bool:
    data = load_json(mcp_path)
    servers = data.get("mcpServers", {})
    return "context-mode" in servers


def context_mode_present_claude(claude_json: pathlib.Path) -> bool:
    data = load_json(claude_json)
    servers = data.get("mcpServers", {})
    return "context-mode" in servers


def context_mode_present_opencode(cfg_path: pathlib.Path) -> bool:
    data = load_json(cfg_path)
    mcp = data.get("mcp", {})
    return "context-mode" in mcp


def context_mode_present_codex(config_toml: pathlib.Path) -> bool:
    if not config_toml.is_file():
        return False
    text = config_toml.read_text(encoding="utf-8")
    return "[mcp_servers.context-mode]" in text


def leanctx_server_env(cm_active: bool) -> dict[str, str]:
    """SB five-tool routed profile env hints for LeanCTX MCP subprocess."""
    env: dict[str, str] = {
        # Conflict #1: namespace separation from Context Mode ctx_* tools.
        "LEANCTX_MCP_TOOL_PREFIX": "lctx_",
    }
    if cm_active:
        # Disable overlapping LeanCTX MCP surfaces owned by RTK/CM in parallel mode.
        env.update(
            {
                "LEANCTX_DISABLE_SHELL_MCP": "1",
                "LEANCTX_DISABLE_SANDBOX_MCP": "1",
                "LEANCTX_DISABLE_FETCH_MCP": "1",
                "LEANCTX_DISABLE_FTS": "1",
                "LEANCTX_PRIMARY_FTS": "context_mode",
            }
        )
    return env


def leanctx_cursor_server(cm_active: bool) -> dict:
    return {
        "command": "lean-ctx",
        "args": ["mcp"],
        "env": leanctx_server_env(cm_active),
    }


def remove_upstream_lean_ctx_duplicate(servers: dict) -> bool:
    """Drop upstream ``lean-ctx`` MCP entry when SB owns ``leanctx``.

    Upstream ``lean-ctx init`` may register ``mcpServers.lean-ctx`` while SB
    install uses the canonical ``leanctx`` key (with ``lctx_`` prefix and
    five-tool env). Both keys spawn separate lean-ctx MCP subprocesses (~2× per
    Cursor worker) — keep ``leanctx`` only.
    """
    if "lean-ctx" not in servers:
        return False
    del servers["lean-ctx"]
    return True


def merge_cursor_mcp(target: pathlib.Path, dry_run: bool) -> dict:
    cm_active = context_mode_present_cursor(target)
    data = load_json(target, {"mcpServers": {}})
    servers = data.setdefault("mcpServers", {})
    changed = False
    if remove_upstream_lean_ctx_duplicate(servers):
        changed = True
    if "leanctx" not in servers:
        servers["leanctx"] = leanctx_cursor_server(cm_active)
        changed = True
    else:
        existing = servers["leanctx"]
        desired_env = leanctx_server_env(cm_active)
        merged_env = dict(existing.get("env", {}))
        for key, val in desired_env.items():
            if merged_env.get(key) != val:
                merged_env[key] = val
                changed = True
        if changed:
            existing["env"] = merged_env
            servers["leanctx"] = existing
    if changed:
        save_json(target, data, dry_run)
    return {"host": "cursor", "mcp_merged": changed, "cm_active": cm_active}


def merge_claude_mcp(target: pathlib.Path, dry_run: bool) -> dict:
    cm_active = context_mode_present_claude(target)
    data = load_json(target, {"mcpServers": {}})
    servers = data.setdefault("mcpServers", {})
    changed = False
    desired = {
        "command": "lean-ctx",
        "args": ["mcp"],
        "env": leanctx_server_env(cm_active),
    }
    if servers.get("leanctx") != desired:
        servers["leanctx"] = desired
        changed = True
    if changed:
        save_json(target, data, dry_run)
    return {"host": "claude", "mcp_merged": changed, "cm_active": cm_active}


def merge_opencode_mcp(target: pathlib.Path, dry_run: bool) -> dict:
    cm_active = context_mode_present_opencode(target)
    data = load_json(
        target,
        {
            "$schema": "https://opencode.ai/config.json",
            "plugin": [],
            "mcp": {},
        },
    )
    data.setdefault("$schema", "https://opencode.ai/config.json")
    mcp = data.setdefault("mcp", {})
    changed = False
    desired = {
        "type": "local",
        "command": ["lean-ctx", "mcp"],
        "enabled": True,
        "environment": leanctx_server_env(cm_active),
    }
    if mcp.get("leanctx") != desired:
        mcp["leanctx"] = desired
        changed = True
    if changed:
        save_json(target, data, dry_run)
    return {"host": "opencode", "mcp_merged": changed, "cm_active": cm_active}


def merge_codex_toml(target: pathlib.Path, dry_run: bool) -> dict:
    cm_active = context_mode_present_codex(target)
    marker = "[mcp_servers.leanctx]"
    env_lines = "\n".join(
        f'{key} = "{val}"' for key, val in leanctx_server_env(cm_active).items()
    )
    block = f"""{marker}
command = "lean-ctx"
args = ["mcp"]

[mcp_servers.leanctx.env]
{env_lines}
"""
    if target.is_file() and marker in target.read_text(encoding="utf-8"):
        return {"host": "codex", "mcp_merged": False, "cm_active": cm_active}
    if dry_run:
        print(f"DRY-RUN: would append leanctx block to {target}")
        return {"host": "codex", "mcp_merged": True, "cm_active": cm_active}
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.is_file():
        shutil.copy2(target, target.with_suffix(target.suffix + ".bak"))
        with target.open("a", encoding="utf-8") as handle:
            if target.stat().st_size > 0:
                handle.write("\n")
            handle.write(block)
    else:
        target.write_text(block, encoding="utf-8")
    return {"host": "codex", "mcp_merged": True, "cm_active": cm_active}


def strip_unprefixed_leanctx_collision(mcp_path: pathlib.Path, dry_run: bool) -> bool:
    """Remove raw ctx_* tool registrations from leanctx server if CM is active."""
    if not mcp_path.is_file():
        return False
    data = load_json(mcp_path)
    servers = data.get("mcpServers", {})
    lean = servers.get("leanctx")
    if not isinstance(lean, dict):
        return False
    disabled = lean.get("disabledTools")
    if not isinstance(disabled, list):
        disabled = []
    cm_overlap = [
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
    changed = False
    for tool in cm_overlap:
        if tool not in disabled:
            disabled.append(tool)
            changed = True
    if changed:
        lean["disabledTools"] = disabled
        servers["leanctx"] = lean
        data["mcpServers"] = servers
        save_json(mcp_path, data, dry_run)
    return changed


def optimize_host(host: str, dry_run: bool) -> dict:
    home = pathlib.Path.home()
    if host == "cursor":
        mcp_path = home / ".cursor" / "mcp.json"
        result = merge_cursor_mcp(mcp_path, dry_run)
        if result.get("cm_active"):
            strip_unprefixed_leanctx_collision(mcp_path, dry_run)
        return result
    if host == "claude":
        return merge_claude_mcp(home / ".claude.json", dry_run)
    if host == "codex":
        codex_home = pathlib.Path(os.environ.get("CODEX_HOME", home / ".codex"))
        return merge_codex_toml(codex_home / "config.toml", dry_run)
    if host == "opencode":
        return merge_opencode_mcp(home / ".config" / "opencode" / "opencode.json", dry_run)
    raise ValueError(f"unsupported host: {host}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Merge LeanCTX MCP into host configs")
    parser.add_argument(
        "--host",
        choices=["cursor", "codex", "claude", "opencode", "all"],
        default="cursor",
    )
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    hosts = ["cursor", "codex", "claude", "opencode"] if args.host == "all" else [args.host]
    results = [optimize_host(h, args.dry_run) for h in hosts]
    print(json.dumps({"status": "ok", "results": results}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())


