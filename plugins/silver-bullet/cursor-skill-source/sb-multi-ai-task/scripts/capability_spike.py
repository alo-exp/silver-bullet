#!/usr/bin/env python3
"""Blocking capability spike contract for multi-ai-task-v2 backends."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from multi_ai_core import SPINE, utc_now_iso

SKILL_ROOT = Path(__file__).resolve().parents[1]
REGISTRY = SKILL_ROOT / "reference" / "model-family-registry-v1.json"


def build_capabilities_stub(*, live: bool = False) -> dict[str, Any]:
    """Return backend-capabilities-v1 snapshot (stub unless --live)."""
    cursor_status = "stub" if not live else "disabled"
    ocg_status = "stub" if not live else "disabled"
    return {
        "schema_id": "backend-capabilities-v1",
        "version": "1.0.0",
        "spine": SPINE,
        "probed_at": utc_now_iso(),
        "backends": {
            "cursor": {
                "status": cursor_status,
                "adapter_id": "cursor-host-adapter-v1",
                "adapter_version": "1.0.0",
                "evidence": {
                    "usage_metered": False,
                    "hard_ceiling_enforced": False,
                    "cancellation_proven": False,
                    "model_identity_hash": None,
                    "config_hash": None,
                },
                "disable_reason": None if live else "adapter not live — stub spike only",
            },
            "ocg": {
                "status": ocg_status,
                "adapter_id": "agent-opencode-multi-ai-worker-v1",
                "adapter_version": "1.0.0",
                "evidence": {
                    "usage_metered": False,
                    "hard_ceiling_enforced": False,
                    "cancellation_proven": False,
                    "model_identity_hash": None,
                    "config_hash": None,
                },
                "disable_reason": None if live else "live spike not run — stub spike only",
            },
        },
    }


def validate_profile(profile_id: str, pool: str) -> None:
    reg = json.loads(REGISTRY.read_text(encoding="utf-8"))
    key = "ocg_lite_pool" if pool == "lite" else "ocg_regular_pool"
    allowed = reg[key]
    if profile_id not in allowed:
        raise ValueError(f"profile {profile_id!r} not in allowlisted {pool} registry pool")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Backend capability spike (contract)")
    parser.add_argument("--output", required=True, help="Write backend-capabilities-v1.json here")
    parser.add_argument("--live", action="store_true", help="Attempt live probes (still fail-closed in scaffold)")
    parser.add_argument("--validate-profile", help="Validate profile id against inventory")
    parser.add_argument("--pool", choices=["lite", "regular"], default="lite")
    args = parser.parse_args(argv)

    if args.validate_profile:
        validate_profile(args.validate_profile, args.pool)

    out_path = Path(args.output)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    payload = build_capabilities_stub(live=args.live)
    out_path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"ok": True, "output": str(out_path), "live": args.live}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
