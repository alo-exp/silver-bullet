#!/usr/bin/env python3
"""Classify landscape candidates into core / adjacent / excluded / sunset."""

from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any

from category_pack import (
    apply_parent_child_dedupe,
    build_alias_map,
    build_known_solutions,
    expand_by_slug_aliases,
    get_adjacent_class_ids,
    get_adjacent_seed_slugs,
    get_all_market_seed_slugs,
    get_core_seed_slugs,
    get_hard_exclusion_slugs,
    get_markets,
    get_must_research_slugs,
    get_primary_market_id,
    get_sunset_registry,
    normalize_slug,
    resolve_canonical_slug,
    resolve_pack_from_need,
    slugify,
)
from materialize_solution_artifacts import _iter_claim_texts

Classification = str  # core | adjacent | excluded | sunset


def _slug_set_from_entries(entries: list[dict[str, Any]]) -> set[str]:
    return {str(e["slug"]) for e in entries if e.get("slug")}


def _sunset_map(pack: dict[str, Any]) -> dict[str, str]:
    return {str(e["slug"]): str(e.get("reason", "sunset")) for e in get_sunset_registry(pack)}


def _market_core_slug_map(pack: dict[str, Any]) -> dict[str, list[str]]:
    """Map canonical slug → market ids where the slug is a core seed."""
    out: dict[str, list[str]] = {}
    for market in get_markets(pack):
        mid = str(market.get("id") or "")
        if not mid:
            continue
        for seed in market.get("seeds") or []:
            if seed.get("slug"):
                slug = str(seed["slug"])
                out.setdefault(slug, []).append(mid)
    return out


def _all_adjacent_seed_slugs(pack: dict[str, Any]) -> set[str]:
    slugs: set[str] = set()
    for market in get_markets(pack):
        for seed in market.get("adjacent_seeds") or []:
            if seed.get("slug"):
                slugs.add(str(seed["slug"]))
    return slugs


def _exclusion_class_by_slug(pack: dict[str, Any]) -> dict[str, str]:
    out: dict[str, str] = {}
    market_core = set(get_all_market_seed_slugs(pack, include_adjacent=False))
    for entry in pack.get("hard_exclusions") or []:
        if entry.get("slug"):
            slug = str(entry["slug"])
            if slug not in market_core:
                out[slug] = str(entry.get("exclusion_class") or "hard_exclusion")
    for market in get_markets(pack):
        for seed in market.get("adjacent_seeds") or []:
            if seed.get("slug") and seed.get("adjacent_class"):
                out[str(seed["slug"])] = str(seed["adjacent_class"])
    return out


def _classify_slug_for_market(
    slug: str,
    market: dict[str, Any],
    *,
    envelope_slugs: set[str],
    hard_vetoes: set[str],
    sunset: dict[str, str],
    hard_exclusions: set[str],
) -> tuple[Classification, str]:
    slug = str(slug)
    market_id = str(market.get("id") or "")
    core_seeds = {str(s["slug"]) for s in (market.get("seeds") or []) if s.get("slug")}
    adjacent_seeds = {str(s["slug"]) for s in (market.get("adjacent_seeds") or []) if s.get("slug")}
    if slug in hard_vetoes:
        return "excluded", "hard_veto from need_profile"
    if slug in sunset:
        return "sunset", sunset[slug]
    if slug in hard_exclusions and slug not in core_seeds:
        return "excluded", "pack hard_exclusion"
    if slug in core_seeds:
        if slug in envelope_slugs or slug == "silver-bullet":
            return "core", f"{market_id} market_seed"
        return "excluded", f"{market_id} seed without envelope evidence (gap)"
    if slug in adjacent_seeds:
        seed = next(
            (s for s in (market.get("adjacent_seeds") or []) if str(s.get("slug") or "") == slug),
            None,
        )
        if isinstance(seed, dict) and seed.get("quarantine"):
            return (
                "adjacent",
                f"{market_id} quarantined watchlist — identity/OSS/license unverified; not MQ/Wave/Leader",
            )
        if isinstance(seed, dict) and "demot" in str(seed.get("notes") or "").lower():
            return "adjacent", f"{market_id} demoted adjacent (not core plotted)"
        return "adjacent", f"{market_id} adjacent_seed"
    return "excluded", f"not in {market_id} seeds"


