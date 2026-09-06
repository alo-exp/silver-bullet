"""Host-neutral manifest, path, and repair primitives for five global tools.

The module is deliberately self-contained: it uses only the Python standard
library and does not import, invoke, or inspect any host plugin or workflow
framework.  Host adapters own their configuration files and call these
primitives for the shared executable contract.
"""
from __future__ import annotations

import json
import os
import shutil
import stat
import sys
import tempfile
from pathlib import Path
from typing import Any, Dict, Iterable, Mapping, Optional, Sequence, Tuple


MANIFEST_SCHEMA = "five-tool-stack/v1"
MANIFEST_FILENAME = "manifest.json"

TOOL_DEFINITIONS: Dict[str, Dict[str, Any]] = {
    "graphify": {
        "package": "graphify",
        "executable": "graphify-mcp",
        "args": ["--transport", "stdio"],
        "env": {},
        "transport": "stdio",
        "capabilities": ["structural-context", "mcp"],
    },
    "agentmemory": {
        "package": "agentmemory",
        "executable": "agentmemory",
        "args": ["mcp"],
        "env": {"AGENTMEMORY_URL": "http://localhost:3111"},
        "transport": "stdio",
        "capabilities": ["durable-memory", "mcp"],
    },
    "context_mode": {
        "package": "context-mode",
        "executable": "context-mode",
        "args": [],
        "env": {},
        "transport": "stdio",
        "capabilities": ["context-routing", "compression", "mcp"],
    },
    "leanctx": {
        "package": "lean-ctx",
        "executable": "lean-ctx",
        "args": ["mcp"],
        "env": {},
        "transport": "stdio",
        "capabilities": ["context-routing", "compression", "mcp"],
    },
    "rtk": {
        "package": "rtk",
        "executable": "rtk",
        "args": [],
        "env": {},
        "transport": "shell-rewrite",
        "capabilities": ["shell-rewrite"],
    },
}

HOST_PROJECTIONS: Dict[str, Dict[str, Any]] = {
    "claude": {"kind": "mcp", "config": "user", "native_context_mode": False},
    "codex": {"kind": "mcp", "config": "user", "native_context_mode": False},
    "cursor": {"kind": "mcp-and-hooks", "config": "user", "native_context_mode": False},
    "opencode": {"kind": "mcp-or-plugin", "config": "user", "native_context_mode": True},
    "pi": {"kind": "extension", "config": "agent", "native_context_mode": True},
}

COORDINATION_RULES: Dict[str, Any] = {
    "one_global_instance_per_tool": True,
    "rtk_rewrite": "single",
    "context_mode": {"native_plugin_mutually_exclusive_with_mcp": True},
    "aliases_are_compatibility_only": True,
}

_EXTRA_LAUNCHER_SUFFIXES = (".exe", ".cmd", ".ps1", ".bat", ".mjs", "")
_HOST_SCOPED_PARTS = {".claude", ".codex", ".cursor", ".pi"}
_HOST_SCOPED_MARKERS = ("/.config/opencode/", "/.config/opencode")


def _env_value(env: Mapping[str, str], name: str) -> str:
    value = env.get(name, "")
    return value if isinstance(value, str) else ""


def global_toolstack_home(
    env: Optional[Mapping[str, str]] = None,
    home: Optional[Path] = None,
    platform_name: Optional[str] = None,
) -> Path:
    """Return the platform-standard data root for the generic runtime."""
    environ = os.environ if env is None else env
    override = _env_value(environ, "FIVE_TOOL_STACK_HOME").strip()
    if override:
        return Path(override).expanduser()

    system = (platform_name or sys.platform).lower()
    home_path = Path(home or Path.home()).expanduser()
    if system.startswith(("win", "msys", "cygwin")):
        local = _env_value(environ, "LOCALAPPDATA")
        roaming = _env_value(environ, "APPDATA")
        return Path(local or roaming or home_path / "AppData" / "Local") / "five-tool-stack"

    state = _env_value(environ, "XDG_STATE_HOME")
    if state:
        return Path(state).expanduser() / "five-tool-stack"
    data = _env_value(environ, "XDG_DATA_HOME")
    if data:
        return Path(data).expanduser() / "five-tool-stack"
    return home_path / ".local" / "state" / "five-tool-stack"


