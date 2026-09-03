#!/usr/bin/env python3
"""Validate Codex/Kay route-smoke transcript command order."""

from __future__ import annotations

import json
import shlex
import sys
from pathlib import Path


def command_tokens(command: object) -> list[str]:
    if isinstance(command, list):
        return [str(part) for part in command]
    if isinstance(command, str):
        try:
            return shlex.split(command)
        except ValueError:
            return [command]
    return []


def command_display(command: object) -> str:
    tokens = command_tokens(command)
    if tokens:
        return " ".join(shlex.quote(token) for token in tokens)
    return repr(command)


def is_hook_bridge(command: object) -> bool:
    return any("project-hook-bridge.sh" in token for token in command_tokens(command))


def is_route_smoke_completion_echo(tokens: list[str], route: str) -> bool:
    if not tokens or tokens[0] != "echo":
        return False

    message = " ".join(tokens[1:]).strip().strip("'\"")
    route_variants = {route, f"`{route}`", f"{route}."}
    for variant in route_variants:
        if message == f"Route smoke complete for {variant}":
            return True
        if message == f"Route smoke complete for {variant}.":
            return True
    return False


def substantive_exec_commands(transcript_path: Path, route: str) -> list[object]:
    commands: list[object] = []
    for command in extract_exec_commands(transcript_path):
        tokens = command_tokens(command)
        if is_route_smoke_completion_echo(tokens, route):
            continue
        commands.append(command)
    return commands


def normalize_route_smoke_adapter(tokens: list[str], route: str) -> list[str] | None:
    expected = ["silver-bullet", "invoke-skill", route]
    if tokens[:3] == expected:
        return expected

    if len(tokens) >= 3 and tokens[0] == "bash" and tokens[1] == "-lc":
        script = tokens[2] if len(tokens) == 3 else " ".join(tokens[2:])
        try:
            inner = shlex.split(script)
        except ValueError:
            inner = script.split()
        if inner[:3] == expected:
            return expected

    return None


def transcript_prompt_matches_route(transcript_path: Path, route: str) -> bool:
    needle = f"silver-bullet invoke-skill {route}"
    for raw in transcript_path.read_text(encoding="utf-8", errors="replace").splitlines():
        if not raw.strip():
            continue
        try:
            row = json.loads(raw)
        except json.JSONDecodeError:
            continue
        if row.get("type") != "prompt.submitted":
            continue
        prompt = row.get("prompt") or ""
        return needle in prompt
    return False


def extract_exec_commands(transcript_path: Path) -> list[object]:
    commands: list[object] = []
    for raw in transcript_path.read_text(encoding="utf-8", errors="replace").splitlines():
        if not raw.strip():
            continue
        try:
            row = json.loads(raw)
        except json.JSONDecodeError:
            continue
        msg = row.get("msg") or {}
        if msg.get("type") != "exec_command_begin":
            continue
        command = msg.get("command")
        if command is None:
            command = msg.get("cmd")
        if is_hook_bridge(command):
            continue
        commands.append(command)
    return commands


def validate_route_smoke_transcript(transcript_path: Path, route: str) -> tuple[bool, str]:
    expected = ["silver-bullet", "invoke-skill", route]

    if not transcript_path.is_file():
        return False, f"no transcript at {transcript_path}"

    if not transcript_prompt_matches_route(transcript_path, route):
        return False, (
            f"transcript prompt does not match route {route}; "
            f"latest capture may be stale at {transcript_path}"
        )

    real_commands = substantive_exec_commands(transcript_path, route)
    if not real_commands:
        return False, f"no non-hook exec_command_begin events found in {transcript_path}"

    normalized_commands: list[list[str]] = []
    for command in real_commands:
        tokens = command_tokens(command)
        normalized = normalize_route_smoke_adapter(tokens, route)
        if normalized is None:
            return False, (
                "first substantive command was not the SB adapter\n"
                f"expected: {' '.join(expected)}\n"
                f"actual:   {command_display(command)}"
            )
        normalized_commands.append(normalized)

    if len(normalized_commands) == 1:
        return True, command_display(real_commands[0])

    if normalized_commands and all(cmd == expected for cmd in normalized_commands):
        return True, command_display(real_commands[0])

    lines = [
        "route-smoke turn ran extra substantive commands after the SB adapter",
        f"expected exactly 1 substantive command, found {len(real_commands)}",
    ]
    for index, command in enumerate(real_commands, 1):
        lines.append(f"{index}. {command_display(command)}")
    return False, "\n".join(lines)


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: route-smoke-transcript.py <transcript.jsonl> <route>", file=sys.stderr)
        return 2

    transcript_path = Path(sys.argv[1])
    route = sys.argv[2]
    ok, message = validate_route_smoke_transcript(transcript_path, route)
    if ok:
        print(message)
        return 0
    print(message)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
