#!/usr/bin/env python3
"""Install the Silver Bullet five-tool adapter into Pi's global agent dir.

Only the tools passed with --enable-tool (the ones the user consented to wire) are switched on, and
pi-lean-ctx is registered only with leanctx. Pi's settings.json and the pi-lean-ctx config are user
files: one that does not parse is reported and left alone, and every write is atomic, goes through
a symlink, keeps the mode and leaves the previous content in <file>.sb-backup.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parent))
# sb_host_config.py sits in scripts/lib (the repository) or beside this file (the deployed copy).
sys.path.append(str(Path(__file__).resolve().parents[1]))

import sb_host_config as sbc  # noqa: E402

from five_tool_instances import ensure_global_instances, global_instances_manifest_path  # noqa: E402


LEANCTX_ENV = {
    "LEANCTX_MCP_TOOL_PREFIX": "lctx_",
    "LEAN_CTX_DISABLED_TOOLS": "ctx_shell,shell,ctx_execute,ctx_search,ctx_index,ctx_url_read,ctx_knowledge,ctx_memory",
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
    sbc.write_json(path, data)


def load_json(path: Path) -> dict[str, Any]:
    """The JSON object in PATH ({} when absent); sbc.ConfigError when it cannot be parsed, so a
    user's file is never replaced by a near-empty one."""
    return sbc.read_json(path, default={})


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
    allow_package_install: bool = False,
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
        sbc.write_atomic(target, source.read_bytes())

    config_path = extension_dir / "config.json"
    try:
        previous_config = load_json(config_path)
    except sbc.ConfigError:
        previous_config = {}  # Silver Bullet's own file; the write below keeps the old copy
    previous_servers = previous_config.get("servers")
    previous_servers = previous_servers if isinstance(previous_servers, dict) else {}
    all_tools = ("graphify", "agentmemory", "context_mode", "leanctx", "rtk")
    # No --enable-tool means "enable nothing new": a tool is switched on only by the user's consent.
    requested = set() if enabled_tools is None else set(enabled_tools)
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
    # Listing an npm package makes Pi install code: only when the caller passes the user's "install"
    # consent (--allow-install). Enabling leanctx alone never adds a package.
    if (
        allow_package_install
        and "leanctx" in requested
        and not any("pi-lean-ctx" in str(item) for item in packages)
    ):
        packages.append("npm:pi-lean-ctx")
    write_json(settings_path, settings, dry_run)

    # Only an explicit LeanCTX update configures the additive pi-lean-ctx bridge; RTK-only or
    # Context-Mode-only updates must not take ownership of Pi's shell.
    leanctx_changed = False
    if "leanctx" in requested:
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
        help="Enable one consented tool while preserving previously enabled Pi tools (repeatable); none by default",
    )
    parser.add_argument(
        "--allow-install",
        action="store_true",
        help="The user consented to install: list the pi-lean-ctx npm package when leanctx is enabled",
    )
    args = parser.parse_args()
    enabled_tools = set(args.enable_tool) if args.enable_tool else None
    previous_umask = os.umask(0o077)  # new Pi files are private; existing files keep their mode
    try:
        result = install(
            Path(args.repo_root).resolve(), args.dry_run, enabled_tools, allow_package_install=args.allow_install
        )
    except sbc.ConfigError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2
    finally:
        os.umask(previous_umask)
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
