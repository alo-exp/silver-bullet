#!/usr/bin/env python3
"""Idempotently patch ~/.cursor/hooks.json for global toolstack gates."""
from __future__ import annotations

import json
import os
import shlex
import shutil
import sys
import tempfile
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parent))

from five_tool_instances import ensure_global_instances, tool_command  # noqa: E402

TS = Path.home() / ".cursor" / "hooks" / "toolstack"
HOOKS = Path.home() / ".cursor" / "hooks.json"
SB_BRIDGE = "cursor-hook-bridge.sh"
LEGACY_ROUTING_HOOK_MARKERS = (
    "lean-ctx hook deny",
    "lean-ctx hook redirect",
    "lean-ctx hook rewrite",
    "toolstack/shell-compression.sh",
)
GLOBAL_GATE_NAMES = (
    "stack-compression-coordinator.sh",
    "graphify-gate.sh",
    "agentmemory-gate.sh",
    "leanctx-gate.sh",
    "rtk-gate.sh",
    "context-mode-gate.sh",
    "token-compression-tools-gate.sh",
    "record-graphify-query.sh",
    "record-agentmemory-usage.sh",
)


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


def is_legacy_routing_hook(command: str) -> bool:
    """Identify old plugin-owned routing hooks superseded by the global stack."""
    normalized = command.replace("\\\\", "")
    if any(marker in normalized for marker in LEGACY_ROUTING_HOOK_MARKERS):
        return True
    return SB_BRIDGE in normalized and any(name in normalized for name in GLOBAL_GATE_NAMES)


def has_cmd(hooks: list, needle: str) -> bool:
    return any(needle in hook_cmd(h) for h in hooks)


def context_mode_hook_phase(command: str) -> str | None:
    """Extract a Context Mode Cursor hook phase from bare or absolute argv."""
    try:
        parts = shlex.split(command)
    except ValueError:
        parts = command.split()
    for index in range(len(parts) - 2):
        if parts[index : index + 2] != ["hook", "cursor"]:
            continue
        if not any("context-mode" in part for part in parts[:index]):
            continue
        phase = parts[index + 2]
        if phase in {"pretooluse", "posttooluse", "afteragentresponse", "sessionstart", "stop"}:
            return phase
    return None


def context_mode_hook_argv(manifest: dict, phase: str) -> list[str]:
    spec = manifest["tools"]["context_mode"]
    command = str(spec["command"])
    argv = [command, *list(spec.get("args", []))]
    if Path(command).suffix in {".js", ".mjs", ".cjs"}:
        node_candidates = []
        node = shutil.which("node")
        if node:
            node_candidates.append(Path(node).resolve())
        for parent in Path(command).resolve().parents:
            node_candidates.append(parent / "bin" / "node")
        node_path = next((candidate for candidate in node_candidates if candidate.is_file() and os.access(candidate, os.X_OK)), None)
        if node_path:
            argv = [str(node_path), *argv]
    return [*argv, "hook", "cursor", phase]


def canonical_context_mode_hook(manifest: dict, phase: str) -> str:
    return shlex.join(context_mode_hook_argv(manifest, phase))


def toolstack_script_exists(script_name: str) -> bool:
    return (TS / script_name).is_file()


def hook_entry_for_script(script_name: str, matcher: str | None = None, timeout: int | None = None) -> dict | None:
    if not toolstack_script_exists(script_name):
        return None
    return entry(f"bash {TS}/{script_name}", matcher, timeout)


def has_toolstack_hook(hooks: list, script_name: str) -> bool:
    return any(f"toolstack/{script_name}" in hook_cmd(h) for h in hooks)


def _merge_matchers(entries: list[dict]) -> str | None:
    """Return the union of Cursor matchers, or None for an unrestricted hook."""
    alternatives: list[str] = []
    for item in entries:
        matcher = item.get("matcher")
        if not matcher or matcher == ".*":
            return None
        for part in str(matcher).split("|"):
            part = part.strip()
            if part and part not in alternatives:
                alternatives.append(part)
    return "|".join(alternatives) or None


