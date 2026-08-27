#!/usr/bin/env python3
"""Save RFL rung-2-fix / rung-3 start to agentmemory HTTP + export file."""
from __future__ import annotations

import json
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path("/Users/shafqat/projects/silver-bullet/repo")
PAYLOAD = {
    "title": "RFL AIM 17ed9bf7 rung-2-fix already-done; starting rung-3 Qwen3.8 XHigh",
    "kind": "decision",
    "text": (
        "Phase A: I-18/I-20/I-21 already fully specified in "
        ".cursor/plans/agent_interaction_modes_17ed9bf7.plan.md "
        "(D1+mermaid §4.1 three-way split; auto+--attach not a pin; leftover "
        "SB_AGENT_INTERACTION_MODE fails leftover-env-pin). No plan edit. "
        "Phase B: scripts/agent-opencode/invoke.sh missing; native opencode run "
        "opencode-go/qwen3.8-max --variant max (no xhigh on CLI 1.17.16)."
    ),
    "tags": ["rfl", "agent-interaction-modes", "17ed9bf7", "qwen3.8", "rung-3"],
}

ENDPOINTS = [
    "http://127.0.0.1:3111/memory",
    "http://127.0.0.1:3111/memories",
    "http://127.0.0.1:3111/v1/memory",
    "http://127.0.0.1:3111/agentmemory/memory",
    "http://127.0.0.1:3111/save",
]


def main() -> int:
    export = ROOT / ".agentmemory" / "memory"
    export.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    out = export / f"rfl-aim-17ed9bf7-rung-03-{stamp}.md"
    out.write_text("# " + PAYLOAD["title"] + "\n\n" + PAYLOAD["text"] + "\n", encoding="utf-8")
    results = []
    body = json.dumps(PAYLOAD).encode()
    for url in ENDPOINTS:
        req = urllib.request.Request(
            url, data=body, headers={"Content-Type": "application/json"}, method="POST"
        )
        try:
            with urllib.request.urlopen(req, timeout=3) as resp:
                results.append({"url": url, "status": resp.status})
                break
        except Exception as exc:  # noqa: BLE001
            results.append({"url": url, "error": str(exc)})
    report = ROOT / ".planning/rfl-agent-interaction-modes-17ed9bf7/rung-03-qwen38-xhigh/agentmemory-save.json"
    report.write_text(json.dumps({"export": str(out), "http": results}, indent=2), encoding="utf-8")
    print(json.dumps({"export": str(out), "http": results}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
