#!/usr/bin/env python3
"""Fetch Cursor model catalog (docs pricing + agent models) and cache JSON."""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))

from cursor_sb_agents_lib import (  # noqa: E402
    default_config,
    fetch_and_cache_catalog,
    filter_selectable_models,
    format_pricing_label,
    load_json,
)


def global_cache_path() -> Path:
    return Path(
        os.environ.get(
            "SB_CURSOR_MODELS_CATALOG",
            Path.home() / ".config/silver-bullet/cursor-models-catalog.json",
        )
    )


def project_cache_path(repo_root: Path | None) -> Path | None:
    if repo_root is None:
        return None
    return repo_root / ".silver-bullet/cursor-models-catalog.json"


def main() -> int:
    parser = argparse.ArgumentParser(description="Fetch Cursor models catalog with pricing")
    parser.add_argument("--repo-root", default="", help="Project root for project-local cache")
    parser.add_argument("--global-cache", default="", help="Override global cache path")
    parser.add_argument("--json", action="store_true", help="Print full catalog JSON to stdout")
    parser.add_argument(
        "--list-selectable",
        action="store_true",
        help="Print selectable base models (respecting Fast/Max filters)",
    )
    parser.add_argument("--include-fast", action="store_true")
    parser.add_argument("--include-max", action="store_true")
    parser.add_argument("--no-fetch", action="store_true", help="Read existing cache only")
    args = parser.parse_args()

    gpath = Path(args.global_cache) if args.global_cache else global_cache_path()
    repo = Path(args.repo_root).resolve() if args.repo_root else None
    ppath = project_cache_path(repo)

    if args.no_fetch and gpath.is_file():
        catalog = load_json(gpath)
    else:
        catalog = fetch_and_cache_catalog(gpath, ppath)

    if args.list_selectable:
        cfg = default_config()
        cfg["include_fast"] = args.include_fast
        cfg["include_max"] = args.include_max
        for model in filter_selectable_models(catalog, args.include_fast, args.include_max):
            label = format_pricing_label(model)
            print(f"{model['id']}\t{model.get('display_name', model['id'])}\t{label}")
        return 0

    if args.json:
        print(json.dumps(catalog, indent=2))
        return 0

    print(f"Catalog cached: {gpath}")
    if ppath and ppath.is_file():
        print(f"Project cache: {ppath}")
    print(f"Models: {len(catalog.get('models', []))} | source: {catalog.get('source')}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
