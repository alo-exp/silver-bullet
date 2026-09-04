#!/usr/bin/env python3
"""Resolve and persist the one user-global Silver Bullet five-tool profile.

Host adapters have different configuration syntaxes, but they must launch the
same machine-global tool executables.  This small manifest is the source used
by those adapters; it deliberately contains no credentials or project paths.
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import tempfile
from pathlib import Path
from typing import Any


MANIFEST_SCHEMA = "v1"
PROFILE = "five_tool_routed"

TOOL_DEFINITIONS: dict[str, dict[str, Any]] = {
    "graphify": {
        "binary": "graphify-mcp",
        "args": ["--transport", "stdio"],
        "env": {},
    },
    "agentmemory": {
        "binary": "agentmemory",
        "args": ["mcp"],
        "env": {"AGENTMEMORY_URL": "http://localhost:3111"},
    },
    "context_mode": {
        "binary": "context-mode",
        "args": [],
        "env": {},
    },
    "leanctx": {
        "binary": "lean-ctx",
        "args": ["mcp"],
        "env": {},
    },
    "rtk": {
        "binary": "rtk",
        "args": [],
        "env": {},
    },
}

# A prior manifest is trusted only when it still names the expected global
# entrypoint.  This prevents an old host-local plugin path or an `npx` shim
# from becoming the shared executable for every host on the next reconcile.
GLOBAL_ENTRYPOINT_NAMES = {
    "graphify": {"graphify-mcp"},
    "agentmemory": {"agentmemory", "cli.mjs"},
    "context_mode": {"context-mode", "cli.bundle.mjs"},
    "leanctx": {"lean-ctx"},
    "rtk": {"rtk"},
}
HOST_SCOPED_PATH_PARTS = {".claude", ".codex", ".cursor"}


def global_toolstack_home() -> Path:
    configured = os.environ.get("SB_GLOBAL_TOOLSTACK_HOME", "")
    if configured:
        return Path(configured).expanduser()
    return Path.home() / ".silver-bullet" / "five-tool-stack"


def global_instances_manifest_path() -> Path:
    return global_toolstack_home() / "instances.json"


CLAUDE_CONTEXT_MODE_PLUGIN = "context-mode@context-mode"


def claude_native_context_mode_enabled(home: Path | None = None) -> bool:
    """Return whether Claude's optional native Context Mode plugin is enabled."""
    settings = (home or Path.home()) / ".claude" / "settings.json"
    try:
        with settings.open(encoding="utf-8") as handle:
            data = json.load(handle)
    except (OSError, ValueError, TypeError):
        return False
    enabled_plugins = data.get("enabledPlugins") if isinstance(data, dict) else None
    return isinstance(enabled_plugins, dict) and enabled_plugins.get(CLAUDE_CONTEXT_MODE_PLUGIN) is True


