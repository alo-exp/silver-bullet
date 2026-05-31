#!/usr/bin/env python3
"""Render an agent-specific skill bundle from the canonical skills tree."""

from __future__ import annotations

import argparse
import os
import pathlib
import re
import shutil
import sys

NAME_RE = re.compile(r"^(name:\s*)(silver-)([A-Za-z0-9_-]+)\s*$", re.MULTILINE)
CODEX_TITLE_WORD_OVERRIDES = {
    "ai": "AI",
    "api": "API",
    "ci": "CI",
    "docs": "Docs",
    "devops": "DevOps",
    "llm": "LLM",
    "pr": "PR",
    "tdd": "TDD",
    "ui": "UI",
    "uat": "UAT",
}

CODEX_REPLACEMENTS = [
    ("Then invoke `/compact` via the Skill tool to compact the loaded context before proceeding.", "Then summarize the loaded context and continue without relying on `/compact`."),
    ("If context >90%: display `Context exhaustion imminent. Running /compact before continuing.` then invoke `/compact`", "If context >90%: display `Context exhaustion imminent. Summarize the current context before continuing.` then continue in a fresh context or subagent"),
    ("If context >80%: display `/compact recommendation: Context window at ~80%. Consider running /compact before continuing.`", "If context >80%: display a context-compaction recommendation and consider summarizing the current context before continuing."),
    ("ask the user to run /compact before proceeding", "ask the user to summarize the current context or continue in a fresh subagent before proceeding"),
    ("skip /compact", "skip context compaction"),
    ("run /compact", "summarize the context"),
    ("invoke /compact", "summarize the context"),
    ("/compact", "context compaction"),
    (os.path.join("~", ".claude") + "/", os.path.join("~", ".codex") + "/"),
    ("$HOME" + "/.claude/", "$HOME" + "/.codex/"),
    ("${HOME}" + "/.claude/", "${HOME}" + "/.codex/"),
    (".claude/", ".codex/"),
    ("For each match found, present it to the user interactively using AskUserQuestion:", "For each match found, present it to the user directly:"),
    ("present it to the user interactively using AskUserQuestion:", "present it to the user directly:"),
    ("present to user using AskUserQuestion:", "present to the user directly:"),
    ("Ask using AskUserQuestion:", "Ask the user directly:"),
    ("Ask the user via AskUserQuestion:", "Ask the user directly:"),
    ("Then use AskUserQuestion:", "Then ask the user directly:"),
    ("Use AskUserQuestion:", "Ask the user directly:"),
    ("Use AskUserQuestion", "Ask the user directly"),
    ("use AskUserQuestion:", "ask the user directly:"),
    ("use AskUserQuestion", "ask the user directly"),
    ("using AskUserQuestion:", "directly:"),
    ("using AskUserQuestion", "directly"),
    ("Only use AskUserQuestion if", "Only ask the user directly if"),
    ("No AskUserQuestion needed", "No interactive user prompt needed"),
    ("No AskUserQuestion.", "No interactive user prompt."),
    ("AskUserQuestion", "direct user interaction"),
    ("**GSD subagent routing:** Handled automatically via `model_profile: \"balanced\"` in `.planning/config.json`. No manual switching required for GSD-orchestrated steps.", "**GSD subagent routing:** Model selection is host-managed. Silver Bullet does not auto-route subagents."),
    ("**Setup requirement:** Every new project must have `.planning/config.json` containing `\"model_profile\": \"balanced\"`. Run after `/gsd-new-project`:\n```bash\nnode \"$HOME/.claude/get-shit-done/bin/gsd-tools.cjs\" config-get model_profile\n```\nIf not `balanced`, run `/gsd-set-profile balanced`.\n\n> **Anti-Skip:** GSD subagent model routing is automatic once `model_profile` is set. You are violating this rule if `.planning/config.json` is missing `model_profile` or uses legacy `planner_model`/`researcher_model`/`checker_model` fields.", "**Setup note:** Do not require `.planning/config.json model_profile` fields as part of Silver Bullet setup. If the active host or GSD version supports model preferences, configure them at the host/tool layer, not in SB-managed workflow instructions.\n\n> **Anti-Skip:** Do not encode subagent model routing policy in Silver Bullet setup files. Host/tool configuration owns model choice."),
    ("No model choice prompt. Agents auto-select the correct model for the current host. Execution-tier agents handle execution, research, and documentation at high throughput; high-tier agents handle design, review, and verification; top-tier agents handle the deepest reasoning cases. The orchestrator (this session) always runs on the host execution tier.", "No model choice prompt from Silver Bullet. Model selection is host-managed, and SB does not auto-route subagents. The orchestrator (this session) stays in the current host session."),
]


def rewrite_names(text: str) -> str:
    def repl(match: re.Match[str]) -> str:
        return f"{match.group(1)}silver:{match.group(3)}"

    return NAME_RE.sub(repl, text, count=1)


def humanize_codex_skill_name(name: str) -> str:
    return " ".join(
        CODEX_TITLE_WORD_OVERRIDES.get(part.lower(), part.capitalize())
        for part in re.split(r"[-_\s]+", name)
        if part
    )


