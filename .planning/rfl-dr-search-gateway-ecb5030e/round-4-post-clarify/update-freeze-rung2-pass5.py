#!/usr/bin/env python3
import json
from pathlib import Path

SHA = "f6ba43bb7d7d4d4ca394333ae5f7c15022059040edac9ec75585654630584cd6"
path = Path(__file__).with_name("LADDER-STATUS.json")
data = json.loads(path.read_text(encoding="utf-8"))
data["freeze"] = {"sha256": SHA, "apply_sha": SHA}
data["updated_at"] = "2026-09-01T07:40:00Z"
data["current_rung"] = "rung-02-cursor-kimi-k3-high"
data["current_phase"] = "rung_2_verify_1"
path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"ok": True, "sha256": SHA}, indent=2))
