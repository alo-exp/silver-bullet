"""Multi-AI catalog defs, flow steps, and process packs for APO catalog generation."""

from __future__ import annotations

from apo_catalog_common import evidence_record

MULTI_AI_FLOW_STEP_ORDER = [
    "FS-MULTI-AI-RESOLVE",
    "FS-MULTI-AI-CAPABILITY-PROBE",
    "FS-MULTI-AI-RESERVE",
    "FS-MULTI-AI-DISPATCH",
    "FS-MULTI-AI-RECONCILE",
    "FS-MULTI-AI-INDEX",
    "FS-SILVER_MULTI_AI_TASK",
]

MULTI_AI_STEP_DEFS: dict[str, dict[str, str]] = {
    "FS-MULTI-AI-RESOLVE": {
        "skill": "silver-multi-ai-task",
        "purpose": "Expand pools, normalize aliases, apply subscription routing for GLM-5.2.",
        "classification": "atomic-flow-implementation",
    },
    "FS-MULTI-AI-CAPABILITY-PROBE": {
        "skill": "silver-multi-ai-task",
        "purpose": "Probe Cursor and OCG backends; read/write capability cache with TTL.",
        "classification": "atomic-flow-implementation",
    },
    "FS-MULTI-AI-RESERVE": {
        "skill": "silver-multi-ai-task",
        "purpose": "Reserve run identity, budget, and per-leg token ceilings.",
        "classification": "atomic-flow-implementation",
    },
    "FS-MULTI-AI-DISPATCH": {
        "skill": "silver-multi-ai-task",
        "purpose": "Launch bounded worker lanes via Cursor host adapter or supervised OCG.",
        "classification": "atomic-flow-implementation",
    },
    "FS-MULTI-AI-RECONCILE": {
        "skill": "silver-multi-ai-task",
        "purpose": "Reconcile usage, CAS-select authoritative attempts, append ledger entries.",
        "classification": "atomic-flow-implementation",
    },
    "FS-MULTI-AI-INDEX": {
        "skill": "silver-multi-ai-task",
        "purpose": "Emit stable multi-ai-result-index-v1 for every resolved logical leg.",
        "classification": "atomic-flow-implementation",
    },
    "FS-SILVER_MULTI_AI_TASK": {
        "skill": "silver-multi-ai-task",
        "purpose": "Public /sb:multi-ai-task primitive entry — generic multi-model orchestration.",
        "classification": "flow-step-skill",
    },
}


def build_multi_ai_flow_steps() -> tuple[list[dict], list[dict]]:
    flow_steps: list[dict] = []
    evidence_records: list[dict] = []
    for step_id in MULTI_AI_FLOW_STEP_ORDER:
        meta = MULTI_AI_STEP_DEFS[step_id]
        ev_id = f"EV-{step_id}"
        v_id = f"VL-{step_id}"
        evidence_records.append(
            evidence_record(ev_id, step_id, v_id, "command_evidence", "skills/silver-multi-ai-task/SKILL.md")
        )
        flow_steps.append({
            "id": step_id,
            "skill": meta["skill"],
            "purpose": meta["purpose"],
            "hierarchy_level": "flow_step",
            "classification": meta["classification"],
            "inputs": ["task brief or DR phase contribution request", "pool selection", "budget caps"],
            "outputs": ["work-item manifest", "dispatch ledger", "result index", "step evidence"],
            "v_loop": {
                "id": v_id,
                "rollup_target": "flow_step",
                "input_contract": f"{step_id} receives bounded multi-AI orchestration context from AF-MULTI-AI-TASK.",
                "work_product": meta["purpose"],
                "verification": {
                    "methods": ["inspection", "command_evidence"],
                    "artifact_refs": ["skills/silver-multi-ai-task/SKILL.md"],
                },
                "validation": {
                    "target": "AF-MULTI-AI-TASK contract",
                    "methods": ["schema validate manifests and index"],
                },
                "repair": {"behavior": "rerun failed sub-step with reconciled ledger", "max_attempts": 2},
                "escalation": {
                    "condition": "capability probe or budget gate blocks dispatch",
                    "blocker_artifact": ".planning/BLOCKERS.md",
                },
                "evidence_refs": [ev_id],
            },
            "reusable_by_flows": ["AF-MULTI-AI-TASK"],
            "canonical_catalog_entity": "AF-MULTI-AI-TASK",
        })
    return flow_steps, evidence_records


def merge_multi_ai_catalog(
    flow_steps: list[dict],
    flow_to_steps: dict[str, list[str]],
    step_evidence: list[dict],
    atomic_flows: list[dict],
    artifacts: list[dict],
    flow_evidence: list[dict],
) -> None:
    ma_steps, ma_evidence = build_multi_ai_flow_steps()
    ma_ids = {step["id"] for step in ma_steps}
    flow_steps[:] = [step for step in flow_steps if step["id"] not in ma_ids]
    flow_steps.extend(ma_steps)
    flow_steps.sort(key=lambda item: item["id"])
    flow_to_steps["AF-MULTI-AI-TASK"] = list(MULTI_AI_FLOW_STEP_ORDER)
    # Drop skill-path orphans before merging authoritative multi-AI evidence.
    step_evidence[:] = [rec for rec in step_evidence if rec.get("producer") not in ma_ids]
    step_evidence.extend(ma_evidence)
    artifacts[:] = [rec for rec in artifacts if rec.get("id") != "ART-MULTI_AI_TASK"]
    artifacts.append({
        "id": "ART-MULTI_AI_TASK",
        "path_pattern": ".planning/multi-ai/<run-id>/*",
        "schema_or_sections": "work-item-manifest.json,dispatch-ledger.json,result-index.json,run-snapshot.json",
        "producer": "AF-MULTI-AI-TASK",
        "verifier": "AF-MULTI-AI-TASK",
        "stale_conditions": ["pool selection changes", "registry version changes", "budget cap changes"],
    })
    flow_evidence[:] = [rec for rec in flow_evidence if rec.get("id") != "EV-AF-MULTI-AI-TASK"]
    flow_evidence.append(
        evidence_record(
            "EV-AF-MULTI-AI-TASK",
            "AF-MULTI-AI-TASK",
            "VL-AF-MULTI-AI-TASK",
            "artifact_review",
            "ART-MULTI_AI_TASK",
        )
    )
    for flow in atomic_flows:
        if flow.get("id") != "AF-MULTI-AI-TASK":
            continue
        flow["owning_skills"] = ["silver-multi-ai-task"]
        flow["flow_steps"] = list(MULTI_AI_FLOW_STEP_ORDER)
        flow["artifacts"] = ["ART-MULTI_AI_TASK"]
        flow["execution"]["parallelizable"] = True
        flow["dedup_gate"] = {
            "equivalence_review": "AF-MULTI-AI-TASK is the sole canonical multi-model orchestration AF.",
            "granularity_review": "capability spans resolve through index; larger than a skill step",
            "usage_review": "referenced by WF-SILVER-MULTI-AI-TASK and WF-SILVER-DEEP-RESEARCH-MULTI-AI",
            "v_loop_review": "VL-AF-MULTI-AI-TASK defines full V-loop with repair.max_attempts 2",
            "step_review": "FS-MULTI-AI-* steps have local V-loops and EV-{step_id} evidence refs",
        }
        v_loop = flow.setdefault("v_loop", {})
        refs = list(v_loop.get("evidence_refs") or [])
        if "EV-AF-MULTI-AI-TASK" not in refs:
            refs.append("EV-AF-MULTI-AI-TASK")
        v_loop["evidence_refs"] = refs
        flow["dedup_gate_status"] = "passed"
