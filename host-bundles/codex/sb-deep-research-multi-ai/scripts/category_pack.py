#!/usr/bin/env python3
"""Load and resolve category market packs for landscape research."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any


def _deep_research_skill_root() -> Path:
    here = Path(__file__).resolve().parent
    for parent in [here.parent, *here.parents]:
        candidate = parent / "silver-deep-research"
        if (candidate / "schemas" / "need_profile.schema.json").is_file():
            return candidate
        candidate = parent / "skills" / "silver-deep-research"
        if (candidate / "schemas" / "need_profile.schema.json").is_file():
            return candidate
    raise FileNotFoundError("silver-deep-research skill root not found")


def category_packs_dir() -> Path:
    return _deep_research_skill_root() / "reference" / "landscape" / "category-packs"


def load_category_pack(pack_id: str) -> dict[str, Any]:
    """Load a category pack JSON by stable pack id (filename without .json)."""
    if not pack_id or not pack_id.replace("-", "").isalnum():
        raise ValueError(f"invalid category_pack_id: {pack_id!r}")
    path = category_packs_dir() / f"{pack_id}.json"
    if not path.is_file():
        raise FileNotFoundError(f"category pack not found: {pack_id} ({path})")
    data = json.loads(path.read_text(encoding="utf-8"))
    if data.get("category_id") != pack_id:
        raise ValueError(
            f"pack category_id {data.get('category_id')!r} does not match id {pack_id!r}"
        )
    return data


def resolve_pack_from_need_profile(need_profile: dict[str, Any]) -> dict[str, Any]:
    """Merge need_profile overrides onto the base category pack."""
    pack_id = need_profile.get("category_pack_id")
    if not pack_id:
        raise ValueError("need_profile missing category_pack_id")
    pack = load_category_pack(str(pack_id))
    merged = dict(pack)
    if need_profile.get("inclusion_criteria"):
        merged["inclusion_criteria"] = need_profile["inclusion_criteria"]
    if need_profile.get("exclusion_classes"):
        merged["exclusion_classes"] = need_profile["exclusion_classes"]
    merged["must_research"] = get_must_research_slugs(merged, need_profile)
    merged["hard_exclusion_slugs"] = sorted(get_hard_exclusion_slugs(merged, need_profile))
    merged["allow_adjacent_section"] = need_profile.get("allow_adjacent_section", True)
    return merged


def get_inclusion_criteria(pack: dict[str, Any]) -> dict[str, Any]:
    criteria = pack.get("inclusion_criteria") or {}
    if not criteria.get("criteria"):
        raise ValueError("pack inclusion_criteria.criteria is empty")
    return criteria


def format_inclusion_criteria_prose(pack: dict[str, Any]) -> str:
    """Plain-language inclusion criteria for landscape report Section 1."""
    criteria = get_inclusion_criteria(pack)
    min_pass = int(criteria.get("min_pass_count") or pack.get("inclusion_threshold") or 3)
    items = list(criteria.get("criteria") or [])
    bullets = "\n".join(
        f"- **{c.get('label', c.get('id', 'Criterion'))}** — {c.get('description', '').strip()}"
        for c in items
        if isinstance(c, dict)
    )
    return (
        f"A vendor belongs in the **core peer set** when it clearly demonstrates at least "
        f"**{min_pass} of {len(items)}** capabilities below (not advisory-only claims):\n\n"
        f"{bullets}"
    )


def get_markets(pack: dict[str, Any]) -> list[dict[str, Any]]:
    """Return market segments; synthesize single APO market from legacy core_seeds when absent."""
    markets = pack.get("markets")
    if markets:
        return list(markets)
    return [
        {
            "id": pack.get("primary_market_id") or "apo",
            "display_name": pack.get("display_name", "Primary market"),
            "role": "primary",
            "definition": pack.get("definition", ""),
            "seeds": pack.get("core_seeds") or [],
            "adjacent_seeds": pack.get("adjacent_seeds") or [],
            "inclusion_criteria": pack.get("inclusion_criteria"),
            "chart_eligible": True,
            "min_core_count": pack.get("min_core_count"),
            "max_core_count": pack.get("max_core_count"),
            "feature_axes": pack.get("feature_axes"),
        }
    ]


def get_primary_market_id(pack: dict[str, Any]) -> str:
    return str(pack.get("primary_market_id") or get_markets(pack)[0]["id"])


def get_market_by_id(pack: dict[str, Any], market_id: str) -> dict[str, Any] | None:
    for market in get_markets(pack):
        if market.get("id") == market_id:
            return market
    return None


def get_market_seeds(pack: dict[str, Any], market_id: str | None = None) -> list[dict[str, Any]]:
    if market_id:
        market = get_market_by_id(pack, market_id)
        return list((market or {}).get("seeds") or [])
    return get_core_seeds(pack)


def get_market_adjacent_seeds(pack: dict[str, Any], market_id: str) -> list[dict[str, Any]]:
    market = get_market_by_id(pack, market_id)
    return list((market or {}).get("adjacent_seeds") or [])


def get_all_market_seed_slugs(pack: dict[str, Any], *, include_adjacent: bool = False) -> list[str]:
    slugs: list[str] = []
    for market in get_markets(pack):
        for seed in market.get("seeds") or []:
            if seed.get("slug"):
                slugs.append(str(seed["slug"]))
        if include_adjacent:
            for seed in market.get("adjacent_seeds") or []:
                if seed.get("slug"):
                    slugs.append(str(seed["slug"]))
    return _dedupe_preserve_order(slugs)


def get_core_seeds(pack: dict[str, Any]) -> list[dict[str, Any]]:
    primary = get_market_by_id(pack, get_primary_market_id(pack))
    if primary and primary.get("seeds"):
        return list(primary["seeds"])
    return list(pack.get("core_seeds") or [])


def get_adjacent_seeds(pack: dict[str, Any]) -> list[dict[str, Any]]:
    primary = get_market_by_id(pack, get_primary_market_id(pack))
    if primary and primary.get("adjacent_seeds") is not None:
        return list(primary["adjacent_seeds"])
    return list(pack.get("adjacent_seeds") or [])


def get_core_seed_slugs(pack: dict[str, Any]) -> list[str]:
    return [str(s["slug"]) for s in get_core_seeds(pack) if s.get("slug")]


def get_adjacent_seed_slugs(pack: dict[str, Any]) -> list[str]:
    return [str(s["slug"]) for s in get_adjacent_seeds(pack) if s.get("slug")]


def get_must_research_slugs(
    pack: dict[str, Any],
    need_profile: dict[str, Any] | None = None,
) -> list[str]:
    slugs: list[str] = []
    for market in get_markets(pack):
        for seed in market.get("seeds") or []:
            if seed.get("must_research") and seed.get("slug"):
                slugs.append(str(seed["slug"]))
    if need_profile:
        for item in need_profile.get("must_research") or []:
            slugs.append(_slugify(str(item)))
        for item in need_profile.get("must_haves") or []:
            # must_haves are capabilities, not product slugs — skip unless slug-like
            if "-" in str(item) and " " not in str(item):
                slugs.append(_slugify(str(item)))
    return _dedupe_preserve_order(slugs)


def get_hard_exclusions(pack: dict[str, Any]) -> list[dict[str, Any]]:
    return list(pack.get("hard_exclusions") or [])


def get_sunset_registry(pack: dict[str, Any]) -> list[dict[str, Any]]:
    return list(pack.get("sunset_registry") or [])


def get_hard_exclusion_slugs(
    pack: dict[str, Any],
    need_profile: dict[str, Any] | None = None,
) -> set[str]:
    slugs: set[str] = set()
    market_cores = set(get_all_market_seed_slugs(pack, include_adjacent=False))
    for entry in get_hard_exclusions(pack):
        if entry.get("slug"):
            slug = str(entry["slug"])
            if slug not in market_cores:
                slugs.add(slug)
    for entry in get_sunset_registry(pack):
        if entry.get("slug"):
            slugs.add(str(entry["slug"]))
    if need_profile:
        for item in need_profile.get("hard_vetoes") or []:
            slugs.add(resolve_canonical_slug(_slugify(str(item)), pack))
    return slugs


def get_product_aliases(pack: dict[str, Any]) -> dict[str, str]:
    aliases = dict(pack.get("product_aliases") or {})
    normalized: dict[str, str] = {}
    for key, value in aliases.items():
        normalized[_slugify(key)] = _slugify(value)
    return normalized


def expand_by_slug_aliases(
    by_slug: dict[str, dict[str, str]],
    pack: dict[str, Any],
) -> dict[str, dict[str, str]]:
    """Mirror product_aliases into by_slug so alias slugs resolve consistently."""
    aliases = get_product_aliases(pack)
    out = dict(by_slug)
    for alias, canonical in aliases.items():
        if alias == canonical:
            continue
        canonical_entry = out.get(canonical)
        if canonical_entry is None or alias in out:
            continue
        mirrored = dict(canonical_entry)
        mirrored["canonical_slug"] = canonical
        mirrored["reason"] = (
            f"alias of {canonical}: {canonical_entry.get('reason', '')}"
        )
        out[alias] = mirrored
    return out


def get_parent_child_dedupe(pack: dict[str, Any]) -> list[dict[str, str]]:
    return list(pack.get("parent_child_dedupe") or [])


def get_exclusion_class_ids(pack: dict[str, Any]) -> list[str]:
    return [str(c["id"]) for c in (pack.get("exclusion_classes") or []) if c.get("id")]


def get_adjacent_class_ids(pack: dict[str, Any]) -> list[str]:
    return [str(c["id"]) for c in (pack.get("adjacent_classes") or []) if c.get("id")]


def get_feature_axes(pack: dict[str, Any]) -> list[dict[str, Any]]:
    return list(pack.get("feature_axes") or [])


def resolve_canonical_slug(slug: str, pack: dict[str, Any]) -> str:
    """Map alias slug to canonical slug using pack product_aliases."""
    normalized = _slugify(slug)
    aliases = get_product_aliases(pack)
    seen: set[str] = set()
    current = normalized
    while current in aliases and current not in seen:
        seen.add(current)
        current = aliases[current]
    return current


def apply_parent_child_dedupe(
    slugs: list[str],
    pack: dict[str, Any],
) -> list[str]:
    """Drop parent slugs when prefer_slug is also present; collapse aliases."""
    canonical = [resolve_canonical_slug(s, pack) for s in slugs]
    slug_set = set(canonical)
    drop: set[str] = set()
    for rule in get_parent_child_dedupe(pack):
        parent = resolve_canonical_slug(rule.get("parent_slug", ""), pack)
        prefer = resolve_canonical_slug(rule.get("prefer_slug", ""), pack)
        if (
            parent
            and prefer
            and parent != prefer
            and parent in slug_set
            and prefer in slug_set
        ):
            drop.add(parent)
    out: list[str] = []
    seen: set[str] = set()
    for slug in canonical:
        if slug in drop or slug in seen:
            continue
        seen.add(slug)
        out.append(slug)
    return out


def pack_prompt_block(pack: dict[str, Any]) -> str:
    """Render pack contract for injection into landscape retrieve/consolidate prompts."""
    criteria = get_inclusion_criteria(pack)
    min_pass = criteria.get("min_pass_count", 3)
    criteria_lines = "\n".join(
        f"  - **{c['id']}** ({c['label']}): {c['description']}"
        for c in criteria.get("criteria", [])
    )
    exclusion_lines = "\n".join(
        f"  - `{c['id']}` — {c['label']}: {c['description']}"
        for c in (pack.get("exclusion_classes") or [])
    )
    core_names = ", ".join(s.get("name", s.get("slug", "")) for s in get_core_seeds(pack))
    adjacent_names = ", ".join(s.get("name", s.get("slug", "")) for s in get_adjacent_seeds(pack))
    market_lines = []
    for market in get_markets(pack):
        seeds = ", ".join(s.get("name", s.get("slug", "")) for s in (market.get("seeds") or []))
        market_lines.append(
            f"  - **{market.get('display_name')}** (`{market.get('id')}`, {market.get('role')}): {seeds}"
        )
    markets_block = ""
    if len(get_markets(pack)) > 1:
        markets_block = f"""
