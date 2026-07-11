#!/usr/bin/env bash
# Codex install module — auto-split from install-codex.sh
prune_legacy_silver_bullet_picker_surfaces() {
  python3 - "$CODEX_HOME_ROOT" <<'PY'
import pathlib
import shutil
import sys

home = pathlib.Path(sys.argv[1]).expanduser()
codex_home = home / ".codex"

roots_to_prune = [
    codex_home / ".tmp" / "marketplaces" / "alo-labs-codex" / "skills",
    codex_home / ".tmp" / "marketplaces" / "alo-labs-codex" / "plugins" / "silver-bullet" / "skills",
    codex_home / ".tmp" / "marketplaces" / "alo-labs-codex" / "plugins" / "silver-bullet" / ".generated-skills",
]

backup_root = codex_home / "legacy-uppercase-backups"
if backup_root.exists():
    for backup in backup_root.rglob("*"):
        if not backup.is_dir():
            continue
        parts = backup.parts
        if backup.name in {"skills", ".generated-skills"} and "silver-bullet" in parts:
            roots_to_prune.append(backup)
        if backup.name == "skills" and len(parts) >= 2 and parts[-2] == "alo-labs-codex":
            roots_to_prune.append(backup)

tmp_marketplaces = codex_home / ".tmp" / "marketplaces"
if tmp_marketplaces.exists():
    for backup in tmp_marketplaces.glob("marketplace-backup-*"):
        if not backup.is_dir():
            continue
        roots_to_prune.extend(
            [
                backup / "root" / "skills",
                backup / "root" / "agents" / "claude",
                backup / "root" / "agents" / "codex",
                backup / "root" / "plugins" / "silver-bullet" / "skills",
                backup / "root" / "plugins" / "silver-bullet" / ".generated-skills",
            ]
        )

tmp_root = codex_home / ".tmp"
if tmp_root.exists():
    for temp_dir in tmp_root.glob("sb-*"):
        if not temp_dir.is_dir():
            continue
        roots_to_prune.extend(
            [
                temp_dir / "plugins" / "silver-bullet" / "skills",
                temp_dir / "plugins" / "silver-bullet" / ".generated-skills",
                temp_dir / "plugins" / "silver-bullet" / "agents",
            ]
        )

for path in sorted(set(roots_to_prune), key=lambda item: len(item.parts), reverse=True):
    if path.exists():
        shutil.rmtree(path)
PY
}


purge_legacy_silver_bullet_standalone_skills() {
  python3 - "$CODEX_HOME_ROOT" "$REPO_ROOT" <<'PY'
import pathlib
import shutil
import sys

home = pathlib.Path(sys.argv[1]).expanduser()
repo_root = pathlib.Path(sys.argv[2])

skill_names = {
    path.name
    for path in (repo_root / "skills").iterdir()
    if path.is_dir()
}
skill_names.add("using-silver-bullet")

roots = [
    home / ".codex" / "skills",
    home / ".agents" / "skills",
]

for root in roots:
    if not root.is_dir():
        continue
    for skill_name in sorted(skill_names):
        target = root / skill_name
        if target.exists() or target.is_symlink():
            if target.is_dir() and not target.is_symlink():
                shutil.rmtree(target)
            else:
                target.unlink()
            print(f"Removed legacy skill: {target}")
PY
}