def canonical_manifest_path(
    env: Optional[Mapping[str, str]] = None,
    home: Optional[Path] = None,
    platform_name: Optional[str] = None,
) -> Path:
    return global_toolstack_home(env, home, platform_name) / MANIFEST_FILENAME


def _read_json(path: Path) -> Dict[str, Any]:
    try:
        with path.open("r", encoding="utf-8", newline="") as handle:
            value = json.load(handle)
    except (OSError, ValueError, TypeError):
        return {}
    return value if isinstance(value, dict) else {}


def load_manifest(path: Path) -> Dict[str, Any]:
    """Load a manifest, returning an empty object for absent/malformed input."""
    return _read_json(Path(path))


def _path_is_host_scoped(value: str) -> bool:
    normalized = value.replace("\\", "/").lower()
    parts = {part.lower() for part in Path(normalized).parts}
    if parts.intersection(_HOST_SCOPED_PARTS):
        return True
    return any(marker in normalized for marker in _HOST_SCOPED_MARKERS)


def _entrypoint_name(value: str) -> str:
    name = Path(value.replace("\\", "/")).name.lower()
    for suffix in _EXTRA_LAUNCHER_SUFFIXES[:-1]:
        if name.endswith(suffix):
            return name[: -len(suffix)]
    return name


def _expected_entrypoint(tool: str, value: str) -> bool:
    definition = TOOL_DEFINITIONS.get(tool)
    if not definition or not value or _path_is_host_scoped(value):
        return False
    expected = str(definition["executable"]).lower()
    actual = _entrypoint_name(value)
    aliases = {
        "agentmemory": {"cli"},
        "context_mode": {"cli.bundle"},
    }
    return actual == expected or actual in aliases.get(tool, set())


def _resolve_candidate(value: str) -> Optional[str]:
    if not value:
        return None
    candidate = Path(value).expanduser()
    if candidate.is_file() and os.access(candidate, os.X_OK):
        return str(candidate.resolve())
    resolved = shutil.which(value)
    if resolved:
        return str(Path(resolved).resolve())
    return None


def _command_override(tool: str, env: Mapping[str, str]) -> str:
    name = "FIVE_TOOL_{}_COMMAND".format(tool.upper())
    return _env_value(env, name).strip()


def _legacy_tool_entry(legacy: Mapping[str, Any], tool: str) -> Dict[str, Any]:
    tools = legacy.get("tools")
    value = tools.get(tool) if isinstance(tools, dict) else None
    return dict(value) if isinstance(value, dict) else {}


def _source_manifest(
    manifest_path: Path,
    legacy_manifest_path: Optional[Path],
) -> Tuple[Dict[str, Any], Optional[str]]:
    current = _read_json(manifest_path)
    if current:
        return current, None
    if legacy_manifest_path:
        legacy = _read_json(Path(legacy_manifest_path))
        if legacy:
            return legacy, "legacy"
    return {}, None


def _select_command(
    tool: str,
    existing: Mapping[str, Any],
    env: Mapping[str, str],
) -> str:
    definition = TOOL_DEFINITIONS[tool]
    prior = _legacy_tool_entry(existing, tool).get("command")
    candidates = [
        _command_override(tool, env),
        prior if isinstance(prior, str) else "",
        str(definition["executable"]),
    ]
    for candidate in candidates:
        resolved = _resolve_candidate(candidate)
        if resolved and _expected_entrypoint(tool, resolved):
            return resolved
    for candidate in candidates:
        if candidate and _expected_entrypoint(tool, candidate):
            return candidate
    return str(definition["executable"])


def _normalise_tool(
    tool: str,
    existing: Mapping[str, Any],
    env: Mapping[str, str],
    selected_versions: Mapping[str, Any],
) -> Dict[str, Any]:
    definition = TOOL_DEFINITIONS[tool]
    prior = _legacy_tool_entry(existing, tool)
    version = selected_versions.get(tool, prior.get("version"))
    identity = {
        "name": tool,
        "package": str(prior.get("identity", {}).get("package", definition["package"])),
        "executable": str(definition["executable"]),
    }
    item: Dict[str, Any] = {
        "identity": identity,
        "command": _select_command(tool, existing, env),
        "args": list(definition["args"]),
        "env": dict(definition["env"]),
        "transport": definition["transport"],
        "version": version,
        "capabilities": list(definition["capabilities"]),
    }
    prior_env = prior.get("env")
    if isinstance(prior_env, dict):
        merged_env = dict(item["env"])
        merged_env.update({str(key): str(value) for key, value in prior_env.items()})
        item["env"] = merged_env
    return item


