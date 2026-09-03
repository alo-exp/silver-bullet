#!/usr/bin/env python3
"""
Reference-following chain tracker for deep/ultradeep retrieval.

Simplified from openclaw chain_tracker (idea-derived; see reference/provenance.md).
"""

from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from urllib.parse import urlparse


def extract_links(text: str, max_links: int = 10) -> list[str]:
    import re
    pattern = r'https?://[^\s\)\]>"\']+'
    found = re.findall(pattern, text)
    seen: set[str] = set()
    out: list[str] = []
    for url in found:
        if url not in seen:
            seen.add(url)
            out.append(url)
        if len(out) >= max_links:
            break
    return out


def normalize_domain(url: str) -> str:
    return (urlparse(url).netloc or "").lower().replace("www.", "")


class ChainTracker:
    def __init__(self, max_depth: int = 2, max_nodes: int = 30):
        self.max_depth = max_depth
        self.max_nodes = max_nodes
        self.nodes: list[dict[str, Any]] = []
        self.edges: list[dict[str, str]] = []
        self._seen: set[str] = set()

    def add_source(self, url: str, parent: str | None = None, depth: int = 0) -> bool:
        if url in self._seen or len(self.nodes) >= self.max_nodes:
            return False
        if depth > self.max_depth:
            return False
        self._seen.add(url)
        node_id = f"n{len(self.nodes)}"
        self.nodes.append({
            "id": node_id,
            "url": url,
            "domain": normalize_domain(url),
            "depth": depth,
            "parent": parent,
            "added_at": datetime.now(timezone.utc).isoformat(),
        })
        if parent:
            self.edges.append({"from": parent, "to": node_id})
        return True

    def follow_references(self, source_url: str, content: str, parent_id: str, depth: int) -> list[str]:
        added = []
        for link in extract_links(content):
            if self.add_source(link, parent=parent_id, depth=depth + 1):
                added.append(link)
        return added

    def to_dict(self) -> dict[str, Any]:
        return {
            "max_depth": self.max_depth,
            "node_count": len(self.nodes),
            "nodes": self.nodes,
            "edges": self.edges,
        }


def load_or_create(path: Path) -> ChainTracker:
    if path.exists():
        data = json.loads(path.read_text(encoding="utf-8"))
        tracker = ChainTracker(
            max_depth=data.get("max_depth", 2),
            max_nodes=30,
        )
        tracker.nodes = data.get("nodes", [])
        tracker.edges = data.get("edges", [])
        tracker._seen = {n["url"] for n in tracker.nodes}
        return tracker
    return ChainTracker()


def save_tracker(tracker: ChainTracker, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(tracker.to_dict(), indent=2), encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description="Reference chain tracker")
    parser.add_argument("--dir", required=True)
    parser.add_argument("--add", help="Add URL to chain")
    parser.add_argument("--follow-file", help="Extract links from file content")
    parser.add_argument("--parent", default=None, help="Parent node id")
    parser.add_argument("--depth", type=int, default=0)
    args = parser.parse_args()

    out_dir = Path(args.dir)
    chain_path = out_dir / "reference-chain.json"
    tracker = load_or_create(chain_path)

    if args.add:
        parent = args.parent
        tracker.add_source(args.add, parent=parent, depth=args.depth)

    if args.follow_file:
        content = Path(args.follow_file).read_text(encoding="utf-8")
        parent_id = args.parent or (tracker.nodes[-1]["id"] if tracker.nodes else None)
        if parent_id:
            tracker.follow_references(args.add or "", content, parent_id, args.depth)

    save_tracker(tracker, chain_path)
    print(json.dumps(tracker.to_dict(), indent=2))


if __name__ == "__main__":
    main()
