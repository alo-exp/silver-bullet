#!/usr/bin/env python3
import json
from pathlib import Path

SHA = "916d87f52b25688f7953c76c89b96802d9438eb8da537a8c16b927b98b2ee138"
path = Path(__file__).with_name("LADDER-STATUS.json")
data = json.loads(path.read_text(encoding="utf-8"))
data["freeze"] = {"sha256": SHA, "apply_sha": SHA}
data["updated_at"] = "2026-08-30T20:50:00Z"
path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"ok": True, "sha256": SHA}, indent=2))
