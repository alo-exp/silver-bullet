"""Load need-profile personas for weighted comparison-matrix scoring."""

from __future__ import annotations

import json
from functools import lru_cache
from pathlib import Path
from typing import Any

from matrix_core import WEIGHTS

_PERSONAS_PATH = Path(__file__).resolve().parent.parent / "reference" / "need-profile-personas.json"


@lru_cache(maxsize=1)
def _catalog() -> dict[str, Any]:
    data = json.loads(_PERSONAS_PATH.read_text(encoding="utf-8"))
    personas = data.get("personas") or {}
    if not isinstance(personas, dict):
        raise ValueError("need-profile-personas.json: personas must be an object")
    return personas


def list_persona_ids() -> list[str]:
    return sorted(_catalog().keys())


def get_persona(persona_id: str) -> dict[str, Any] | None:
    if not persona_id:
        return None
    persona = _catalog().get(persona_id)
    return dict(persona) if isinstance(persona, dict) else None


def _priority_rank(priority: str) -> int:
    return WEIGHTS.get(priority, 1)


def max_priority(a: str, b: str) -> str:
    """Return the higher-weight priority label."""
    if _priority_rank(a) >= _priority_rank(b):
        return a
    return b


def apply_persona_priority(
    feature: str,
    category: str | None,
    base_priority: str,
    need: dict[str, Any],
) -> str:
    """Raise priority using persona_id floors/overrides when present."""
    persona_id = need.get("persona_id")
    if not persona_id:
        return base_priority

    persona = get_persona(str(persona_id))
    if not persona:
        return base_priority

    priority = base_priority
    overrides = persona.get("feature_priority_overrides") or {}
    if feature in overrides:
        priority = max_priority(priority, str(overrides[feature]))

    if category:
        floors = persona.get("category_priority_floor") or {}
        for key, floor in floors.items():
            if category == key or category.endswith(key) or key in category:
                priority = max_priority(priority, str(floor))

    return priority
