#!/usr/bin/env python3
"""
SB-owned search orchestrator — intent classify, provider route, portal dispatch.

Landscape-only portal retrieval. SB-owned descriptors only.
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from urllib.parse import quote

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from catalog_loader import load_catalog  # noqa: E402
from github_skill_retrieval import enrich_github_search_hits  # noqa: E402



def _github_branch_resolver() -> dict[str, str] | None:
    """Optional offline/replay branch map via SB_DR_GITHUB_BRANCHES_JSON."""
    path = os.environ.get("SB_DR_GITHUB_BRANCHES_JSON")
    if not path:
        return None
    branch_path = Path(path)
    if not branch_path.exists():
        return None
    return json.loads(branch_path.read_text(encoding="utf-8"))

LANDSCAPE_TYPES = frozenset({"landscape", "skill-comparison"})


def classify_intent(query: str, research_type: str | None = None) -> str:
    catalog = load_catalog("intent_classes")
    if research_type in ("landscape", "skill-comparison"):
        return "landscape"
    if research_type == "market":
        return "market"
    if research_type == "technical":
        return "technical"
    q = query.lower()
    if any(w in q for w in ("compare", "versus", " vs ", "tradeoff")):
        return "comparative"
    return catalog.get("default_class", "factual")


def probe_search_cli() -> dict[str, Any]:
    path = shutil.which("search")
    if not path:
        return {"status": "unavailable", "providers_available": [], "path": None}
    return {"status": "available", "providers_available": ["search-cli"], "path": path}


def fetch_portal(portal_id: str, query: str, mock_responses: dict | None = None) -> dict[str, Any]:
    portals = load_catalog("skill_portals").get("portals", {})
    portal = portals.get(portal_id)
    if not portal:
        return {"portal_id": portal_id, "status": "error", "reason": "unknown portal"}

    if mock_responses and portal_id in mock_responses:
        return {
            "portal_id": portal_id,
            "status": "ok",
            "results": mock_responses[portal_id],
            "mock": True,
        }

    url_tmpl = portal.get("search_url")
    if not url_tmpl:
        return {
            "portal_id": portal_id,
            "status": "skipped",
            "reason": portal.get("notes", "no search_url"),
        }

    url = url_tmpl.format(query=quote(query))
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "silver-deep-research/1.0"})
        with urllib.request.urlopen(req, timeout=10) as resp:
            body = resp.read().decode("utf-8")
            data = json.loads(body) if body.strip().startswith(("{", "[")) else {"raw": body[:500]}
        return {"portal_id": portal_id, "status": "ok", "results": data}
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
        return {
            "portal_id": portal_id,
            "status": "error",
            "reason": str(exc),
            "fallback_on_error": portal.get("fallback_on_error", True),
        }


def orchestrate(
    query: str,
    out_dir: Path,
    research_type: str | None = None,
    mode: str = "standard",
    mock_responses: dict | None = None,
    offline: bool = False,
) -> dict[str, Any]:
    intent = classify_intent(query, research_type)
    search_cli = probe_search_cli() if not offline else {
        "status": "unavailable",
        "providers_available": [],
        "fallback_reason": "offline",
    }

    portals_attempted: list[str] = []
    portals_succeeded: list[str] = []
    portal_partials: dict[str, Any] = {}
    fallback_reason = None

    if search_cli["status"] == "unavailable":
        fallback_reason = "search-cli not installed; using host search/fetch fallback"

    if research_type in LANDSCAPE_TYPES:
        portals_cfg = load_catalog("skill_portals").get("portals", {})
        for portal_id in portals_cfg:
            portals_attempted.append(portal_id)
            if offline:
                result = {
                    "portal_id": portal_id,
                    "status": "skipped",
                    "reason": "offline fixture",
                }
            else:
                result = fetch_portal(portal_id, query, mock_responses)
            if result.get("status") == "ok":
                if portal_id == "github" and isinstance(result.get("results"), list):
                    result = dict(result)
                    result["results"] = enrich_github_search_hits(
                        result["results"], _github_branch_resolver(),
                    )
                portals_succeeded.append(portal_id)
                partial_path = out_dir / f"portal-{portal_id}.json"
                out_dir.mkdir(parents=True, exist_ok=True)
                with open(partial_path, "w", encoding="utf-8") as f:
                    json.dump(result, f, indent=2)
                portal_partials[portal_id] = str(partial_path)

    record = {
        "orchestrated_at": datetime.now(timezone.utc).isoformat(),
        "query": query,
        "mode": mode,
        "research_type": research_type,
        "intent_class": intent,
        "search_cli": search_cli,
        "retrieval": {
            "intent_class": intent,
            "portals_attempted": portals_attempted,
            "portals_succeeded": portals_succeeded,
            "portal_partials": portal_partials,
            "fallback_reason": fallback_reason,
        },
    }

    manifest_path = out_dir / "run_manifest.json"
    if manifest_path.exists():
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    else:
        manifest = {"version": "3.0.0", "query": query, "mode": mode}
    manifest["search_cli"] = search_cli
    manifest["retrieval"] = record["retrieval"]
    if fallback_reason:
        manifest["fallback_reason"] = fallback_reason
    out_dir.mkdir(parents=True, exist_ok=True)
    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2)

    return record


def main() -> None:
    parser = argparse.ArgumentParser(description="SB search orchestrator")
    parser.add_argument("--query", "-q", required=True)
    parser.add_argument("--dir", required=True, help="Research output directory")
    parser.add_argument("--research-type", default=None)
    parser.add_argument("--mode", default="standard")
    parser.add_argument("--offline", action="store_true")
    parser.add_argument("--mock-portal-json", help="JSON file: portal_id -> results")
    args = parser.parse_args()

    mock = None
    if args.mock_portal_json:
        mock = json.loads(Path(args.mock_portal_json).read_text(encoding="utf-8"))

    result = orchestrate(
        query=args.query,
        out_dir=Path(args.dir),
        research_type=args.research_type,
        mode=args.mode,
        mock_responses=mock,
        offline=args.offline,
    )
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
