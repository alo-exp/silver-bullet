#!/usr/bin/env python3
"""Idempotently patch ~/.cursor/hooks.json for global toolstack gates."""
from __future__ import annotations

import json
import os
import tempfile
from pathlib import Path
from typing import Any

TS = Path.home() / ".cursor" / "hooks" / "toolstack"
HOOKS = Path.home() / ".cursor" / "hooks.json"
SB_BRIDGE = "cursor-hook-bridge.sh"


def load_json(path: Path) -> dict[str, Any]:
    if path.is_file():
        with path.open(encoding="utf-8") as handle:
            return json.load(handle)
    return {}


def normalize_hooks_config(data: dict[str, Any]) -> dict[str, Any]:
    """Canonical form for idempotent comparison (empty hooks ≡ missing key)."""
    normalized = json.loads(json.dumps(data))
    hooks = normalized.get("hooks")
    if isinstance(hooks, dict) and not hooks:
        normalized.pop("hooks", None)
    return normalized


def patch_enabled(name: str) -> bool:
    return os.environ.get(f"RT_PATCH_{name.upper()}", "0") == "1"


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


def toolstack_script_exists(script_name: str) -> bool:
    return (TS / script_name).is_file()


def hook_entry_for_script(script_name: str, matcher: str | None = None, timeout: int | None = None) -> dict | None:
    if not toolstack_script_exists(script_name):
        return None
    return entry(f"bash {TS}/{script_name}", matcher, timeout)


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


def ensure_rtk_before_cm(pretool: list, *, patch_rtk: bool, patch_cm: bool) -> bool:
    rtk_idx = cm_idx = None
    for i, h in enumerate(pretool):
        cmd = hook_cmd(h)
        if cmd == "rtk hook cursor":
            rtk_idx = i
        elif "context-mode hook cursor pretooluse" in cmd:
            cm_idx = i
    if not patch_rtk:
        return False
    if rtk_idx is not None and cm_idx is not None and rtk_idx > cm_idx:
        entry_rtk = pretool.pop(rtk_idx)
        pretool.insert(cm_idx, entry_rtk)
        return True
    if rtk_idx is None and cm_idx is not None:
        pretool.insert(cm_idx, {"command": "rtk hook cursor", "matcher": "Shell"})
        return True
    return False


def hook_list(hooks: dict[str, Any], key: str) -> tuple[list, bool]:
    """Return (list, attached). Unattached list is ephemeral until first mutation."""
    existing = hooks.get(key)
    if isinstance(existing, list):
        return existing, True
    return [], False


def attach_hook_list(hooks: dict[str, Any], key: str, lst: list) -> None:
    hooks[key] = lst


