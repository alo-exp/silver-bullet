#!/usr/bin/env python3
"""Host-driven DR-multi-AI live phase runner."""

from __future__ import annotations

import hashlib
import json
import secrets
from pathlib import Path
from typing import Any

from skill_paths import ensure_dir_on_path, ensure_scripts_on_path

DRM_SCRIPTS = Path(__file__).resolve().parent
ensure_scripts_on_path("silver-multi-ai-task", marker="live_dispatch.py")
ensure_dir_on_path(DRM_SCRIPTS)

from consolidate import consolidate  # noqa: E402
from json_hash import sha256_bytes, sha256_json  # noqa: E402
from live_dispatch import dispatch_phase_parallel, stub_mode  # noqa: E402
from materialize_solution_artifacts import materialize_solution_artifacts  # noqa: E402
from synthesize_landscape import synthesize_landscape  # noqa: E402
from category_pack import (  # noqa: E402
    get_must_research_slugs,
    load_category_pack,
    pack_prompt_block,
    resolve_pack_from_need,
)
from multi_ai_core import (  # noqa: E402
    BudgetPolicy,
    PoolSelection,
    build_result_index,
    detect_host,
    empty_ledger,
    new_run_id,
    new_work_item_id,
    resolve_pool,
    utc_now_iso,
)


def deterministic_work_item_id(run_id: str, phase_id: str) -> str:
    payload = f"{run_id}\0{phase_id}".encode("utf-8")
    return f"work-{hashlib.sha256(payload).hexdigest()[:32]}"


def research_brief(query: str, research_type: str) -> str:
    lines = [
        f"Research topic: {query}",
        f"Research type: {research_type}",
        "Understand Silver Bullet (repo + site at https://sb.alolabs.dev/).",
        "Multi-market landscape — chart + solution cards **per market**:",
        "  1. **Primary (APO):** Agentic Process Orchestrators — compliance wrappers above host runtimes.",
        "  2. **Secondary (SDLC plugins):** OSS methodology packs (BMAD, GSD, Superpowers, GitHub Spec Kit, Oh My plugins, Zuvo as OSS, SuperClaude, Ruflo) — formidable SB substitutes even if adjacent to APO.",
        "  3. **Tertiary (agentic SDLC SaaS):** Factory/Factory.ai, Devin, Augment Cosmos, Tembo — analyst-grade substitutes even when vendors do not self-label APO.",
        "APO targeting must NOT exclude secondary-market OSS/plugin substitutes from solution cards or charts.",
        "Zuvo license is OSS (not commercial). Apply factory↔factory-ai aliases from category pack.",
        "Few products self-label APO; map Cosmos/Factory/Devin-class vendors as landscape peers per market definition.",
        "Produce startup-weighted comparison matrix entries and evidence-backed claims.",
    ]
    return "\n".join(lines)


