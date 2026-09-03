#!/usr/bin/env python3
import json
from pathlib import Path

SHA = "9b79d0144559ac6abbe360f39f7c894742295bb0f1e245124b21606559099a21"
path = Path(__file__).with_name("LADDER-STATUS.json")
data = json.loads(path.read_text(encoding="utf-8"))
data["freeze"] = {"sha256": SHA, "apply_sha": SHA}
data["updated_at"] = "2026-08-30T21:12:00Z"
data["current_rung"] = "rung-02-cursor-kimi-k3-high"
data["current_phase"] = "rung_2_verify_1"
path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"ok": True, "sha256": SHA}, indent=2))