**Multi-market landscape (chart + solution cards per market):**
{chr(10).join(market_lines)}

**Membership is NOT mutually exclusive:** a solution may compete as core/adjacent in one OR multiple markets when evidence supports it (e.g. Silver Bullet in both APO and sdlc-plugins). Do not force exclusive single-market placement.
"""
    hard_names = ", ".join(
        e.get("name", e.get("slug", "")) for e in get_hard_exclusions(pack)
    )
    sunset_names = ", ".join(
        e.get("name", e.get("slug", "")) for e in get_sunset_registry(pack)
    )
    return f"""## Category market contract — {pack.get("display_name", pack.get("category_id"))}

**Definition:** {pack.get("definition", "")}

**Jobs to be done:**
{chr(10).join(f"- {j}" for j in (pack.get("jobs_to_be_done") or []))}

**Inclusion criteria (candidate must pass ≥{min_pass} of {len(criteria.get("criteria", []))}):**
{criteria_lines}

**Exclusion classes (never Top-N / MQ / Wave / matrix — Adjacent or Excluded only):**
{exclusion_lines}

**Must-research core seeds:** {core_names}
{markets_block}
**Adjacent-only seeds (short Adjacent section if enabled):** {adjacent_names}

**Hard exclusions (never list as in-scope):** {hard_names}

