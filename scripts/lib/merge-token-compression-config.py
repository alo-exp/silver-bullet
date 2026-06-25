#!/usr/bin/env python3
"""Idempotently merge RTK + Context Mode global host artifacts (SB-independent)."""

from __future__ import annotations

import argparse
import json
import os
import pathlib
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
    backup_file(path)
    with path.open("w", encoding="utf-8") as handle:
        json.dump(data, handle, indent=2)
        handle.write("\n")


def backup_file(path: pathlib.Path) -> None:
    if path.is_file():
        shutil.copy2(path, path.with_suffix(path.suffix + ".bak"))


def hook_command(entry: dict) -> str:
    return str(entry.get("command", ""))


def merge_hook_entries(existing: list, new_entries: list) -> tuple[list, int]:
    merged = list(existing)
    added = 0
    for entry in new_entries:
        cmd = hook_command(entry)
        if not cmd:
            continue
        if any(hook_command(item) == cmd for item in merged):
            continue
        merged.append(entry)
        added += 1
    return merged, added


def reorder_pretooluse_rtk_before_cm(hooks: dict) -> bool:
    """Ensure rtk hook cursor runs before context-mode pretooluse on preToolUse."""
    pretool = hooks.get("preToolUse")
    if not isinstance(pretool, list):
        return False
    rtk_idx = cm_idx = None
    for idx, entry in enumerate(pretool):
        cmd = hook_command(entry)
        if cmd == "rtk hook cursor":
            rtk_idx = idx
        elif "context-mode hook cursor pretooluse" in cmd:
            cm_idx = idx
    if rtk_idx is None or cm_idx is None or rtk_idx < cm_idx:
        return False
    rtk_entry = pretool.pop(rtk_idx)
    insert_at = cm_idx - 1 if cm_idx > rtk_idx else cm_idx
    pretool.insert(insert_at, rtk_entry)
    hooks["preToolUse"] = pretool
    return True


def merge_hooks_file(target: pathlib.Path, fragments: list[dict], dry_run: bool) -> int:
    settings = load_json(target, {"version": 1, "hooks": {}})
    settings.setdefault("version", 1)
    hooks = settings.setdefault("hooks", {})
    total_added = 0
    for fragment in fragments:
        for event, entries in fragment.get("hooks", {}).items():
            event_list = hooks.setdefault(event, [])
            merged, added = merge_hook_entries(event_list, entries)
            hooks[event] = merged
            total_added += added
    reorder_pretooluse_rtk_before_cm(hooks)
    save_json(target, settings, dry_run)
    return total_added


def merge_codex_hooks_file(target: pathlib.Path, fragment: dict, dry_run: bool) -> int:
    """Merge Codex hooks.json (nested hooks[].hooks structure)."""
    settings = load_json(target, {"hooks": {}})
    hooks = settings.setdefault("hooks", {})
    added = 0
    for event, groups in fragment.get("hooks", {}).items():
        event_list = hooks.setdefault(event, [])
        for group in groups:
            cmd_entries = group.get("hooks", [])
            new_cmds = [
                h.get("command", "")
                for h in cmd_entries
                if isinstance(h, dict) and h.get("command")
            ]
            found = False
            for existing in event_list:
                if not isinstance(existing, dict):
                    continue
                existing_cmds = [
                    h.get("command", "")
                    for h in existing.get("hooks", [])
                    if isinstance(h, dict)
                ]
                if any(c in existing_cmds for c in new_cmds):
                    found = True
                    break
            if not found:
                event_list.append(group)
                added += 1
    save_json(target, settings, dry_run)
    return added


def merge_mcp_server(target: pathlib.Path, server_name: str, server_cfg: dict, dry_run: bool) -> bool:
    data = load_json(target, {"mcpServers": {}})
    servers = data.setdefault("mcpServers", {})
    if server_name in servers:
        return False
    servers[server_name] = server_cfg
    save_json(target, data, dry_run)
    return True


