#!/usr/bin/env python3
import json
from pathlib import Path

path = Path(__file__).with_name("LADDER-STATUS.json")
data = json.loads(path.read_text(encoding="utf-8"))
data["current_rung"] = "rung-02-cursor-kimi-k3-high"
data["current_phase"] = "rung_2_review"
data["updated_at"] = "2026-08-30T21:06:00Z"
if not isinstance(data.get("rung_2"), dict):
    data["rung_2"] = {}
data["rung_2"].setdefault("consecutive_clean_reviews", 0)
path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"ok": True, "current_rung": data["current_rung"]}, indent=2))
