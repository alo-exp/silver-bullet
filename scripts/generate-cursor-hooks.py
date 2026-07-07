#!/usr/bin/env python3
"""Generate hooks/cursor-hooks.json from the canonical Claude hooks.json manifest."""

from __future__ import annotations

import json
import pathlib
import shlex
import sys

REPO_ROOT = pathlib.Path(__file__).resolve().parents[1]
HOOKS_JSON = REPO_ROOT / "hooks" / "hooks.json"
OUT_JSON = REPO_ROOT / "hooks" / "cursor-hooks.json"
PLUGIN_OUT_JSON = REPO_ROOT / "plugins" / "silver-bullet" / "cursor-hooks.json"

EVENT_MAP = {
    "SessionStart": "sessionStart",
    "PreToolUse": "preToolUse",
    "PostToolUse": "postToolUse",
    "Stop": "stop",
    "SubagentStart": "subagentStart",
    "SubagentStop": "subagentStop",
    "UserPromptSubmit": "beforeSubmitPrompt",
}

PLUGIN_ROOT = "${CURSOR_PLUGIN_ROOT}"


def normalize_hook_path(hook_path: str) -> str:
    hook_path = hook_path.strip('"').replace("${CLAUDE_PLUGIN_ROOT}", PLUGIN_ROOT)
    marker = "/plugins/silver-bullet/hooks/"
    if marker in hook_path:
        suffix = hook_path.split(marker, 1)[1]
        return f"{PLUGIN_ROOT}/hooks/{suffix}"
    if hook_path.startswith(f"{PLUGIN_ROOT}/hooks/"):
        return hook_path
    return hook_path


def extract_hook_path(command: str) -> str:
    command = command.replace("${CLAUDE_PLUGIN_ROOT}", PLUGIN_ROOT)
    if "/cursor-hook-bridge.sh" in command:
        try:
            parts = shlex.split(command)
        except ValueError:
            parts = command.split()
        if len(parts) >= 3:
            return parts[2]
        return command.strip('"')
    try:
        parts = shlex.split(command)
    except ValueError:
        parts = command.split()
    adapter_idx = next(
        (index for index, part in enumerate(parts) if "codex-hook-adapter" in part),
        None,
    )
    if adapter_idx is not None and len(parts) > adapter_idx + 2:
        return parts[adapter_idx + 2].replace("${CLAUDE_PLUGIN_ROOT}", PLUGIN_ROOT)
    if parts:
        return parts[-1].replace("${CLAUDE_PLUGIN_ROOT}", PLUGIN_ROOT)
    return command.strip('"')


def rewrite_command(command: str, cursor_event: str) -> str:
    if "/cursor-hook-bridge.sh" in command:
        return command.replace("${CLAUDE_PLUGIN_ROOT}", PLUGIN_ROOT)
    hook_path = normalize_hook_path(extract_hook_path(command))
    if " " in hook_path and not (hook_path.startswith('"') and hook_path.endswith('"')):
        hook_path = f'"{hook_path}"'
    return f'"{PLUGIN_ROOT}/hooks/cursor-hook-bridge.sh" {cursor_event} {hook_path}'


def translate_matcher(matcher: str, cursor_event: str) -> str | None:
    if not matcher or matcher == ".*":
        return matcher
    parts = [part.strip() for part in matcher.split("|") if part.strip()]
    translated: list[str] = []
    for part in parts:
        if part in {"Bash", "shell"}:
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
        token in {"Bash", "exec_command", "shell"} for token in matcher.split("|")
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
    payload = json.dumps(build_cursor_hooks(src), indent=2) + "\n"
    OUT_JSON.write_text(payload, encoding="utf-8")
    PLUGIN_OUT_JSON.parent.mkdir(parents=True, exist_ok=True)
    PLUGIN_OUT_JSON.write_text(payload, encoding="utf-8")
    print(f"wrote {OUT_JSON}")
    print(f"wrote {PLUGIN_OUT_JSON}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
