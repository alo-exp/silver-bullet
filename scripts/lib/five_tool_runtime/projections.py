"""Pure host-projection builders for the independent five-tool runtime."""
from __future__ import annotations

from pathlib import Path
from typing import Any, Dict, Iterable, Mapping, Optional

from .runtime import HOST_PROJECTIONS, TOOL_DEFINITIONS, duplicate_registration_names, launch_spec


MCP_TOOL_NAMES = ("graphify", "agentmemory", "context_mode", "leanctx")


def _mcp_name(tool: str) -> str:
    return "context-mode" if tool == "context_mode" else tool


def mcp_server_entries(
    manifest: Mapping[str, Any],
    *,
    native_context_mode: bool = False,
) -> Dict[str, Dict[str, Any]]:
    """Build the common MCP server map used by Claude, Codex, and Cursor."""
    entries: Dict[str, Dict[str, Any]] = {}
    for tool in MCP_TOOL_NAMES:
        if tool == "context_mode" and native_context_mode:
            continue
        spec = launch_spec(manifest, tool)
        entry: Dict[str, Any] = {
            "command": spec["command"],
            "args": list(spec["args"]),
        }
        if spec["env"]:
            entry["env"] = dict(spec["env"])
        entries[_mcp_name(tool)] = entry
    return entries


def opencode_plugin_reference(manifest: Mapping[str, Any]) -> Optional[str]:
    """Return the native Context Mode plugin beside its global launcher."""
    command = str(launch_spec(manifest, "context_mode")["command"])
    normalized = command.replace("\\", "/")
    if not normalized.endswith("/cli.bundle.mjs"):
        return None
    package_root = Path(normalized).parent
    return "file://{}".format(package_root / "build" / "adapters" / "opencode" / "plugin.js")


def pi_server_entries(
    manifest: Mapping[str, Any],
    enabled_tools: Optional[Iterable[str]] = None,
) -> Dict[str, Dict[str, Any]]:
    """Build Pi's native extension metadata without taking over its shell."""
    selected = set(enabled_tools) if enabled_tools is not None else set(TOOL_DEFINITIONS)
    entries: Dict[str, Dict[str, Any]] = {}
    for tool in TOOL_DEFINITIONS:
        spec = launch_spec(manifest, tool)
        entries[tool] = {
            "enabled": tool in selected,
            "command": spec["command"],
            "args": list(spec["args"]),
            "transport": spec["transport"],
        }
    # RTK is the one shell rewrite owner; its native Pi extension route is
    # represented but disabled so a second rewrite layer cannot be registered.
    entries["rtk"]["enabled"] = False
    return entries


def project_host(
    manifest: Mapping[str, Any],
    host: str,
    *,
    enabled_tools: Optional[Iterable[str]] = None,
) -> Dict[str, Any]:
    """Return a deterministic, host-neutral projection description."""
    if host not in HOST_PROJECTIONS:
        raise ValueError("unsupported host: {}".format(host))
    native = bool(HOST_PROJECTIONS[host]["native_context_mode"])
    projection: Dict[str, Any] = {
        "host": host,
        "kind": HOST_PROJECTIONS[host]["kind"],
        "mcpServers": mcp_server_entries(manifest, native_context_mode=native),
        "rules": {
            "rtkRewriteOwner": "rtk",
            "contextModeNative": native,
            "contextModeMcpPresent": "context-mode" in mcp_server_entries(
                manifest, native_context_mode=native
            ),
        },
    }
    if host == "opencode":
        plugin = opencode_plugin_reference(manifest)
        projection["plugin"] = [plugin] if plugin else []
    elif host == "pi":
        projection["servers"] = pi_server_entries(manifest, enabled_tools)
    return projection


def validate_projection(projection: Mapping[str, Any]) -> Dict[str, Any]:
    """Validate duplicate and Context Mode invariants in a projection."""
    names = list((projection.get("mcpServers") or {}).keys())
    duplicates = duplicate_registration_names(names)
    errors = []  # type: list[str]
    if duplicates:
        errors.append("duplicate MCP registrations: {}".format(", ".join(duplicates)))
    rules = projection.get("rules")
    if isinstance(rules, dict) and rules.get("contextModeNative") and rules.get("contextModeMcpPresent"):
        errors.append("native Context Mode and MCP Context Mode both enabled")
    if isinstance(rules, dict) and rules.get("rtkRewriteOwner") != "rtk":
        errors.append("RTK rewrite owner is not rtk")
    return {"valid": not errors, "errors": errors}
