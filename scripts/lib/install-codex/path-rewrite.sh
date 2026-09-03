#!/usr/bin/env bash
# Codex install module — auto-split from install-codex.sh
rewrite_codex_bundle_host_paths() {
  local marketplace_root
  local package_root

  marketplace_root="$(codex_marketplace_root)"
  package_root="${marketplace_root}/plugins/silver-bullet"

  [[ -d "$package_root" ]] || return 0

  python3 - "$marketplace_root" "$package_root" "${CODEX_HOME_ROOT}/.codex/plugins/cache" <<'PY'
import json
import os
import pathlib
import re
import sys

marketplace_root = pathlib.Path(sys.argv[1])
package_root = pathlib.Path(sys.argv[2])
cache_roots = [pathlib.Path(arg) for arg in sys.argv[3:] if arg]

canonical_hooks_path = marketplace_root / "hooks" / "hooks.json"

install_targets = [package_root]
for cache_root in cache_roots:
    package_cache_root = cache_root / "alo-labs-codex" / "silver-bullet"
    if not package_cache_root.exists():
        continue
    for version_dir in package_cache_root.iterdir():
        if version_dir.name == "current" or not version_dir.is_dir():
            continue
        install_targets.append(version_dir)

path_rewrite_roots = [package_root]
for cache_root in cache_roots:
    package_cache_root = cache_root / "alo-labs-codex" / "silver-bullet"
    if not package_cache_root.exists():
        continue
    for version_dir in package_cache_root.iterdir():
        if version_dir.name == "current" or not version_dir.is_dir():
            continue
        path_rewrite_roots.append(version_dir)

for optional_sub in ("host-bundles/codex", "agents/codex"):
    optional_root = marketplace_root / optional_sub
    if optional_root.is_dir():
        path_rewrite_roots.append(optional_root)

skip_path_parts = {
    ".git",
    "tests",
    ".planning",
    "node_modules",
    "graphify-out",
    ".agentmemory",
    ".visual-audit",
}

path_segment_re = re.compile(r'/\.claude(?=/|$)')
home_claude_replacements = (
    ("os.homedir(), '.codex'", "os.homedir(), '.codex'"),
    ('os.homedir(), ".codex"', 'os.homedir(), ".codex"'),
    ("os.homedir() + '/.codex'", "os.homedir() + '/.codex'"),
    ('os.homedir() + "/.codex"', 'os.homedir() + "/.codex"'),
)


def rewrite_hook_manifest(file_path, source_text=None):
    if file_path.resolve() == canonical_hooks_path.resolve():
        return False

    try:
        data = json.loads(source_text if source_text is not None else file_path.read_text())
    except Exception:
        return False

    if not isinstance(data, dict) or "hooks" not in data:
        return False

    changed = source_text is not None
    adapter_path = str(package_root / "hooks" / "codex-hook-adapter.sh")

    def rewrite_value(value):
        nonlocal changed
        if isinstance(value, str):
            updated = value.replace("${CLAUDE_PLUGIN_ROOT}", str(package_root))
            if file_path.name == "hooks.json":
                for src, dst in home_claude_replacements:
                    updated = updated.replace(src, dst)
                updated = updated.replace("\\.codex/", "\\.codex/")
                updated = updated.replace(".codex/", ".codex/")
                updated = updated.replace("~/\\.claude", "~/.codex")
                updated = updated.replace("$HOME/.codex", "$HOME/.codex")
                updated = updated.replace("${HOME}/.codex", "${HOME}/.codex")
                updated = path_segment_re.sub("/.codex", updated)
            if updated != value:
                changed = True
            return updated
        if isinstance(value, list):
            return [rewrite_value(item) for item in value]
        if isinstance(value, dict):
            return {key: rewrite_value(item) for key, item in value.items()}
        return value

    updated = rewrite_value(data)

    shell_like_matchers = ("Bash", "shell", "exec_command")

    def dedupe_hooks(hooks):
        deduped = []
        seen = set()
        for hook in hooks:
            key = json.dumps(hook, sort_keys=True)
            if key in seen:
                continue
            seen.add(key)
            deduped.append(hook)
        return deduped

    def codex_matchers_for(matcher):
        if not isinstance(matcher, str) or "|" not in matcher and matcher != "Bash":
            return [matcher]

        parts = [part for part in matcher.split("|") if part]
        if not parts:
            return [matcher]

        if not any(part in shell_like_matchers for part in parts):
            return [matcher]

        non_shell_parts = [part for part in parts if part not in shell_like_matchers]
        expanded = []
        if non_shell_parts:
            expanded.append("|".join(non_shell_parts))
        expanded.extend(shell_like_matchers)

        ordered = []
        seen = set()
        for item in expanded:
            if item in seen:
                continue
            seen.add(item)
            ordered.append(item)
        return ordered or [matcher]

    normalized_hooks = {}
    for event_name, groups in updated.get("hooks", {}).items():
        merged_groups = {}
        ordered_matchers = []
        for group in groups:
            hooks = dedupe_hooks(group.get("hooks", []))
            for matcher in codex_matchers_for(group.get("matcher", "")):
                if matcher not in merged_groups:
                    merged_groups[matcher] = {"matcher": matcher, "hooks": []}
                    ordered_matchers.append(matcher)
                existing = merged_groups[matcher]["hooks"]
                seen_commands = {
                    json.dumps(hook, sort_keys=True)
                    for hook in existing
                }
                for hook in hooks:
                    hook_key = json.dumps(hook, sort_keys=True)
                    if hook_key in seen_commands:
                        continue
                    existing.append(hook)
                    seen_commands.add(hook_key)
        normalized_hooks[event_name] = [merged_groups[matcher] for matcher in ordered_matchers]

    for event_name, groups in normalized_hooks.items():
        for group in groups:
            hooks = group.get("hooks", [])
            for hook in hooks:
                if hook.get("type") != "command":
                    continue
                command = hook.get("command", "")
                if not isinstance(command, str) or not command:
                    continue
                if adapter_path in command:
                    continue
                hook["command"] = f'"{adapter_path}" "{event_name}" {command}'
                changed = True

    if normalized_hooks != updated.get("hooks", {}):
        updated["hooks"] = normalized_hooks
        changed = True

    if changed:
        file_path.write_text(json.dumps(updated, indent=2) + "\n")
    return changed


for root in path_rewrite_roots:
    for file_path in root.rglob("*"):
        if not file_path.is_file() or file_path.is_symlink():
            continue
        if skip_path_parts.intersection(file_path.parts):
            continue
        if file_path.name == "runtime-paths.sh" and "hooks" in file_path.parts:
            continue
        if file_path.name == "hooks.json":
            continue
        try:
            text = file_path.read_text()
        except UnicodeDecodeError:
            continue
        except Exception:
            continue

        updated = text
        for src, dst in home_claude_replacements:
            updated = updated.replace(src, dst)
        updated = updated.replace("\\.codex/", "\\.codex/")
        updated = updated.replace(".codex/", ".codex/")
        updated = updated.replace("~/\\.claude", "~/.codex")
        updated = updated.replace("$HOME/.codex", "$HOME/.codex")
        updated = updated.replace("${HOME}/.codex", "${HOME}/.codex")
        updated = path_segment_re.sub("/.codex", updated)
        home = os.path.expanduser("~")
        if home:
            updated = updated.replace(f"{home}/.codex", "$HOME/.codex")
            updated = updated.replace(f"{home}/.claude", "$HOME/.codex")

        if updated != text:
            file_path.write_text(updated)

if canonical_hooks_path.is_file():
    try:
        canonical_hooks_text = canonical_hooks_path.read_text()
    except Exception:
        canonical_hooks_text = ""
    if canonical_hooks_text:
        for root in install_targets:
            hooks_path = root / "hooks" / "hooks.json"
            if hooks_path.resolve() == canonical_hooks_path.resolve():
                continue
            hooks_path.parent.mkdir(parents=True, exist_ok=True)
            rewrite_hook_manifest(hooks_path, canonical_hooks_text)
PY
}

