#!/usr/bin/env python3
"""Small standalone CLI for installing and validating the generic runtime."""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any, Dict, Optional

try:
    from .runtime import ensure_manifest, inspect_manifest, repair_manifest
except ImportError:  # direct execution from a copied standalone package
    from runtime import ensure_manifest, inspect_manifest, repair_manifest


def _common(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--manifest", type=Path)
    parser.add_argument("--legacy-manifest", type=Path)
    parser.add_argument("--home", type=Path)
    parser.add_argument("--platform", dest="platform_name")
    parser.add_argument("--dry-run", action="store_true")


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Generic five-tool runtime")
    sub = parser.add_subparsers(dest="command", required=True)
    for name in ("install", "repair"):
        child = sub.add_parser(name)
        _common(child)
    inspect = sub.add_parser("inspect")
    _common(inspect)
    validate = sub.add_parser("validate")
    _common(validate)
    return parser


def main(argv: Optional[list[str]] = None) -> int:
    args = _parser().parse_args(argv)
    if args.command in ("install", "repair"):
        fn = repair_manifest if args.command == "repair" else ensure_manifest
        result = fn(
            manifest_path=args.manifest,
            legacy_manifest_path=args.legacy_manifest,
            home=args.home,
            platform_name=args.platform_name,
            dry_run=args.dry_run,
        )
        output: Dict[str, Any] = result
        ok = bool(result.get("_result", {}).get("validation", {}).get("valid"))
    else:
        result = inspect_manifest(
            manifest_path=args.manifest,
            home=args.home,
            platform_name=args.platform_name,
        )
        output = result
        ok = bool(result.get("valid"))
    print(json.dumps(output, indent=2, ensure_ascii=False))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
