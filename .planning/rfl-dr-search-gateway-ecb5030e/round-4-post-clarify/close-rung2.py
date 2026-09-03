#!/usr/bin/env python3
import json
from pathlib import Path

SHA = "f6ba43bb7d7d4d4ca394333ae5f7c15022059040edac9ec75585654630584cd6"
path = Path(__file__).with_name("LADDER-STATUS.json")
data = json.loads(path.read_text(encoding="utf-8"))
data["current_phase"] = "rung_2_closed"
data["updated_at"] = "2026-09-01T08:20:00Z"
data["consecutive_clean_reviews"] = 2
data["consecutive_clean_rung"] = "rung-02-cursor-kimi-k3-high"
rung2 = data.get("rung_2") or {}
rung2["consecutive_clean_reviews"] = 2
rung2["closed"] = True
rung2["closed_sha256"] = SHA
data["rung_2"] = rung2
path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
print(
    json.dumps(
        {
            "ok": True,
            "consecutive_clean_reviews": data.get("consecutive_clean_reviews"),
            "phase": data["current_phase"],
            "closed_sha256": SHA,
        },
        indent=2,
    )
)
