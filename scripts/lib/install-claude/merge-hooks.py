#!/usr/bin/env python3
"""
Idempotently merge Silver Bullet hooks from hooks.json into the host runtime settings.json.
Purges stale SB hook entries from previous installs before registering new ones.
Usage: python3 merge_hooks.py <sb_install_path>
"""
import json, os, pathlib, re, shutil, sys

install_path = sys.argv[1]
hooks_src = os.path.join(install_path, 'hooks', 'hooks.json')
settings_path = os.path.join(os.path.expanduser('~'), '.claude', 'settings.json')


def stable_install_path(raw_install_path):
    """Normalize versioned plugin cache paths to a stable alias."""

    match = re.match(r'^(.*?/silver-bullet)/(\d+\.\d+\.\d+)$', raw_install_path)
    if not match:
        return raw_install_path

    versioned_path = pathlib.Path(raw_install_path)
    alias_path = pathlib.Path(match.group(1)) / 'current'

    try:
        alias_path.parent.mkdir(parents=True, exist_ok=True)
        if alias_path.exists() or alias_path.is_symlink():
            if alias_path.is_dir() and not alias_path.is_symlink():
                shutil.rmtree(alias_path)
            else:
                alias_path.unlink()
        alias_path.symlink_to(versioned_path)
        return str(alias_path)
    except OSError:
        return raw_install_path


install_path = stable_install_path(install_path)

with open(hooks_src) as f:
    src = json.load(f)

sb_hooks = src.get('hooks', {})

def sub_path(obj, install_path):
    if isinstance(obj, str):
        return obj.replace('${CLAUDE_PLUGIN_ROOT}', install_path)
    if isinstance(obj, list):
        return [sub_path(i, install_path) for i in obj]
    if isinstance(obj, dict):
        return {k: sub_path(v, install_path) for k, v in obj.items()}
    return obj

sb_hooks = sub_path(sb_hooks, install_path)

# Matches any Silver Bullet hook path, including mirrored app-root installs.
SB_HOOK_RE = re.compile(r'/silver-bullet/[^/]+/hooks/')

def is_stale_sb_hook(hook):
    if not isinstance(hook, dict):
        return False
    cmd = hook.get('command', '')
    if not isinstance(cmd, str):
        return False
    if '${CLAUDE_PLUGIN_ROOT}/hooks/' in cmd:
        return True
    return bool(SB_HOOK_RE.search(cmd)) and install_path not in cmd


def json_member(data, key, kind):
    """Return data[key] as kind; repair missing/null/empty, refuse other wrong types."""
    value = data.get(key)
    if isinstance(value, kind):
        return value
    if value is None or value == {} or value == []:
        value = kind()
        data[key] = value
        return value
    label = 'object' if kind is dict else 'array'
    raise ValueError(f'{settings_path}: {key} must be a JSON {label}')


def group_hooks(group):
    """The hook list of a settings group; non-dict groups have none."""
    if not isinstance(group, dict) or 'hooks' not in group:
        return []
    return json_member(group, 'hooks', list)


if os.path.exists(settings_path):
    with open(settings_path) as f:
        settings = json.load(f)
    if not isinstance(settings, dict):
        raise ValueError(f'{settings_path}: expected a JSON object at the top level')
else:
    settings = {}

existing_hooks = json_member(settings, 'hooks', dict)

# Purge stale SB entries from previous installs before adding current version
for event in list(existing_hooks.keys()):
    cleaned = []
    for group in json_member(existing_hooks, event, list):
        if not isinstance(group, dict):
            cleaned.append(group)  # foreign entry: keep untouched
            continue
        kept = [h for h in group_hooks(group) if not is_stale_sb_hook(h)]
        if kept:
            group['hooks'] = kept
            cleaned.append(group)
    if cleaned:
        existing_hooks[event] = cleaned
    else:
        del existing_hooks[event]

for event, entries in sb_hooks.items():
    existing_event = json_member(existing_hooks, event, list)
    for new_group in entries:
        new_hooks_list = new_group.get('hooks', [])
        for new_hook in new_hooks_list:
            new_cmd = new_hook.get('command', '')
            already_present = any(
                isinstance(h, dict) and h.get('command', '') == new_cmd
                for group in existing_event
                for h in group_hooks(group)
            )
            if not already_present:
                matcher = new_group.get('matcher', '')
                matched = next(
                    (g for g in existing_event
                     if isinstance(g, dict) and g.get('matcher', '') == matcher),
                    None
                )
                if matched:
                    json_member(matched, 'hooks', list).append(new_hook)
                else:
                    existing_event.append({'matcher': matcher, 'hooks': [new_hook]})

os.makedirs(os.path.dirname(settings_path), exist_ok=True)
with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2)
    f.write('\n')

print('SB hooks registered in the host runtime settings.json')
