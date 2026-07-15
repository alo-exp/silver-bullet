#!/usr/bin/env python3
"""Render an agent-specific skill bundle from the canonical skills tree."""

from __future__ import annotations

import argparse
import contextlib
import errno
import fcntl
import os
import pathlib
import re
import shutil
import sys
import time

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


def resolve_codex_host_agnostic_terms(text: str) -> str:
    updated = text
    for old, new in (
        ("alo-labs-secondary host", "alo-labs-codex"),
        (".secondary host", ".codex"),
        ("secondary host", "Codex"),
    ):
        updated = updated.replace(old, new)
    return updated


def resolve_cursor_host_agnostic_terms(text: str) -> str:
    updated = text
    for old, new in (
        ("alo-labs-secondary host", "alo-labs"),
        (".secondary host", ".cursor"),
        ("secondary host", "Cursor"),
    ):
        updated = updated.replace(old, new)
    return updated


def resolve_claude_host_agnostic_terms(text: str) -> str:
    updated = text
    for old, new in (
        ("alo-labs-secondary host", "alo-labs"),
        (".secondary host", ".claude"),
        ("secondary host", "Codex"),
        ("primary host", "Claude Code"),
    ):
        updated = updated.replace(old, new)
    return updated


CURSOR_REPLACEMENTS = [
    ("${CLAUDE_PLUGIN_ROOT}", "${CURSOR_PLUGIN_ROOT}"),
    ("Claude Code", "Cursor"),
    ("Claude settings", "Cursor hooks.json"),
    (".codex/settings.json", ".cursor/hooks.json"),
    ("merge-hooks.py", "merge-cursor-hooks.py"),
    ("PostToolUse/Skill or Codex `silver-bullet invoke-skill`", "PostToolUse/Skill (Cursor Skill tool) or `silver-bullet invoke-skill`"),
    ("`/compact`", "context compaction"),
    ("AskUserQuestion", "direct user interaction"),
]

