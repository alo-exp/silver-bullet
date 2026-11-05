#!/usr/bin/env python3
"""Strip what older Silver Bullet releases wrote under ~/.cursor (Cursor is no longer a host).

Usage: uninstall_cursor_legacy.py [--cursor-home DIR] [--dry-run]

Removal-only. It never installs, enables or repairs anything. Every item is matched by an exact
Silver Bullet marker or an exact name, never by a prefix or a guess; anything that merely looks
like Silver Bullet's is reported and left in place.

  hooks.json            entries whose program lives in a Silver Bullet hooks directory, the
                        old Cursor bridge, or the global toolstack gates (atomic write, backup)
  mcp.json              servers named like a Silver Bullet five-tool server that also point
                        into Silver Bullet's own runtime directories (atomic write, backup)
  agents/               generated sb agents (marker comment plus frontmatter checks) and the
                        colon-named agents listed in install-cursor/shipped-agent-names.txt
  rules/                the rule files Silver Bullet shipped, matched by name and exact
                        description line
  hooks/toolstack, toolstack.json, state/toolstack
                        the global toolstack Silver Bullet deployed
  plugins/              Silver Bullet's cache, local and marketplace copies, and its entry in
                        installed_plugins.json

Whole files and directories are moved to <cursor-home>/.silver-bullet-legacy-backup/<UTC stamp>/
(never deleted). JSON files keep a <file>.sb-backup copy. A second run finds nothing to do.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

LIB_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(LIB_DIR))
from sb_host_config import (  # noqa: E402
    ConfigError,
    command_program,
    is_sb_hook_command,
    read_json,
    sb_hook_names,
    write_json,
)

HOOKS_DIR = LIB_DIR.parents[1] / "hooks"
SHIPPED_NAMES = LIB_DIR / "install-cursor" / "shipped-agent-names.txt"

# The hook scripts the retired Cursor merge and the global toolstack registered by name.
LEGACY_HOOK_NAMES = frozenset({"cursor-hook-bridge.sh"})
TOOLSTACK_GATES = frozenset(
    {
        "stack-compression-coordinator.sh",
        "graphify-gate.sh",
        "agentmemory-gate.sh",
        "leanctx-gate.sh",
        "rtk-gate.sh",
        "context-mode-gate.sh",
        "token-compression-tools-gate.sh",
        "record-graphify-query.sh",
        "record-agentmemory-usage.sh",
        "session-bootstrap.sh",
        "shell-compression.sh",
    }
)
# Programs the retired Cursor merge treated as Silver Bullet's wherever they sit.
ADAPTER_PROGRAMS = frozenset({"codex-hook-adapter.sh"})
# Files the Cursor hooks kept in ~/.cursor/.silver-bullet (exact names; nothing else there is touched).
STATE_FILES = (
    "site-session.json",
    "site-visual-evidence.json",
    "site-vloops.json",
    "agent-delegation-active.json",
    "subagent-spawns.jsonl",
    "live-publish-evidence.json",
    "pending-completion-audit.json",
)
PLUGIN_DIRS = (
    "cache/alo-labs/silver-bullet",
    "cache/alo-labs-agent-plugins/silver-bullet",
    "cache/alo-labs-cursor/silver-bullet",
    "marketplaces/github.com/alo-exp/silver-bullet",
)
# Files the global toolstack installers deployed into ~/.cursor/hooks/toolstack (exact names).
TOOLSTACK_FILES = TOOLSTACK_GATES | frozenset(
    {
        "five_tool_instances.py",
        "patch-hooks.py",
        "patch-mcp.py",
        "fix-shell-compression-hook.py",
        "install-pi.py",
        "opencode.py",
        "parity-verify.sh",
        "verify.sh",
        "install.sh",
        "install-body.sh",
        "global-recommended-tools.mdc",
        "__pycache__",
    }
)
PLUGIN_ROOT_PLACEHOLDERS = ("${CURSOR_PLUGIN_ROOT}", "$CURSOR_PLUGIN_ROOT")

AGENT_MARKER = "<!-- sb-managed: cursor-sb-agents -->"
AGENT_DESCRIPTION_PREFIX = "SB reusable ladder agent — "
AGENT_FILENAME = re.compile(r"[A-Za-z0-9][A-Za-z0-9._ -]*\.md")
AGENT_SUFFIXES = (".md", ".json", ".yaml", ".yml")

RULES = {
    "agentmemory": "agentmemory session capture and Graphify synergy",
    "leanctx": "LeanCTX routing rules for SB five-tool parallel stack",
    "no-fast-mode": "Never launch parent or Task/subagent work in Fast mode",
    "recommended-tools": (
        "SB recommended tools — full enforcement in Cursor",
        "Global recommended tools — five_tool_routed stack (always enforced)",
    ),
    "rfl-verify-composer-2.5": (
        "RFL verify_1/verify_2 always use native Cursor Composer 2.5 Task — never Pi/Omni or Fast",
    ),
    "rfl-verify-grok-4.5-high": "DEPRECATED — see rfl-verify-composer-2.5.mdc for the current RFL verify model policy",
    "silver-orchestrator": "Silver Bullet parent orchestrator — delegate via Task workers only; never implement directly",
    "subagent-grok-4.6-high": (
        "Default all Task/subagent work to Grok 4.6 High; do not use Extra High/XHigh unless the user explicitly names it"
    ),
    "token-compression-enforcement": "Global RTK + Context Mode enforcement — hard requirements for all Cursor workspaces",
}

TOOLSTACK_HEADER = "# Global toolstack helpers — reads ~/.cursor/toolstack.json; defers to SB when bridge active."
TOOLSTACK_STATE_DIR = "~/.cursor/state/toolstack"
_MCP_BASE = ("graphify", "leanctx", "agentmemory", "context-mode", "alumnium")
MCP_NAMES = frozenset(_MCP_BASE) | frozenset("user-" + name for name in _MCP_BASE)
MCP_RUNTIME_DIRS = ("/.silver-bullet/", "/five-tool-stack/")
PLUGIN_ID = "silver-bullet@alo-labs"


class Cleanup:
    def __init__(self, cursor_home: Path, dry_run: bool) -> None:
        self.home = cursor_home
        self.dry_run = dry_run
        self.bucket = cursor_home / ".silver-bullet-legacy-backup" / datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
        self.changes = 0
        self.hook_names = sb_hook_names(HOOKS_DIR) | LEGACY_HOOK_NAMES
        self.shipped = {
            line.strip()
            for line in SHIPPED_NAMES.read_text(encoding="utf-8").splitlines()
            if line.strip() and not line.startswith("#")
        }

    def say(self, past: str, bare: str, what) -> None:
        print(f"would {bare}: {what}" if self.dry_run else f"{past}: {what}")

    def note(self, what) -> None:
        print(f"kept: {what}", file=sys.stderr)

    def reachable(self, path: Path) -> bool:
        """False (and a note) when a parent folder of ``path`` under the Cursor home is a symlink."""
        current = self.home
        for part in path.relative_to(self.home).parts[:-1]:
            current = current / part
            if current.is_symlink():
                self.note(f"{path}: symlinked parent folder {current} is not followed")
                return False
        return True

    def move_away(self, path: Path) -> None:
        """Move ``path`` (a file, a directory or a symlink itself) into the backup bucket."""
        if not self.reachable(path):
            return
        self.changes += 1
        self.say("moved", "move", f"{path} -> {self.bucket}")
        if self.dry_run:
            return
        target = self.bucket / path.relative_to(self.home)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(str(path), str(target))

    def save_json(self, path: Path, data) -> None:
        if not self.reachable(path):
            return
        self.changes += 1
        self.say("updated", "update", path)
        if not self.dry_run:
            write_json(path, data)

    # ------------------------------------------------------------------ hooks.json

    def is_sb_command(self, command) -> bool:
        if is_sb_hook_command(command, hook_names=self.hook_names):
            return True
        program = command_program(command)
        for placeholder in PLUGIN_ROOT_PLACEHOLDERS:
            if program.startswith(placeholder + "/hooks/") and program.rsplit("/", 1)[1] in self.hook_names:
                return True
        if program.rsplit("/", 1)[-1] in ADAPTER_PROGRAMS:
            return True
        for toolstack in (
            str(self.home / "hooks" / "toolstack") + "/",
            "~/.cursor/hooks/toolstack/",
            "$HOME/.cursor/hooks/toolstack/",
            "${HOME}/.cursor/hooks/toolstack/",
        ):
            if program.startswith(toolstack) and program[len(toolstack) :] in TOOLSTACK_GATES:
                return True
        return False

    def is_sb_entry(self, entry) -> bool:
        command = entry.get("command") if isinstance(entry, dict) else None
        if not isinstance(command, str):
            return False
        # An earlier malformed merge routed the Cursor bridge through the Codex adapter.
        if "codex-hook-adapter" in command and "cursor-hook-bridge" in command:
            return True
        return self.is_sb_command(command)

    def clean_hooks(self) -> None:
        path = self.home / "hooks.json"
        data = read_json(path, default=None)
        if data is None:
            return
        events = data.get("hooks")
        if not isinstance(events, dict):
            return
        changed = False
        for event in list(events):
            entries = events[event]
            if not isinstance(entries, list):
                continue
            kept = [entry for entry in entries if not self.is_sb_entry(entry)]
            if len(kept) == len(entries):
                continue
            changed = True
            if kept:
                events[event] = kept
            else:
                del events[event]
        if changed:
            self.save_json(path, data)

    # ------------------------------------------------------------------- mcp.json

    @staticmethod
    def is_sb_server(name, spec) -> bool:
        if name not in MCP_NAMES or not isinstance(spec, dict):
            return False
        text = json.dumps([spec.get("command"), spec.get("args")])
        return any(directory in text for directory in MCP_RUNTIME_DIRS)

    def clean_mcp(self) -> None:
        path = self.home / "mcp.json"
        data = read_json(path, default=None)
        servers = data.get("mcpServers") if data else None
        if not isinstance(servers, dict):
            return
        owned = [name for name, spec in servers.items() if self.is_sb_server(name, spec)]
        for name in servers:
            if name in MCP_NAMES and name not in owned:
                self.note(f"{path}: server {name!r} does not point into a Silver Bullet runtime directory")
        for name in owned:
            del servers[name]
        if owned:
            self.save_json(path, data)

    # ------------------------------------------------------------------- agents

    @staticmethod
    def is_generated_agent(path: Path) -> bool:
        if path.is_symlink() or not AGENT_FILENAME.fullmatch(path.name):
            return False
        try:
            lines = [line.strip() for line in path.read_text(encoding="utf-8").splitlines()]
        except (OSError, UnicodeDecodeError):
            return False
        if not lines or lines[0] != "---" or "---" not in lines[1:]:
            return False
        meta = {}
        for line in lines[1 : lines.index("---", 1)]:
            key, _, value = line.partition(":")
            meta[key.strip()] = value.strip()
        non_empty = [line for line in lines if line]
        return (
            meta.get("name") == path.stem
            and meta.get("description", "").startswith(AGENT_DESCRIPTION_PREFIX)
            and non_empty[-1] == AGENT_MARKER
        )

    def clean_agents(self) -> None:
        root = self.home / "agents"
        if not root.is_dir():
            return
        for item in sorted(root.iterdir()):
            if item.is_symlink():
                continue
            name = item.name if item.is_dir() else item.stem
            suffix_ok = item.is_dir() or item.suffix.lower() in AGENT_SUFFIXES
            if suffix_ok and name in self.shipped:
                self.move_away(item)
            elif item.is_file() and self.is_generated_agent(item):
                self.move_away(item)

    # -------------------------------------------------------------------- rules

    def clean_rules(self) -> None:
        root = self.home / "rules"
        for name, value in RULES.items():
            descriptions = (value,) if isinstance(value, str) else value
            path = root / f"{name}.mdc"
            if path.is_symlink() or not path.is_file():
                continue
            try:
                head = path.read_text(encoding="utf-8").splitlines()[:6]
            except (OSError, UnicodeDecodeError):
                head = []
            if any(f"description: {description}" in head for description in descriptions):
                self.move_away(path)
            else:
                self.note(f"{path}: named like a Silver Bullet rule but the description differs")

    # ---------------------------------------------------------------- toolstack

    def clean_toolstack(self) -> None:
        deployed = self.home / "hooks" / "toolstack"
        common = deployed / "lib" / "common.sh"
        if deployed.is_dir() and not deployed.is_symlink():
            if common.is_file() and TOOLSTACK_HEADER in common.read_text(encoding="utf-8", errors="replace"):
                self.move_toolstack_files(deployed)
            else:
                self.note(f"{deployed}: lib/common.sh lacks the Silver Bullet toolstack header")
        config = self.home / "toolstack.json"
        try:
            marked = read_json(config, default={}).get("state_dir") == TOOLSTACK_STATE_DIR
        except ConfigError:
            marked = False
        if marked:
            self.move_away(config)
            state = self.home / "state" / "toolstack"
            if state.is_dir() and not state.is_symlink():
                self.move_away(state)

    def move_toolstack_files(self, deployed: Path) -> None:
        """Move only the files the installers deployed; user scripts stay with their hooks.json entries."""
        for item in sorted(deployed.iterdir()):
            if item.name == "lib":
                common = item / "common.sh"
                if common.is_file() and not common.is_symlink():
                    self.move_away(common)
            elif item.name in TOOLSTACK_FILES and not (item.is_symlink() and item.is_dir()):
                self.move_away(item)
        for folder in (deployed / "lib", deployed):
            if not self.dry_run and folder.is_dir() and not folder.is_symlink() and not any(folder.iterdir()):
                folder.rmdir()
        for item in sorted(deployed.rglob("*")) if deployed.is_dir() else ():
            if item.is_file() or item.is_symlink():
                self.note(f"{item}: not a Silver Bullet toolstack file, left in place")

    # ------------------------------------------------------------------ plugins

    def clean_plugins(self) -> None:
        plugins = self.home / "plugins"
        for rel in PLUGIN_DIRS:
            path = plugins / rel
            if path.is_symlink() or path.is_dir():
                self.move_away(path)
        local = plugins / "local" / "silver-bullet"
        manifest = local / ".cursor-plugin" / "plugin.json"
        try:
            local_name = read_json(manifest, default={}).get("name")
        except ConfigError:
            local_name = None
        if local.is_dir() and not local.is_symlink():
            if local_name == "silver-bullet":
                self.move_away(local)
            else:
                self.note(f"{local}: plugin manifest does not name silver-bullet")
        registry = plugins / "installed_plugins.json"
        data = read_json(registry, default={})
        installed = data.get("plugins")
        if isinstance(installed, dict) and PLUGIN_ID in installed:
            del installed[PLUGIN_ID]
            self.save_json(registry, data)

    def clean_state(self) -> None:
        state = self.home / ".silver-bullet"
        for name in STATE_FILES:
            path = state / name
            if path.is_symlink() or path.is_file():
                self.move_away(path)

    def run(self) -> int:
        failed = False
        for step in (
            self.clean_hooks,
            self.clean_mcp,
            self.clean_agents,
            self.clean_rules,
            self.clean_toolstack,
            self.clean_plugins,
            self.clean_state,
        ):
            try:
                step()
            except (ConfigError, OSError) as exc:
                print(f"ERROR: {exc}", file=sys.stderr)
                failed = True
        if self.changes:
            print(f"Cursor legacy cleanup: {self.changes} change(s); moved items are under {self.bucket}")
        else:
            print(f"Cursor legacy cleanup: nothing Silver Bullet created was found under {self.home}")
        return 1 if failed else 0


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Remove what older Silver Bullet releases wrote under ~/.cursor.")
    parser.add_argument("--cursor-home", default=os.environ.get("CURSOR_HOME") or str(Path.home() / ".cursor"))
    parser.add_argument("--dry-run", action="store_true", help="report what would change and change nothing")
    args = parser.parse_args(argv)
    home = Path(args.cursor_home).expanduser()
    if not home.is_dir():
        print(f"Cursor legacy cleanup: no {home} directory, nothing to do")
        return 0
    return Cleanup(home, args.dry_run).run()


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
