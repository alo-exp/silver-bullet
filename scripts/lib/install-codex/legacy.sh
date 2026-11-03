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

# Older Codex plugin installs converted every command stub into an internal
# source-command-* skill. That migration surface is an implementation detail,
# not a public SB skill namespace; remove it from every cached SB version.
cache_root = codex_home / "plugins" / "cache"
if cache_root.exists():
    for pattern in ("*/*/.codex-plugin/migrated-command-skills", "*/*/*/.codex-plugin/migrated-command-skills"):
        roots_to_prune.extend(cache_root.glob(pattern))

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
                backup / "root" / "plugins" / "silver-bullet" / ".codex-plugin" / "migrated-command-skills",
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
                temp_dir / "plugins" / "silver-bullet" / ".codex-plugin" / "migrated-command-skills",
            ]
        )

for path in sorted(set(roots_to_prune), key=lambda item: len(item.parts), reverse=True):
    if path.exists():
        shutil.rmtree(path)
PY
}


# Remove Silver Bullet skill directories an earlier install copied into ~/.codex/skills or
# ~/.agents/skills (--purge-legacy-skills and the post-release uninstall), by the names of
# SB's skills. A directory carrying the ownership marker Silver Bullet writes
# (.silver-bullet-managed whose first line is "source=Silver Bullet") is removed; a symlink
# only when it points into Silver Bullet's own checkout or package. An unmarked directory
# under Silver Bullet's own names (silver-*, sb-*, sb:*, using-silver-bullet; copies made
# before the marker existed) is moved to ~/.codex/.silver-bullet-backup, never deleted.
# Anything else, such as a user's own "security" or "tdd" skill, is reported and left alone
# (R7-06).
purge_legacy_silver_bullet_standalone_skills() {
  python3 - "$CODEX_HOME_ROOT" "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)" <<'PY'
import os
import pathlib
import re
import shutil
import sys
import time

home = pathlib.Path(sys.argv[1]).expanduser()
repo_root = os.path.realpath(sys.argv[2])
SB_PACKAGE_RE = re.compile(r"/plugins/(?:cache/[^/]+/)?silver-bullet(?:/|$)|/marketplaces/alo-labs-codex(?:/|$)")
SB_NAMESPACE = re.compile(r"(?:silver|sb|(?:silver-|sb[:-]).+|using-silver-bullet)")
backup_root = home / ".codex" / ".silver-bullet-backup" / "skills" / time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())


def sb_managed(path: pathlib.Path) -> bool:
    marker = path / ".silver-bullet-managed"
    try:
        first = marker.read_text(encoding="utf-8").splitlines()[:1]
    except (OSError, UnicodeDecodeError):
        return False
    return not marker.is_symlink() and first == ["source=Silver Bullet"]


def sb_link(path: pathlib.Path) -> bool:
    target = os.path.realpath(path)
    return target == repo_root or target.startswith(repo_root + os.sep) or bool(SB_PACKAGE_RE.search(target))


skills_dir = pathlib.Path(repo_root) / "skills"
skill_names = {path.name for path in skills_dir.iterdir() if path.is_dir()} if skills_dir.is_dir() else set()
skill_names.add("using-silver-bullet")

for label, root in (("codex", home / ".codex" / "skills"), ("agents", home / ".agents" / "skills")):
    if not root.is_dir():
        continue
    for skill_name in sorted(skill_names):
        target = root / skill_name
        if target.is_symlink():
            if sb_link(target):
                target.unlink()
                print(f"Removed legacy skill: {target}")
            else:
                print(f"Kept {target}: it links outside Silver Bullet", file=sys.stderr)
        elif target.is_dir():
            if sb_managed(target):
                shutil.rmtree(target)
                print(f"Removed legacy skill: {target}")
            elif SB_NAMESPACE.fullmatch(skill_name):
                (backup_root / label).mkdir(parents=True, exist_ok=True)
                shutil.move(str(target), str(backup_root / label / skill_name))
                print(f"Removed legacy skill: {target} (backed up to {backup_root / label / skill_name})")
            else:
                print(f"Kept {target}: no Silver Bullet ownership marker", file=sys.stderr)
        elif target.exists():
            print(f"Kept {target}: not a Silver Bullet skill directory", file=sys.stderr)
PY
}


