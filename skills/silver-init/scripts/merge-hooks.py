#!/usr/bin/env python3
"""
Idempotently merge Silver Bullet hooks from hooks.json into ~/.claude/settings.json.
Usage: python3 merge_hooks.py <sb_install_path>
"""
import json, os, sys

install_path = sys.argv[1]
hooks_src = os.path.join(install_path, 'hooks', 'hooks.json')
settings_path = os.path.expanduser('~/.claude/settings.json')

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

if os.path.exists(settings_path):
    with open(settings_path) as f:
        settings = json.load(f)
else:
    settings = {}

existing_hooks = settings.setdefault('hooks', {})

for event, entries in sb_hooks.items():
    existing_event = existing_hooks.setdefault(event, [])
    for new_group in entries:
        new_hooks_list = new_group.get('hooks', [])
        for new_hook in new_hooks_list:
            new_cmd = new_hook.get('command', '')
            already_present = any(
                h.get('command', '') == new_cmd
                for group in existing_event
                for h in group.get('hooks', [])
            )
            if not already_present:
                matcher = new_group.get('matcher', '')
                matched = next(
                    (g for g in existing_event if g.get('matcher', '') == matcher),
                    None
                )
                if matched:
                    matched.setdefault('hooks', []).append(new_hook)
                else:
                    existing_event.append({'matcher': matcher, 'hooks': [new_hook]})

with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2)
    f.write('\n')

print('SB hooks registered in ~/.claude/settings.json')
