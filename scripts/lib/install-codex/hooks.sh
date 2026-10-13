#!/usr/bin/env bash
# Codex install module — auto-split from install-codex.sh
normalize_codex_hook_async_flags() {
  local marketplace_root
  marketplace_root="$(codex_marketplace_root)"

  python3 - "$marketplace_root" "${CODEX_HOME_ROOT}/.codex/plugins/cache" <<'PY'
import json
import pathlib
import sys

marketplace_root = pathlib.Path(sys.argv[1])
cache_roots = [pathlib.Path(sys.argv[2])]

# The marketplace keeps a top-level hooks tree and a materialized plugin copy.
# Both can carry stale async flags, so normalize each surface before Codex reads it.
candidate_files = [
    marketplace_root / "hooks/hooks.json",
    marketplace_root / "plugins/silver-bullet/hooks/hooks.json",
]

for cache_root in cache_roots:
    package_root = cache_root / "alo-labs-codex" / "silver-bullet"
    if not package_root.exists():
        continue
    for version_dir in sorted((p for p in package_root.iterdir() if p.is_dir()), key=lambda p: p.name):
        if version_dir.name == "current":
            continue
        candidate_files.append(version_dir / "hooks/hooks.json")

seen = set()
for hooks_json in candidate_files:
    key = str(hooks_json)
    if key in seen or not hooks_json.is_file():
        continue
    seen.add(key)

    data = json.loads(hooks_json.read_text())
    changed = False
    for event_items in data.get("hooks", {}).values():
        for item in event_items:
            for hook in item.get("hooks", []):
                if hook.get("async") is True:
                    hook["async"] = False
                    changed = True

    if changed:
        hooks_json.write_text(json.dumps(data, indent=2) + "\n")
PY
}


seed_silver_bullet_hook_trust_state() {
  local marketplace_root
  marketplace_root="$(codex_marketplace_root)"
  [[ -d "${marketplace_root}/plugins/silver-bullet" ]] || return 0

  python3 - "${marketplace_root}/plugins/silver-bullet" "${CODEX_HOME_ROOT}/.codex/config.toml" "$MERGE_USER_HOOKS" "$CODEX_HOME_ROOT" <<'PY'
import hashlib
import json
import os
import pathlib
import re
import sys

package_root = pathlib.Path(sys.argv[1])
target_paths = [pathlib.Path(sys.argv[2])]
merge_user_hooks = sys.argv[3] == "1"
home = pathlib.Path(sys.argv[4]).expanduser()
resolved_home = home.resolve()

package_hooks_src = package_root / "hooks" / "hooks.json"
if not package_hooks_src.is_file():
    sys.exit(0)

package_hooks_prefix = "silver-bullet@alo-labs-codex:hooks/hooks.json"
raw_user_hooks_prefix = str(home / ".codex" / "hooks.json")
resolved_user_hooks_prefix = str(resolved_home / ".codex" / "hooks.json")

def event_slug(name: str) -> str:
    return re.sub(r"(?<!^)(?=[A-Z])", "_", name).lower()

def canonical_json(value):
    if isinstance(value, dict):
        return {key: canonical_json(value[key]) for key in sorted(value) if value[key] is not None}
    if isinstance(value, list):
        return [canonical_json(item) for item in value]
    return value

def hook_current_hash(event_name, matcher, hook):
    hook_type = hook.get("type")
    if hook_type is None and "command" in hook:
        hook_type = "command"
    if hook_type != "command":
        return None
    if hook.get("async", False):
        return None

    command = hook.get("command", "")
    command_windows = hook.get("commandWindows")
    if command_windows is None:
        command_windows = hook.get("command_windows")
    if os.name == "nt" and command_windows:
        command = command_windows
    if not str(command).strip():
        return None

    normalized_hook = {
        "type": "command",
        "command": command,
        "timeout": max(int(hook.get("timeout", 600) or 600), 1),
        "async": False,
    }
    status_message = hook.get("statusMessage")
    if status_message is None:
        status_message = hook.get("status_message")
    if status_message is not None:
        normalized_hook["statusMessage"] = status_message

    identity = {
        "event_name": event_slug(event_name),
        "hooks": [normalized_hook],
    }
    if matcher is not None:
        identity["matcher"] = matcher

    serialized = json.dumps(
        canonical_json(identity),
        separators=(",", ":"),
        sort_keys=True,
    ).encode("utf-8")
    return "sha256:" + hashlib.sha256(serialized).hexdigest()

def first_existing(*paths):
    for path in paths:
        if path.is_file():
            return path
    return None

def hooks_data_for(path):
    if path is None:
        return {}
    return json.loads(path.read_text()).get("hooks", {})

resolved_sources = {}
resolved_sources[package_hooks_prefix] = package_hooks_src
if merge_user_hooks:
    user_hooks_src = first_existing(home / ".codex" / "hooks.json")
    for prefix in [raw_user_hooks_prefix, resolved_user_hooks_prefix]:
        if prefix not in resolved_sources:
            resolved_sources[prefix] = user_hooks_src

entries = []

for prefix, source_path in resolved_sources.items():
    for event_name, groups in hooks_data_for(source_path).items():
        slug = event_slug(event_name)
        for group_index, group in enumerate(groups):
            for hook_index, hook in enumerate(group.get("hooks", [])):
                digest = hook_current_hash(event_name, group.get("matcher"), hook)
                if digest is None:
                    continue
                key = f"{prefix}:{slug}:{group_index}:{hook_index}"
                entries.append((key, digest))

def render_entries():
    lines = []
    for key, digest in entries:
        lines.append(f'[hooks.state."{key}"]')
        lines.append(f'trusted_hash = "{digest}"')
        lines.append("")
    return lines

for config_path in target_paths:
    text = config_path.read_text() if config_path.is_file() else ""
    lines = text.splitlines()
    output = []
    changed = False
    hooks_state_seen = False
    inserted = False
    i = 0

    while i < len(lines):
        line = lines[i]
        if line == "[hooks.state]":
            hooks_state_seen = True
            output.append(line)
            i += 1
            continue

        if hooks_state_seen:
            if (
                line.startswith(f'[hooks.state."{package_hooks_prefix}')
                or line.startswith(f'[hooks.state."{raw_user_hooks_prefix}')
                or line.startswith(f'[hooks.state."{resolved_user_hooks_prefix}')
            ):
                changed = True
                i += 1
                while i < len(lines) and not lines[i].startswith('['):
                    i += 1
                continue

            if line.startswith("[") and not line.startswith("[hooks.state."):
                if not inserted:
                    output.extend(render_entries())
                    inserted = True
                    changed = True
                hooks_state_seen = False
                output.append(line)
                i += 1
                continue

        output.append(line)
        i += 1

    if hooks_state_seen and not inserted:
        output.extend(render_entries())
        inserted = True
        changed = True

    if not hooks_state_seen and not inserted:
        if output and output[-1] != "":
            output.append("")
        output.append("[hooks.state]")
        output.extend(render_entries())
        changed = True

    if changed:
        new_text = "\n".join(output).rstrip("\n") + "\n"
        config_path.write_text(new_text)
PY
}


