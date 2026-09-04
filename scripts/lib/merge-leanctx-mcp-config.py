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

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent / "global-toolstack"))

from five_tool_instances import (  # noqa: E402
    ensure_global_instances,
    mcp_server_spec,
)
from opencode import (  # noqa: E402
    opencode_context_mode_plugin_present,
    opencode_ensure_context_mode_plugin,
    opencode_existing_server_present,
    opencode_remove_context_mode_mcp,
    opencode_server_config,
    opencode_upsert_server,
)


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
    return "context-mode" in servers or "user-context-mode" in servers


def context_mode_present_opencode(cfg_path: pathlib.Path) -> bool:
    data = load_json(cfg_path)
    mcp = data.get("mcp", {})
    return (
        opencode_context_mode_plugin_present(data)
        or "context-mode" in mcp
        or "user-context-mode" in mcp
    )


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


def leanctx_cursor_server(cm_active: bool, manifest: dict) -> dict:
    desired = mcp_server_spec(manifest, "leanctx")
    desired["env"] = leanctx_server_env(cm_active)
    if cm_active:
        desired["disabledTools"] = list(CM_OVERLAP_TOOLS)
    return desired


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


def merge_cursor_mcp(target: pathlib.Path, dry_run: bool, manifest: dict) -> dict:
    cm_active = context_mode_present_cursor(target)
    data = load_json(target, {"mcpServers": {}})
    servers = data.setdefault("mcpServers", {})
    changed = False
    if remove_upstream_lean_ctx_duplicate(servers):
        changed = True
    if "leanctx" not in servers:
        servers["leanctx"] = leanctx_cursor_server(cm_active, manifest)
        changed = True
    else:
        existing = servers["leanctx"]
        desired = leanctx_cursor_server(cm_active, manifest)
        for key in ("command", "args"):
            if existing.get(key) != desired[key]:
                existing[key] = desired[key]
                changed = True
        desired_env = leanctx_server_env(cm_active)
        merged_env = dict(existing.get("env", {}))
        for key, val in desired_env.items():
            if merged_env.get(key) != val:
                merged_env[key] = val
                changed = True
        if changed:
            existing["env"] = merged_env
            servers["leanctx"] = existing
        if cm_active:
            disabled = list(existing.get("disabledTools", []))
            for tool in CM_OVERLAP_TOOLS:
                if tool not in disabled:
                    disabled.append(tool)
                    changed = True
            existing["disabledTools"] = disabled
            servers["leanctx"] = existing
    if changed:
        save_json(target, data, dry_run)
    return {"host": "cursor", "mcp_merged": changed, "cm_active": cm_active}


def merge_claude_mcp(target: pathlib.Path, dry_run: bool, manifest: dict) -> dict:
    cm_active = context_mode_present_claude(target)
    data = load_json(target, {"mcpServers": {}})
    servers = data.setdefault("mcpServers", {})
    changed = False
    if remove_upstream_lean_ctx_duplicate(servers):
        changed = True
    desired = leanctx_cursor_server(cm_active, manifest)
    if servers.get("leanctx") != desired:
        servers["leanctx"] = desired
        changed = True
    if changed:
        save_json(target, data, dry_run)
    return {"host": "claude", "mcp_merged": changed, "cm_active": cm_active}


def merge_opencode_mcp(target: pathlib.Path, dry_run: bool, manifest: dict) -> dict:
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
    if not isinstance(mcp, dict):
        mcp = {}
        data["mcp"] = mcp
    changed = False
    cm_plugin_active = opencode_context_mode_plugin_present(data)
    plugins = data.get("plugin")
    if cm_plugin_active and isinstance(plugins, list):
        changed = opencode_ensure_context_mode_plugin(
            plugins, manifest, allow_add=False
        ) or changed
    cm_active = cm_plugin_active or opencode_existing_server_present(
        mcp, "context-mode", ("user-context-mode",)
    )
    if cm_plugin_active:
        changed = opencode_remove_context_mode_mcp(mcp) or changed
    elif cm_active:
        changed = opencode_upsert_server(
            mcp,
            "context-mode",
            opencode_server_config(manifest, "context_mode"),
            aliases=("user-context-mode",),
        ) or changed
    changed = opencode_upsert_server(
        mcp,
        "leanctx",
        opencode_server_config(
            manifest,
            "leanctx",
            environment=leanctx_server_env(cm_active),
        ),
        aliases=("lean-ctx", "lean-ctx-standalone", "user-leanctx", "user-lean-ctx"),
    ) or changed
    if changed:
        if dry_run:
            print(f"DRY-RUN: would write {target}")
        else:
            save_json(target, data, dry_run)
    return {"host": "opencode", "mcp_merged": changed, "cm_active": cm_active}


