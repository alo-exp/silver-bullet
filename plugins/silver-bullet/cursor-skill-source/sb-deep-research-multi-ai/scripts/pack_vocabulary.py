#!/usr/bin/env python3
"""Category-pack vocabulary: SDLC/APO wording and rules live in the pack overlay, not in code.

The overlay's ``vocabulary`` object maps ``"<module>.<ATTRIBUTE>"`` to JSON data. The modules
define neutral defaults (empty lists/dicts, never-matching patterns); ``activated(pack)``
swaps in the overlay's values for the duration of one report build when a category pack is
selected, then restores the defaults. Single-threaded use only (module globals are swapped).
"""

from __future__ import annotations

import contextlib
import importlib
import re
import sys
from pathlib import Path
from typing import Any, Iterator

from category_pack import pack_overlay

NEVER = re.compile(r"(?!x)x")


def _regex(value: Any) -> re.Pattern[str]:
    if not value:
        return NEVER
    if isinstance(value, dict):
        return re.compile(value["pattern"], int(value.get("flags", 0)))
    return re.compile(str(value))


def _prose_signals(value: Any) -> list[tuple[re.Pattern[str], list[str]]]:
    return [(_regex(item[0]), list(item[1])) for item in value or []]


def _weights(value: Any) -> tuple[tuple[str, float], ...]:
    return tuple((str(k), float(w)) for k, w in value or [])


def _pairs(value: Any) -> tuple[tuple[str, str], ...]:
    return tuple((str(k), str(v)) for k, v in value or [])


def _tuple(value: Any) -> tuple[str, ...]:
    return tuple(str(v) for v in value or [])


def _frozen(value: Any) -> frozenset[str]:
    return frozenset(str(v) for v in value or [])


def _makers(value: Any) -> dict[str, frozenset[str]]:
    return {str(k).lower(): frozenset(str(w).lower() for w in words or []) for k, words in (value or {}).items()}


CONVERTERS: dict[str, Any] = {
    "materialize_solution_artifacts.FEATURE_TEMPLATE": list,
    "materialize_solution_artifacts._FEATURE_ALIASES": dict,
    "materialize_solution_artifacts._INCLUSION_CRITERION_FEATURES": dict,
    "materialize_solution_artifacts._CRITERION_KEYWORD_TO_ID": dict,
    "materialize_solution_artifacts._PROSE_POSITIVE_SIGNALS": _prose_signals,
    "materialize_solution_artifacts._CORE_SET_CLAIM_RE": _regex,
    "materialize_solution_artifacts._MATRIX_LEADERS_RE": _regex,
    "materialize_solution_artifacts._INCLUSION_CRITERIA_SIGNAL_RE": _regex,
    "materialize_solution_artifacts._PAREN_CRITERION_SLUGS_RE": _regex,
    "materialize_solution_artifacts._ALL_SEVEN_INCLUSION_RE": _regex,
    "materialize_solution_artifacts.HOST_RUNTIME_SLUGS": _frozen,
    "materialize_solution_artifacts.AMBIGUOUS_NAMES": _frozen,
    "materialize_solution_artifacts.NON_VENDOR_TERMS": _frozen,
    "materialize_solution_artifacts.PROPER_PHRASES": _frozen,
    "materialize_solution_artifacts.PRODUCT_MAKERS": _makers,
    "materialize_solution_artifacts.OVERVIEW_IDENTITY_FILTERS": list,
    "synthesize_landscape.KCF_NAMES": list,
    "synthesize_landscape._CHART_SUPPORT_ALIASES": dict,
    "synthesize_landscape._WAVE_STRATEGY_FEATURE_WEIGHTS": _weights,
    "synthesize_landscape._WAVE_STRATEGY_HOST_MARKERS": _tuple,
    "synthesize_landscape._DIVERGENCE_SUBJECTS": _pairs,
    "synthesize_landscape._DIVERGENCE_SUBJECT_LABELS": dict,
    "synthesize_landscape.FORBIDDEN_CHART_SLUGS": _frozen,
    "synthesize_landscape.SOLO_HOST_MARKER": str,
    "synthesize_landscape.PRESENCE_REQUIRES_FEATURE": str,
    "synthesize_landscape.KCF_FALLBACK_EXCLUDE": _tuple,
    "vendor_link_labels.EXTRA_BLOCKED_LABELS": _frozen,
    "vendor_link_labels.SLUG_LINK_LABEL_OVERRIDES": dict,
    "vendor_link_labels.ALLOWED_SHORT_ACRONYM_LABELS": _frozen,
    "synthesize_landscape.LEADER_RULES": dict,
    "synthesize_landscape.METHODOLOGY_GATE_FEATURE": str,
    "synthesize_landscape._DOMAIN_AXIS_PROFILES": dict,
    "landscape_critique_artifacts.LEDGER": dict,
    "landscape_critique_artifacts.INCLUSION_CRITERIA_ORDER": _tuple,
    "landscape_critique_artifacts.INCLUSION_CRITERIA_ABBR": _tuple,
    "validate_landscape_content._MUST_HAVE_ALIASES": dict,
    "validate_landscape_content.RENAME_POLICIES": list,
    "solution_classifier.RENAME_EXCLUSIONS": dict,
    "vendor_link_labels.VENDOR_URL_REWRITES": dict,
}


def converted(vocabulary: dict[str, Any]) -> dict[str, Any]:
    """Overlay JSON -> {"module.ATTR": python value} for the known attributes."""
    return {key: CONVERTERS[key](vocabulary[key]) for key in CONVERTERS if key in vocabulary}


def _targets(module_name: str) -> list[Any]:
    """The importable module plus, when the module runs as a script, the ``__main__`` copy.

    ``python3 synthesize_landscape.py`` executes the file as ``__main__``: its functions read
    ``__main__``'s globals, a different object from ``import synthesize_landscape``.
    """
    module = importlib.import_module(module_name)
    targets = [module]
    main = sys.modules.get("__main__")
    main_file = getattr(main, "__file__", None)
    if main is not None and main is not module and main_file and Path(main_file).stem == module_name:
        targets.append(main)
    return targets


@contextlib.contextmanager
def apply_values(values: dict[str, Any]) -> Iterator[None]:
    """Temporarily set module attributes ("module.ATTR" -> value), on ``__main__`` too if it is that script."""
    saved: list[tuple[Any, str, Any]] = []
    try:
        for key, value in values.items():
            module_name, attr = key.rsplit(".", 1)
            for target in _targets(module_name):
                saved.append((target, attr, getattr(target, attr)))
                setattr(target, attr, value)
        yield
    finally:
        for target, attr, old in reversed(saved):
            setattr(target, attr, old)


def activated(pack: dict[str, Any] | None) -> contextlib.AbstractContextManager[None]:
    """Context manager applying the selected pack's vocabulary (no-op without a pack)."""
    vocabulary = pack_overlay(pack).get("vocabulary") if pack else None
    return apply_values(converted(vocabulary or {}))


def for_research_dir(fn: Any) -> Any:
    """Decorator: run ``fn(research_dir, ...)`` with the vocabulary of the dir's need-profile pack."""
    import functools
    import json

    from category_pack import resolve_pack_from_need

    @functools.wraps(fn)
    def wrapper(research_dir: Any, *args: Any, **kwargs: Any) -> Any:
        try:
            need = json.loads((Path(research_dir) / "need_profile.json").read_text(encoding="utf-8"))
        except (OSError, ValueError):
            need = {}
        with activated(resolve_pack_from_need(need if isinstance(need, dict) else {})):
            return fn(research_dir, *args, **kwargs)

    return wrapper