def merge_cli_allowlist(target: pathlib.Path, allow_entries: list[str], dry_run: bool) -> int:
    data = load_json(target, {"version": 1, "permissions": {"allow": [], "deny": []}})
    data.setdefault("version", 1)
    perms = data.setdefault("permissions", {})
    allow = perms.setdefault("allow", [])
    added = 0
    for entry in allow_entries:
        if entry not in allow:
            allow.append(entry)
            added += 1
    save_json(target, data, dry_run)
    return added


def copy_file(src: pathlib.Path, dest: pathlib.Path, dry_run: bool) -> bool:
    if not src.is_file():
        return False
    try:
        if src.resolve() == dest.resolve():
            return False
    except OSError:
        pass
    if dry_run:
        print(f"DRY-RUN: would copy {src} -> {dest}")
        return True
    dest.parent.mkdir(parents=True, exist_ok=True)
    backup_file(dest)
    shutil.copy2(src, dest)
    return True


def append_unique_plugin(plugins: list, entry: str) -> bool:
    if entry in plugins:
        return False
    plugins.append(entry)
    return True


def context_mode_pkg_root() -> pathlib.Path | None:
    npm_root = os.environ.get("CONTEXT_MODE_PKG")
    if npm_root:
        candidate = pathlib.Path(npm_root)
        if candidate.is_dir():
            return candidate
    try:
        import subprocess

        out = subprocess.check_output(["npm", "root", "-g"], text=True).strip()
        candidate = pathlib.Path(out) / "context-mode"
        if candidate.is_dir():
            return candidate
    except (OSError, subprocess.CalledProcessError):
        pass
    return None


def context_mode_cursor_hooks_path(repo_root: pathlib.Path) -> pathlib.Path | None:
    cm_pkg = context_mode_pkg_root()
    if cm_pkg:
        candidate = cm_pkg / "configs" / "cursor" / "hooks.json"
        if candidate.is_file():
            return candidate
    bundled = repo_root / "scripts" / "lib" / "context-mode-cursor-hooks.json"
    if bundled.is_file():
        return bundled
    return None


def context_mode_extended_cursor_hooks() -> dict:
    return {
        "hooks": {
            "sessionStart": [
                {
                    "command": "context-mode hook cursor sessionstart",
                    "matcher": "startup|clear|compact",
                }
            ],
            "afterAgentResponse": [
                {"command": "context-mode hook cursor afteragentresponse"}
            ],
        }
    }


def merge_codex_config_toml(target: pathlib.Path, dry_run: bool) -> bool:
    cm_pkg = context_mode_pkg_root()
    if not cm_pkg:
        return False
    snippet_path = cm_pkg / "configs" / "codex" / "config.toml"
    if not snippet_path.is_file():
        return False
    snippet = snippet_path.read_text(encoding="utf-8")
    marker = "[mcp_servers.context-mode]"
    if target.is_file() and marker in target.read_text(encoding="utf-8"):
        return False
    if dry_run:
        print(f"DRY-RUN: would append context-mode block to {target}")
        return True
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.is_file():
        backup_file(target)
    with target.open("a", encoding="utf-8") as handle:
        if target.stat().st_size > 0:
            handle.write("\n")
        handle.write(snippet)
        if not snippet.endswith("\n"):
            handle.write("\n")
    return True


def merge_hermes_context_mode_mcp(config_path: pathlib.Path, dry_run: bool) -> bool:
    marker = "# === rtk-cm context-mode MCP block ==="
    end_marker = "# === end rtk-cm context-mode MCP block ==="
    block = f"""{marker}
mcp_servers:
  context-mode:
    command: context-mode
    args: [mcp]
    env: {{}}
{end_marker}
"""
    if config_path.is_file():
        text = config_path.read_text(encoding="utf-8")
        if "context-mode:" in text and "mcp_servers:" in text:
            return False
        if marker in text:
            return False
    if dry_run:
        print(f"DRY-RUN: would append context-mode MCP to {config_path}")
        return True
    config_path.parent.mkdir(parents=True, exist_ok=True)
    if config_path.is_file():
        backup_file(config_path)
        with config_path.open("a", encoding="utf-8") as handle:
            handle.write("\n")
            handle.write(block)
    else:
        config_path.write_text(f"plugins:\n  enabled: []\n\n{block}", encoding="utf-8")
    return True