def atomic_write_json(path: Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = json.dumps(data, indent=2) + "\n"
    with tempfile.NamedTemporaryFile(
        mode="w",
        encoding="utf-8",
        dir=path.parent,
        delete=False,
        prefix=".hooks-merge.",
    ) as tmp:
        tmp.write(payload)
        tmp_path = Path(tmp.name)
    tmp_path.replace(path)


def main() -> int:
    patch_graphify = patch_enabled("GRAPHIFY")
    patch_agentmemory = patch_enabled("AGENTMEMORY")
    patch_rtk = patch_enabled("RTK")
    patch_cm = patch_enabled("CONTEXT_MODE")
    patch_leanctx = patch_enabled("LEANCTX")
    patch_coordinator = patch_rtk or patch_cm or patch_leanctx
    patch_token_gate = patch_rtk or patch_cm

    if not any(
        (
            patch_graphify,
            patch_agentmemory,
            patch_rtk,
            patch_cm,
            patch_leanctx,
        )
    ):
        print("OK: hooks.json unchanged (no consented patch targets)")
        return 0

    original = load_json(HOOKS)
    data = json.loads(json.dumps(original))
    hooks = data.setdefault("hooks", {})
    changed = 0

    if patch_graphify:
        ss, ss_attached = hook_list(hooks, "sessionStart")
        bootstrap = hook_entry_for_script("session-bootstrap.sh", "startup|clear|compact", 120)
        if bootstrap and not has_toolstack_hook(ss, "session-bootstrap.sh"):
            insert_at = 0
            for i, h in enumerate(ss):
                if "sidekick" in hook_cmd(h):
                    insert_at = i + 1
                    break
            ss.insert(insert_at, bootstrap)
            if not ss_attached:
                attach_hook_list(hooks, "sessionStart", ss)
            changed += 1

    pt, pt_attached = hook_list(hooks, "preToolUse")
    if patch_rtk:
        before_len = len(pt)
        pt[:] = [
            h for h in pt
            if "lean-ctx hook rewrite" not in hook_cmd(h).replace("\\", "")
        ]
        removed = before_len - len(pt)
        if removed:
            if not pt_attached:
                attach_hook_list(hooks, "preToolUse", pt)
                pt_attached = True
            changed += removed
        shell_entry = hook_entry_for_script("shell-compression.sh", "Shell")
        if shell_entry and not has_toolstack_hook(pt, "shell-compression.sh"):
            insert_at = 0
            for i, h in enumerate(pt):
                if "sidekick" in hook_cmd(h):
                    insert_at = i + 1
                    break
            pt.insert(insert_at, shell_entry)
            if not pt_attached:
                attach_hook_list(hooks, "preToolUse", pt)
                pt_attached = True
            changed += 1
    if ensure_rtk_before_cm(pt, patch_rtk=patch_rtk, patch_cm=patch_cm):
        if not pt_attached:
            attach_hook_list(hooks, "preToolUse", pt)
            pt_attached = True
        changed += 1

    gate_specs: list[tuple[str, str | None, int | None]] = []
    if patch_coordinator:
        gate_specs.append(
            # Include Read|Grep — the SB bridge registers a dedicated matcher for
            # compression routing on those tools; omitting it leaves a coverage gap
            # when the bridge entry is absent or superseded.
            ("stack-compression-coordinator.sh", "Edit|Write|MultiEdit|Shell|Read|Grep|CallMcpTool|MCP|WebFetch", 10)
        )
    if patch_graphify:
        gate_specs.append(("graphify-gate.sh", "Edit|Write|MultiEdit|Shell", 10))
    if patch_agentmemory:
        gate_specs.append(("agentmemory-gate.sh", "Edit|Write|MultiEdit|Shell", 10))
    if patch_rtk:
        gate_specs.append(("rtk-gate.sh", "Edit|Write|MultiEdit|Shell", 10))
    if patch_cm:
        gate_specs.append(("context-mode-gate.sh", "Edit|Write|MultiEdit|Shell", 10))
    if patch_token_gate:
        gate_specs.append(("token-compression-tools-gate.sh", "Edit|Write|MultiEdit|Shell", 10))
    gate_entries: list[dict] = []
    for script_name, matcher, timeout in gate_specs:
        ge = hook_entry_for_script(script_name, matcher, timeout)
        if ge:
            gate_entries.append(ge)
    for ge in gate_entries:
        name = ge["command"].split("/")[-1]
        if not has_toolstack_hook(pt, name):
            insert_before_bridge(pt, [ge])
            if not pt_attached:
                attach_hook_list(hooks, "preToolUse", pt)
                pt_attached = True
            changed += 1

    if patch_graphify:
        ase, ase_attached = hook_list(hooks, "afterShellExecution")
        record_shell = hook_entry_for_script("record-graphify-query.sh", ".*", 10)
        if record_shell and not has_toolstack_hook(ase, "record-graphify-query.sh"):
            insert_before_bridge(ase, [record_shell])
            if not ase_attached:
                attach_hook_list(hooks, "afterShellExecution", ase)
            changed += 1

    ptu, ptu_attached = hook_list(hooks, "postToolUse")
    rec: list[dict] = []
    if patch_graphify:
        ge = hook_entry_for_script("record-graphify-query.sh", "Shell", 10)
        if ge:
            rec.append(ge)
    if patch_agentmemory:
        ge = hook_entry_for_script("record-agentmemory-usage.sh", "CallMcpTool|MCP|Shell", 10)
        if ge:
            rec.append(ge)
    for r in rec:
        name = r["command"].split("/")[-1]
        if not has_toolstack_hook(ptu, name):
            insert_at = 0
            for i, h in enumerate(ptu):
                if "context-mode hook cursor posttooluse" in hook_cmd(h):
                    insert_at = i + 1
                    break
            ptu.insert(insert_at, r)
            if not ptu_attached:
                attach_hook_list(hooks, "postToolUse", ptu)
                ptu_attached = True
            changed += 1

    if changed == 0:
        print("OK: hooks.json unchanged (idempotent)")
        return 0

    atomic_write_json(HOOKS, data)
    print(f"OK: hooks.json patched ({changed} changes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