def _manifest_payload(
    existing: Mapping[str, Any],
    env: Mapping[str, str],
    selected_versions: Mapping[str, Any],
    migrated_from: Optional[str],
) -> Dict[str, Any]:
    payload: Dict[str, Any] = {
        "schema": MANIFEST_SCHEMA,
        "scope": "user-global",
        "profile": "five_tool_routed",
        "tools": {
            tool: _normalise_tool(tool, existing, env, selected_versions)
            for tool in TOOL_DEFINITIONS
        },
        "hosts": {host: dict(spec) for host, spec in HOST_PROJECTIONS.items()},
        "coordination": dict(COORDINATION_RULES),
    }
    if migrated_from:
        payload["migration"] = {"source": migrated_from, "completed": True}
    return payload


def _atomic_write(path: Path, payload: Mapping[str, Any]) -> None:
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    try:
        target.parent.chmod(stat.S_IRWXU)
    except OSError:
        pass
    encoded = json.dumps(payload, indent=2, ensure_ascii=False) + "\n"
    temporary: Optional[Path] = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w",
            encoding="utf-8",
            newline="\n",
            dir=str(target.parent),
            prefix=".manifest-",
            delete=False,
        ) as handle:
            handle.write(encoded)
            temporary = Path(handle.name)
        try:
            temporary.chmod(stat.S_IRUSR | stat.S_IWUSR)
        except OSError:
            pass
        temporary.replace(target)
    finally:
        if temporary and temporary.exists():
            try:
                temporary.unlink()
            except OSError:
                pass


def validate_manifest(
    manifest: Mapping[str, Any],
    require_commands: bool = False,
    platform_name: Optional[str] = None,
) -> Dict[str, Any]:
    """Return structured diagnostics without mutating the manifest."""
    errors = []  # type: list[str]
    warnings = []  # type: list[str]
    if manifest.get("schema") != MANIFEST_SCHEMA:
        errors.append("schema must be {}".format(MANIFEST_SCHEMA))
    if manifest.get("scope") != "user-global":
        errors.append("scope must be user-global")
    tools = manifest.get("tools")
    if not isinstance(tools, dict):
        errors.append("tools must be an object")
        tools = {}
    for tool, definition in TOOL_DEFINITIONS.items():
        value = tools.get(tool)
        if not isinstance(value, dict):
            errors.append("missing tool: {}".format(tool))
            continue
        command = value.get("command")
        if not isinstance(command, str) or not command:
            errors.append("{} command is missing".format(tool))
        elif not _expected_entrypoint(tool, command):
            errors.append("{} command is not a global entrypoint: {}".format(tool, command))
        elif require_commands and not _resolve_candidate(command):
            errors.append("{} command is unavailable: {}".format(tool, command))
        elif not _resolve_candidate(command):
            warnings.append("{} command is unavailable: {}".format(tool, command))
        if value.get("transport") != definition["transport"]:
            errors.append("{} transport is incorrect".format(tool))
        if not isinstance(value.get("args"), list):
            errors.append("{} args are missing".format(tool))
        if not isinstance(value.get("env"), dict):
            errors.append("{} env is missing".format(tool))
        identity = value.get("identity")
        if not isinstance(identity, dict):
            errors.append("{} identity is missing".format(tool))
        elif identity.get("name") != tool or not identity.get("package"):
            errors.append("{} identity is malformed".format(tool))
        if not isinstance(value.get("capabilities"), list):
            errors.append("{} capabilities are missing".format(tool))
    hosts = manifest.get("hosts")
    if not isinstance(hosts, dict):
        errors.append("hosts are missing")
    else:
        for host in HOST_PROJECTIONS:
            if not isinstance(hosts.get(host), dict):
                errors.append("missing host projection: {}".format(host))
    coordination = manifest.get("coordination")
    if not isinstance(coordination, dict):
        errors.append("coordination rules are missing")
    else:
        if coordination.get("one_global_instance_per_tool") is not True:
            errors.append("one-global-instance rule is missing")
        if coordination.get("rtk_rewrite") != "single":
            errors.append("RTK rewrite rule must be single")
        context_mode = coordination.get("context_mode")
        if not isinstance(context_mode, dict) or context_mode.get("native_plugin_mutually_exclusive_with_mcp") is not True:
            errors.append("Context Mode mutual-exclusion rule is missing")
    return {
        "valid": not errors,
        "errors": errors,
        "warnings": warnings,
        "platform": platform_name or sys.platform,
        "tools": len(tools),
    }