def toml_section_bounds(text: str, header: str) -> tuple[int, int] | None:
    match = re.search(rf"(?m)^{re.escape(header)}\s*$", text)
    if not match:
        return None
    next_header = re.search(r"(?m)^\[", text[match.end() :])
    end = match.end() + (next_header.start() if next_header else len(text[match.end() :]))
    return match.start(), end


def normalize_codex_root(text: str, server: str, manifest: dict) -> str:
    spec = mcp_server_spec(manifest, "leanctx")
    header = f"[mcp_servers.{server}]"
    bounds = toml_section_bounds(text, header)
    if bounds is None:
        return text
    start, end = bounds
    header_end = text.find("\n", start, end)
    if header_end < 0:
        header_end = end
    body = text[header_end + 1 : end]
    for key, value in (
        ("command", f"command = {json.dumps(spec['command'])}"),
        ("args", f"args = {json.dumps(spec['args'])}"),
    ):
        pattern = rf"(?m)^{re.escape(key)}\s*=.*$"
        if re.search(pattern, body):
            body = re.sub(pattern, value, body, count=1)
        else:
            body = f"{value}\n" + body
    return text[: header_end + 1] + body + text[end:]


def normalize_codex_env(text: str, env: dict[str, str]) -> str:
    header = "[mcp_servers.leanctx.env]"
    bounds = toml_section_bounds(text, header)
    if bounds is None:
        if text and not text.endswith("\n"):
            text += "\n"
        if text:
            text += "\n"
        text += header + "\n"
        text += "\n".join(f"{key} = {json.dumps(value)}" for key, value in env.items()) + "\n"
        return text
    start, end = bounds
    header_end = text.find("\n", start, end)
    if header_end < 0:
        header_end = end
    body = text[header_end + 1 : end]
    for key, value in env.items():
        line = f"{key} = {json.dumps(value)}"
        pattern = rf"(?m)^{re.escape(key)}\s*=.*$"
        if re.search(pattern, body):
            body = re.sub(pattern, line, body, count=1)
        else:
            body = f"{line}\n" + body
    return text[: header_end + 1] + body + text[end:]


def merge_codex_toml(target: pathlib.Path, dry_run: bool, manifest: dict) -> dict:
    cm_active = context_mode_present_codex(target)
    original = target.read_text(encoding="utf-8") if target.is_file() else ""
    text = re.sub(
        r"(?ms)^\[mcp_servers\.lean-ctx(?:\.env)?\]\n.*?(?=^\[|\Z)",
        "",
        original,
    )
    changed = text != original
    marker = "[mcp_servers.leanctx]"
    env_lines = "\n".join(
        f'{key} = "{val}"' for key, val in leanctx_server_env(cm_active).items()
    )
    spec = mcp_server_spec(manifest, "leanctx")
    block = f"""{marker}
command = {json.dumps(spec['command'])}
args = {json.dumps(spec['args'])}

[mcp_servers.leanctx.env]
{env_lines}
"""
    if marker not in text:
        if text and not text.endswith("\n"):
            text += "\n"
        if text:
            text += "\n"
        text += block
        changed = True
    else:
        updated = normalize_codex_root(text, "leanctx", manifest)
        updated = normalize_codex_env(updated, leanctx_server_env(cm_active))
        changed = changed or updated != text
        text = updated
    if not changed:
        return {"host": "codex", "mcp_merged": False, "cm_active": cm_active}
    if dry_run:
        print(f"DRY-RUN: would append leanctx block to {target}")
        return {"host": "codex", "mcp_merged": True, "cm_active": cm_active}
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.is_file():
        shutil.copy2(target, target.with_suffix(target.suffix + ".bak"))
    target.write_text(text, encoding="utf-8")
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


def optimize_host(host: str, dry_run: bool, manifest: dict | None = None) -> dict:
    manifest = manifest or ensure_global_instances(dry_run=dry_run)
    home = pathlib.Path.home()
    if host == "cursor":
        mcp_path = home / ".cursor" / "mcp.json"
        result = merge_cursor_mcp(mcp_path, dry_run, manifest)
        if result.get("cm_active"):
            strip_unprefixed_leanctx_collision(mcp_path, dry_run)
        return result
    if host == "claude":
        return merge_claude_mcp(home / ".claude.json", dry_run, manifest)
    if host == "codex":
        codex_home = pathlib.Path(os.environ.get("CODEX_HOME", home / ".codex"))
        return merge_codex_toml(codex_home / "config.toml", dry_run, manifest)
    if host == "opencode":
        return merge_opencode_mcp(home / ".config" / "opencode" / "opencode.json", dry_run, manifest)
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
    manifest = ensure_global_instances(dry_run=args.dry_run)
    results = [optimize_host(h, args.dry_run, manifest) for h in hosts]
    print(json.dumps({"status": "ok", "results": results}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