**Sunset / discontinued (never list):** {sunset_names}

**Core count bounds:** {pack.get("min_core_count")}–{pack.get("max_core_count")} in-scope solutions total (commercial + OSS).

**Naming rules:** Use product-level names (e.g. Augment Cosmos not Augment Code; Devin not Cognition+Devin). Apply parent/child dedupe from pack aliases.
"""


def _slugify(value: str) -> str:
    return (
        value.strip()
        .lower()
        .replace("_", "-")
        .replace(" ", "-")
    )


def _dedupe_preserve_order(items: list[str]) -> list[str]:
    seen: set[str] = set()
    out: list[str] = []
    for item in items:
        if item not in seen:
            seen.add(item)
            out.append(item)
    return out


# --- Bridge helpers for multi-AI synthesis / classifier pipeline ---

def resolve_pack_from_need(need: dict[str, Any] | None) -> dict[str, Any] | None:
    """Load pack from need_profile; return None when category_pack_id absent."""
    if not need or not need.get("category_pack_id"):
        return None
    try:
        return resolve_pack_from_need_profile(need)
    except (FileNotFoundError, ValueError):
        return None


def slugify(value: str) -> str:
    return _slugify(value)


def build_alias_map(pack: dict[str, Any]) -> dict[str, str]:
    aliases = dict(pack.get("product_aliases") or {})
    for seed in get_core_seeds(pack) + get_adjacent_seeds(pack):
        slug = str(seed.get("slug", ""))
        if slug:
            aliases[slug] = slug
            aliases[_slugify(slug)] = slug
            name = str(seed.get("name", ""))
            if name:
                aliases[_slugify(name)] = slug
    for entry in get_hard_exclusions(pack) + get_sunset_registry(pack):
        slug = str(entry.get("slug", ""))
        if slug:
            aliases[slug] = resolve_canonical_slug(slug, pack)
    normalized: dict[str, str] = {}
    for key, value in aliases.items():
        normalized[_slugify(key)] = resolve_canonical_slug(str(value), pack)
    return normalized


def build_known_solutions(pack: dict[str, Any]) -> dict[str, str]:
    names: dict[str, str] = {}
    for market in get_markets(pack):
        for seed in (market.get("seeds") or []) + (market.get("adjacent_seeds") or []):
            if seed.get("slug"):
                names[str(seed["slug"])] = str(seed.get("name") or seed["slug"])
    for entry in get_hard_exclusions(pack) + get_sunset_registry(pack):
        if entry.get("slug"):
            names[str(entry["slug"])] = str(entry.get("name") or entry["slug"])
    for alias, canonical in get_product_aliases(pack).items():
        if canonical in names and alias not in names:
            names[alias] = names[canonical]
    return names


def build_license_by_slug(pack: dict[str, Any]) -> dict[str, str]:
    licenses: dict[str, str] = {}
    for market in get_markets(pack):
        for seed in (market.get("seeds") or []) + (market.get("adjacent_seeds") or []):
            if seed.get("slug"):
                licenses[str(seed["slug"])] = str(seed.get("license") or "commercial")
    for seed in get_core_seeds(pack) + get_adjacent_seeds(pack):
        if seed.get("slug") and seed["slug"] not in licenses:
            licenses[str(seed["slug"])] = str(seed.get("license") or "commercial")
    for alias, canonical in get_product_aliases(pack).items():
        if canonical in licenses and alias not in licenses:
            licenses[alias] = licenses[canonical]
    return licenses


def build_overview_seeds(pack: dict[str, Any]) -> dict[str, str]:
    """Pack may carry overview_seeds dict; otherwise empty (synthesis uses SCR)."""
    return dict(pack.get("overview_seeds") or {})


def normalize_slug(token: str, pack: dict[str, Any] | None = None) -> str | None:
    if not token or not pack:
        return _slugify(token) if token else None
    return resolve_canonical_slug(_slugify(token), pack)


def _seed_homepage(seed: dict[str, Any]) -> str | None:
    for key in ("homepage", "url", "homepage_url", "official_url"):
        value = seed.get(key)
        if value:
            return str(value).strip()
    return None


def _seed_github(seed: dict[str, Any]) -> str | None:
    for key in ("github", "github_url", "repo", "repo_url"):
        value = seed.get(key)
        if value:
            return str(value).strip()
    return None


def build_homepage_by_slug(pack: dict[str, Any]) -> dict[str, str]:
    """Slug → official homepage from pack seeds, homepage_by_slug map, and aliases."""
    urls: dict[str, str] = {}
    pack_map = pack.get("homepage_by_slug") or {}
    if isinstance(pack_map, dict):
        for slug, url in pack_map.items():
            if slug and url:
                urls[str(slug)] = str(url).strip()

    for market in get_markets(pack):
        for seed in (market.get("seeds") or []) + (market.get("adjacent_seeds") or []):
            if not isinstance(seed, dict) or not seed.get("slug"):
                continue
            slug = str(seed["slug"])
            homepage = _seed_homepage(seed)
            if homepage:
                urls[slug] = homepage

    for alias, canonical in get_product_aliases(pack).items():
        if canonical in urls and alias not in urls:
            urls[alias] = urls[canonical]
        if alias in urls and canonical not in urls:
            urls[canonical] = urls[alias]
    return urls


def build_github_by_slug(pack: dict[str, Any]) -> dict[str, str]:
    """Slug → canonical GitHub repo from pack github_by_slug map and seed fields."""
    urls: dict[str, str] = {}
    pack_map = pack.get("github_by_slug") or {}
    if isinstance(pack_map, dict):
        for slug, url in pack_map.items():
            if slug and url:
                urls[str(slug)] = str(url).strip()

    for market in get_markets(pack):
        for seed in (market.get("seeds") or []) + (market.get("adjacent_seeds") or []):
            if not isinstance(seed, dict) or not seed.get("slug"):
                continue
            slug = str(seed["slug"])
            github = _seed_github(seed)
            if github:
                urls[slug] = github

    for alias, canonical in get_product_aliases(pack).items():
        if canonical in urls and alias not in urls:
            urls[alias] = urls[canonical]
        if alias in urls and canonical not in urls:
            urls[canonical] = urls[alias]
    return urls


def catalog_entries_from_pack(
    pack: dict[str, Any],
    core_slugs: list[str],
    *,
    market_id: str | None = None,
) -> tuple[list[dict[str, str]], list[dict[str, str]]]:
    """Split classified core slugs into commercial and OSS catalog entries."""
    names = build_known_solutions(pack)
    license_by_slug = build_license_by_slug(pack)
    homepage_by_slug = build_homepage_by_slug(pack)
    github_by_slug = build_github_by_slug(pack)

    commercial: list[dict[str, str]] = []
    oss: list[dict[str, str]] = []
    for slug in core_slugs:
        if market_id:
            market = get_market_by_id(pack, market_id)
            market_slugs = {str(s["slug"]) for s in (market or {}).get("seeds") or [] if s.get("slug")}
            if slug not in market_slugs:
                continue
        entry: dict[str, str] = {
            "slug": slug,
            "name": names.get(slug, slug.replace("-", " ").title()),
        }
        homepage = homepage_by_slug.get(slug)
        if homepage:
            entry["url"] = homepage
        github = github_by_slug.get(slug)
        if github:
            entry["github"] = github
        lic = license_by_slug.get(slug, "commercial")
        if lic == "oss":
            entry["license"] = "OSS"
            oss.append(entry)
        else:
            commercial.append(entry)
    return commercial, oss


def market_slug_sets(pack: dict[str, Any]) -> dict[str, set[str]]:
    """Map market id → set of core seed slugs for that market."""
    out: dict[str, set[str]] = {}
    for market in get_markets(pack):
        mid = str(market.get("id") or "")
        if not mid:
            continue
        out[mid] = {str(s["slug"]) for s in (market.get("seeds") or []) if s.get("slug")}
    return out

