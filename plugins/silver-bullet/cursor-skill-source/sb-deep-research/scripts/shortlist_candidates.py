#!/usr/bin/env python3
"""
Shortlist top-N candidates from landscape survey for SCR deep dive.

Reads candidates.jsonl (one JSON object per line with name, score, license, etc.)
and need_profile.json for license_preference filtering. Outputs shortlist.json
with exactly --count entries (default 5 for solution-landscape).
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any


def _slug(name: str) -> str:
    return "".join(c if c.isalnum() else "-" for c in name.lower()).strip("-")[:64]


def load_jsonl(path: Path) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        rows.append(json.loads(line))
    return rows


def _normalize_license(lic: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", (lic or "").lower())


_COMMERCIAL_MARKERS = ("commercial", "proprietary", "saas")


def _is_commercial_license(lic: str) -> bool:
    if not lic:
        return False
    norm = _normalize_license(lic)
    if not norm:
        return False
    if "noncommercial" in norm or "notcommercial" in norm:
        return False
    if norm in _COMMERCIAL_MARKERS:
        return True
    return any(marker in norm for marker in _COMMERCIAL_MARKERS)


_OSS_WORDS = frozenset({"oss", "opensource", "foss", "floss", "apache", "mit", "gpl", "bsd", "isc",
                        "mpl", "lgpl", "agpl", "unlicense", "zlib", "epl", "cddl", "osl", "postgresql"})
_OSS_PREFIXES = ("apache", "mit", "bsd", "gpl", "lgpl", "agpl", "mpl", "isc", "epl", "cddl", "osl",
                 "unlicense", "zlib", "cc0", "opensource")


def _is_oss_license(lic: str) -> bool:
    """SPDX ids (Apache-2.0, MIT, BSD-3-Clause, GPL-3.0-or-later, ...) and plain names."""
    norm = _normalize_license(lic)
    if not norm or _is_commercial_license(lic):
        return False
    if "source-available" in lic.lower() or "sourceavailable" in norm:
        return False
    return norm in _OSS_WORDS or norm.startswith(_OSS_PREFIXES)


def license_ok(row: dict[str, Any], pref: str) -> bool:
    lic = (row.get("license") or row.get("license_type") or "").strip()
    if pref == "mixed":
        return True
    if pref == "oss":
        return _is_oss_license(lic)
    if pref == "commercial":
        return _is_commercial_license(lic)
    return True


def score_row(row: dict[str, Any], must_haves: list[str]) -> float:
    base = float(row.get("score", row.get("relevance", 0)) or 0)
    name_blob = json.dumps(row).lower()
    for mh in must_haves:
        if mh.lower() in name_blob:
            base += 2.0
    return base


def shortlist(
    candidates: list[dict[str, Any]],
    need_profile: dict[str, Any],
    count: int,
    pack_dirs: Any = (),
) -> list[dict[str, Any]]:
    forbidden: set[str] = set()
    pack = None
    if need_profile.get("category_pack_id"):
        from dr_category_pack import (
            get_hard_exclusion_slugs,
            resolve_canonical_slug,
            resolve_pack_from_need_profile,
        )

        # Fail closed: a category pack that cannot be resolved is an error, not a skip.
        pack = resolve_pack_from_need_profile(need_profile, pack_dirs)
        forbidden = {str(x) for x in get_hard_exclusion_slugs(pack, need_profile) if x}
    pref = need_profile.get("license_preference", "mixed")
    must = need_profile.get("must_haves") or []
    vetoes = {v.lower() for v in need_profile.get("hard_vetoes") or []}

    filtered = []
    for row in candidates:
        name = row.get("name") or row.get("solution") or ""
        if any(v in name.lower() for v in vetoes):
            continue
        if not license_ok(row, pref):
            continue
        if pack is not None:
            cand = _slug(str(row.get("slug") or name))
            by_name = _slug(name)
            if {cand, by_name, resolve_canonical_slug(cand, pack),
                    resolve_canonical_slug(by_name, pack)} & forbidden:
                continue
        filtered.append(row)

    ranked = sorted(filtered, key=lambda r: -score_row(r, must))
    picked = ranked[:count]
    result = []
    for i, row in enumerate(picked, start=1):
        name = row.get("name") or row.get("solution") or f"solution-{i}"
        result.append({
            "rank": i,
            "name": name,
            "slug": _slug(str(row.get("slug") or name)) or _slug(name) or f"solution-{i}",
            "license": row.get("license"),
            "rationale": row.get("rationale", "Top candidate from landscape survey"),
            "score": score_row(row, must),
        })
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description="Shortlist top-N solutions for SCR")
    parser.add_argument("--candidates", required=True, help="candidates.jsonl path")
    parser.add_argument("--need-profile", required=True, help="need_profile.json path")
    parser.add_argument("--out", required=True, help="Output shortlist.json path")
    parser.add_argument("--count", type=int, default=5, help="Exact shortlist size")
    args = parser.parse_args()

    candidates = load_jsonl(Path(args.candidates))
    need_profile = json.loads(Path(args.need_profile).read_text(encoding="utf-8"))
    from dr_category_pack import project_pack_dirs

    try:
        items = shortlist(
            candidates, need_profile, args.count,
            project_pack_dirs(Path(args.need_profile).resolve().parent),
        )
    except (OSError, ValueError) as exc:
        print(json.dumps({"status": "error", "reason": f"category pack: {exc}"}), file=sys.stderr)
        sys.exit(1)

    if len(items) != args.count:
        print(
            json.dumps({
                "status": "error",
                "reason": f"shortlist has {len(items)} items, expected {args.count}",
            }),
            file=sys.stderr,
        )
        sys.exit(1)

    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    payload = {"count": args.count, "solutions": items}
    out_path.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    print(json.dumps({"status": "ok", "count": len(items), "out": str(out_path)}))


if __name__ == "__main__":
    main()
