#!/usr/bin/env python3
"""Generate hooks/cursor-hooks.json from the canonical Claude hooks.json manifest."""

from __future__ import annotations

import json
import pathlib
import sys

REPO_ROOT = pathlib.Path(__file__).resolve().parents[1]
HOOKS_JSON = REPO_ROOT / "hooks" / "hooks.json"
OUT_JSON = REPO_ROOT / "hooks" / "cursor-hooks.json"

EVENT_MAP = {
    "SessionStart": "sessionStart",
    "PreToolUse": "preToolUse",
    "PostToolUse": "postToolUse",
    "Stop": "stop",
    "SubagentStop": "subagentStop",
    "UserPromptSubmit": "beforeSubmitPrompt",
}

PLUGIN_ROOT = "${CURSOR_PLUGIN_ROOT}"


def rewrite_command(command: str, cursor_event: str) -> str:
    command = command.replace("${CLAUDE_PLUGIN_ROOT}", PLUGIN_ROOT)
    hook_path = command.strip('"')
    if "/cursor-hook-bridge.sh" in hook_path:
        return command
    bridge = f'"{PLUGIN_ROOT}/hooks/cursor-hook-bridge.sh" {cursor_event} {hook_path}'
    return f'"{bridge}"'


def translate_matcher(matcher: str, cursor_event: str) -> str | None:
    if not matcher or matcher == ".*":
        return matcher
    parts = [part.strip() for part in matcher.split("|") if part.strip()]
    translated: list[str] = []
    for part in parts:
        if part == "Bash":
            translated.append("Shell")
        elif part == "exec_command":
            if cursor_event in {"beforeShellExecution", "afterShellExecution"}:
                return None
            translated.append("Shell")
        elif part == "apply_patch":
            translated.append("Write")
        else:
            translated.append(part)
    return "|".join(dict.fromkeys(translated)) if translated else None


def should_duplicate_to_shell(event: str, matcher: str) -> bool:
    return event in {"PreToolUse", "PostToolUse"} and any(
        token in {"Bash", "exec_command"} for token in matcher.split("|")
    )


def shell_cursor_event(claude_event: str) -> str:
    return "beforeShellExecution" if claude_event == "PreToolUse" else "afterShellExecution"


def build_cursor_hooks(src: dict) -> dict:
    cursor_hooks: dict[str, list[dict]] = {}
    for claude_event, groups in src.get("hooks", {}).items():
        cursor_event = EVENT_MAP.get(claude_event)
        if not cursor_event:
            continue
        for group in groups:
            matcher = group.get("matcher", ".*")
            for hook in group.get("hooks", []):
                if hook.get("type", "command") != "command":
                    continue
                entry = {"command": rewrite_command(hook.get("command", ""), cursor_event)}
                if hook.get("timeout") is not None:
                    entry["timeout"] = hook["timeout"]
                translated = translate_matcher(matcher, cursor_event)
                if translated:
                    entry["matcher"] = translated
                cursor_hooks.setdefault(cursor_event, []).append(entry)
                if should_duplicate_to_shell(claude_event, matcher):
                    shell_event = shell_cursor_event(claude_event)
                    shell_entry = {
                        "command": rewrite_command(hook.get("command", ""), shell_event),
                        "matcher": ".*",
                    }
                    if hook.get("timeout") is not None:
                        shell_entry["timeout"] = hook["timeout"]
                    cursor_hooks.setdefault(shell_event, []).append(shell_entry)
    return {"version": 1, "hooks": cursor_hooks}


def main() -> int:
    src = json.loads(HOOKS_JSON.read_text(encoding="utf-8"))
    OUT_JSON.write_text(json.dumps(build_cursor_hooks(src), indent=2) + "\n", encoding="utf-8")
    print(f"wrote {OUT_JSON}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