def _extract_candidates_from_text(
    text: str,
    aliases: dict[str, str],
    known: dict[str, str],
) -> list[str]:
    found: list[str] = []
    lower = text.lower()
    for alias, canonical in sorted(aliases.items(), key=lambda x: -len(x[0])):
        if len(alias) < 2:
            continue
        if alias in lower or alias.replace("-", " ") in lower:
            if canonical not in found:
                found.append(canonical)
    for slug, display in known.items():
        if slug.replace("-", " ") in lower or slug in lower or display.lower() in lower:
            if slug not in found:
                found.append(slug)
    return found


def _envelope_evidence_slugs(
    envelopes: list[dict[str, Any]],
    pack: dict[str, Any],
) -> set[str]:
    """Slugs found in envelope text only (not pack seed injection)."""
    aliases = build_alias_map(pack)
    known = build_known_solutions(pack)
    found: set[str] = set()
    for text in _iter_claim_texts(envelopes):
        for slug in _extract_candidates_from_text(text, aliases, known):
            found.add(resolve_canonical_slug(slug, pack))
    return found


def discover_candidate_slugs(
    envelopes: list[dict[str, Any]],
    pack: dict[str, Any],
) -> list[str]:
    """Discover candidate slugs from envelopes using pack aliases (open discovery)."""
    aliases = build_alias_map(pack)
    known = build_known_solutions(pack)
    scores: dict[str, int] = {}

    for slug in get_all_market_seed_slugs(pack, include_adjacent=True):
        scores[slug] = scores.get(slug, 0) + 1

    for text in _iter_claim_texts(envelopes):
        for slug in _extract_candidates_from_text(text, aliases, known):
            canonical = resolve_canonical_slug(slug, pack)
            scores[canonical] = scores.get(canonical, 0) + 1
        for token in re.split(r"[,;/\n]", text):
            token = token.strip()
            if len(token) < 2 or len(token) > 40:
                continue
            if " " not in token and len(token.split()) == 1:
                resolved = normalize_slug(token, pack)
                if resolved and resolved in known:
                    scores[resolved] = scores.get(resolved, 0) + 1

    return sorted(scores, key=lambda s: (-scores[s], s))


def _classify_slug(
    slug: str,
    pack: dict[str, Any],
    *,
    hard_vetoes: set[str],
    core_seeds: set[str],
    all_core_seeds: set[str],
    market_core_map: dict[str, list[str]],
    adjacent_seeds: set[str],
    all_adjacent_seeds: set[str],
    hard_exclusions: set[str],
    sunset: dict[str, str],
    exclusion_map: dict[str, str],
    adjacent_class_ids: set[str],
    envelope_slugs: set[str],
) -> tuple[Classification, str]:
    slug = resolve_canonical_slug(slug, pack)
    if slug in hard_vetoes:
        return "excluded", "hard_veto from need_profile"
    if slug in sunset:
        return "sunset", sunset[slug]
    if slug in hard_exclusions and slug not in all_core_seeds:
        exc = exclusion_map.get(slug, "hard_exclusion")
        return "excluded", f"pack hard_exclusion ({exc})"
    if slug == "augment-code":
        return "excluded", "augment-code brand excluded; use augment-cosmos if in scope"
    if slug in all_core_seeds:
        markets = market_core_map.get(slug, [])
        market_label = markets[0] if markets else "market"
        if slug in envelope_slugs or slug == "silver-bullet":
            if slug in core_seeds:
                return "core", "pack core_seed"
            return "core", f"{market_label} market_seed"
        if slug in core_seeds:
            return "excluded", "core_seed without envelope evidence (gap)"
        return "excluded", f"{market_label} market_seed without envelope evidence (gap)"
    if slug in all_adjacent_seeds or slug in adjacent_seeds:
        if slug in all_core_seeds:
            return "excluded", "market core seed; not adjacent"
        return "adjacent", "pack adjacent_seed"
    exc_class = exclusion_map.get(slug)
    if exc_class:
        if exc_class in adjacent_class_ids:
            return "adjacent", f"exclusion_class {exc_class} (adjacent only)"
        return "excluded", f"exclusion_class {exc_class}"
    return "excluded", "not in pack seeds and no inclusion evidence"


