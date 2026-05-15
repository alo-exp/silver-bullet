#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  printf 'Usage: %s <package-root> [<package-root> ...]\n' "${0##*/}" >&2
  exit 2
fi

python3 - "$@" <<'PY'
import pathlib
import sys

LINE_REPLACEMENTS = [
    ("Then invoke `/compact` via the Skill tool to compact the loaded context before proceeding.", "Then summarize the loaded context and continue without relying on `/compact`."),
    ("If context >90%: display `Context exhaustion imminent. Running /compact before continuing.` then invoke `/compact`", "If context >90%: display `Context exhaustion imminent. Summarize the current context before continuing.` then continue in a fresh context or subagent"),
    ("If context >80%: display `/compact recommendation: Context window at ~80%. Consider running /compact before continuing.`", "If context >80%: display a context-compaction recommendation and consider summarizing the current context before continuing."),
    ("ask the user to run /compact before proceeding", "ask the user to summarize the current context or continue in a fresh subagent before proceeding"),
    ("skip /compact", "skip context compaction"),
    ("run /compact", "summarize the context"),
    ("invoke /compact", "summarize the context"),
    ("/compact", "context compaction"),
    ("~/.claude/", "~/.codex/"),
    ("$HOME/.claude/", "$HOME/.codex/"),
    ("${HOME}/.claude/", "${HOME}/.codex/"),
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


def sanitize_text(text: str) -> str:
    updated = text
    for old, new in LINE_REPLACEMENTS:
        updated = updated.replace(old, new)
    return updated


def sanitize_root(root: pathlib.Path) -> None:
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
        if not current.is_file():
            continue

        try:
            text = current.read_text()
        except UnicodeDecodeError:
            continue
        except Exception:
            continue

        updated = sanitize_text(text)
        if updated != text:
            current.write_text(updated)


for root_arg in sys.argv[1:]:
    sanitize_root(pathlib.Path(root_arg))
PY