def codex_title_for_name(name: str, current_title: str | None = None) -> str:
    if name == "silver":
        title = "Router"
    elif name.startswith("silver:"):
        title = humanize_codex_skill_name(name.split(":", 1)[1])
    elif current_title:
        title = current_title.removeprefix("Silver: ").strip()
    else:
        title = humanize_codex_skill_name(name)

    return f"Silver: {title}"


def ensure_codex_picker_title(text: str) -> str:
    lines = text.splitlines(keepends=True)
    if not lines or lines[0].strip() != "---":
        return text

    frontmatter_end: int | None = None
    name_idx: int | None = None
    title_idx: int | None = None
    skill_name: str | None = None
    current_title: str | None = None

    for idx, line in enumerate(lines[1:], start=1):
        if line.strip() == "---":
            frontmatter_end = idx
            break
        name_match = re.match(r"^(name:\s*)(.+?)\s*$", line)
        if name_match and name_idx is None:
            name_idx = idx
            skill_name = name_match.group(2).strip().strip('"')
            continue
        if re.match(r"^title:\s*", line) and title_idx is None:
            title_idx = idx
            current_title = re.sub(r"^title:\s*", "", line).strip().strip('"')

    if frontmatter_end is None or name_idx is None or skill_name is None:
        return text

    title = codex_title_for_name(skill_name, current_title=current_title)
    title_line = f"title: {title}\n"
    if title_idx is not None and title_idx < frontmatter_end:
        lines[title_idx] = title_line
    else:
        lines.insert(name_idx + 1, title_line)

    return "".join(lines)


def runtime_placeholders(agent: str) -> list[tuple[str, str]]:
    current_home = os.path.join("~", f".{agent}")
    opposite = "claude" if agent == "codex" else "codex"
    opposite_home = os.path.join("~", f".{opposite}")

    return [
        ("${SB_RUNTIME_HOME_ROOT}", current_home),
        ("${SB_RUNTIME_STATE_DIR}", f"{current_home}/.silver-bullet"),
        ("${SB_RUNTIME_PLUGIN_CACHE_ROOT}", f"{current_home}/plugins/cache"),
        (f"{opposite_home}/", f"{current_home}/"),
        (opposite_home, current_home),
        (f"$HOME/.{opposite}/", f"$HOME/.{agent}/"),
        (f"$HOME/.{opposite}", f"$HOME/.{agent}"),
        (f"${{HOME}}/.{opposite}/", f"${{HOME}}/.{agent}/"),
        (f"${{HOME}}/.{opposite}", f"${{HOME}}/.{agent}"),
        (f".{opposite}/", f".{agent}/"),
        (f".{opposite}", f".{agent}"),
    ]


def sanitize_codex_text(text: str) -> str:
    updated = text
    for old, new in CODEX_REPLACEMENTS:
        updated = updated.replace(old, new)
    return updated


def sanitize_text(text: str, agent: str, preserve_runtime_placeholders: bool = False) -> str:
    updated = rewrite_names(text)
    if agent == "codex":
        updated = ensure_codex_picker_title(updated)
    if not preserve_runtime_placeholders:
        for old, new in runtime_placeholders(agent):
            updated = updated.replace(old, new)
    if agent == "codex":
        updated = sanitize_codex_text(updated)
    return updated


def rewrite_file(path: pathlib.Path, agent: str) -> bool:
    if path.name == "runtime-paths.sh" and "hooks" in path.parts:
        return False

    try:
        text = path.read_text()
    except UnicodeDecodeError:
        return False
    except Exception:
        return False

    preserve_runtime_placeholders = "hooks" in path.parts
    updated = sanitize_text(text, agent, preserve_runtime_placeholders=preserve_runtime_placeholders)
    if updated == text:
        return False

    path.write_text(updated)
    return True


def sanitize_root(root: pathlib.Path, agent: str) -> None:
    if not root.exists():
        return

    stack = [root]
    while stack:
        current = stack.pop()
        if current.is_symlink():
            continue
        if current.is_dir():
            for child in sorted(current.iterdir(), key=lambda path: path.name, reverse=True):
                stack.append(child)
            continue
        if current.is_file():
            rewrite_file(current, agent)


def render_bundle(source_root: pathlib.Path, dest_root: pathlib.Path, agent: str) -> None:
    if not source_root.is_dir():
        raise SystemExit(f"source root missing: {source_root}")

    if dest_root.exists() or dest_root.is_symlink():
        if dest_root.is_dir() and not dest_root.is_symlink():
            shutil.rmtree(dest_root)
        else:
            dest_root.unlink()

    dest_root.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(source_root, dest_root, symlinks=False)
    sanitize_root(dest_root, agent)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("render", "sanitize"))
    parser.add_argument("--agent", required=True, choices=("claude", "codex"))
    parser.add_argument("--source-root")
    parser.add_argument("--dest-root")
    parser.add_argument("--root")
    args = parser.parse_args()

    if args.mode == "render":
        if not args.source_root or not args.dest_root:
            parser.error("render mode requires --source-root and --dest-root")
        render_bundle(pathlib.Path(args.source_root), pathlib.Path(args.dest_root), args.agent)
        return 0

    if not args.root:
        parser.error("sanitize mode requires --root")
    sanitize_root(pathlib.Path(args.root), args.agent)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
