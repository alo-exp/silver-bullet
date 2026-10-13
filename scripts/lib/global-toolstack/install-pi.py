#!/usr/bin/env python3
"""Install the Silver Bullet five-tool adapter into Pi's global agent dir."""
from __future__ import annotations

import argparse
import json
import os
import shutil
import tempfile
from pathlib import Path
from typing import Any

import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))

from five_tool_instances import ensure_global_instances, global_instances_manifest_path  # noqa: E402


LEANCTX_ENV = {
    "LEANCTX_MCP_TOOL_PREFIX": "lctx_",
    "LEANCTX_DISABLE_SHELL_MCP": "1",
    "LEANCTX_DISABLE_SANDBOX_MCP": "1",
    "LEANCTX_DISABLE_FETCH_MCP": "1",
    "LEANCTX_DISABLE_FTS": "1",
    "LEANCTX_PRIMARY_FTS": "context_mode",
}


def write_json(path: Path, data: dict[str, Any], dry_run: bool) -> None:
    if dry_run:
        print(f"DRY-RUN: would write {path}")
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    encoded = json.dumps(data, indent=2) + "\n"
    with tempfile.NamedTemporaryFile(
        mode="w", encoding="utf-8", dir=path.parent, prefix=".sb-pi-", delete=False
    ) as handle:
        handle.write(encoded)
        temporary = Path(handle.name)
    temporary.chmod(0o600)
    temporary.replace(path)


def load_json(path: Path) -> dict[str, Any]:
    if not path.is_file():
        return {}
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError, TypeError):
        return {}
    return value if isinstance(value, dict) else {}


def add_unique(items: list[Any], value: str) -> bool:
    if value in items:
        return False
    items.append(value)
    return True


def update_pi_leanctx_config(
    path: Path, manifest: dict[str, Any], dry_run: bool
) -> bool:
    data = load_json(path)
    data["mode"] = "additive"
    # Pi's native bash must remain visible so the SB adapter can hand it to
    # RTK; pi-lean-ctx's ctx_shell would otherwise become a second shell owner.
    data["routeShell"] = False
    data["enableMcp"] = True
    data["binary"] = str(manifest["tools"]["leanctx"]["command"])
    env = dict(data.get("env", {})) if isinstance(data.get("env"), dict) else {}
    env.update(LEANCTX_ENV)
    data["env"] = env
    disabled = list(data.get("disableTools", [])) if isinstance(data.get("disableTools"), list) else []
    add_unique(disabled, "ctx_shell")
    data["disableTools"] = disabled
    data.setdefault("toolPrefix", "lctx_")
    if not path.is_file() or load_json(path) != data:
        write_json(path, data, dry_run)
        return True
    return False


def install(
    repo_root: Path,
    dry_run: bool,
    enabled_tools: set[str] | None = None,
) -> dict[str, Any]:
    manifest = ensure_global_instances(dry_run=dry_run)
    manifest_path = global_instances_manifest_path()
    agent_dir = Path(os.environ.get("PI_CODING_AGENT_DIR", Path.home() / ".pi" / "agent")).expanduser()
    extension_dir = agent_dir / "extensions" / "silver-bullet-five-tool-stack"
    source = Path(__file__).resolve().parent / "pi-five-tool-stack.ts"
    target = extension_dir / "index.ts"
    if not source.is_file():
        raise RuntimeError(f"Pi adapter source missing: {source}")
    if dry_run:
        print(f"DRY-RUN: would copy {source} -> {target}")
    else:
        extension_dir.mkdir(parents=True, exist_ok=True)
        if not target.is_file() or target.read_bytes() != source.read_bytes():
            shutil.copy2(source, target)

    config_path = extension_dir / "config.json"
    previous_config = load_json(config_path)
    previous_servers = previous_config.get("servers")
    previous_servers = previous_servers if isinstance(previous_servers, dict) else {}
    all_tools = ("graphify", "agentmemory", "context_mode", "leanctx", "rtk")
    requested = set(all_tools) if enabled_tools is None else set(enabled_tools)
    config = {
        "schema": "v1",
        "profile": "five_tool_routed",
        "manifest": str(manifest_path),
        "servers": {
            name: {
                "enabled": name in requested
                or (isinstance(previous_servers.get(name), dict)
                    and previous_servers[name].get("enabled") is True)
            }
            for name in all_tools
        },
    }
    write_json(config_path, config, dry_run)

    settings_path = agent_dir / "settings.json"
    settings = load_json(settings_path)
    extensions = settings.setdefault("extensions", [])
    if not isinstance(extensions, list):
        extensions = []
        settings["extensions"] = extensions
    extension_ref = "~/.pi/agent/extensions/silver-bullet-five-tool-stack"
    if os.environ.get("PI_CODING_AGENT_DIR"):
        extension_ref = str(extension_dir)
    add_unique(extensions, extension_ref)
    packages = settings.setdefault("packages", [])
    if not isinstance(packages, list):
        packages = []
        settings["packages"] = packages
    if not any("pi-lean-ctx" in str(item) for item in packages):
        packages.append("npm:pi-lean-ctx")
    write_json(settings_path, settings, dry_run)

    # Selective adapter updates (for example RTK-only receipt repair) must not
    # silently take ownership of Pi's shell by rewriting pi-lean-ctx.  The
    # full install and explicit LeanCTX updates still configure the additive
    # bridge below.
    leanctx_changed = False
    if enabled_tools is None or "leanctx" in requested:
        leanctx_changed = update_pi_leanctx_config(
            agent_dir / "extensions" / "pi-lean-ctx" / "config.json", manifest, dry_run
        )
    package_dir = agent_dir / "npm" / "node_modules" / "pi-lean-ctx"
    if not package_dir.is_dir():
        print(f"WARN: pi-lean-ctx package is not installed under {package_dir}")

    return {
        "host": "pi",
        "status": "supported",
        "manifest": str(manifest_path),
        "extension": str(target),
        "settings": str(settings_path),
        "leanctx_config_changed": leanctx_changed,
        "pi_leanctx_installed": package_dir.is_dir(),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Install the SB five-tool Pi adapter")
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument(
        "--enable-tool",
        action="append",
        choices=("graphify", "agentmemory", "context_mode", "leanctx", "rtk"),
        help="Enable one tool while preserving previously enabled Pi tools (repeatable)",
    )
    args = parser.parse_args()
    enabled_tools = set(args.enable_tool) if args.enable_tool else None
    result = install(Path(args.repo_root).resolve(), args.dry_run, enabled_tools)
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
