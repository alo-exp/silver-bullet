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


# Record Codex trust for Silver Bullet's own hooks in config.toml
# ([hooks.state."<key>"] trusted_hash = ...), so Codex runs them without a review prompt.
# Keys cover the package hooks (silver-bullet@alo-labs-codex:hooks/hooks.json:...) and, when
# SB merges its hooks into ~/.codex/hooks.json (Kay), the SB-owned entries there; the user's own
# hooks are never marked trusted. config.toml is edited structurally (R7-09): an existing table
# keeps its other keys, stale package entries go, nothing is declared twice, and comments and
# unknown tables survive. A config whose only fault is SB's own duplicated trust tables (left by
# older installers) is repaired; any other unparseable config is left alone with a warning,
# since Codex then simply asks the user to review the hooks.
seed_silver_bullet_hook_trust_state() {
  local marketplace_root
  marketplace_root="$(codex_marketplace_root)"
  [[ -d "${marketplace_root}/plugins/silver-bullet" ]] || return 0

  python3 - "${marketplace_root}/plugins/silver-bullet" "${CODEX_HOME_ROOT}/.codex/config.toml" "$MERGE_USER_HOOKS" \
    "$CODEX_HOME_ROOT" "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" <<'PY'
import hashlib
import json
import os
import pathlib
import re
import sys

package_root = pathlib.Path(sys.argv[1])
config_path = pathlib.Path(sys.argv[2])
merge_user_hooks = sys.argv[3] == "1"
home = pathlib.Path(sys.argv[4]).expanduser()
lib_dir = pathlib.Path(sys.argv[5])
sys.path.insert(0, str(lib_dir))
from sb_host_config import (  # noqa: E402
    ConfigError, is_sb_hook_command, read_json, read_toml_repairing, sb_hook_names, toml_string, write_toml,
)

package_hooks_src = package_root / "hooks" / "hooks.json"
if not package_hooks_src.is_file():
    sys.exit(0)

package_hooks_prefix = "silver-bullet@alo-labs-codex:hooks/hooks.json"
user_hooks_path = home / ".codex" / "hooks.json"
user_prefixes = list(dict.fromkeys([str(user_hooks_path), str(home.resolve() / ".codex" / "hooks.json")]))
names = sb_hook_names(lib_dir.parents[1] / "hooks", package_root / "hooks")


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


def trusted_entries(prefix, source, user_file):
    data = read_json(source) or {}
    events = data.get("hooks")
    entries = {}
    for event_name, groups in (events.items() if isinstance(events, dict) else ()):
        for group_index, group in enumerate(groups if isinstance(groups, list) else ()):
            hooks = group.get("hooks") if isinstance(group, dict) else None
            for hook_index, hook in enumerate(hooks if isinstance(hooks, list) else ()):
                if not isinstance(hook, dict):
                    continue
                if user_file and not is_sb_hook_command(
                    hook.get("command"), hook_names=names, install_roots=(str(package_root),)
                ):
                    continue
                digest = hook_current_hash(event_name, group.get("matcher"), hook)
                if digest is not None:
                    entries[f"{prefix}:{event_slug(event_name)}:{group_index}:{hook_index}"] = digest
    return entries


def sb_trust(path) -> bool:
    return len(path) >= 3 and path[:2] == ("hooks", "state") and path[2].startswith("silver-bullet@")


def load_config():
    doc, repaired = read_toml_repairing(config_path, sb_trust)
    if repaired:
        print(f"Repaired {config_path}: removed Silver Bullet hook-trust tables declared twice", file=sys.stderr)
    return doc


try:
    entries = trusted_entries(package_hooks_prefix, package_hooks_src, False)
    if merge_user_hooks and user_hooks_path.is_file():
        for prefix in user_prefixes:
            entries.update(trusted_entries(prefix, user_hooks_path, True))
    doc = load_config()
    doc.remove(lambda p: sb_trust(p) and p[2].startswith(package_hooks_prefix + ":") and p[2] not in entries)
    for key, digest in entries.items():
        doc.set_value(("hooks", "state", key), "trusted_hash", toml_string(digest))
    write_toml(config_path, doc)
except ConfigError as exc:
    print(f"WARN: Silver Bullet hook trust not seeded: {exc}. Codex will ask you to review the hooks.", file=sys.stderr)
PY
}