CODEX_REPLACEMENTS = [
    ("`context compaction`", "context compaction"),
    ("PostToolUse/Skill or Codex `silver-bullet invoke-skill`", "Claude Skill event or Codex `silver-bullet invoke-skill`"),
    ("`PostToolUse/Skill` does not fire", "No supported skill invocation event/receipt is observed"),
    ("Manually record skills in agent-mode sessions", "Use supported skill invocation channels in agent-mode sessions"),
    ("invoke each required skill and then explicitly write its name to the SB state file via a Bash command. This is brittle and not recommended for releases.", "invoke each required skill through the active runtime's supported channel. Direct state-file writes are not supported and must not be used for releases."),
    ("dispatch it as a subagent via the Agent tool", "delegate it through the active runtime's supported subagent or delegation mechanism"),
    ("Agent tool", "active runtime delegation mechanism"),
    ("If subagent dispatch is not possible, ask the user to run `/compact` before proceeding, then continue the step at full thoroughness.", "If subagent dispatch is not possible, summarize the current context or continue in a fresh context before proceeding, then continue the step at full thoroughness."),
    ("If subagent dispatch is not possible, ask the user to run `context compaction` before proceeding, then continue the step at full thoroughness.", "If subagent dispatch is not possible, summarize the current context or continue in a fresh context before proceeding, then continue the step at full thoroughness."),
    ("claude mcp install silver-bullet@alo-labs", "bash \"$HOME/.codex/plugins/cache/alo-labs-codex/silver-bullet/current/scripts/install-codex.sh\" --purge-legacy-skills"),
    ("Read/Edit/Write tools", "active runtime file-reading and file-editing mechanisms"),
    ("Edit/Write tools", "active runtime file-editing mechanisms"),
    ("Read tool", "active runtime file-reading mechanism"),
    ("Write tool", "active runtime file-writing mechanism"),
    ("Edit tool", "active runtime file-editing mechanism"),
    ("Then invoke `/compact` via the Skill tool to compact the loaded context before proceeding.", "Then summarize the loaded context and continue without relying on context compaction."),
    ("If context >90%: display `Context exhaustion imminent. Running /compact before continuing.` then invoke `/compact`", "If context >90%: display `Context exhaustion imminent. Summarize the current context before continuing.` then continue in a fresh context or subagent"),
    ("If context >80%: display `/compact recommendation: Context window at ~80%. Consider running /compact before continuing.`", "If context >80%: display a context-compaction recommendation and consider summarizing the current context before continuing."),
    ("ask the user to run /compact before proceeding", "ask the user to summarize the current context or continue in a fresh subagent before proceeding"),
    ("skip /compact", "skip context compaction"),
    ("run /compact", "summarize the context"),
    ("invoke /compact", "summarize the context"),
    ("/compact", "context compaction"),
    ("all via Skill tool", "all through the active runtime's SB-recognized skill invocation channel"),
    ("via the Skill tool", "through the active runtime's SB-recognized skill invocation channel"),
    ("via Skill tool", "through the active runtime's SB-recognized skill invocation channel"),
    ("Skill tool invocations", "supported skill invocation events/receipts"),
    ("Skill tool invocation", "supported skill invocation"),
    ("Skill tool calls", "supported skill invocation events/receipts"),
    ("Skill tool", "runtime-native skill invocation channel"),
    ("PostToolUse/Skill", "PostToolUse/Skill or Codex invoke-skill receipt"),
    ("PostToolUse/Skill or Codex invoke-skill receipt" + " or Codex invoke-skill receipt", "PostToolUse/Skill or Codex invoke-skill receipt"),
    (os.path.join("~", ".claude") + "/", os.path.join("~", ".codex") + "/"),
    ("$HOME" + "/.codex/", "$HOME" + "/.codex/"),
    ("${HOME}" + "/.codex/", "${HOME}" + "/.codex/"),
    (".codex/", ".codex/"),
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
    ("**Setup requirement:** Every new project must have `.planning/config.json` containing `\"model_profile\": \"balanced\"`. Run after `/gsd-new-project`:\n```bash\nnode \"$HOME/.codex/get-shit-done/bin/gsd-tools.cjs\" config-get model_profile\n```\nIf not `balanced`, run `/gsd-set-profile balanced`.\n\n> **Anti-Skip:** GSD subagent model routing is automatic once `model_profile` is set. You are violating this rule if `.planning/config.json` is missing `model_profile` or uses legacy `planner_model`/`researcher_model`/`checker_model` fields.", "**Setup note:** Do not require `.planning/config.json model_profile` fields as part of Silver Bullet setup. If the active host or an external tool supports model preferences, configure them at the host/tool layer, not in SB-managed workflow instructions.\n\n> **Anti-Skip:** Do not encode subagent model routing policy in Silver Bullet setup files. Host/tool configuration owns model choice."),
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
        route = name.split(":", 1)[1]
        title = humanize_codex_skill_name(route)
    elif current_title:
        title = current_title.removeprefix("Silver: ").strip()
    else:
        title = humanize_codex_skill_name(name)

    # Codex already renders `silver:*` skills under the native `/Silver:` group.
    # Prefixing their title too produces `/Silver: Silver: ...` in the picker.
    if name == "silver" or name.startswith("silver:"):
        return title

    # A few SB helper skills keep non-silver canonical names for compatibility.
    # Keep those grouped under the Silver picker title without changing their name.
    return f"Silver: {title}"


def yaml_quote_scalar(value: str) -> str:
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def yaml_unquote_scalar(value: str) -> str:
    stripped = value.strip()
    if len(stripped) >= 2 and stripped[0] == stripped[-1] and stripped[0] in {'"', "'"}:
        return stripped[1:-1]
    return stripped


def quote_codex_frontmatter_scalars(text: str) -> str:
    lines = text.splitlines(keepends=True)
    if not lines or lines[0].strip() != "---":
        return text

    for idx, line in enumerate(lines[1:], start=1):
        if line.strip() == "---":
            break
        match = re.match(r"^([A-Za-z0-9_-]+:\s*)(.+?)(\r?\n?)$", line)
        if not match:
            continue
        prefix, value, newline = match.groups()
        stripped = value.strip()
        if stripped in {">", "|", ">-", "|-"} or not stripped:
            continue
        if stripped[0] in {'"', "'"}:
            continue
        if ":" in stripped or stripped.startswith(("/", "@", "`")):
            lines[idx] = f"{prefix}{yaml_quote_scalar(stripped)}{newline}"

    return "".join(lines)


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
            skill_name = yaml_unquote_scalar(name_match.group(2))
            continue
        if re.match(r"^title:\s*", line) and title_idx is None:
            title_idx = idx
            current_title = yaml_unquote_scalar(re.sub(r"^title:\s*", "", line))

    if frontmatter_end is None or name_idx is None or skill_name is None:
        return text

    title = codex_title_for_name(skill_name, current_title=current_title)
    title_line = f"title: {yaml_quote_scalar(title)}\n"
    if title_idx is not None and title_idx < frontmatter_end:
        lines[title_idx] = title_line
    else:
        lines.insert(name_idx + 1, title_line)

    return "".join(lines)


PROTECTED_RUNTIME_SUBSTRINGS = (
    "scripts/lib/install-cursor/templates/cursor-rules/",
    "templates/cursor-rules/",
    ".cursor/rules/",
)


def _mask_protected_runtime_subs(text: str) -> tuple[str, list[tuple[str, str]]]:
    masks: list[tuple[str, str]] = []
    updated = text
    for index, protected in enumerate(PROTECTED_RUNTIME_SUBSTRINGS):
        if protected not in updated:
            continue
        token = f"__SB_PROTECTED_RUNTIME_{index}__"
        masks.append((token, protected))
        updated = updated.replace(protected, token)
    return updated, masks


def _unmask_protected_runtime_subs(text: str, masks: list[tuple[str, str]]) -> str:
    updated = text
    for token, protected in masks:
        updated = updated.replace(token, protected)
    return updated


def runtime_placeholders(agent: str) -> list[tuple[str, str]]:
    current_home = f"$HOME/.{agent}"
    others = [name for name in ("claude", "codex", "cursor") if name != agent]

    pairs: list[tuple[str, str]] = [
        ("${SB_RUNTIME_HOME_ROOT}", current_home),
        ("${SB_RUNTIME_STATE_DIR}", f"{current_home}/.silver-bullet"),
        ("${SB_RUNTIME_PLUGIN_CACHE_ROOT}", f"{current_home}/plugins/cache"),
        (f"$HOME/.{agent}/", f"{current_home}/"),
        (f"$HOME/.{agent}", current_home),
        (f"${{HOME}}/.{agent}/", f"${{HOME}}/.{agent}/"),
        (f"${{HOME}}/.{agent}", f"${{HOME}}/.{agent}"),
        (f".{agent}/", f".{agent}/"),
        (f".{agent}", f".{agent}"),
    ]
    for opposite in others:
        opposite_home = f"$HOME/.{opposite}"
        pairs.extend(
            [
                (os.path.join("~", f".{opposite}") + "/", f"{current_home}/"),
                (os.path.join("~", f".{opposite}"), current_home),
                (f"{opposite_home}/", f"{current_home}/"),
                (opposite_home, current_home),
                (f"$HOME/.{opposite}/", f"$HOME/.{agent}/"),
                (f"$HOME/.{opposite}", f"$HOME/.{agent}"),
                (f"${{HOME}}/.{opposite}/", f"${{HOME}}/.{agent}/"),
                (f"${{HOME}}/.{opposite}", f"${{HOME}}/.{agent}"),
            ]
        )
    return pairs


def sanitize_cursor_text(text: str) -> str:
    # Preserve cross-host delegation rows — do not rewrite Claude Code host label to Cursor.
    host_row_token = "__SB_CURSOR_HOST_ROW_CLAUDE_CODE__"
    delegate_executor_tui = "__SB_CURSOR_DELEGATE_CLAUDE_CODE_TUI__"
    delegate_executor_runs = "__SB_CURSOR_DELEGATE_CLAUDE_CODE_EXECUTES__"
    updated = resolve_cursor_host_agnostic_terms(text).replace("| **Claude Code** |", f"| **{host_row_token}** |")
    updated = updated.replace(
        "when Claude Code TUI is the intended executor", delegate_executor_tui
    )
    updated = updated.replace("while Claude Code executes", delegate_executor_runs)
    for old, new in CURSOR_REPLACEMENTS:
        updated = updated.replace(old, new)
    updated = updated.replace(f"| **{host_row_token}** |", "| **Claude Code** |")
    updated = updated.replace(
        delegate_executor_tui, "when Claude Code TUI is the intended executor"
    )
    updated = updated.replace(delegate_executor_runs, "while Claude Code executes")
    return updated


def sanitize_codex_text(text: str) -> str:
    updated = resolve_codex_host_agnostic_terms(text)
    for old, new in CODEX_REPLACEMENTS:
        updated = updated.replace(old, new)
    return updated


def sanitize_text(text: str, agent: str, preserve_runtime_placeholders: bool = False) -> str:
    updated = text
    if agent in {"claude", "codex", "cursor"}:
        updated = rewrite_names(updated)
    if agent == "claude":
        updated = resolve_claude_host_agnostic_terms(updated)
    if agent == "codex":
        updated = ensure_codex_picker_title(updated)
        updated = quote_codex_frontmatter_scalars(updated)
    if not preserve_runtime_placeholders:
        updated, protected_masks = _mask_protected_runtime_subs(updated)
        for old, new in runtime_placeholders(agent):
            updated = updated.replace(old, new)
        updated = _unmask_protected_runtime_subs(updated, protected_masks)
        if agent == "codex":
            home = os.path.expanduser("~")
            if home:
                updated = updated.replace(f"{home}/.codex", "$HOME/.codex")
    if agent == "codex":
        updated = sanitize_codex_text(updated)
    elif agent == "cursor":
        updated = sanitize_cursor_text(updated)
    return updated


def _safe_rmtree(path: pathlib.Path, *, retries: int = 8, delay: float = 0.05) -> None:
    if not path.exists() and not path.is_symlink():
        return

    last_error: OSError | None = None
    for attempt in range(retries):
        try:
            if path.is_symlink() or path.is_file():
                path.unlink()
                return
            shutil.rmtree(path)
            return
        except FileNotFoundError:
            return
        except OSError as exc:
            last_error = exc
            if exc.errno in {errno.ENOTEMPTY, errno.EBUSY, errno.EEXIST} and attempt + 1 < retries:
                time.sleep(delay * (attempt + 1))
                continue
            raise

    if last_error is not None:
        raise last_error


@contextlib.contextmanager
def _render_lock(dest_root: pathlib.Path):
    lock_path = dest_root.parent / f".{dest_root.name}.render.lock"
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    with open(lock_path, "w", encoding="utf-8") as lock_file:
        fcntl.flock(lock_file.fileno(), fcntl.LOCK_EX)
        yield


def rewrite_file(path: pathlib.Path, agent: str) -> bool:
    if path.name == "runtime-paths.sh" and "hooks" in path.parts:
        return False

    for attempt in range(3):
        try:
            if not path.is_file():
                return False
            text = path.read_text()
        except UnicodeDecodeError:
            return False
        except OSError:
            if attempt + 1 >= 3:
                return False
            time.sleep(0.05 * (attempt + 1))
            continue

        preserve_runtime_placeholders = "hooks" in path.parts
        updated = sanitize_text(text, agent, preserve_runtime_placeholders=preserve_runtime_placeholders)
        if updated == text:
            return False

        try:
            path.write_text(updated)
            return True
        except OSError:
            if attempt + 1 >= 3:
                return False
            time.sleep(0.05 * (attempt + 1))

    return False


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


def rename_colon_route_skill_directories(root: pathlib.Path, *, host: str) -> None:
    """Align skill folder names with silver: frontmatter routes.

    Hosts list skills from both directory names and SKILL.md ``name:`` fields.
    Hyphen directories (``silver-feature``) plus colon names (``silver:feature``)
    produce duplicate picker entries (skill vs subagent on Cursor); rename dirs
    to the colon form only.
    """
    if not root.is_dir():
        return

    for child in sorted(root.iterdir(), key=lambda path: path.name):
        if not child.is_dir() or child.is_symlink():
            continue
        dirname = child.name
        if dirname == "silver" or not dirname.startswith("silver-"):
            continue
        route = dirname.removeprefix("silver-")
        target = child.parent / f"silver:{route}"
        if target.exists():
            raise SystemExit(f"{host} skill rename collision: {dirname} -> {target.name}")
        child.rename(target)


def read_skill_frontmatter(path: pathlib.Path) -> dict[str, str]:
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except UnicodeDecodeError:
        lines = path.read_text(errors="replace").splitlines()
    if not lines or lines[0].strip() != "---":
        return {}

    meta: dict[str, str] = {}
    for line in lines[1:]:
        if line.strip() == "---":
            break
        match = re.match(r"^([A-Za-z0-9_-]+):\s*(.*)$", line)
        if not match:
            continue
        meta[match.group(1)] = match.group(2).strip().strip('"').strip("'")
    return meta


def set_user_invocable_false(path: pathlib.Path) -> bool:
    try:
        text = path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        text = path.read_text(errors="replace")
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return False

    end = 1
    while end < len(lines) and lines[end].strip() != "---":
        end += 1
    if end >= len(lines):
        return False

    fm_lines = lines[1:end]
    body_lines = lines[end + 1 :]
    found = False
    updated_fm: list[str] = []
    for line in fm_lines:
        if line.startswith("user-invocable:"):
            if line.strip() != "user-invocable: false":
                updated_fm.append("user-invocable: false")
            else:
                updated_fm.append(line)
            found = True
        else:
            updated_fm.append(line)
    if not found:
        updated_fm.append("user-invocable: false")

    trailing_newline = "\n" if text.endswith("\n") else ""
    updated = "---\n" + "\n".join(updated_fm) + "\n---"
    if body_lines:
        updated += "\n" + "\n".join(body_lines)
    updated += trailing_newline
    if updated == text:
        return False
    path.write_text(updated, encoding="utf-8")
    return True


def command_stub_routes(commands_dir: pathlib.Path) -> set[str]:
    routes: set[str] = set()
    if not commands_dir.is_dir():
        return routes
    for path in sorted(commands_dir.glob("*.md")):
        name = read_skill_frontmatter(path).get("name", "").strip() or path.stem
        if name.startswith("silver-"):
            name = "silver:" + name[len("silver-") :]
        if name:
            routes.add(name)
    return routes


def suppress_command_stub_skills_from_picker(root: pathlib.Path, commands_dir: pathlib.Path) -> None:
    """Hide picker skills that already have plugin command stubs.

    Codex still discovers mirrored bundle skills in some layouts; mark them
    internal so only native slash/command surfaces stay public.
    """
    routes = command_stub_routes(commands_dir)
    if not routes:
        return

    for skill_md in sorted(root.glob("*/SKILL.md")):
        name = read_skill_frontmatter(skill_md).get("name", "").strip()
        if name in routes:
            set_user_invocable_false(skill_md)


def exclude_command_stub_skills_from_cursor_subagent_surface(
    root: pathlib.Path, commands_dir: pathlib.Path
) -> None:
    """Drop command-covered skills from the Cursor subagent surface.

    Cursor registers plugin ``commands/`` as slash entries and every directory
    under ``plugin.json`` ``skills`` as subagents, regardless of
    ``user-invocable: false``. Routes with both surfaces duplicate in the menu;
    keep slash commands public and retain full instructions in ``skill-source/``.
    """
    routes = command_stub_routes(commands_dir)
    if not routes:
        return

    for skill_md in sorted(root.glob("*/SKILL.md")):
        name = read_skill_frontmatter(skill_md).get("name", "").strip()
        if name not in routes:
            continue
        skill_dir = skill_md.parent
        _safe_rmtree(skill_dir)


def render_bundle(source_root: pathlib.Path, dest_root: pathlib.Path, agent: str) -> None:
    if not source_root.is_dir():
        raise SystemExit(f"source root missing: {source_root}")

    dest_root.parent.mkdir(parents=True, exist_ok=True)
    with _render_lock(dest_root):
        staging = dest_root.parent / f".{dest_root.name}.staging-{os.getpid()}"
        try:
            _safe_rmtree(staging)
            shutil.copytree(source_root, staging, symlinks=False)
            if agent in {"claude", "cursor"}:
                for metadata in staging.glob("*/agents/openai.yaml"):
                    metadata.unlink()
            sanitize_root(staging, agent)
            if agent in {"claude", "cursor"}:
                rename_colon_route_skill_directories(staging, host=agent)
            if agent in {"cursor", "codex"}:
                commands_dir = source_root.parent / "plugins" / "silver-bullet" / "commands"
                suppress_command_stub_skills_from_picker(staging, commands_dir)
                if agent == "cursor":
                    exclude_command_stub_skills_from_cursor_subagent_surface(staging, commands_dir)
            _safe_rmtree(dest_root)
            staging.rename(dest_root)
        except Exception:
            _safe_rmtree(staging)
            raise


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("render", "sanitize"))
    parser.add_argument("--agent", required=True, choices=("claude", "codex", "cursor"))
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
