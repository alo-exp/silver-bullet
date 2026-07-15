#!/usr/bin/env python3
"""Idempotently patch ~/.cursor/hooks.json for global toolstack gates."""
from __future__ import annotations

import json
import os
from pathlib import Path

TS = Path.home() / ".cursor" / "hooks" / "toolstack"
HOOKS = Path.home() / ".cursor" / "hooks.json"
SB_BRIDGE = "cursor-hook-bridge.sh"


def entry(cmd: str, matcher: str | None = None, timeout: int | None = None) -> dict:
    e: dict = {"command": cmd}
    if matcher:
        e["matcher"] = matcher
    if timeout:
        e["timeout"] = timeout
    return e


def hook_cmd(h: dict) -> str:
    return str(h.get("command", ""))


def has_cmd(hooks: list, needle: str) -> bool:
    return any(needle in hook_cmd(h) for h in hooks)


def has_toolstack_hook(hooks: list, script_name: str) -> bool:
    return any(f"toolstack/{script_name}" in hook_cmd(h) for h in hooks)


def insert_before_bridge(hooks: list, new_entries: list) -> int:
    insert_at = len(hooks)
    for i, h in enumerate(hooks):
        if SB_BRIDGE in hook_cmd(h):
            insert_at = i
            break
    added = 0
    for e in reversed(new_entries):
        script = e["command"].split("/")[-1]
        if has_toolstack_hook(hooks, script):
            continue
        hooks.insert(insert_at, e)
        added += 1
    return added


def ensure_rtk_before_cm(pretool: list) -> bool:
    rtk_idx = cm_idx = None
    for i, h in enumerate(pretool):
        cmd = hook_cmd(h)
        if cmd == "rtk hook cursor":
            rtk_idx = i
        elif "context-mode hook cursor pretooluse" in cmd:
            cm_idx = i
    if rtk_idx is not None and cm_idx is not None and rtk_idx > cm_idx:
        entry_rtk = pretool.pop(rtk_idx)
        pretool.insert(cm_idx, entry_rtk)
        return True
    if rtk_idx is None and cm_idx is not None:
        pretool.insert(cm_idx, {"command": "rtk hook cursor", "matcher": "Shell"})
        return True
    return False


def main() -> int:
    with HOOKS.open(encoding="utf-8") as f:
        data = json.load(f)
    hooks = data.setdefault("hooks", {})
    changed = 0

    ss = hooks.setdefault("sessionStart", [])
    bootstrap = entry(f"bash {TS}/session-bootstrap.sh", "startup|clear|compact", 120)
    if not has_toolstack_hook(ss, "session-bootstrap.sh"):
        insert_at = 0
        for i, h in enumerate(ss):
            if "sidekick" in hook_cmd(h):
                insert_at = i + 1
                break
        ss.insert(insert_at, bootstrap)
        changed += 1

    pt = hooks.setdefault("preToolUse", [])
    shell_comp = f"bash {TS}/shell-compression.sh"
    for h in pt:
        cmd = hook_cmd(h)
        if "lean-ctx hook rewrite" in cmd:
            h["command"] = shell_comp
            if "matcher" not in h:
                h["matcher"] = "Shell"
            changed += 1
    if not has_toolstack_hook(pt, "shell-compression.sh"):
        insert_at = 0
        for i, h in enumerate(pt):
            if "sidekick" in hook_cmd(h):
                insert_at = i + 1
                break
        pt.insert(insert_at, entry(shell_comp, "Shell"))
        changed += 1
    if ensure_rtk_before_cm(pt):
        changed += 1

    gate_entries = [
        entry(f"bash {TS}/stack-compression-coordinator.sh", "Edit|Write|MultiEdit|Shell|CallMcpTool|MCP|WebFetch", 10),
        entry(f"bash {TS}/graphify-gate.sh", "Edit|Write|MultiEdit|Shell", 10),
        entry(f"bash {TS}/agentmemory-gate.sh", "Edit|Write|MultiEdit|Shell", 10),
        entry(f"bash {TS}/rtk-gate.sh", "Edit|Write|MultiEdit|Shell", 10),
        entry(f"bash {TS}/context-mode-gate.sh", "Edit|Write|MultiEdit|Shell", 10),
        entry(f"bash {TS}/token-compression-tools-gate.sh", "Edit|Write|MultiEdit|Shell", 10),
    ]
    for ge in gate_entries:
        name = ge["command"].split("/")[-1]
        if not has_toolstack_hook(pt, name):
            insert_before_bridge(pt, [ge])
            changed += 1

    ase = hooks.setdefault("afterShellExecution", [])
    if not has_toolstack_hook(ase, "record-graphify-query.sh"):
        insert_before_bridge(ase, [entry(f"bash {TS}/record-graphify-query.sh", ".*", 10)])
        changed += 1

    ptu = hooks.setdefault("postToolUse", [])
    rec = [
        entry(f"bash {TS}/record-graphify-query.sh", "Shell", 10),
        entry(f"bash {TS}/record-agentmemory-usage.sh", "CallMcpTool|MCP|Shell", 10),
    ]
    for r in rec:
        name = r["command"].split("/")[-1]
        if not has_toolstack_hook(ptu, name):
            insert_at = 0
            for i, h in enumerate(ptu):
                if "context-mode hook cursor posttooluse" in hook_cmd(h):
                    insert_at = i + 1
                    break
            ptu.insert(insert_at, r)
            changed += 1

    with HOOKS.open("w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
    print(f"OK: hooks.json patched ({changed} changes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
