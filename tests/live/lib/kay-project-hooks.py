#!/usr/bin/env python3
import json
import os
import pathlib
import sys


BRIDGE_HOOK_NAMES = {
    "silver-bullet-kay-tool-before",
    "silver-bullet-kay-tool-after",
    "silver-bullet-kay-file-before-write",
    "silver-bullet-kay-file-after-write",
}

BRIDGE_ENV_KEYS = (
    "SILVER_BULLET_RUNTIME",
    "SB_RUNTIME_EXTRA_STATE_ROOTS",
    "SILVER_BULLET_HOOK_AUDIT_LOG",
    "SB_KAY_HOOK_BRIDGE_DEBUG",
)


def expand_project_paths(project_path: str) -> list[str]:
    path = pathlib.Path(project_path)
    candidates = [path, path.resolve()]
    out: list[str] = []
    seen: set[str] = set()
    for candidate in candidates:
        candidate_str = str(candidate)
        if candidate_str in seen:
            continue
        seen.add(candidate_str)
        out.append(candidate_str)
    return out


def strip_existing_bridge_blocks(lines: list[str], project_paths: list[str]) -> list[str]:
    headers = {f'[[projects."{project_path}".hooks]]' for project_path in project_paths}
    out: list[str] = []
    index = 0
    while index < len(lines):
        line = lines[index]
        if line in headers:
            block = [line]
            index += 1
            while index < len(lines) and not lines[index].startswith("["):
                block.append(lines[index])
                index += 1
            if any(f'name = "{name}"' in "\n".join(block) for name in BRIDGE_HOOK_NAMES):
                continue
            out.extend(block)
            continue
        out.append(line)
        index += 1
    return out


def toml_basic_string(value: str) -> str:
    return json.dumps(value)


def build_bridge_env_inline_table(plugin_root: str, home_root: str) -> str:
    env_items: list[tuple[str, str]] = [
        ("CLAUDE_PLUGIN_ROOT", plugin_root),
        ("HOME", home_root),
        ("KAY_HOME", home_root),
        ("SB_KAY_HOOK_BRIDGE_LEGACY_FALLBACK", "1"),
    ]

    for key in BRIDGE_ENV_KEYS:
        value = os.environ.get(key)
        if value:
            env_items.append((key, value))

    rendered = ", ".join(
        f"{key} = {toml_basic_string(value)}" for key, value in env_items
    )
    return "{ " + rendered + " }"


def append_bridge_hooks(
    lines: list[str],
    project_paths: list[str],
    bridge_path: str,
    plugin_root: str,
    home_root: str,
) -> list[str]:
    hook_specs = [
        ("tool.before", "silver-bullet-kay-tool-before", 15000),
        ("tool.after", "silver-bullet-kay-tool-after", 15000),
        ("file.before_write", "silver-bullet-kay-file-before-write", 15000),
        ("file.after_write", "silver-bullet-kay-file-after-write", 15000),
    ]
    env_inline_table = build_bridge_env_inline_table(plugin_root, home_root)

    out = list(lines)
    if out and out[-1] != "":
        out.append("")

    for project_path in project_paths:
        for event, name, timeout_ms in hook_specs:
            out.extend(
                [
                    f'[[projects."{project_path}".hooks]]',
                    f'event = "{event}"',
                    f'name = "{name}"',
                    f'command = ["bash", "{bridge_path}"]',
                    f"env = {env_inline_table}",
                    f'timeout_ms = {timeout_ms}',
                    "run_in_background = false",
                    "",
                ]
            )

    while out and out[-1] == "":
        out.pop()
    return out


def main() -> int:
    if len(sys.argv) != 5:
        raise SystemExit(2)

    config_path = pathlib.Path(sys.argv[1])
    project_path = sys.argv[2]
    bridge_path = sys.argv[3]
    plugin_root = sys.argv[4]
    home_root = str(config_path.parent.parent)

    text = config_path.read_text() if config_path.is_file() else ""
    lines = text.splitlines()
    project_paths = expand_project_paths(project_path)
    lines = strip_existing_bridge_blocks(lines, project_paths)
    lines = append_bridge_hooks(lines, project_paths, bridge_path, plugin_root, home_root)
    config_path.write_text("\n".join(lines).rstrip("\n") + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
