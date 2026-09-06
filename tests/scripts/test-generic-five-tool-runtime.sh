#!/usr/bin/env bash
# No-Silver-Bullet acceptance tests for the independent five-tool runtime.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

HOME="$TMP_ROOT/home" \
  PYTHONPATH="$REPO_ROOT/scripts/lib" \
  REPO_ROOT="$REPO_ROOT" \
  TMP_ROOT="$TMP_ROOT" \
  env -u SB_GLOBAL_TOOLSTACK_HOME -u SB_GLOBAL_TOOLSTACK_MANIFEST \
      -u SILVER_BULLET_RUNTIME -u SILVER_BULLET_STATE_FILE \
      python3 - <<'PY'
import hashlib
import json
import os
from pathlib import Path

from five_tool_runtime.runtime import (
    MANIFEST_SCHEMA,
    TOOL_DEFINITIONS,
    duplicate_registration_names,
    ensure_manifest,
    global_toolstack_home,
    launch_spec,
    launch_argv,
    merged_environment,
    load_manifest,
    repair_manifest,
    validate_manifest,
)
from five_tool_runtime.projections import project_host, validate_projection

root = Path(os.environ["TMP_ROOT"])
package_root = Path(os.environ["REPO_ROOT"]) / "scripts" / "lib" / "five_tool_runtime"
package_source = "\n".join(path.read_text(encoding="utf-8") for path in package_root.glob("*.py"))
assert "silver-bullet" not in package_source.lower()
assert "SB_" not in package_source
home = root / "home"
bin_dir = root / "bin"
bin_dir.mkdir(parents=True)
for definition in TOOL_DEFINITIONS.values():
    path = bin_dir / definition["executable"]
    path.write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
    path.chmod(0o755)

runtime_root = root / "generic-state"
env = {"FIVE_TOOL_STACK_HOME": str(runtime_root), "PATH": str(bin_dir) + os.pathsep + os.environ["PATH"]}
manifest_path = runtime_root / "manifest.json"
unrelated = runtime_root / "unrelated.json"
unrelated.parent.mkdir(parents=True)
unrelated.write_text('{"keep":true}\n', encoding="utf-8")

first = ensure_manifest(manifest_path=manifest_path, env=env, home=home)
assert first["_result"]["changed"] is True
assert first["_result"]["validation"]["valid"] is True
saved_hash = hashlib.sha256(manifest_path.read_bytes()).hexdigest()
assert validate_manifest(load_manifest(manifest_path), require_commands=True)["valid"]
assert unrelated.read_text(encoding="utf-8") == '{"keep":true}\n'

second = ensure_manifest(manifest_path=manifest_path, env=env, home=home)
assert second["_result"]["changed"] is False
assert hashlib.sha256(manifest_path.read_bytes()).hexdigest() == saved_hash

manifest = load_manifest(manifest_path)
assert manifest["schema"] == MANIFEST_SCHEMA
assert set(manifest["tools"]) == set(TOOL_DEFINITIONS)
assert set(manifest["hosts"]) == {"claude", "codex", "cursor", "opencode", "pi"}
assert manifest["coordination"]["rtk_rewrite"] == "single"
assert launch_spec(manifest, "graphify")["transport"] == "stdio"
assert launch_spec(manifest, "rtk")["transport"] == "shell-rewrite"
windows_launch_manifest = {
    "tools": {
        "rtk": {"command": r"C:\\Tools\\rtk.ps1", "args": ["--json"], "env": {"RTK_MODE": "once"}},
    }
}
assert launch_argv(windows_launch_manifest, "rtk", platform_name="win32") == [
    "powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", r"C:\\Tools\\rtk.ps1", "--json"
]
assert merged_environment({"KEEP": "yes"}, windows_launch_manifest, "rtk")["RTK_MODE"] == "once"
assert duplicate_registration_names(["graphify", "agentmemory", "graphify"]) == ("graphify",)
for host in ("claude", "codex", "cursor", "opencode", "pi"):
    projection = project_host(manifest, host)
    assert validate_projection(projection)["valid"] is True
    assert projection["rules"]["rtkRewriteOwner"] == "rtk"
assert "context-mode" in project_host(manifest, "claude")["mcpServers"]
assert "context-mode" not in project_host(manifest, "opencode")["mcpServers"]
assert project_host(manifest, "opencode")["plugin"]
assert project_host(manifest, "pi")["servers"]["rtk"]["enabled"] is False

# A malformed canonical file is repaired while unrelated files remain intact.
manifest_path.write_text("{malformed\n", encoding="utf-8")
repaired = repair_manifest(manifest_path=manifest_path, env=env, home=home)
assert repaired["_result"]["validation"]["valid"] is True
assert unrelated.exists()
partial = load_manifest(manifest_path)
del partial["tools"]["rtk"]["args"]
assert "rtk args are missing" in validate_manifest(partial)["errors"]

# Legacy state is read only as an explicit migration source; the canonical
# destination is the platform-neutral manifest and the legacy bytes remain.
legacy = root / "legacy" / "instances.json"
legacy.parent.mkdir(parents=True)
legacy_payload = {
    "schema": "v1",
    "scope": "user-global",
    "profile": "five_tool_routed",
    "tools": {
        "graphify": {"command": str(bin_dir / "graphify-mcp"), "args": []},
        "agentmemory": {"command": str(bin_dir / "agentmemory"), "args": []},
    },
}
legacy.write_text(json.dumps(legacy_payload), encoding="utf-8")
migrated_path = root / "migrated" / "manifest.json"
migrated = ensure_manifest(
    manifest_path=migrated_path,
    legacy_manifest_path=legacy,
    env=env,
    home=home,
)
assert migrated["_result"]["migrated"] is True
assert migrated["tools"]["graphify"]["command"] == str((bin_dir / "graphify-mcp").resolve())
assert legacy.read_text(encoding="utf-8") == json.dumps(legacy_payload)

# Windows path and launcher fixtures are deterministic on this Unix runner.
windows_env = {
    "LOCALAPPDATA": r"C:\\Users\\Ada\\AppData\\Local",
    "APPDATA": r"C:\\Users\\Ada\\AppData\\Roaming",
}
windows_root = global_toolstack_home(windows_env, home=Path(r"C:\\Users\\Ada"), platform_name="win32")
assert str(windows_root).endswith("five-tool-stack")
windows_manifest = {
    "schema": MANIFEST_SCHEMA,
    "scope": "user-global",
    "tools": {
        name: {
            "identity": {"name": name, "package": definition["package"], "executable": definition["executable"]},
            "command": r"C:\\Tools\\{}".format(definition["executable"] + ".exe"),
            "args": list(definition["args"]),
            "env": dict(definition["env"]),
            "transport": definition["transport"],
            "version": None,
            "capabilities": list(definition["capabilities"]),
        }
        for name, definition in TOOL_DEFINITIONS.items()
    },
    "hosts": {name: {} for name in ("claude", "codex", "cursor", "opencode", "pi")},
    "coordination": {
        "one_global_instance_per_tool": True,
        "rtk_rewrite": "single",
        "context_mode": {"native_plugin_mutually_exclusive_with_mcp": True},
    },
}
assert validate_manifest(windows_manifest, platform_name="win32")["valid"]

print("PASS: generic five-tool runtime installs, migrates, repairs, validates, and handles Windows fixtures")
print("Results: 1 passed, 0 failed")
PY