def disable_claude_native_context_mode(*, dry_run: bool = False) -> bool:
    """Disable Claude's bundled runtime before the shared MCP entry is added."""
    if not claude_native_context_mode_enabled():
        return False
    if dry_run:
        return True
    claude = shutil.which("claude")
    if not claude:
        raise RuntimeError(
            "Claude Context Mode plugin is enabled but the claude CLI is unavailable"
        )
    result = subprocess.run(
        [claude, "plugin", "disable", CLAUDE_CONTEXT_MODE_PLUGIN, "--scope", "user"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        detail = (result.stderr or "").strip().splitlines()[-1:]
        suffix = f": {detail[0]}" if detail else ""
        raise RuntimeError(f"failed to disable {CLAUDE_CONTEXT_MODE_PLUGIN}{suffix}")
    return True


def _command_override(tool: str) -> str:
    env_name = f"SB_GLOBAL_{tool.upper()}_COMMAND"
    return os.environ.get(env_name, "").strip()


def _absolute_executable(value: str) -> str | None:
    if not value:
        return None
    candidate = Path(value).expanduser()
    if candidate.is_file() and os.access(candidate, os.X_OK):
        return str(candidate.resolve())
    resolved = shutil.which(value)
    if resolved:
        return str(Path(resolved).resolve())
    return None


def _is_global_entrypoint(tool: str, command: str) -> bool:
    path = Path(command)
    if any(part in HOST_SCOPED_PATH_PARTS for part in path.parts):
        return False
    return path.name in GLOBAL_ENTRYPOINT_NAMES[tool]


def _load_manifest(path: Path) -> dict[str, Any]:
    if not path.is_file():
        return {}
    try:
        with path.open(encoding="utf-8") as handle:
            value = json.load(handle)
    except (OSError, ValueError, TypeError):
        return {}
    return value if isinstance(value, dict) else {}


def _prior_command(existing: dict[str, Any], tool: str) -> str:
    tools = existing.get("tools")
    if not isinstance(tools, dict):
        return ""
    value = tools.get(tool)
    if not isinstance(value, dict):
        return ""
    command = value.get("command")
    return command if isinstance(command, str) else ""


def _resolve_command(existing: dict[str, Any], tool: str) -> str:
    definition = TOOL_DEFINITIONS[tool]
    override = _command_override(tool)
    # Preserve a previously selected executable when it is still usable.  This
    # prevents one host's PATH from silently selecting a second installation.
    for candidate in (override, _prior_command(existing, tool), definition["binary"]):
        resolved = _absolute_executable(candidate)
        if resolved and _is_global_entrypoint(tool, resolved):
            return resolved
    # Keep partial installs repairable: the host reports the missing binary
    # while the manifest remains deterministic and can be completed later.
    for candidate in (override, _prior_command(existing, tool), definition["binary"]):
        if candidate and _is_global_entrypoint(tool, candidate):
            return candidate
    return definition["binary"]


def _manifest_payload(existing: dict[str, Any]) -> dict[str, Any]:
    tools: dict[str, Any] = {}
    for tool, definition in TOOL_DEFINITIONS.items():
        spec: dict[str, Any] = {
            "command": _resolve_command(existing, tool),
            "args": list(definition["args"]),
        }
        if definition["env"]:
            spec["env"] = dict(definition["env"])
        tools[tool] = spec
    return {
        "schema": MANIFEST_SCHEMA,
        "scope": "user-global",
        "profile": PROFILE,
        "tools": tools,
    }


def _atomic_write(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    try:
        path.parent.chmod(0o700)
    except OSError:
        pass
    encoded = json.dumps(payload, indent=2) + "\n"
    with tempfile.NamedTemporaryFile(
        mode="w",
        encoding="utf-8",
        dir=path.parent,
        prefix=".instances-",
        delete=False,
    ) as handle:
        handle.write(encoded)
        temporary = Path(handle.name)
    try:
        temporary.chmod(0o600)
    except OSError:
        pass
    temporary.replace(path)


def ensure_global_instances(*, dry_run: bool = False) -> dict[str, Any]:
    """Return the canonical global profile and persist it unless dry-running."""
    path = global_instances_manifest_path()
    existing = _load_manifest(path)
    payload = _manifest_payload(existing)
    if not dry_run and existing != payload:
        _atomic_write(path, payload)
    return payload


def tool_spec(manifest: dict[str, Any], tool: str) -> dict[str, Any]:
    tools = manifest.get("tools")
    spec = tools.get(tool) if isinstance(tools, dict) else None
    if not isinstance(spec, dict):
        raise KeyError(f"missing global five-tool spec: {tool}")
    return {
        "command": str(spec["command"]),
        "args": list(spec.get("args", [])),
        **({"env": dict(spec["env"])} if isinstance(spec.get("env"), dict) else {}),
    }


def tool_command(manifest: dict[str, Any], tool: str) -> str:
    return tool_spec(manifest, tool)["command"]


def mcp_server_spec(manifest: dict[str, Any], tool: str) -> dict[str, Any]:
    return tool_spec(manifest, tool)