merge_silver_bullet_hooks_into_user_config() {
  local marketplace_root package_root
  marketplace_root="$(codex_marketplace_root)"
  package_root="${marketplace_root}/plugins/silver-bullet"

  [[ -d "${package_root}/hooks" ]] || return 0

  python3 - "$package_root" "${CODEX_HOME_ROOT}/.codex/hooks.json" <<'PY'
import json
import pathlib
import re
import sys

package_root = pathlib.Path(sys.argv[1])
target_paths = [pathlib.Path(sys.argv[2])]
hooks_src = package_root / "hooks" / "hooks.json"

if not hooks_src.is_file():
    sys.exit(0)

src_data = json.loads(hooks_src.read_text())
sb_hooks = src_data.get("hooks", {})

def sub_path(obj):
    if isinstance(obj, str):
        return obj.replace("${CLAUDE_PLUGIN_ROOT}", str(package_root))
    if isinstance(obj, list):
        return [sub_path(item) for item in obj]
    if isinstance(obj, dict):
        return {key: sub_path(value) for key, value in obj.items()}
    return obj

sb_hooks = sub_path(sb_hooks)
sb_hook_re = re.compile(r'/silver-bullet(?:/[^/]+)?/hooks/')

for hooks_path in target_paths:
    if hooks_path.is_file():
        data = json.loads(hooks_path.read_text())
    else:
        data = {}

    hooks_by_event = data.setdefault("hooks", {})
    changed = False

    # Purge stale SB hooks from previous installs first.
    for event_name in list(hooks_by_event.keys()):
        groups = hooks_by_event[event_name]
        kept_groups = []

        for group in groups:
            hooks = group.get("hooks", [])
            kept_hooks = [hook for hook in hooks if not sb_hook_re.search(hook.get("command", ""))]

            if len(kept_hooks) != len(hooks):
                changed = True

            if kept_hooks:
                if len(kept_hooks) != len(hooks):
                    group = dict(group)
                    group["hooks"] = kept_hooks
                kept_groups.append(group)
            else:
                changed = True

        if kept_groups:
            hooks_by_event[event_name] = kept_groups
        elif event_name in hooks_by_event:
            del hooks_by_event[event_name]

    # Merge the current SB hook surface, deduping by command within each matcher group.
    for event_name, entries in sb_hooks.items():
        existing_event = hooks_by_event.setdefault(event_name, [])
        for new_group in entries:
            new_hooks_list = new_group.get("hooks", [])
            matcher = new_group.get("matcher", "")
            matched = next((g for g in existing_event if g.get("matcher", "") == matcher), None)
            if matched is None:
                matched = {"matcher": matcher, "hooks": []}
                existing_event.append(matched)
                changed = True
            for new_hook in new_hooks_list:
                new_cmd = new_hook.get("command", "")
                already_present = any(
                    h.get("command", "") == new_cmd
                    for h in matched.get("hooks", [])
                )
                if already_present:
                    continue

                matched.setdefault("hooks", []).append(new_hook)
                changed = True

    if changed:
        hooks_path.parent.mkdir(parents=True, exist_ok=True)
        hooks_path.write_text(json.dumps(data, indent=2) + "\n")
PY
}