def build_phase_query(output_root: Path, query: str, research_type: str) -> str:
    """Research brief plus [CATEGORY_PACK] block for DR-RETRIEVE / DR-TRIANGULATE workers."""
    brief = research_brief(query, research_type)
    need_path = output_root / "need_profile.json"
    if not need_path.is_file():
        return brief
    try:
        need = json.loads(need_path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return brief
    pack = resolve_pack_from_need(need)
    if pack:
        brief = f"{brief}\n\n[CATEGORY_PACK]\n{pack_prompt_block(pack)}"
    return brief


def write_scope(output_root: Path, query: str) -> None:
    scope = f"""# Landscape scope

Agentic SDLC orchestration solutions operating **one level above coding agents** — end-to-end, process-driven, workflow-based agentic layers for software engineering and DevOps (SecOps-adjacent). Excludes raw LLM APIs and single-shot copilots.

Research topic: `{query}`
"""
    output_root.mkdir(parents=True, exist_ok=True)
    (output_root / "scope.md").write_text(scope, encoding="utf-8")


def write_need_profile(output_root: Path) -> None:
    pack_id = "agentic-sdlc-process-orchestrator"
    pack = load_category_pack(pack_id)
    profile: dict[str, Any] = {
        "category": pack.get("display_name", "Agentic SDLC Process Orchestrators"),
        "category_pack_id": pack_id,
        "audience": "startup engineering leaders",
        "persona_id": "startup",
        "license_preference": "mixed",
        "must_haves": [
            "workflow composition",
            "multi-agent orchestration",
            "verification gates",
            "cross-session state",
            "process layer above host runtime",
        ],
        "must_research": get_must_research_slugs(pack),
        "allow_adjacent_section": True,
        "adjacent_categories": [
            "SDLC plugin substitutes (BMAD, GSD, Superpowers, Spec Kit, Oh My, Zuvo OSS)",
            "agentic SDLC SaaS (Factory, Devin, Augment Cosmos)",
            "host runtimes (Cursor, Claude Code, Codex)",
            "generic agent frameworks (LangGraph, CrewAI)",
        ],
        "hard_vetoes": [
            e["slug"] for e in (pack.get("hard_exclusions") or [])[:8]
        ],
        "success_criteria": [
            "Three market charts (APO, SDLC plugins, agentic SDLC SaaS) with per-market solution cards",
            "BMAD, GSD, Superpowers, Spec Kit, Zuvo cards present; Zuvo in oss_vendors",
            "Section 8 does not exclude secondary/tertiary market cores",
            "Coding agents excluded from APO Top-N only — not from secondary/tertiary markets",
            "Adjacent and Excluded sections present when evidence supports",
        ],
        "interview_complete": True,
        "auto_assumed": True,
    }
    (output_root / "need_profile.json").write_text(
        json.dumps(profile, indent=2) + "\n",
        encoding="utf-8",
    )


def build_run_manifest(
    *,
    run_id: str,
    query: str,
    mode: str,
    research_type: str,
    report_dir: str,
    selection: PoolSelection,
    parallel_phases: list[str],
    started_at: str,
    finished_at: str | None = None,
    dispatch_mode: str = "live",
    budget_stop_reason: str | None = None,
    work_item_refs: list[dict[str, Any]] | None = None,
) -> dict[str, Any]:
    resolved = resolve_pool(selection)
    phases_out = []
    refs = work_item_refs or []
    if not refs:
        for phase_id in parallel_phases:
            wid = deterministic_work_item_id(run_id, phase_id)
            phases_out.append({"phase_id": phase_id, "work_item_id": wid, "parallel": True})
            refs.append({"work_item_id": wid, "manifest_path": f"work-items/{wid}/multi-ai-work-item-manifest-v1.json", "manifest_sha256": "0" * 64})
    else:
        for phase_id in parallel_phases:
            wid = deterministic_work_item_id(run_id, phase_id)
            phases_out.append({"phase_id": phase_id, "work_item_id": wid, "parallel": True})

    return {
        "schema_id": "deep-research-run-manifest-v4",
        "version": "4.0.0",
        "spine": "multi-ai-task-v2",
        "run_id": run_id,
        "query": query,
        "mode": mode,
        "research_type": research_type,
        "started_at": started_at,
        "finished_at": finished_at,
        "report_dir": report_dir,
        "workflow_id": "WF-SILVER-DEEP-RESEARCH-MULTI-AI",
        "multi_ai": {
            "budget": {
                "currency_micro_usd_cap": 5_000_000,
                "total_tokens_cap": 2_000_000,
                "currency_micro_usd_actual": 0,
                "total_tokens_actual": 0,
                "price_known": False,
                "usage_metered": dispatch_mode == "live",
                "budget_stop_reason": budget_stop_reason,
            },
            "phases": phases_out,
            "work_item_refs": refs,
            "pool_config": {
                "ocg_pool": selection.ocg_pool,
                "cursor_pool": selection.cursor_pool,
                "include_only": selection.include_only,
                "resolved_pool": [{"logical_model_id": x["logical_model_id"], "backend": x["backend"]} for x in resolved],
                "dispatch_mode": dispatch_mode,
            },
            "result_index_path": "result-index.json",
            "result_index_sha256": None,
        },
        "artifact_paths": {
            "scope": "scope.md",
            "landscape": "landscape/landscape-report.md",
            "shortlist": "shortlist/shortlist.json",
            "comparison": "comparison/comparison.json",
            "landscape_report_html": "landscape-report.html",
        },
    }


def build_multi_phase_result_index(
    run_id: str,
    ledger: dict[str, Any],
    resolved: list[dict[str, Any]],
    phase_work_items: list[tuple[str, str]],
    phase_results: list[dict[str, Any]],
) -> dict[str, Any]:
    entries = []
    status_by_key: dict[tuple[str, str], str] = {}
    for phase in phase_results:
        wid = phase["work_item_id"]
        for worker in phase.get("workers", []):
            key = (wid, worker["logical_model_id"])
            status_by_key[key] = worker.get("status", "pending")

    for phase_id, work_item_id in phase_work_items:
        for item in sorted(resolved, key=lambda x: x["logical_model_id"]):
            lid = item["logical_model_id"]
            entries.append(
                {
                    "work_item_id": work_item_id,
                    "phase_id": phase_id,
                    "logical_model_id": lid,
                    "status": status_by_key.get((work_item_id, lid), "pending"),
                    "authoritative_attempt_id": None,
                    "validation_outcome": None,
                    "terminal_reason": None,
                }
            )

    return {
        "schema_id": "multi-ai-result-index-v1",
        "version": "1.0.0",
        "spine": "multi-ai-task-v2",
        "run_id": run_id,
        "ledger_generation": ledger.get("generation", 0),
        "ledger_head_hash": ledger.get("head_hash", sha256_json([])),
        "entries": entries,
    }


def validate_pool_completeness(
    resolved: list[dict[str, Any]],
    phase_results: list[dict[str, Any]],
) -> tuple[bool, list[str]]:
    """Hard-fail when any resolved-pool agent lacks an envelope for any phase."""
    expected = {item["logical_model_id"] for item in resolved}
    errors: list[str] = []
    for phase in phase_results:
        phase_id = phase.get("phase_id", "?")
        with_envelope: set[str] = set()
        for worker in phase.get("workers") or []:
            # Older fixture callers recorded only has_envelope; treat that as
            # completed while live dispatch records an explicit status.
            if worker.get("has_envelope") and worker.get("status", "completed") == "completed":
                with_envelope.add(str(worker.get("logical_model_id")))
        missing = sorted(expected - with_envelope)
        if missing:
            errors.append(f"phase {phase_id}: missing envelopes for {missing}")
    return (not errors, errors)


def run_dr_live(
    *,
    query: str,
    output_root: Path,
    selection: PoolSelection,
    parallel_phases: list[str],
    mode: str = "ultradeep",
    research_type: str = "solution-landscape",
    max_phases: int | None = None,
    timeout_sec: int = 600,
) -> dict[str, Any]:
    if stub_mode():
        return {"ok": False, "error_code": "DR_MULTI_AI_LIVE_NOT_READY", "message": "SB_MULTI_AI_STUB=1"}

    output_root.mkdir(parents=True, exist_ok=True)
    write_scope(output_root, query)
    write_need_profile(output_root)

    run_id = new_run_id()
    started_at = utc_now_iso()
    brief = build_phase_query(output_root, query, research_type)
    resolved = resolve_pool(selection)
    phases_to_run = parallel_phases[: max_phases or len(parallel_phases)]

    all_envelopes: list[dict[str, Any]] = []
    phase_results: list[dict[str, Any]] = []
    phase_work_items: list[tuple[str, str]] = []
    context = ""

    for phase_id in phases_to_run:
        work_item_id = deterministic_work_item_id(run_id, phase_id)
        phase_work_items.append((phase_id, work_item_id))
        workers = dispatch_phase_parallel(
            phase_id=phase_id,
            query=brief,
            run_id=run_id,
            work_item_id=work_item_id,
            resolved_pool=resolved,
            output_dir=output_root,
            context=context,
            concurrency=len(resolved),
            timeout_sec=timeout_sec,
            ocg_pool=selection.ocg_pool if selection.ocg_pool in {"lite", "regular"} else "lite",
        )
        phase_envelopes = [w.envelope for w in workers if w.envelope]
        all_envelopes.extend(phase_envelopes)
        phase_results.append({
            "phase_id": phase_id,
            "work_item_id": work_item_id,
            "workers": [
                {
                    "logical_model_id": w.logical_model_id,
                    "status": w.status,
                    "backend": w.backend,
                    "error": w.error,
                    "effective_model_id": w.effective_model_id,
                    "has_envelope": w.envelope is not None,
                    "authoritative": w.status == "completed",
                }
                for w in workers
            ],
            "envelopes": len(phase_envelopes),
        })
        if phase_envelopes:
            context = json.dumps([e.get("payload", {}) for e in phase_envelopes[-5:]], indent=2)
            context = context[:2000]

    pool_ok, pool_errors = validate_pool_completeness(resolved, phase_results)
    if not pool_ok:
        return {
            "ok": False,
            "error_code": "POOL_INCOMPLETE",
            "message": "resolved pool agents missing envelopes for one or more phases",
            "pool_errors": pool_errors,
            "resolved_pool_size": len(resolved),
            "phases_run": phases_to_run,
            "phase_results": phase_results,
            "output_root": str(output_root),
            "live_dispatch": True,
            "dispatch_mode": "live",
        }

    ledger = empty_ledger(run_id)
    index = build_multi_phase_result_index(run_id, ledger, resolved, phase_work_items, phase_results)

    envelopes_path = output_root / "contributions" / "all-envelopes.json"
    envelopes_path.parent.mkdir(parents=True, exist_ok=True)
    envelopes_path.write_text(json.dumps(all_envelopes, indent=2) + "\n", encoding="utf-8")

    index_path = output_root / "result-index.json"
    index_path.write_text(json.dumps(index, indent=2) + "\n", encoding="utf-8")

    consolidated_dir = output_root / "consolidated"
    consolidated_dir.mkdir(parents=True, exist_ok=True)
    consolidation = consolidate(all_envelopes, index, len(resolved))
    consolidation["content_hash"] = sha256_json({k: v for k, v in consolidation.items() if k != "content_hash"})
    consolidation_path = consolidated_dir / "consolidation.json"
    consolidation_path.write_text(json.dumps(consolidation, indent=2) + "\n", encoding="utf-8")

    manifest = build_run_manifest(
        run_id=run_id,
        query=query,
        mode=mode,
        research_type=research_type,
        report_dir=str(output_root),
        selection=selection,
        parallel_phases=phases_to_run,
        started_at=started_at,
        finished_at=utc_now_iso(),
        dispatch_mode="live",
        budget_stop_reason=None if all_envelopes else "PARTIAL_LIVE_NO_ENVELOPES",
    )
    manifest["multi_ai"]["result_index_sha256"] = sha256_bytes(index_path.read_bytes())
    manifest_path = output_root / "run_manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

    materialize_result: dict[str, Any] | None = None
    landscape_synthesis: dict[str, Any] | None = None
    if research_type in {"solution-landscape", "solution-compare"} and all_envelopes:
        materialize_result = materialize_solution_artifacts(output_root, envelopes=all_envelopes)
        landscape_synthesis = synthesize_landscape(output_root, force=True)

    return {
        "ok": bool(all_envelopes),
        "partial": len(phases_to_run) < len(parallel_phases),
        "phases_run": phases_to_run,
        "run_id": run_id,
        "output_root": str(output_root),
        "envelopes_count": len(all_envelopes),
        "phase_results": phase_results,
        "consolidation_path": str(consolidation_path),
        "manifest_path": str(manifest_path),
        "materialize": materialize_result,
        "landscape_synthesis": landscape_synthesis,
        "host": detect_host(),
        "live_dispatch": True,
        "dispatch_mode": "live",
    }