def classify_solutions(
    envelopes: list[dict[str, Any]],
    need: dict[str, Any] | None = None,
    pack: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """Classify discovered candidates. Returns catalog audit dict."""
    if pack is None:
        pack = resolve_pack_from_need(need)
    if not pack:
        raise ValueError("category pack required for classification")

    hard_vetoes: set[str] = set()
    for v in (need or {}).get("hard_vetoes") or []:
        hard_vetoes.add(resolve_canonical_slug(slugify(str(v)), pack))

    core_seeds = set(get_core_seed_slugs(pack))
    all_core_seeds = set(get_all_market_seed_slugs(pack, include_adjacent=False))
    market_core_map = _market_core_slug_map(pack)
    adjacent_seeds = set(get_adjacent_seed_slugs(pack))
    all_adjacent_seeds = _all_adjacent_seed_slugs(pack)
    hard_exclusions = get_hard_exclusion_slugs(pack, need)
    sunset = _sunset_map(pack)
    exclusion_map = _exclusion_class_by_slug(pack)
    adjacent_class_ids = set(get_adjacent_class_ids(pack))

    candidates = discover_candidate_slugs(envelopes, pack)
    envelope_slugs = _envelope_evidence_slugs(envelopes, pack)
    by_slug: dict[str, dict[str, str]] = {}
    classified: dict[str, Classification] = {}

    for slug in candidates:
        canonical = resolve_canonical_slug(slug, pack)
        cls, reason = _classify_slug(
            canonical,
            pack,
            hard_vetoes=hard_vetoes,
            core_seeds=core_seeds,
            all_core_seeds=all_core_seeds,
            market_core_map=market_core_map,
            adjacent_seeds=adjacent_seeds,
            all_adjacent_seeds=all_adjacent_seeds,
            hard_exclusions=hard_exclusions,
            sunset=sunset,
            exclusion_map=exclusion_map,
            adjacent_class_ids=adjacent_class_ids,
            envelope_slugs=envelope_slugs,
        )
        classified[canonical] = cls
        by_slug[canonical] = {"classification": cls, "reason": reason}

    core = [s for s, c in classified.items() if c == "core"]
    adjacent = [s for s, c in classified.items() if c == "adjacent"]
    excluded = [s for s, c in classified.items() if c == "excluded"]
    sunset_slugs = [s for s, c in classified.items() if c == "sunset"]

    core = apply_parent_child_dedupe(core, pack)
    deduped_set = set(core)
    for slug, cls in list(classified.items()):
        if cls == "core" and slug not in deduped_set:
            classified[slug] = "excluded"
            by_slug[slug] = {"classification": "excluded", "reason": "parent_child_dedupe"}
            excluded.append(slug)

    core = [s for s, c in classified.items() if c == "core"]
    adjacent = [s for s, c in classified.items() if c == "adjacent"]
    excluded = [s for s, c in classified.items() if c == "excluded"]
    sunset_slugs = [s for s, c in classified.items() if c == "sunset"]

    must_research = get_must_research_slugs(pack, need)
    envelope_slugs = _envelope_evidence_slugs(envelopes, pack)
    gaps = [s for s in must_research if s not in envelope_slugs and s not in core]

    markets_audit: dict[str, dict[str, Any]] = {}
    primary_id = get_primary_market_id(pack)
    for market in get_markets(pack):
        mid = str(market.get("id") or "")
        m_core: list[str] = []
        m_adjacent: list[str] = []
        m_excluded: list[str] = []
        for slug in candidates:
            canonical = resolve_canonical_slug(slug, pack)
            m_cls, m_reason = _classify_slug_for_market(
                canonical,
                market,
                envelope_slugs=envelope_slugs,
                hard_vetoes=hard_vetoes,
                sunset=sunset,
                hard_exclusions=hard_exclusions,
            )
            if m_cls == "core":
                m_core.append(canonical)
            elif m_cls == "adjacent":
                m_adjacent.append(canonical)
            elif m_cls == "excluded":
                m_excluded.append(canonical)
        m_core = apply_parent_child_dedupe(m_core, pack)
        max_m = int(market.get("max_core_count") or pack.get("max_core_count") or 25)
        if len(m_core) > max_m:
            ranked_m = sorted(m_core, key=lambda s: (s not in must_research, s))
            m_core = ranked_m[:max_m]
        markets_audit[mid] = {
            "role": market.get("role"),
            "display_name": market.get("display_name"),
            "chart_eligible": bool(market.get("chart_eligible", True)),
            "core": sorted(set(m_core)),
            "adjacent": sorted(set(m_adjacent)),
            "excluded": sorted(set(m_excluded)),
        }

    all_market_cores: set[str] = set()
    for ma in markets_audit.values():
        all_market_cores.update(ma.get("core") or [])

    matrix_slugs = apply_parent_child_dedupe(sorted(all_market_cores), pack)
    matrix_set = set(matrix_slugs)

    for mid, ma in markets_audit.items():
        ma["adjacent"] = sorted(
            set(ma.get("adjacent") or []) - all_market_cores
        )

    for slug in matrix_set:
        markets = market_core_map.get(slug, [])
        market_label = markets[0] if markets else "matrix"
        classified[slug] = "core"
        by_slug[slug] = {
            "classification": "core",
            "reason": (
                "pack core_seed"
                if slug in core_seeds
                else f"{market_label} market_core (matrix)"
            ),
        }

    primary_core = sorted(markets_audit.get(primary_id, {}).get("core") or [])
    core = apply_parent_child_dedupe(primary_core, pack)
    adjacent = sorted(
        set(s for s, c in classified.items() if c == "adjacent") - all_market_cores
    )
    for slug in adjacent:
        by_slug[slug] = {
            "classification": "adjacent",
            "reason": by_slug.get(slug, {}).get("reason", "pack adjacent_seed"),
        }
    excluded = sorted(
        set(s for s, c in classified.items() if c == "excluded" and s not in matrix_set)
    )
    sunset_slugs = sorted(set(s for s, c in classified.items() if c == "sunset"))
    by_slug = expand_by_slug_aliases(by_slug, pack)

    return {
        "pack_id": pack.get("category_id"),
        "primary_market_id": primary_id,
        "core": core,
        "matrix_slugs": apply_parent_child_dedupe(matrix_slugs, pack),
        "markets": markets_audit,
        "adjacent": sorted(set(adjacent)),
        "excluded": sorted(set(excluded)),
        "sunset": sorted(set(sunset_slugs)),
        "gaps": gaps,
        "by_slug": by_slug,
        "counts": {
            "core": len(core),
            "matrix_slugs": len(matrix_slugs),
            "adjacent": len(set(adjacent)),
            "excluded": len(set(excluded)),
            "sunset": len(set(sunset_slugs)),
            "gaps": len(gaps),
        },
    }


def write_catalog_audit(research_dir: Path, audit: dict[str, Any]) -> Path:
    research_dir = Path(research_dir)
    landscape_dir = research_dir / "landscape"
    landscape_dir.mkdir(parents=True, exist_ok=True)
    out = landscape_dir / "catalog_audit.json"
    out.write_text(json.dumps(audit, indent=2) + "\n", encoding="utf-8")
    return out


def classify_and_audit(
    research_dir: Path,
    envelopes: list[dict[str, Any]] | None = None,
    need: dict[str, Any] | None = None,
) -> dict[str, Any]:
    research_dir = Path(research_dir)
    if need is None:
        need_path = research_dir / "need_profile.json"
        need = json.loads(need_path.read_text(encoding="utf-8")) if need_path.is_file() else {}
    if envelopes is None:
        env_path = research_dir / "contributions" / "all-envelopes.json"
        if env_path.is_file():
            raw = json.loads(env_path.read_text(encoding="utf-8"))
            envelopes = [e for e in raw if isinstance(e, dict)] if isinstance(raw, list) else []
        else:
            envelopes = []
    audit = classify_solutions(envelopes, need)
    write_catalog_audit(research_dir, audit)
    return audit
