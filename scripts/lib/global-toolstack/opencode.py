#!/usr/bin/env python3
"""OpenCode-specific projection of the shared five-tool manifest."""
from __future__ import annotations

from pathlib import Path
from typing import Any
from urllib.parse import unquote, urlparse

from five_tool_instances import mcp_server_spec


CONTEXT_MODE_PLUGIN_NAME = "context-mode"
CONTEXT_MODE_PLUGIN_ENTRY = "build/adapters/opencode/plugin.js"


def opencode_server_config(
    manifest: dict[str, Any],
    tool: str,
    *,
    environment: dict[str, str] | None = None,
) -> dict[str, Any]:
    """Return the canonical OpenCode local-MCP shape for one global tool."""
    spec = mcp_server_spec(manifest, tool)
    env = dict(spec.get("env", {})) if environment is None else dict(environment)
    config: dict[str, Any] = {
        "type": "local",
        "command": [spec["command"], *spec.get("args", [])],
        "enabled": True,
    }
    if env:
        config["environment"] = env
    return config


def opencode_upsert_server(
    servers: dict[str, Any],
    name: str,
    config: dict[str, Any],
    *,
    aliases: tuple[str, ...] = (),
    allow_add: bool = True,
) -> bool:
    """Canonicalize one server and remove legacy aliases idempotently."""
    existing = servers.get(name)
    if not isinstance(existing, dict):
        for alias in aliases:
            candidate = servers.get(alias)
            if isinstance(candidate, dict):
                existing = candidate
                break

    changed = False
    for alias in aliases:
        if alias in servers:
            del servers[alias]
            changed = True

    if not isinstance(existing, dict):
        if not allow_add:
            return changed
        servers[name] = dict(config)
        return True

    normalized = dict(existing)
    for key in ("type", "command", "enabled"):
        if normalized.get(key) != config.get(key):
            normalized[key] = config[key]
            changed = True

    desired_env = config.get("environment")
    if desired_env:
        if normalized.get("environment") != desired_env:
            normalized["environment"] = dict(desired_env)
            changed = True
        if "env" in normalized:
            del normalized["env"]
            changed = True
    else:
        for key in ("environment", "env"):
            if key in normalized:
                del normalized[key]
                changed = True

    if servers.get(name) != normalized:
        servers[name] = normalized
        changed = True
    return changed


def opencode_existing_server_present(
    servers: dict[str, Any], name: str, aliases: tuple[str, ...] = ()
) -> bool:
    return isinstance(servers.get(name), dict) or any(
        isinstance(servers.get(alias), dict) for alias in aliases
    )


def opencode_context_mode_plugin_present(config: dict[str, Any]) -> bool:
    """Return whether OpenCode's native Context Mode plugin is registered."""
    plugins = config.get("plugin")
    return isinstance(plugins, list) and any(
        opencode_is_context_mode_plugin(entry) for entry in plugins
    )


def opencode_is_context_mode_plugin(entry: Any) -> bool:
    """Recognize npm and absolute-file Context Mode plugin references."""
    if not isinstance(entry, str):
        return False
    if entry == CONTEXT_MODE_PLUGIN_NAME or entry.startswith(f"{CONTEXT_MODE_PLUGIN_NAME}@"):
        return True
    path = unquote(urlparse(entry).path if entry.startswith("file:") else entry)
    return path.endswith(f"/{CONTEXT_MODE_PLUGIN_ENTRY}")


def opencode_context_mode_plugin_spec(manifest: dict[str, Any]) -> str:
    """Return a plugin reference that loads the manifest's global package.

    OpenCode resolves a bare npm plugin name from its own cache.  When the
    manifest contains the normal absolute global CLI path, point OpenCode at
    that package's plugin entry instead so every host uses the same install.
    The bare name remains a compatibility fallback for partial/test installs.
    """
    command = mcp_server_spec(manifest, "context_mode")["command"]
    candidate = Path(command).expanduser().parent / CONTEXT_MODE_PLUGIN_ENTRY
    if Path(command).is_absolute() and candidate.is_file():
        return candidate.resolve().as_uri()
    return CONTEXT_MODE_PLUGIN_NAME


def opencode_ensure_context_mode_plugin(
    plugins: list[Any], manifest: dict[str, Any], *, allow_add: bool = True
) -> bool:
    """Keep exactly one Context Mode plugin, backed by the shared manifest."""
    desired = opencode_context_mode_plugin_spec(manifest)
    matches = [
        index for index, entry in enumerate(plugins) if opencode_is_context_mode_plugin(entry)
    ]
    if not matches:
        if not allow_add:
            return False
        plugins.append(desired)
        return True

    changed = False
    first = matches[0]
    if plugins[first] != desired:
        plugins[first] = desired
        changed = True
    for index in reversed(matches[1:]):
        del plugins[index]
        changed = True
    return changed


def opencode_remove_context_mode_mcp(servers: dict[str, Any]) -> bool:
    """Remove legacy Context Mode MCP aliases when the native plugin owns CM."""
    changed = False
    for name in ("context-mode", "user-context-mode"):
        if name in servers:
            del servers[name]
            changed = True
    return changed
