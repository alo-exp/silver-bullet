#!/usr/bin/env python3
"""Load YAML/JSON catalogs without hard PyYAML dependency."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any


CATALOGS_DIR = Path(__file__).resolve().parent.parent / "reference" / "catalogs"


def load_catalog(name: str) -> dict[str, Any]:
    """Load catalog by stem (e.g. intent_classes). Prefers .json over .yaml."""
    json_path = CATALOGS_DIR / f"{name}.json"
    if json_path.exists():
        with open(json_path, encoding="utf-8") as f:
            return json.load(f)

    yaml_path = CATALOGS_DIR / f"{name}.yaml"
    if yaml_path.exists():
        try:
            import yaml  # type: ignore
        except ImportError as exc:
            raise RuntimeError(
                f"Catalog {name}.json missing and PyYAML not installed"
            ) from exc
        with open(yaml_path, encoding="utf-8") as f:
            return yaml.safe_load(f)

    raise FileNotFoundError(f"Catalog not found: {name}")


def list_catalogs() -> list[str]:
    stems = set()
    if CATALOGS_DIR.is_dir():
        for p in CATALOGS_DIR.iterdir():
            if p.suffix in ('.json', '.yaml'):
                stems.add(p.stem)
    return sorted(stems)