def deduplicate_hook_entries(entries: list) -> tuple[list, int]:
    """Collapse repeated commands while preserving the union of their matchers."""
    result: list = []
    indexes: dict[str, int] = {}
    grouped: dict[str, list[dict]] = {}
    for item in entries:
        if not isinstance(item, dict) or not hook_cmd(item):
            result.append(item)
            continue
        command = hook_cmd(item)
        if command not in indexes:
            indexes[command] = len(result)
            grouped[command] = []
            result.append(item)
        grouped[command].append(item)

    for command, items in grouped.items():
        if len(items) == 1:
            continue
        merged = result[indexes[command]]
        matcher = _merge_matchers(items)
        if matcher is None:
            merged.pop("matcher", None)
        else:
            merged["matcher"] = matcher
        timeouts = [
            item.get("timeout")
            for item in items
            if isinstance(item.get("timeout"), (int, float))
        ]
        if timeouts:
            merged["timeout"] = max(timeouts)

    return result, len(entries) - len(result)


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


def ensure_rtk_before_cm(
    pretool: list, *, patch_rtk: bool, patch_cm: bool, rtk_hook_command: str
) -> bool:
    rtk_idx = cm_idx = None
    changed = False
    for i, h in enumerate(pretool):
        cmd = hook_cmd(h)
        if cmd.endswith("rtk hook cursor"):
            rtk_idx = i
        elif context_mode_hook_phase(cmd) == "pretooluse":
            cm_idx = i
    if not patch_rtk:
        return False
    if rtk_idx is not None and hook_cmd(pretool[rtk_idx]) != rtk_hook_command:
        pretool[rtk_idx]["command"] = rtk_hook_command
        changed = True
    if rtk_idx is not None and cm_idx is not None and rtk_idx > cm_idx:
        entry_rtk = pretool.pop(rtk_idx)
        pretool.insert(cm_idx, entry_rtk)
        changed = True
    if rtk_idx is None and cm_idx is not None:
        pretool.insert(cm_idx, {"command": rtk_hook_command, "matcher": "Shell"})
        changed = True
    return changed


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

    manifest = ensure_global_instances()
    rtk_hook_command = f"{tool_command(manifest, 'rtk')} hook cursor"

    original = load_json(HOOKS)
    data = json.loads(json.dumps(original))
    hooks = data.setdefault("hooks", {})
    changed = 0

    for event, event_hooks in list(hooks.items()):
        if not isinstance(event_hooks, list):
            continue
        kept = []
        removed = 0
        for item in event_hooks:
            if isinstance(item, dict) and is_legacy_routing_hook(hook_cmd(item)):
                removed += 1
            else:
                kept.append(item)
        if removed:
            hooks[event] = kept
            changed += removed

    for event, event_hooks in list(hooks.items()):
        if not isinstance(event_hooks, list):
            continue
        for item in event_hooks:
            if not isinstance(item, dict):
                continue
            phase = context_mode_hook_phase(hook_cmd(item))
            if phase is None:
                continue
            canonical = canonical_context_mode_hook(manifest, phase)
            if hook_cmd(item) != canonical:
                item["command"] = canonical
                changed += 1

    for event, event_hooks in list(hooks.items()):
        if not isinstance(event_hooks, list):
            continue
        cleaned, removed = deduplicate_hook_entries(event_hooks)
        if removed:
            hooks[event] = cleaned
            changed += removed

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
    # The manifest-backed RTK hook below is the single global shell rewrite
    # owner. The older shell-compression wrapper could invoke RTK a second
    # time (or fall back to LeanCTX rewrite), so it remains deployable for
    # compatibility but must not be wired into Cursor hooks.
    if ensure_rtk_before_cm(
        pt,
        patch_rtk=patch_rtk,
        patch_cm=patch_cm,
        rtk_hook_command=rtk_hook_command,
    ):
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
