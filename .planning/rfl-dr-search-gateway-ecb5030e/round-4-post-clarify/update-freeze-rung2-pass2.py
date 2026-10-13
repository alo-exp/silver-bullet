#!/usr/bin/env python3
import json
from pathlib import Path

SHA = "0f3258bc4a2b9ed937504c65a8c4a1259d92f5dd1e7f55cff4a370e401f3a79f"
path = Path(__file__).with_name("LADDER-STATUS.json")
data = json.loads(path.read_text(encoding="utf-8"))
data["freeze"] = {"sha256": SHA, "apply_sha": SHA}
data["updated_at"] = "2026-08-30T21:24:00Z"
data["current_rung"] = "rung-02-cursor-kimi-k3-high"
data["current_phase"] = "rung_2_verify_1"
path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"ok": True, "sha256": SHA}, indent=2))