# Drop Silver Bullet's retired plugin id (silver-bullet@alo-labs-codex-local) from Codex's
# registry, config.toml and cache. The current id, silver-bullet@alo-labs-codex, is never
# touched here: the directory install-codex.sh runs from must not decide whether Silver Bullet
# is enabled in every project (R7-10). config.toml is edited structurally, keeping comments and
# other tables (R7-09); an unparseable registry or config is refused, never rewritten.
purge_legacy_silver_bullet_codex_alias() {
  python3 - "${CODEX_HOME_ROOT}/.codex/plugins/installed_plugins.json" "${CODEX_HOME_ROOT}/.codex/config.toml" \
    "$CODEX_HOME_ROOT" "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" <<'PY'
import pathlib
import shutil
import sys

registry_path = pathlib.Path(sys.argv[1])
config_path = pathlib.Path(sys.argv[2])
home_root = pathlib.Path(sys.argv[3]).expanduser()
sys.path.insert(0, sys.argv[4])
from sb_host_config import ConfigError, TomlDocument, read_json, read_toml, write_json, write_toml  # noqa: E402

LEGACY_ID = "silver-bullet@alo-labs-codex-local"


def legacy(path) -> bool:
    if len(path) >= 2 and path[0] == "plugins" and path[1] == LEGACY_ID:
        return True
    return len(path) >= 3 and path[:2] == ("hooks", "state") and path[2].startswith(LEGACY_ID + ":")


try:
    data = read_json(registry_path)
    plugins = data.get("plugins") if data is not None else None
    if isinstance(plugins, dict) and LEGACY_ID in plugins:
        del plugins[LEGACY_ID]
        write_json(registry_path, data)
    if config_path.is_file():
        doc = read_toml(config_path)
        # Older installers wrote "/.Codex/" paths; fold them back before editing.
        doc = TomlDocument(doc.text.replace("/.Codex/", "/.codex/"), str(config_path))
        doc.remove(legacy)
        write_toml(config_path, doc)
except ConfigError as exc:
    sys.exit(f"ERROR: {exc}")

cache_root = home_root / ".codex" / "plugins" / "cache" / "alo-labs-codex-local" / "silver-bullet"
if cache_root.is_symlink() or cache_root.is_file():
    cache_root.unlink()
elif cache_root.is_dir():
    shutil.rmtree(cache_root)
PY
}


# Remove Silver Bullet's hooks from ~/.codex/hooks.json (native Codex runs the plugin's own
# hooks, so a merged copy runs twice) together with the trust entries that pointed at them.
# Only entries Silver Bullet provably owns go (sb_host_config.is_sb_hook_command); the user's
# hooks and their trust stay. Trust for the current package (silver-bullet@alo-labs-codex:...)
# is kept, so an install never revokes what Codex already trusts (R7-10); "--all", used by the
# post-release uninstall, drops it too. Files that do not parse are refused, never rewritten.
purge_legacy_silver_bullet_hooks_from_user_config() {
  python3 - "${CODEX_HOME_ROOT}/.codex/hooks.json" "${CODEX_HOME_ROOT}/.codex/config.toml" "${1:-}" \
    "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" "$CODEX_HOME_ROOT" <<'PY'
import pathlib
import re
import sys

hooks_path = pathlib.Path(sys.argv[1])
config_path = pathlib.Path(sys.argv[2])
purge_all = sys.argv[3] == "--all"
lib_dir = pathlib.Path(sys.argv[4])
home = pathlib.Path(sys.argv[5]).expanduser()
sys.path.insert(0, str(lib_dir))
from sb_host_config import ConfigError, is_sb_hook_command, read_json, read_toml, sb_hook_names, write_json, write_toml  # noqa: E402

package_root = home / ".codex" / ".tmp" / "marketplaces" / "alo-labs-codex" / "plugins" / "silver-bullet"
names = sb_hook_names(lib_dir.parents[1] / "hooks", package_root / "hooks")
user_prefixes = {str(home / ".codex" / "hooks.json"), str(home.resolve() / ".codex" / "hooks.json")}
removed_keys = set()
moved_keys = {}  # trust keys of the user's own hooks whose position in hooks.json shifts


def event_slug(name: str) -> str:
    return re.sub(r"(?<!^)(?=[A-Z])", "_", name).lower()


def sb_trust(path) -> bool:
    if len(path) < 3 or path[:2] != ("hooks", "state"):
        return False
    key = path[2]
    if key in removed_keys:
        return True
    return key.startswith("silver-bullet@") and (purge_all or not key.startswith("silver-bullet@alo-labs-codex:"))


try:
    data = read_json(hooks_path)
    events = data.get("hooks") if data is not None else None
    if isinstance(events, dict):
        changed = False
        for event_name in list(events):
            groups = events[event_name]
            if not isinstance(groups, list):
                continue
            kept_groups = []
            for group_index, group in enumerate(groups):
                hooks = group.get("hooks") if isinstance(group, dict) else None
                if not isinstance(hooks, list):
                    kept_groups.append(group)
                    continue
                kept = []
                for hook_index, hook in enumerate(hooks):
                    if isinstance(hook, dict) and is_sb_hook_command(
                        hook.get("command"), hook_names=names, install_roots=(str(package_root),)
                    ):
                        removed_keys.update(f"{prefix}:{event_slug(event_name)}:{group_index}:{hook_index}" for prefix in user_prefixes)
                        continue
                    for prefix in user_prefixes:  # Codex keys trust by position: follow the hook
                        moved_keys[f"{prefix}:{event_slug(event_name)}:{group_index}:{hook_index}"] = (
                            f"{prefix}:{event_slug(event_name)}:{len(kept_groups)}:{len(kept)}")
                    kept.append(hook)
                if len(kept) == len(hooks):
                    kept_groups.append(group)
                    continue
                changed = True
                if kept:
                    kept_groups.append({**group, "hooks": kept})
            if kept_groups:
                events[event_name] = kept_groups
            elif groups:
                del events[event_name]
        if changed:
            write_json(hooks_path, data)
    if config_path.is_file():
        doc = read_toml(config_path)
        doc.remove(sb_trust)
        doc.rename_tables({("hooks", "state", old): ("hooks", "state", new) for old, new in moved_keys.items()})
        write_toml(config_path, doc)
except ConfigError as exc:
    sys.exit(f"ERROR: {exc}")
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
