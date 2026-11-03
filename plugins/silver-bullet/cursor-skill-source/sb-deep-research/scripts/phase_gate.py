#!/usr/bin/env python3
"""
Phase gate — validates required artifacts exist before phase rollup.

Pattern adapted from lingzhi227 file-gate (idea-derived; see reference/provenance.md).
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any


def _skill_root() -> Path:
    return Path(__file__).resolve().parent.parent


def load_phases_config() -> dict[str, Any]:
    root = _skill_root()
    json_path = root / "phases.json"
    if json_path.exists():
        with open(json_path, encoding="utf-8") as f:
            return json.load(f)
    yaml_path = root / "phases.yaml"
    if yaml_path.exists():
        try:
            import yaml  # type: ignore
        except ImportError as exc:
            raise RuntimeError("phases.json missing and PyYAML not installed") from exc
        with open(yaml_path, encoding="utf-8") as f:
            return yaml.safe_load(f)
    raise FileNotFoundError("Neither phases.json nor phases.yaml found")


def resolve_research_type(out_dir: Path, explicit: str | None = None) -> str:
    if explicit:
        return explicit
    manifest_path = out_dir / "run_manifest.json"
    if manifest_path.exists():
        rt = json.loads(manifest_path.read_text(encoding="utf-8")).get("research_type")
        if rt:
            return rt
    return "default"


def phase_required_artifacts(
    phase_key: str,
    config: dict[str, Any],
    research_type: str = "default",
) -> list[str]:
    phases = config.get("phases", {})
    if phase_key not in phases:
        return []
    base = list(phases[phase_key].get("required_artifacts", []))
    rt_cfg = config.get("research_types", {}).get(research_type, {})
    extra = rt_cfg.get("phase_artifacts", {}).get(phase_key, {})
    for artifact in extra.get("add", []):
        if artifact not in base:
            base.append(artifact)
    return base


SOLUTION_TYPES = frozenset({"solution-landscape", "solution-compare"})
SOLUTION_ALLOWED_MODES = frozenset({"deep", "ultradeep"})


def check_solution_mode_gate(mode: str, research_type: str) -> tuple[bool, str]:
    """Solution research types allow only deep or ultradeep mode."""
    if research_type not in SOLUTION_TYPES:
        return True, "ok"
    if mode not in SOLUTION_ALLOWED_MODES:
        return False, (
            f"research_type={research_type} requires mode deep or ultradeep "
            f"(got {mode})"
        )
    return True, "ok"


def resolve_mode(out_dir: Path, explicit: str | None = None) -> str | None:
    if explicit:
        return explicit
    manifest_path = out_dir / "run_manifest.json"
    if manifest_path.exists():
        mode = json.loads(manifest_path.read_text(encoding="utf-8")).get("mode")
        if mode:
            return mode
    return None


def _category_packs_dir() -> Path:
    return _skill_root() / "reference" / "landscape" / "category-packs"


def _load_category_pack_for_gate(pack_id: str) -> dict[str, Any]:
    path = _category_packs_dir() / f"{pack_id}.json"
    if not path.is_file():
        raise FileNotFoundError(f"category pack not found: {pack_id}")
    data = json.loads(path.read_text(encoding="utf-8"))
    if data.get("category_id") != pack_id:
        raise ValueError(f"pack category_id mismatch for {pack_id}")
    return data


def _effective_inclusion_criteria(need_profile: dict[str, Any], pack: dict[str, Any]) -> dict[str, Any]:
    override = need_profile.get("inclusion_criteria")
    if override:
        return override
    return pack.get("inclusion_criteria") or {}


def check_category_pack_gate(need_profile: dict[str, Any]) -> tuple[bool, str]:
    """Fail closed when landscape/compare lacks a resolvable pack with inclusion criteria."""
    pack_id = need_profile.get("category_pack_id")
    if not pack_id:
        return False, "need_profile.json missing category_pack_id (required for solution research)"
    try:
        pack = _load_category_pack_for_gate(str(pack_id))
    except (FileNotFoundError, ValueError, json.JSONDecodeError) as exc:
        return False, f"unresolvable category_pack_id {pack_id!r}: {exc}"
    criteria = _effective_inclusion_criteria(need_profile, pack)
    items = criteria.get("criteria") or []
    if not items:
        return False, "inclusion_criteria empty (pack and need_profile overrides)"
    if criteria.get("rule") != "min_pass_count":
        return False, "inclusion_criteria.rule must be min_pass_count"
    min_pass = criteria.get("min_pass_count")
    if not isinstance(min_pass, int) or min_pass < 1:
        return False, "inclusion_criteria.min_pass_count must be a positive integer"
    return True, "ok"


def check_need_profile_gate(
    out_dir: Path,
    research_type: str | None = None,
) -> tuple[bool, str]:
    """Block DR-RETRIEVE until need_profile interview is complete (solution types)."""
    path = out_dir / "need_profile.json"
    if not path.exists():
        return False, "missing need_profile.json"
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return False, "invalid need_profile.json"
    if not data.get("interview_complete"):
        return False, "need_profile.json interview_complete is false"
    if data.get("license_preference") not in ("oss", "commercial", "mixed"):
        return False, "need_profile.json license_preference not set"
    rt = research_type or resolve_research_type(out_dir)
    if rt in SOLUTION_TYPES:
        pack_ok, pack_detail = check_category_pack_gate(data)
        if not pack_ok:
            return False, pack_detail
    return True, "ok"


def artifact_satisfied(out_dir: Path, artifact: str) -> tuple[bool, str]:
    path = out_dir / artifact
    if not path.exists():
        return False, f"missing: {artifact}"

    if artifact.endswith(".jsonl"):
        if path.stat().st_size == 0:
            return False, f"empty: {artifact}"
        return True, "ok"

    if artifact.endswith(".md"):
        text = path.read_text(encoding="utf-8").strip()
        if len(text) < 20:
            return False, f"too short: {artifact}"
        return True, "ok"

    if artifact.endswith(".json"):
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            return False, f"invalid json: {artifact}"
        if not data:
            return False, f"empty: {artifact}"
        if artifact == "shortlist/shortlist.json":
            if resolve_research_type(out_dir) == "solution-landscape":
                solutions = data.get("solutions") or []
                if len(solutions) != 5:
                    return False, (
                        f"shortlist must have exactly 5 solutions, got {len(solutions)}"
                    )
        return True, "ok"

    if path.stat().st_size == 0:
        return False, f"empty: {artifact}"
    return True, "ok"


def check_phase(out_dir: Path, phase_key: str, config: dict[str, Any] | None = None, research_type: str | None = None) -> dict[str, Any]:
    config = config or load_phases_config()
    phases = config.get("phases", {})
    if phase_key not in phases:
        return {"phase": phase_key, "status": "error", "reason": f"unknown phase: {phase_key}"}

    rt = resolve_research_type(out_dir, research_type)
    phase = phases[phase_key]
    results: list[dict[str, str]] = []
    all_ok = True

    if phase_key in ("scope", "retrieve") and rt in SOLUTION_TYPES:
        ok, detail = check_need_profile_gate(out_dir, research_type=rt)
        results.append({"artifact": "need_profile.json (gate)", "ok": ok, "detail": detail})
        if not ok:
            all_ok = False

    for artifact in phase_required_artifacts(phase_key, config, rt):
        ok, detail = artifact_satisfied(out_dir, artifact)
        results.append({"artifact": artifact, "ok": ok, "detail": detail})
        if not ok:
            all_ok = False

    return {
        "phase": phase_key,
        "phase_id": phase.get("id"),
        "research_type": rt,
        "status": "pass" if all_ok else "fail",
        "artifacts": results,
    }


def check_mode_complete(out_dir: Path, mode: str, config: dict[str, Any] | None = None, research_type: str | None = None) -> dict[str, Any]:
    config = config or load_phases_config()
    modes = config.get("modes", {})
    if mode not in modes:
        return {"mode": mode, "status": "error", "reason": f"unknown mode: {mode}"}

    rt = resolve_research_type(out_dir, research_type)
    mode_ok, mode_detail = check_solution_mode_gate(mode, rt)
    if not mode_ok:
        return {
            "mode": mode,
            "research_type": rt,
            "status": "fail",
            "reason": mode_detail,
            "phases": [],
        }

    phase_results = []
    all_ok = True
    for phase_key in modes[mode].get("phases", []):
        result = check_phase(out_dir, phase_key, config, rt)
        phase_results.append(result)
        if result["status"] != "pass":
            all_ok = False

    return {
        "mode": mode,
        "research_type": rt,
        "status": "pass" if all_ok else "fail",
        "phases": phase_results,
    }


def cmd_check(args: argparse.Namespace) -> int:
    out_dir = Path(args.dir).resolve()
    if not out_dir.is_dir():
        print(json.dumps({"status": "error", "reason": f"not a directory: {out_dir}"}))
        return 1

    rt = getattr(args, "research_type", None)

    resolved_rt = resolve_research_type(out_dir, rt)

    if args.phase:
        mode = resolve_mode(out_dir, args.mode)
        if resolved_rt in SOLUTION_TYPES and mode:
            mode_ok, mode_detail = check_solution_mode_gate(mode, resolved_rt)
            if not mode_ok:
                print(json.dumps({
                    "phase": args.phase,
                    "research_type": resolved_rt,
                    "mode": mode,
                    "status": "fail",
                    "reason": mode_detail,
                }, indent=2))
                return 1
        result = check_phase(out_dir, args.phase, research_type=rt)
    else:
        mode = resolve_mode(out_dir, args.mode)
        if not mode:
            mode = "standard"
        result = check_mode_complete(out_dir, mode, research_type=rt)

    print(json.dumps(result, indent=2))
    return 0 if result.get("status") == "pass" else 1


def main() -> None:
    parser = argparse.ArgumentParser(description="Validate phase artifacts before rollup")
    parser.add_argument("--dir", required=True, help="Research output directory")
    parser.add_argument("--phase", help="Single phase key (e.g. retrieve)")
    parser.add_argument("--mode", help="Mode for full gate (quick|standard|deep|ultradeep)")
    parser.add_argument(
        "--research-type",
        dest="research_type",
        help="Override research_type (default|solution-landscape|solution-compare)",
    )
    args = parser.parse_args()
    sys.exit(cmd_check(args))


if __name__ == "__main__":
    main()

