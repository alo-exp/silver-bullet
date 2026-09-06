#!/usr/bin/env python3
"""Silver Bullet adapter for the independent five-tool runtime.

The generic package owns the manifest, platform paths, and repair semantics.
This module keeps the historical import surface used by SB host adapters and
provides only the SB-specific Context Mode compatibility operation.
"""
from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any, Dict


_MODULE_DIR = Path(__file__).resolve().parent
_LIB_ROOT = next(
    (
        candidate
        for candidate in (_MODULE_DIR / "lib", _MODULE_DIR.parent)
        if (candidate / "five_tool_runtime").is_dir()
    ),
    _MODULE_DIR.parent,
)
if str(_LIB_ROOT) not in sys.path:
    sys.path.insert(0, str(_LIB_ROOT))

from five_tool_runtime.runtime import (  # noqa: E402
    TOOL_DEFINITIONS,
    canonical_manifest_path,
    ensure_manifest,
    global_toolstack_home as generic_toolstack_home,
    launch_spec,
)


MANIFEST_SCHEMA = "five-tool-stack/v1"
PROFILE = "five_tool_routed"
CLAUDE_CONTEXT_MODE_PLUGIN = "context-mode@context-mode"


def _adapter_environment() -> Dict[str, str]:
    """Translate the old SB override names without leaking them into runtime."""
    environment = dict(os.environ)
    for tool in TOOL_DEFINITIONS:
        legacy_name = "SB_GLOBAL_{}_COMMAND".format(tool.upper())
        generic_name = "FIVE_TOOL_{}_COMMAND".format(tool.upper())
        if environment.get(legacy_name) and not environment.get(generic_name):
            environment[generic_name] = environment[legacy_name]
    return environment


def _legacy_override_home() -> Path | None:
    configured = os.environ.get("SB_GLOBAL_TOOLSTACK_HOME", "").strip()
    return Path(configured).expanduser() if configured else None


def global_toolstack_home() -> Path:
    """Return the explicit legacy override or the generic platform root."""
    override = _legacy_override_home()
    if override:
        return override
    return generic_toolstack_home(_adapter_environment())


def global_instances_manifest_path() -> Path:
    """Return the compatibility path used by old SB adapters when overridden."""
    override = _legacy_override_home()
    if override:
        return override / "instances.json"
    return canonical_manifest_path(_adapter_environment())


def _legacy_manifest_path() -> Path:
    return Path.home() / ".silver-bullet" / "five-tool-stack" / "instances.json"


def claude_native_context_mode_enabled(home: Path | None = None) -> bool:
    """Return whether Claude's optional native Context Mode plugin is enabled."""
    settings = (home or Path.home()) / ".claude" / "settings.json"
    try:
        import json

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
        suffix = ": {}".format(detail[0]) if detail else ""
        raise RuntimeError("failed to disable {}{}".format(CLAUDE_CONTEXT_MODE_PLUGIN, suffix))
    return True


def ensure_global_instances(*, dry_run: bool = False) -> Dict[str, Any]:
    """Reconcile the generic manifest, preserving the historical SB API."""
    override = _legacy_override_home()
    return ensure_manifest(
        manifest_path=global_instances_manifest_path(),
        legacy_manifest_path=None if override else _legacy_manifest_path(),
        env=_adapter_environment(),
        dry_run=dry_run,
    )


def tool_spec(manifest: Dict[str, Any], tool: str) -> Dict[str, Any]:
    return launch_spec(manifest, tool)


def tool_command(manifest: Dict[str, Any], tool: str) -> str:
    return tool_spec(manifest, tool)["command"]


def mcp_server_spec(manifest: Dict[str, Any], tool: str) -> Dict[str, Any]:
    return tool_spec(manifest, tool)
