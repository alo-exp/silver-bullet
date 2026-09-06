#!/usr/bin/env python3
"""Atomic in-memory merge for host MCP config — Graphify + LeanCTX five-tool profile.

Preserves unrelated MCP servers. Requires the global Graphify MCP stdio handshake
before adding a missing Graphify server entry.
"""
from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parent))

from five_tool_instances import (  # noqa: E402
    disable_claude_native_context_mode,
    ensure_global_instances,
    mcp_server_spec,
    tool_command,
)
from opencode import (  # noqa: E402
    opencode_context_mode_plugin_present,
    opencode_ensure_context_mode_plugin,
    opencode_existing_server_present,
    opencode_remove_context_mode_mcp,
    opencode_server_config,
    opencode_upsert_server,
)

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


def graphify_mcp_installed(manifest: dict[str, Any]) -> bool:
    command = tool_command(manifest, "graphify")
    return Path(command).is_file() or shutil.which(command) is not None


def graphify_mcp_handshake(manifest: dict[str, Any]) -> tuple[bool, str | None]:
    if not graphify_mcp_installed(manifest):
        return False, "graphify-mcp not installed"
    spec = mcp_server_spec(manifest, "graphify")
    try:
        proc = subprocess.run(
            [spec["command"], *spec["args"]],
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


def merge_agentmemory(servers: dict[str, Any], manifest: dict[str, Any]) -> bool:
    desired = mcp_server_spec(manifest, "agentmemory")
    # Prefer the canonical name for new entries, while preserving the legacy
    # user-agentmemory alias when an existing host config already uses it.
    server_name = (
        "user-agentmemory"
        if "user-agentmemory" in servers and "agentmemory" not in servers
        else "agentmemory"
    )
    existing = servers.get(server_name)
    if not isinstance(existing, dict):
        servers[server_name] = desired
        return True
    changed = False
    for key in ("command", "args"):
        if existing.get(key) != desired[key]:
            existing[key] = desired[key]
            changed = True
    env = dict(existing.get("env", {})) if isinstance(existing.get("env"), dict) else {}
    for key, value in desired.get("env", {}).items():
        if env.get(key) != value:
            env[key] = value
            changed = True
    if env and existing.get("env") != env:
        existing["env"] = env
        changed = True
    servers[server_name] = existing
    return changed


def merge_graphify(
    servers: dict[str, Any], *, manifest: dict[str, Any], require_handshake: bool
) -> bool:
    desired = mcp_server_spec(manifest, "graphify")
    existing = servers.get("graphify")
    if isinstance(existing, dict):
        changed = False
        for key in ("command", "args"):
            if existing.get(key) != desired[key]:
                existing[key] = desired[key]
                changed = True
        servers["graphify"] = existing
        return changed
    if require_handshake:
        ok, reason = graphify_mcp_handshake(manifest)
        if not ok:
            if reason:
                print(f"WARN: graphify merge skipped: {reason}", file=sys.stderr)
            return False
    servers["graphify"] = desired
    return True


def context_mode_present(servers: dict[str, Any]) -> bool:
    return "context-mode" in servers or "user-context-mode" in servers


def merge_leanctx(servers: dict[str, Any], manifest: dict[str, Any]) -> bool:
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
        lean = mcp_server_spec(manifest, "leanctx")
        servers["leanctx"] = lean
        changed = True
    else:
        desired = mcp_server_spec(manifest, "leanctx")
        for key in ("command", "args"):
            if lean.get(key) != desired[key]:
                lean[key] = desired[key]
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


def normalize_context_mode(servers: dict[str, Any], manifest: dict[str, Any]) -> bool:
    """Normalize Context Mode to one canonical shared MCP entry."""
    desired = mcp_server_spec(manifest, "context_mode")
    changed = False
    existing = servers.get("context-mode")
    legacy = servers.get("user-context-mode")
    if not isinstance(existing, dict) and isinstance(legacy, dict):
        existing = legacy
        servers["context-mode"] = existing
        changed = True
    if "user-context-mode" in servers:
        del servers["user-context-mode"]
        changed = True
    if not isinstance(existing, dict):
        return changed
    for key in ("command", "args"):
        if existing.get(key) != desired[key]:
            existing[key] = desired[key]
            changed = True
    servers["context-mode"] = existing
    return changed


def ensure_context_mode(
    servers: dict[str, Any], manifest: dict[str, Any], *, allow_add: bool
) -> bool:
    """Normalize Context Mode or add its shared MCP entry when consented."""
    if context_mode_present(servers):
        changed = normalize_context_mode(servers, manifest)
        if "context-mode" in servers or not allow_add:
            return changed
    if not allow_add:
        return False
    servers["context-mode"] = mcp_server_spec(manifest, "context_mode")
    return True


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


def merge_opencode_mcp(
    path: Path,
    *,
    patch_graphify: bool,
    patch_leanctx: bool,
    patch_agentmemory: bool,
    patch_context_mode: bool,
    manifest: dict[str, Any],
) -> tuple[bool, str]:
    """Project shared MCP tools while leaving Context Mode to its native plugin."""
    original = load_json(path)
    data = json.loads(json.dumps(original))
    mcp = data.setdefault("mcp", {})
    if not isinstance(mcp, dict):
        mcp = {}
        data["mcp"] = mcp

    changed = False
    plugins = data.get("plugin")
    if patch_context_mode:
        if not isinstance(plugins, list):
            plugins = []
            data["plugin"] = plugins
    if isinstance(plugins, list):
        # Canonicalize an already-enabled plugin even when this invocation is
        # repairing another tool; never add Context Mode without its consent.
        changed = opencode_ensure_context_mode_plugin(
            plugins, manifest, allow_add=patch_context_mode
        ) or changed
    cm_plugin_active = opencode_context_mode_plugin_present(data)
    if cm_plugin_active:
        # OpenCode's native plugin registers CM in-process.  Keeping a legacy
        # mcp.context-mode entry alongside it makes OpenCode suppress all
        # ctx_* tools, so the plugin is the sole Context Mode owner.
        changed = opencode_remove_context_mode_mcp(mcp) or changed
    cm_active = cm_plugin_active or opencode_existing_server_present(
        mcp, "context-mode", ("user-context-mode",)
    )

    if patch_graphify:
        if opencode_existing_server_present(mcp, "graphify"):
            changed = opencode_upsert_server(
                mcp,
                "graphify",
                opencode_server_config(manifest, "graphify"),
            ) or changed
        else:
            ok, reason = graphify_mcp_handshake(manifest)
            if not ok:
                if reason:
                    print(f"WARN: graphify merge skipped: {reason}", file=sys.stderr)
            else:
                changed = opencode_upsert_server(
                    mcp,
                    "graphify",
                    opencode_server_config(manifest, "graphify"),
                ) or changed

    if patch_agentmemory:
        changed = opencode_upsert_server(
            mcp,
            "agentmemory",
            opencode_server_config(manifest, "agentmemory"),
            aliases=("user-agentmemory",),
        ) or changed

    if patch_context_mode and not cm_plugin_active:
        changed = opencode_upsert_server(
            mcp,
            "context-mode",
            opencode_server_config(manifest, "context_mode"),
            aliases=("user-context-mode",),
        ) or changed

    if patch_leanctx:
        lean_env = LEANCTX_ENV_CM_ACTIVE if cm_active else LEANCTX_ENV_BASE
        changed = opencode_upsert_server(
            mcp,
            "leanctx",
            opencode_server_config(
                manifest,
                "leanctx",
                environment=lean_env,
            ),
            aliases=("lean-ctx", "lean-ctx-standalone", "user-leanctx", "user-lean-ctx"),
        ) or changed

    if normalize_mcp_config(data) == normalize_mcp_config(original):
        return False, "OK: opencode.json unchanged (idempotent)"
    atomic_write_json(path, data)
    return True, "OK: opencode.json merged atomically"


def install_pi_adapter(
    repo_root: Path,
    *,
    dry_run: bool,
    enabled_tools: set[str],
) -> tuple[bool, str]:
    """Install the native Pi adapter without importing a hyphenated filename."""
    import importlib.util

    installer_path = Path(__file__).resolve().parent / "install-pi.py"
    spec = importlib.util.spec_from_file_location("silver_bullet_install_pi", installer_path)
    if spec is None or spec.loader is None:
        return False, "ERROR: unable to load Pi adapter installer"
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    result = module.install(repo_root, dry_run, enabled_tools)
    return True, "OK: Pi five-tool adapter installed (" + ",".join(sorted(enabled_tools)) + ")"


def codex_mcp_block(
    server: str, *, cm_active: bool, manifest: dict[str, Any]
) -> str:
    spec = mcp_server_spec(manifest, server if server != "context-mode" else "context_mode")
    if server == "graphify":
        return (
            "[mcp_servers.graphify]\n"
            f"command = {json.dumps(spec['command'])}\n"
            f"args = {json.dumps(spec['args'])}\n"
        )
    if server == "agentmemory":
        return (
            '[mcp_servers.agentmemory]\n'
            f"command = {json.dumps(spec['command'])}\n"
            f"args = {json.dumps(spec['args'])}\n\n"
            '[mcp_servers.agentmemory.env]\n'
            f"AGENTMEMORY_URL = {json.dumps(spec['env']['AGENTMEMORY_URL'])}\n"
        )
    if server == "context-mode":
        return (
            '[mcp_servers.context-mode]\n'
            f"command = {json.dumps(spec['command'])}\n"
            f"args = {json.dumps(spec['args'])}\n"
        )
    env = LEANCTX_ENV_CM_ACTIVE if cm_active else LEANCTX_ENV_BASE
    env_lines = "\n".join(f'{key} = "{value}"' for key, value in env.items())
    return (
        '[mcp_servers.leanctx]\n'
        f"command = {json.dumps(spec['command'])}\n"
        f"args = {json.dumps(spec['args'])}\n\n"
        '[mcp_servers.leanctx.env]\n'
        f'{env_lines}\n'
    )


def _toml_section_bounds(text: str, header: str) -> tuple[int, int] | None:
    match = re.search(rf"(?m)^{re.escape(header)}\s*$", text)
    if not match:
        return None
    next_header = re.search(r"(?m)^\[", text[match.end() :])
    end = match.end() + (next_header.start() if next_header else len(text[match.end() :]))
    return match.start(), end


def _toml_set_root_keys(body: str, command: str, args: list[str]) -> str:
    values = {
        "command": f"command = {json.dumps(command)}",
        "args": f"args = {json.dumps(args)}",
    }
    for key, line in values.items():
        pattern = rf"(?m)^{re.escape(key)}\s*=.*$"
        if re.search(pattern, body):
            body = re.sub(pattern, line, body, count=1)
        else:
            body = f"{line}\n" + body
    return body


def _toml_set_env(text: str, server: str, env: dict[str, str]) -> str:
    header = f"[mcp_servers.{server}.env]"
    bounds = _toml_section_bounds(text, header)
    if bounds is None:
        if text and not text.endswith("\n"):
            text += "\n"
        if text:
            text += "\n"
        text += header + "\n"
        text += "\n".join(f"{key} = {json.dumps(value)}" for key, value in env.items())
        text += "\n"
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


def _toml_normalize_server(
    text: str, server: str, *, manifest: dict[str, Any], cm_active: bool
) -> str:
    spec_name = server if server != "context-mode" else "context_mode"
    spec = mcp_server_spec(manifest, spec_name)
    header = f"[mcp_servers.{server}]"
    bounds = _toml_section_bounds(text, header)
    if bounds is None:
        if text and not text.endswith("\n"):
            text += "\n"
        if text:
            text += "\n"
        text += codex_mcp_block(server, cm_active=cm_active, manifest=manifest)
    else:
        start, end = bounds
        header_end = text.find("\n", start, end)
        if header_end < 0:
            header_end = end
        body = text[header_end + 1 : end]
        body = _toml_set_root_keys(body, spec["command"], spec["args"])
        text = text[: header_end + 1] + body + text[end:]
    if spec.get("env"):
        text = _toml_set_env(text, server, spec["env"])
    return text


def merge_codex_mcp(path: Path, *, patch_graphify: bool, patch_leanctx: bool,
                    patch_agentmemory: bool, patch_context_mode: bool,
                    manifest: dict[str, Any]) -> tuple[bool, str]:
    original = path.read_text(encoding="utf-8") if path.is_file() else ""
    cm_active = patch_context_mode or "[mcp_servers.context-mode]" in original
    text = original
    changed = False
    text = re.sub(
        r"(?ms)^\[mcp_servers\.lean-ctx(?:\.env)?\]\n.*?(?=^\[|\Z)",
        "",
        text,
    )
    changed = text != original
    for server, enabled in (
        ("graphify", patch_graphify),
        ("leanctx", patch_leanctx),
        ("agentmemory", patch_agentmemory),
    ):
        if not enabled:
            continue
        updated = _toml_normalize_server(
            text, server, manifest=manifest, cm_active=cm_active
        )
        changed = changed or updated != text
        text = updated
    if patch_context_mode or "[mcp_servers.context-mode]" in text:
        updated = _toml_normalize_server(
            text, "context-mode", manifest=manifest, cm_active=cm_active
        )
        changed = changed or updated != text
        text = updated
    if not changed:
        return False, "OK: config.toml unchanged (idempotent)"
    atomic_write_text(path, text)
    return True, "OK: config.toml merged atomically"


def atomic_write_text(path: Path, payload: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(
        mode="w", encoding="utf-8", dir=path.parent, delete=False, prefix=".mcp-merge."
    ) as tmp:
        tmp.write(payload)
        tmp_path = Path(tmp.name)
    tmp_path.replace(path)


def main() -> int:
    patch_graphify = os.environ.get("RT_PATCH_GRAPHIFY", "0") == "1"
    patch_leanctx = os.environ.get("RT_PATCH_LEANCTX", "0") == "1"
    patch_agentmemory = os.environ.get("RT_PATCH_AGENTMEMORY", "0") == "1"
    patch_context_mode = os.environ.get("RT_PATCH_CONTEXT_MODE", "0") == "1"
    if not patch_graphify and not patch_leanctx and not patch_agentmemory and not patch_context_mode:
        print("OK: mcp.json unchanged (no patch flags)")
        return 0

    manifest = ensure_global_instances()

    host = os.environ.get("RT_HOST", "cursor")
    if host == "claude" and patch_context_mode:
        try:
            disable_claude_native_context_mode()
        except RuntimeError as exc:
            print(f"ERROR: {exc}", file=sys.stderr)
            return 2
    if host == "codex":
        _, message = merge_codex_mcp(
            Path(os.environ.get("CODEX_HOME", str(Path.home() / ".codex"))) / "config.toml",
            patch_graphify=patch_graphify,
            patch_leanctx=patch_leanctx,
            patch_agentmemory=patch_agentmemory,
            patch_context_mode=patch_context_mode,
            manifest=manifest,
        )
        print(message)
        return 0

    if host == "opencode":
        _, message = merge_opencode_mcp(
            Path.home() / ".config" / "opencode" / "opencode.json",
            patch_graphify=patch_graphify,
            patch_leanctx=patch_leanctx,
            patch_agentmemory=patch_agentmemory,
            patch_context_mode=patch_context_mode,
            manifest=manifest,
        )
        print(message)
        return 0

    if host == "pi":
        enabled = {
            tool
            for tool, selected in (
                ("graphify", patch_graphify),
                ("agentmemory", patch_agentmemory),
                ("context_mode", patch_context_mode),
                ("leanctx", patch_leanctx),
            )
            if selected
        }
        ok, message = install_pi_adapter(
            Path(os.environ.get("TOOLSTACK_REPO_ROOT", Path.cwd())),
            dry_run=False,
            enabled_tools=enabled,
        )
        if not ok:
            print(message, file=sys.stderr)
            return 2
        print(message)
        return 0

    mcp_path = Path.home() / (".claude.json" if host == "claude" else ".cursor/mcp.json")
    original = load_json(mcp_path)
    original_normalized = normalize_mcp_config(original)
    data = json.loads(json.dumps(original))
    servers = data.setdefault("mcpServers", {})
    added_graphify = False
    leanctx_changed = False
    added_agentmemory = False
    if patch_context_mode:
        ensure_context_mode(servers, manifest, allow_add=True)
    if patch_graphify:
        added_graphify = merge_graphify(
            servers, manifest=manifest, require_handshake=True
        )
    if patch_leanctx:
        leanctx_changed = merge_leanctx(servers, manifest)
    if patch_agentmemory:
        added_agentmemory = merge_agentmemory(servers, manifest)
    normalize_context_mode(servers, manifest)

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
