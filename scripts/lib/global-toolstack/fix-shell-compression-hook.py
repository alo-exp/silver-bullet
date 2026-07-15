#!/usr/bin/env python3
"""Replace lean-ctx hook rewrite with shell-compression.sh; ensure rtk hook cursor before CM."""
from __future__ import annotations

import json
from pathlib import Path

HOOKS = Path.home() / ".cursor" / "hooks.json"
TS_SHELL = Path.home() / ".cursor" / "hooks" / "toolstack" / "shell-compression.sh"


def hook_cmd(entry: dict) -> str:
    return str(entry.get("command", ""))


def main() -> int:
    with HOOKS.open(encoding="utf-8") as f:
        data = json.load(f)

    pt = data.get("hooks", {}).get("preToolUse", [])
    changed = 0
    for h in pt:
        cmd = hook_cmd(h)
        if "lean-ctx hook rewrite" in cmd.replace("\\", ""):
            h["command"] = f"bash {TS_SHELL}"
            if "matcher" not in h:
                h["matcher"] = "Shell"
            changed += 1

    rtk_idx = cm_idx = None
    for i, h in enumerate(pt):
        cmd = hook_cmd(h)
        if cmd == "rtk hook cursor":
            rtk_idx = i
        elif "context-mode hook cursor pretooluse" in cmd:
            cm_idx = i

    if rtk_idx is None and cm_idx is not None:
        pt.insert(cm_idx, {"command": "rtk hook cursor", "matcher": "Shell"})
        changed += 1
    elif rtk_idx is not None and cm_idx is not None and rtk_idx > cm_idx:
        rtk_entry = pt.pop(rtk_idx)
        pt.insert(cm_idx, rtk_entry)
        changed += 1

    data.setdefault("hooks", {})["preToolUse"] = pt
    with HOOKS.open("w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
        f.write("\n")

    print(f"shell-compression-hook: {changed} change(s)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
