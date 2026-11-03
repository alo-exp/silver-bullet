#!/usr/bin/env python3
"""
Build comparison.json and comparison-matrix.md from SCR features + need profile.

Union features across solutions/s/*/features.json, apply priority weights from
need_profile (must_haves -> Critical), compute weighted scores, rank solutions.
"""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

from matrix_core import TICK, score_solutions_from_rows
from need_profile_personas import apply_persona_priority


def _slug(name: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")


def _feature_name(feat: Any) -> str | None:
    if isinstance(feat, str):
        name = feat.strip()
        return name or None
    if isinstance(feat, dict):
        name = feat.get("name") or feat.get("feature")
        return str(name).strip() if name else None
    return None


_TRUE_WORDS = frozenset({"true", "yes", "y", "1", "supported", "present"})


def _feature_supported(feat: Any) -> bool:
    """Whether a feature entry counts as present for the solution.

    A bare string lists a present feature (legacy form, no evidence to check). A
    dict is the documented form and needs an explicit ``supported`` / ``present``
    true (a bool or an affirmative word: the string "false" is false) or a
    non-empty ``evidence_ids`` list; an ``evidence_ids`` list that is present but
    empty means no evidence, so no tick.
    """
    if not isinstance(feat, dict):
        return True
    if "evidence_ids" in feat and not feat["evidence_ids"]:
        return False
    if "supported" not in feat and "present" not in feat:
        return bool(feat.get("evidence_ids"))
    value = feat.get("supported", feat.get("present"))
    if isinstance(value, str):
        return value.strip().lower() in _TRUE_WORDS
    return bool(value)


def load_features(solutions_dir: Path) -> dict[str, dict[str, Any]]:
    out: dict[str, dict[str, Any]] = {}
    if not solutions_dir.is_dir():
        return out
    for sol_dir in sorted(solutions_dir.iterdir()):
        feat_path = sol_dir / "features.json"
        if not feat_path.exists():
            continue
        data = json.loads(feat_path.read_text(encoding="utf-8"))
        name = data.get("solution_name") or sol_dir.name
        out[name] = data
    return out


def priority_for_feature(
    feature: str,
    need: dict[str, Any],
    category: str | None = None,
) -> str:
    overrides = need.get("weights_override") or {}
    if feature in overrides:
        base = overrides[feature]
    else:
        must = {m.lower().strip() for m in need.get("must_haves") or []}
        nice = {n.lower().strip() for n in need.get("nice_to_haves") or []}
        fl = feature.lower().strip()
        if fl in must:
            base = "Critical"
        elif fl in nice:
            base = "High"
        else:
            base = "Medium"
    return apply_persona_priority(feature, category, base, need)


def build_comparison_json(
    features_by_solution: dict[str, dict[str, Any]],
    need: dict[str, Any],
) -> dict[str, Any]:
    all_features: dict[str, str] = {}
    categories: dict[str, list[str]] = {}

    for _name, data in features_by_solution.items():
        for cat in data.get("categories") or []:
            cname = cat.get("name") or "General"
            categories.setdefault(cname, [])
            for feat in cat.get("features") or []:
                fname = _feature_name(feat)
                if not fname:
                    continue
                # A feature listed under several categories is one row (first wins),
                # so it is weighted once.
                if fname in all_features:
                    continue
                all_features[fname] = cname
                categories[cname].append(fname)

    for _name, data in features_by_solution.items():
        for feat in data.get("features") or []:
            fname = _feature_name(feat)
            if not fname or fname in all_features:
                continue
            all_features[fname] = "Capabilities"
            categories.setdefault("Capabilities", []).append(fname)

    solutions = list(features_by_solution.keys())
    rows: list[dict[str, Any]] = []
    row_buffer: list[dict[str, Any]] = []

    for cat_name, feat_names in categories.items():
        rows.append({"type": "category", "name": cat_name})
        for fname in feat_names:
            prio = priority_for_feature(fname, need, cat_name)
            row: dict[str, Any] = {
                "type": "feature",
                "name": fname,
                "priority": prio,
                "solutions": {},
            }
            for sol in solutions:
                data = features_by_solution[sol]
                found_in_categories = False
                has = False
                for cat in data.get("categories") or []:
                    for feat in cat.get("features") or []:
                        if _feature_name(feat) == fname:
                            found_in_categories = True
                            has = _feature_supported(feat)
                            break
                    if found_in_categories:
                        break
                if not found_in_categories:
                    for feat in data.get("features") or []:
                        if _feature_name(feat) == fname:
                            has = _feature_supported(feat)
                            break
                row["solutions"][sol] = TICK if has else ""
            rows.append(row)
            row_buffer.append(row)

    scores = score_solutions_from_rows(row_buffer, solutions)

    ranking = sorted(
        [{"solution": s, "score": scores[s]} for s in solutions],
        key=lambda x: -x["score"],
    )
    for i, r in enumerate(ranking, start=1):
        r["rank"] = i

    tie = [r["solution"] for r in ranking if r["score"] == ranking[0]["score"]] if ranking else []
    tie = tie if len(tie) > 1 else []
    # On a tie the first-listed solution is only a placeholder: "tie" names every
    # tied solution so reports state that the matrix does not separate them.
    winner = ranking[0]["solution"] if ranking else None
    runner = ranking[1]["solution"] if len(ranking) > 1 else None

    return {
        "research_type": need.get("research_type"),
        "license_preference": need.get("license_preference"),
        "categories": list(categories.keys()),
        "rows": rows,
        "rankings": ranking,
        "winner": winner,
        "runner_up": runner,
        "tie": tie,
        "caveats": need.get("constraints") or [],
    }


def matrix_markdown(comparison: dict[str, Any]) -> str:
    solutions = [r["solution"] for r in comparison.get("rankings", [])]
    lines = ["# Comparison Matrix", ""]
    lines.append("| Feature | Priority | " + " | ".join(solutions) + " |")
    lines.append("|---------|----------|" + "|".join(["---"] * len(solutions)) + "|")
    for row in comparison.get("rows", []):
        if row.get("type") == "category":
            lines.append(f"| **{row['name']}** | | " + " | ".join([""] * len(solutions)) + " |")
            continue
        cells = [row["solutions"].get(s, "") for s in solutions]
        lines.append(
            f"| {row['name']} | {row['priority']} | " + " | ".join(cells) + " |"
        )
    lines.append("")
    lines.append("## Rankings")
    for r in comparison.get("rankings", []):
        lines.append(f"- #{r['rank']} **{r['solution']}** — score {r['score']}")
    if comparison.get("tie"):
        lines.append("")
        lines.append(
            "**Tie:** " + ", ".join(comparison["tie"])
            + " have the same score; the matrix does not separate them."
        )
    return "\n".join(lines) + "\n"


def compare_solutions(
    out_dir: Path,
    *,
    need_profile: Path | None = None,
    emit_xlsx: bool = True,
) -> dict[str, Any]:
    """Build comparison.json/md and optionally comparison-matrix.xlsx."""
    need_path = need_profile if need_profile else out_dir / "need_profile.json"
    need = json.loads(need_path.read_text(encoding="utf-8"))

    features = load_features(out_dir / "solutions")
    if len(features) < 2:
        raise ValueError("Need at least 2 solutions with features.json")

    # With a category_pack_id the pack's hard exclusions are binding: an
    # unresolvable pack fails the run rather than skipping the exclusions.
    if need.get("category_pack_id"):
        from dr_category_pack import (
            get_hard_exclusion_slugs,
            project_pack_dirs,
            resolve_canonical_slug,
            resolve_pack_from_need_profile,
        )

        try:
            pack = resolve_pack_from_need_profile(need, project_pack_dirs(out_dir))
        except (OSError, ValueError) as exc:
            raise ValueError(f"category pack could not be resolved: {exc}") from exc
        forbidden = {str(s) for s in get_hard_exclusion_slugs(pack, need) if s}
        features = {
            k: v
            for k, v in features.items()
            if _slug(k) not in forbidden
            and resolve_canonical_slug(_slug(k), pack) not in forbidden
        }
        if len(features) < 2:
            raise ValueError("Fewer than 2 solutions remain after category-pack exclusions")

    comparison = build_comparison_json(features, need)
    comp_dir = out_dir / "comparison"
    comp_dir.mkdir(parents=True, exist_ok=True)
    (comp_dir / "comparison.json").write_text(
        json.dumps(comparison, indent=2), encoding="utf-8"
    )
    (comp_dir / "comparison-matrix.md").write_text(
        matrix_markdown(comparison), encoding="utf-8"
    )

    payload: dict[str, Any] = {"status": "ok", "winner": comparison.get("winner")}
    if emit_xlsx:
        from generate_comparison_xlsx import generate_comparison_xlsx

        try:
            xlsx_result = generate_comparison_xlsx(out_dir)
        except ImportError as exc:
            raise RuntimeError(
                "openpyxl is required for comparison-matrix.xlsx "
                "(pip install openpyxl or pass --no-emit-xlsx)"
            ) from exc
        if xlsx_result.get("status") != "ok":
            raise RuntimeError(xlsx_result.get("reason", "xlsx generation failed"))
        payload["xlsx"] = xlsx_result.get("output")
    return payload


def main() -> None:
    parser = argparse.ArgumentParser(description="Build comparison matrix from SCRs")
    parser.add_argument("--dir", required=True, help="Research output directory")
    parser.add_argument("--need-profile", help="need_profile.json (default: dir/need_profile.json)")
    parser.add_argument(
        "--emit-xlsx",
        action=argparse.BooleanOptionalAction,
        default=True,
        help="Also write comparison/{report-stem}-comparison-matrix.xlsx (default: on; use --no-emit-xlsx to skip)",
    )
    args = parser.parse_args()

    out_dir = Path(args.dir)
    need_path = Path(args.need_profile) if args.need_profile else None
    try:
        payload = compare_solutions(
            out_dir,
            need_profile=need_path,
            emit_xlsx=args.emit_xlsx,
        )
    except (ValueError, RuntimeError) as exc:
        raise SystemExit(str(exc)) from exc
    print(json.dumps(payload))


if __name__ == "__main__":
    main()