def optimize_cursor(repo_root: pathlib.Path, dry_run: bool, skip_cli_config: bool = False) -> dict:
    cursor_home = pathlib.Path.home() / ".cursor"
    hooks_path = cursor_home / "hooks.json"
    mcp_path = cursor_home / "mcp.json"
    cli_config_path = cursor_home / "cli-config.json"
    global_rules = cursor_home / "rules"
    project_rules = repo_root / ".cursor" / "rules"

    cm_pkg = context_mode_pkg_root()
    fragments: list[dict] = []
    cm_hooks = context_mode_cursor_hooks_path(repo_root)
    if cm_hooks:
        fragments.append(load_json(cm_hooks))
    fragments.append(context_mode_extended_cursor_hooks())

    hooks_added = merge_hooks_file(hooks_path, fragments, dry_run) if fragments else 0

    mcp_added = False
    if cm_pkg:
        cm_mcp = cm_pkg / "configs" / "cursor" / "mcp.json"
        if cm_mcp.is_file():
            mcp_data = load_json(cm_mcp)
            servers = mcp_data.get("mcpServers", {})
            for name, cfg in servers.items():
                if merge_mcp_server(mcp_path, name, cfg, dry_run):
                    mcp_added = True

    allow_added = 0
    if not skip_cli_config:
        allowlist_path = repo_root / "scripts" / "lib" / "cursor-cli-allowlist.json"
        allow_data = load_json(allowlist_path, {"allow": []})
        allow_added = merge_cli_allowlist(cli_config_path, allow_data.get("allow", []), dry_run)

    rules_copied = 0
    rule_sources = [
        (repo_root / "templates" / "cursor" / "token-compression-enforcement.mdc", global_rules / "token-compression-enforcement.mdc"),
        (repo_root / ".cursor" / "rules" / "context-mode.mdc", global_rules / "context-mode.mdc"),
    ]
    if cm_pkg:
        rule_sources.insert(
            1,
            (cm_pkg / "configs" / "cursor" / "context-mode.mdc", global_rules / "context-mode.mdc"),
        )
    for src, dest in rule_sources:
        if copy_file(src, dest, dry_run):
            rules_copied += 1
        if src.name == "context-mode.mdc":
            copy_file(src, project_rules / "context-mode.mdc", dry_run)

    return {
        "host": "cursor",
        "status": "supported",
        "hooks_added": hooks_added,
        "mcp_added": mcp_added,
        "allow_added": allow_added,
        "rules_copied": rules_copied,
    }


def optimize_codex(dry_run: bool) -> dict:
    codex_home = pathlib.Path(os.environ.get("CODEX_HOME", pathlib.Path.home() / ".codex"))
    hooks_path = codex_home / "hooks.json"
    config_path = codex_home / "config.toml"
    cm_pkg = context_mode_pkg_root()
    hooks_added = 0
    config_merged = False
    agents_copied = False
    if cm_pkg:
        cm_hooks = cm_pkg / "configs" / "codex" / "hooks.json"
        if cm_hooks.is_file():
            hooks_added = merge_codex_hooks_file(hooks_path, load_json(cm_hooks), dry_run)
        agents_src = cm_pkg / "configs" / "codex" / "AGENTS.md"
        agents_copied = copy_file(agents_src, codex_home / "AGENTS.md", dry_run)
        config_merged = merge_codex_config_toml(config_path, dry_run)
    return {
        "host": "codex",
        "status": "supported",
        "hooks_added": hooks_added,
        "config_merged": config_merged,
        "agents_copied": agents_copied,
    }