# Older installers could leave Silver Bullet's own hook-trust tables declared twice, which makes
# config.toml invalid TOML and would stop every later structural edit. Run first in install-codex.sh:
# when that is the file's only fault, those tables are removed (the trust seeding writes them
# again); any other fault is left alone, for the edit that needs it to report.
repair_silver_bullet_duplicate_trust_tables() {
  python3 - "${CODEX_HOME_ROOT}/.codex/config.toml" "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" <<'PY'
import sys

sys.path.insert(0, sys.argv[2])
from sb_host_config import ConfigError, read_toml_repairing, write_toml  # noqa: E402

path = sys.argv[1]
try:
    doc, repaired = read_toml_repairing(path, lambda p: len(p) >= 3 and p[:2] == ("hooks", "state") and p[2].startswith("silver-bullet@"))
    if repaired:
        write_toml(path, doc)
        print(f"Repaired {path}: removed Silver Bullet hook-trust tables declared twice", file=sys.stderr)
except ConfigError:
    pass
PY
}


# Merge Silver Bullet's hooks into ~/.codex/hooks.json for hosts that read only the user hook
# file (Kay, or SB_CODEX_MERGE_USER_HOOKS=1). Every entry Silver Bullet owns is replaced by the
# current package's, grouped by matcher; the user's own hooks are kept as they are. The write is
# atomic with a backup, and an unparseable or wrongly typed file is refused.
merge_silver_bullet_hooks_into_user_config() {
  local marketplace_root package_root
  marketplace_root="$(codex_marketplace_root)"
  package_root="${marketplace_root}/plugins/silver-bullet"

  [[ -d "${package_root}/hooks" ]] || return 0

  python3 - "$package_root" "${CODEX_HOME_ROOT}/.codex/hooks.json" "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" <<'PY'
import pathlib
import sys

package_root = pathlib.Path(sys.argv[1])
hooks_path = pathlib.Path(sys.argv[2])
lib_dir = pathlib.Path(sys.argv[3])
sys.path.insert(0, str(lib_dir))
from sb_host_config import ConfigError, is_sb_hook_command, read_json, sb_hook_names, write_json  # noqa: E402

names = sb_hook_names(lib_dir.parents[1] / "hooks", package_root / "hooks")


def sub_path(obj):
    if isinstance(obj, str):
        return obj.replace("${CLAUDE_PLUGIN_ROOT}", str(package_root))
    if isinstance(obj, list):
        return [sub_path(item) for item in obj]
    if isinstance(obj, dict):
        return {key: sub_path(value) for key, value in obj.items()}
    return obj


def owned(hook) -> bool:
    return isinstance(hook, dict) and is_sb_hook_command(
        hook.get("command"), hook_names=names, install_roots=(str(package_root),)
    )


try:
    src = read_json(package_root / "hooks" / "hooks.json")
    if src is None:
        sys.exit(0)
    sb_hooks = sub_path(src.get("hooks") or {})
    data = read_json(hooks_path, default={})
    events = data.setdefault("hooks", {})
    if not isinstance(events, dict):
        raise ConfigError(f"{hooks_path}: 'hooks' must be an object; left unchanged")

    for event_name in list(events):
        groups = events[event_name]
        if not isinstance(groups, list):
            continue
        kept_groups = []
        for group in groups:
            hooks = group.get("hooks") if isinstance(group, dict) else None
            if not isinstance(hooks, list):
                kept_groups.append(group)
                continue
            kept = [hook for hook in hooks if not owned(hook)]
            if len(kept) == len(hooks):
                kept_groups.append(group)
            elif kept:
                kept_groups.append({**group, "hooks": kept})
        if kept_groups or not groups:
            events[event_name] = kept_groups
        else:
            del events[event_name]

    for event_name, groups in sb_hooks.items():
        existing = events.setdefault(event_name, [])
        if not isinstance(existing, list):
            raise ConfigError(f"{hooks_path}: {event_name} must be an array; left unchanged")
        for new_group in groups:
            # Always a group of its own, after the user's: a user's hook keeps its position,
            # and with it the Codex trust keyed to that position.
            existing.append({"matcher": new_group.get("matcher", ""), "hooks": list(new_group.get("hooks", []))})
    write_json(hooks_path, data)
except ConfigError as exc:
    sys.exit(f"ERROR: {exc}")
PY
}
