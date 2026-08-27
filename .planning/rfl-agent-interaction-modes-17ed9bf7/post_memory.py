#!/usr/bin/env python3
"""HTTP fallback save to local agentmemory (MCP memory_save unavailable)."""
from __future__ import annotations

import json
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

PAYLOAD = {
    "title": "RFL start: agent interaction modes 17ed9bf7",
    "kind": "decision",
    "text": (
        "RFL coordinator started on .cursor/plans/agent_interaction_modes_17ed9bf7.plan.md. "
        "Scope: plan/spec only. User mapping overrides resolver JSON. Rung 1: OpenCode MiniMax M3 High NI. "
        "Charter+ledger: .planning/rfl-agent-interaction-modes-17ed9bf7/"
    ),
    "tags": ["rfl", "agent-interaction-modes", "17ed9bf7", "minimax-m3"],
}

ENDPOINTS = [
    "http://127.0.0.1:3111/memory",
    "http://127.0.0.1:3111/memories",
    "http://127.0.0.1:3111/v1/memory",
    "http://127.0.0.1:3111/agentmemory/memory",
    "http://127.0.0.1:3111/save",
    "http://127.0.0.1:8080/memory",
]


def main() -> int:
    root = Path(__file__).resolve().parents[2]
    export = root / ".agentmemory" / "memory"
    export.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    out = export / f"rfl-agent-interaction-modes-17ed9bf7-{stamp}.md"
    out.write_text(
        "# RFL agent interaction modes\n\n"
        + PAYLOAD["text"]
        + "\n\nPlan: .cursor/plans/agent_interaction_modes_17ed9bf7.plan.md\n",
        encoding="utf-8",
    )
    results = []
    body = json.dumps(PAYLOAD).encode()
    for url in ENDPOINTS:
        req = urllib.request.Request(
            url,
            data=body,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        try:
            with urllib.request.urlopen(req, timeout=3) as resp:
                results.append({"url": url, "status": resp.status, "body": resp.read()[:300].decode("utf-8", "replace")})
                break
        except Exception as exc:  # noqa: BLE001
            results.append({"url": url, "error": str(exc)})
    report = root / ".planning" / "rfl-agent-interaction-modes-17ed9bf7" / "agentmemory-save.json"
    report.write_text(json.dumps({"export": str(out), "http": results}, indent=2), encoding="utf-8")
    print(json.dumps({"export": str(out), "http": results}, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