def optimize_claude(dry_run: bool) -> dict:
    """Merge npm-global MCP path when Claude plugin is not used."""
    claude_json = pathlib.Path.home() / ".claude.json"
    mcp_added = merge_mcp_server(
        claude_json,
        "context-mode",
        {"command": "context-mode", "args": ["mcp"]},
        dry_run,
    )
    return {"host": "claude", "status": "supported", "mcp_added": mcp_added}


def optimize_opencode(dry_run: bool) -> dict:
    opencode_home = pathlib.Path.home() / ".config" / "opencode"
    cfg_path = opencode_home / "opencode.json"
    cm_pkg = context_mode_pkg_root()

    data = load_json(
        cfg_path,
        {
            "$schema": "https://opencode.ai/config.json",
            "plugin": [],
            "mcp": {},
        },
    )
    data.setdefault("$schema", "https://opencode.ai/config.json")
    plugins = data.setdefault("plugin", [])
    plugin_added = append_unique_plugin(plugins, "context-mode")

    # Ensure RTK plugin path if file exists
    rtk_plugin = opencode_home / "plugins" / "rtk.ts"
    rtk_rel = "./plugins/rtk.ts"
    if rtk_plugin.is_file():
        plugin_added = append_unique_plugin(plugins, rtk_rel) or plugin_added

    mcp = data.setdefault("mcp", {})
    mcp_added = False
    if "context-mode" not in mcp:
        mcp["context-mode"] = {
            "type": "local",
            "command": ["context-mode", "mcp"],
            "enabled": True,
        }
        mcp_added = True

    if plugin_added or mcp_added or not cfg_path.is_file():
        save_json(cfg_path, data, dry_run)

    agents_copied = False
    if cm_pkg:
        agents_src = cm_pkg / "configs" / "opencode" / "AGENTS.md"
        agents_copied = copy_file(agents_src, opencode_home / "AGENTS.md", dry_run)

    return {
        "host": "opencode",
        "status": "supported",
        "plugin_added": plugin_added,
        "mcp_added": mcp_added,
        "agents_copied": agents_copied,
    }


def optimize_hermes(dry_run: bool) -> dict:
    config_path = pathlib.Path.home() / ".hermes" / "config.yaml"
    mcp_merged = merge_hermes_context_mode_mcp(config_path, dry_run)
    return {
        "host": "hermes",
        "status": "partial",
        "mcp_merged": mcp_merged,
        "note": "RTK via rtk init --agent hermes; Context Mode MCP only (no official Hermes adapter)",
    }


def optimize_goose() -> dict:
    return {
        "host": "goose",
        "status": "unsupported",
        "skipped": True,
        "reason": "Neither RTK nor Context Mode ship Goose integrations upstream",
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Merge RTK + Context Mode global host config")
    parser.add_argument(
        "--host",
        choices=["cursor", "codex", "claude", "opencode", "hermes", "goose", "all"],
        default="cursor",
    )
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--skip-cli-config", action="store_true")
    args = parser.parse_args()

    repo_root = pathlib.Path(args.repo_root).resolve()
    results: list[dict] = []
    hosts = (
        ["cursor", "codex", "claude", "opencode", "hermes", "goose"]
        if args.host == "all"
        else [args.host]
    )

    optimizers = {
        "cursor": lambda: optimize_cursor(repo_root, args.dry_run, args.skip_cli_config),
        "codex": lambda: optimize_codex(args.dry_run),
        "claude": lambda: optimize_claude(args.dry_run),
        "opencode": lambda: optimize_opencode(args.dry_run),
        "hermes": lambda: optimize_hermes(args.dry_run),
        "goose": optimize_goose,
    }

    for host in hosts:
        results.append(optimizers[host]())

    print(json.dumps({"status": "ok", "results": results}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