purge_legacy_silver_bullet_codex_alias() {
  python3 - "${CODEX_HOME_ROOT}/.codex/plugins/installed_plugins.json" "${CODEX_HOME_ROOT}/.codex/config.toml" "$CODEX_HOME_ROOT" <<'PY'
import json
import pathlib
import shutil
import sys

registry_paths = [pathlib.Path(sys.argv[1])]
config_paths = [pathlib.Path(sys.argv[2])]
home_root = pathlib.Path(sys.argv[3]).expanduser()
legacy_plugin_ids = {
    "silver-bullet@alo-labs-codex",
    "silver-bullet@alo-labs-codex-local",
}
legacy_cache_roots = [
    home_root / ".codex" / "plugins" / "cache" / "alo-labs-codex-local" / "silver-bullet",
]

for registry_path in registry_paths:
    if not registry_path.is_file():
        continue

    data = json.loads(registry_path.read_text())
    plugins = data.get("plugins", {})
    changed = False
    for plugin_id in legacy_plugin_ids:
        if plugin_id in plugins:
            del plugins[plugin_id]
            changed = True
    if changed:
        registry_path.write_text(json.dumps(data, indent=2) + "\n")

for config_path in config_paths:
    if not config_path.is_file():
        continue

    text = config_path.read_text()
    text = text.replace("/.Codex/", "/.codex/")
    lines = text.splitlines()
    output = []
    i = 0
    changed = False

    while i < len(lines):
        line = lines[i]
        stripped = line.strip()
        if any(stripped == f'[plugins."{plugin_id}"]' for plugin_id in legacy_plugin_ids):
            changed = True
            i += 1
            while i < len(lines) and not lines[i].startswith('['):
                i += 1
            continue
        if any(stripped.startswith(f'[hooks.state."{plugin_id}') for plugin_id in legacy_plugin_ids):
            changed = True
            i += 1
            while i < len(lines) and not lines[i].startswith('['):
                i += 1
            continue
        output.append(line)
        i += 1

    if changed:
        new_text = '\n'.join(output)
        if text.endswith('\n'):
            new_text += '\n'
        config_path.write_text(new_text)

for cache_root in legacy_cache_roots:
    if cache_root.exists():
        if cache_root.is_dir() and not cache_root.is_symlink():
            shutil.rmtree(cache_root)
        else:
            cache_root.unlink()
PY
}


purge_legacy_silver_bullet_hooks_from_user_config() {
  python3 - "${CODEX_HOME_ROOT}/.codex/hooks.json" <<'PY'
import json
import pathlib
import re
import sys

sb_hook_re = re.compile(r'(?:^|[/.])silver-bullet(?:/|@|$)')

for raw_path in sys.argv[1:]:
    hooks_path = pathlib.Path(raw_path)
    if not hooks_path.is_file():
        continue

    data = json.loads(hooks_path.read_text())
    hooks_by_event = data.get("hooks", {})
    changed = False

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
        else:
            del hooks_by_event[event_name]

    if changed:
        hooks_path.write_text(json.dumps(data, indent=2) + "\n")
PY

  python3 - "${CODEX_HOME_ROOT}/.codex/config.toml" <<'PY'
import pathlib
import sys

for raw_path in sys.argv[1:]:
    config_path = pathlib.Path(raw_path)
    if not config_path.is_file():
        continue

    text = config_path.read_text()
    lines = text.splitlines()
    output = []
    i = 0
    changed = False

    while i < len(lines):
        line = lines[i]
        if line.startswith('[hooks.state."silver-bullet@'):
            changed = True
            i += 1
            while i < len(lines) and not lines[i].startswith('['):
                i += 1
            continue
        output.append(line)
        i += 1

    if changed:
        new_text = '\n'.join(output)
        if text.endswith('\n'):
            new_text += '\n'
        config_path.write_text(new_text)
PY
}


scrub_legacy_silver_bullet_traces() {
  local marketplace_root
  local changelog_file

  marketplace_root="$(codex_marketplace_root)"
  [[ -d "$marketplace_root" ]] || return 0
  changelog_file="${marketplace_root}/CHANGELOG.md"
  [[ -f "$changelog_file" ]] || return 0

  python3 - "$changelog_file" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_text()
lines = [line for line in text.splitlines() if "using-silver-bullet" not in line]
new_text = "\n".join(lines)
if text.endswith("\n"):
    new_text += "\n"
path.write_text(new_text)
PY
}


