#!/usr/bin/env python3
"""Idempotently merge RTK + Context Mode Cursor/Codex host artifacts."""

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
    with path.open("w", encoding="utf-8") as handle:
        json.dump(data, handle, indent=2)
        handle.write("\n")


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
    if reorder_pretooluse_rtk_before_cm(hooks):
        total_added += 0  # reorder only; counted as maintenance
    save_json(target, settings, dry_run)
    return total_added


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
    shutil.copy2(src, dest)
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
        "hooks_added": hooks_added,
        "mcp_added": mcp_added,
        "allow_added": allow_added,
        "rules_copied": rules_copied,
    }


def optimize_codex(dry_run: bool) -> dict:
    codex_home = pathlib.Path(os.environ.get("CODEX_HOME", pathlib.Path.home() / ".codex"))
    hooks_path = codex_home / "hooks.json"
    cm_pkg = context_mode_pkg_root()
    hooks_added = 0
    if cm_pkg:
        cm_hooks = cm_pkg / "configs" / "codex" / "hooks.json"
        if cm_hooks.is_file():
            hooks_added = merge_hooks_file(hooks_path, [load_json(cm_hooks)], dry_run)
        agents_src = cm_pkg / "configs" / "codex" / "AGENTS.md"
        copy_file(agents_src, codex_home / "AGENTS.md", dry_run)
    return {"host": "codex", "hooks_added": hooks_added}


def main() -> int:
    parser = argparse.ArgumentParser(description="Merge RTK + Context Mode host config")
    parser.add_argument("--host", choices=["cursor", "codex", "all"], default="cursor")
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--skip-cli-config", action="store_true")
    args = parser.parse_args()

    repo_root = pathlib.Path(args.repo_root).resolve()
    results: list[dict] = []
    if args.host in ("cursor", "all"):
        results.append(optimize_cursor(repo_root, args.dry_run, args.skip_cli_config))
    if args.host in ("codex", "all"):
        results.append(optimize_codex(args.dry_run))

    print(json.dumps({"status": "ok", "results": results}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