def ensure_manifest(
    manifest_path: Optional[Path] = None,
    legacy_manifest_path: Optional[Path] = None,
    env: Optional[Mapping[str, str]] = None,
    home: Optional[Path] = None,
    platform_name: Optional[str] = None,
    selected_versions: Optional[Mapping[str, Any]] = None,
    dry_run: bool = False,
) -> Dict[str, Any]:
    """Install or reconcile one canonical manifest atomically and idempotently."""
    environ = os.environ if env is None else env
    path = Path(manifest_path) if manifest_path else canonical_manifest_path(environ, home, platform_name)
    existing, migrated_from = _source_manifest(path, legacy_manifest_path)
    payload = _manifest_payload(existing, environ, selected_versions or {}, migrated_from)
    changed = existing != payload or not path.is_file()
    if changed and not dry_run:
        _atomic_write(path, payload)
    payload["_result"] = {
        "path": str(path),
        "changed": changed,
        "migrated": bool(migrated_from),
        "validation": validate_manifest(payload, platform_name=platform_name),
    }
    return payload


def repair_manifest(**kwargs: Any) -> Dict[str, Any]:
    """Repair malformed/partial state using the same idempotent install path."""
    return ensure_manifest(**kwargs)


def inspect_manifest(
    manifest_path: Optional[Path] = None,
    env: Optional[Mapping[str, str]] = None,
    home: Optional[Path] = None,
    platform_name: Optional[str] = None,
) -> Dict[str, Any]:
    path = Path(manifest_path) if manifest_path else canonical_manifest_path(env, home, platform_name)
    value = load_manifest(path)
    result = validate_manifest(value, platform_name=platform_name)
    result.update({"path": str(path), "present": path.is_file(), "manifest": value})
    return result


def launch_spec(manifest: Mapping[str, Any], tool: str) -> Dict[str, Any]:
    """Return a normalized process-launch shape for a host adapter."""
    tools = manifest.get("tools")
    value = tools.get(tool) if isinstance(tools, dict) else None
    if not isinstance(value, dict) or not isinstance(value.get("command"), str):
        raise KeyError("missing tool: {}".format(tool))
    return {
        "command": value["command"],
        "args": list(value.get("args", [])),
        "env": dict(value.get("env", {})) if isinstance(value.get("env"), dict) else {},
        "transport": value.get("transport"),
        "identity": dict(value.get("identity", {})),
        "capabilities": list(value.get("capabilities", [])),
    }


def launch_argv(
    manifest: Mapping[str, Any],
    tool: str,
    platform_name: Optional[str] = None,
) -> list[str]:
    """Return a subprocess-safe argv, including Windows script launchers."""
    spec = launch_spec(manifest, tool)
    command = str(spec["command"])
    args = list(spec["args"])
    system = (platform_name or sys.platform).lower()
    if system.startswith(("win", "msys", "cygwin")):
        suffix = Path(command.replace("\\", "/")).suffix.lower()
        if suffix == ".ps1":
            return [
                "powershell.exe",
                "-NoProfile",
                "-ExecutionPolicy",
                "Bypass",
                "-File",
                command,
                *args,
            ]
        if suffix in (".cmd", ".bat"):
            return ["cmd.exe", "/d", "/c", command, *args]
    return [command, *args]


def merged_environment(
    base: Optional[Mapping[str, str]],
    manifest: Mapping[str, Any],
    tool: str,
) -> Dict[str, str]:
    """Merge a tool's manifest environment over a caller's process environment."""
    result = dict(base or {})
    result.update({str(key): str(value) for key, value in launch_spec(manifest, tool)["env"].items()})
    return result


def duplicate_registration_names(names: Iterable[str]) -> Tuple[str, ...]:
    """Return duplicate registration keys while preserving first-seen order."""
    seen = set()
    duplicates = []
    for name in names:
        if name in seen and name not in duplicates:
            duplicates.append(name)
        seen.add(name)
    return tuple(duplicates)
