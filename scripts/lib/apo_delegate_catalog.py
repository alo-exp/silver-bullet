"""AF-AGENT-DELEGATE catalog defs, flow steps, and merge for APO catalog generation."""

from __future__ import annotations

from apo_catalog_common import evidence_record

DELEGATE_FLOW_STEP_ORDER = [
    "FS-DELEGATE-BRIEF",
    "FS-DELEGATE-GUARD_ON",
    "FS-DELEGATE-LAUNCH",
    "FS-DELEGATE-CODEX-LAUNCH",
    "FS-DELEGATE-CODEX-ROUTE",
    "FS-SILVER_AGENT_CODEX",
    "FS-DELEGATE-CURSOR-LAUNCH",
    "FS-DELEGATE-CURSOR-ROUTE",
    "FS-DELEGATE-CURSOR-SUBAGENT-POLICY",
    "FS-SILVER_AGENT_CURSOR",
    "FS-DELEGATE-CLAUDE-LAUNCH",
    "FS-DELEGATE-CLAUDE-ROUTE",
    "FS-SILVER_AGENT_CLAUDE",
    "FS-DELEGATE-CHECKPOINT",
    "FS-DELEGATE-VERIFY",
    "FS-DELEGATE-RELAUNCH",
    "FS-DELEGATE-MENTOR",
    "FS-DELEGATE-GUARD_OFF",
]

DELEGATE_STEP_DEFS: dict[str, dict[str, str]] = {
    "FS-DELEGATE-BRIEF": {
        "skill": "silver-agent-codex|silver-agent-cursor|silver-agent-claude",
        "purpose": "Host prepares bounded brief, ownership scope, and acceptance criteria.",
        "classification": "flow-step-skill",
    },
    "FS-DELEGATE-GUARD_ON": {
        "skill": "distribution-only",
        "purpose": "Activate session-scoped delegation guard for parent supervision tier.",
        "classification": "atomic-flow-implementation",
    },
    "FS-DELEGATE-LAUNCH": {
        "skill": "silver-agent-worker",
        "purpose": "Native worker launches external CLI with implementer contract.",
        "classification": "atomic-flow-implementation",
    },
    "FS-DELEGATE-CODEX-LAUNCH": {
        "skill": "silver-agent-codex",
        "purpose": "Spawn agent-codex-delegate.sh with CODEX_HOME isolation and hook-trust.",
        "classification": "flow-step-skill",
    },

    "FS-SILVER_AGENT_CODEX": {
        "skill": "silver-agent-codex",
        "purpose": "Catalog-backed silver-agent-codex step inside AF-AGENT-DELEGATE delegate spine.",
        "classification": "flow-step-skill",
    },
    "FS-SILVER_AGENT_CURSOR": {
        "skill": "silver-agent-cursor",
        "purpose": "Catalog-backed silver-agent-cursor step inside AF-AGENT-DELEGATE delegate spine.",
        "classification": "flow-step-skill",
    },
    "FS-SILVER_AGENT_CLAUDE": {
        "skill": "silver-agent-claude",
        "purpose": "Catalog-backed silver-agent-claude step inside AF-AGENT-DELEGATE delegate spine.",
        "classification": "flow-step-skill",
    },
    "FS-DELEGATE-CODEX-ROUTE": {
        "skill": "silver-agent-codex",
        "purpose": "Inject $silver:* route syntax into external agent brief.",
        "classification": "flow-step-skill",
    },
    "FS-DELEGATE-CURSOR-LAUNCH": {
        "skill": "silver-agent-cursor",
        "purpose": "Spawn agent-cursor-delegate.sh with Keychain auth and model policy.",
        "classification": "flow-step-skill",
    },
    "FS-DELEGATE-CURSOR-ROUTE": {
        "skill": "silver-agent-cursor",
        "purpose": "Inject /silver:* route syntax into external agent brief.",
        "classification": "flow-step-skill",
    },
    "FS-DELEGATE-CURSOR-SUBAGENT-POLICY": {
        "skill": "silver-agent-cursor",
        "purpose": "Enforce composer-2.5 only (never Fast) on nested Task spawns.",
        "classification": "flow-step-skill",
    },
    "FS-DELEGATE-CLAUDE-LAUNCH": {
        "skill": "silver-agent-claude",
        "purpose": "Spawn agent-claude-delegate.sh with CLAUDE_CONFIG_DIR isolation and OAuth auth.",
        "classification": "flow-step-skill",
    },
    "FS-DELEGATE-CLAUDE-ROUTE": {
        "skill": "silver-agent-claude",
        "purpose": "Inject /silver:* route syntax into external agent brief.",
        "classification": "flow-step-skill",
    },
    "FS-DELEGATE-CHECKPOINT": {
        "skill": "distribution-only",
        "purpose": "Record checkpoint evidence from delegate supervision.",
        "classification": "atomic-flow-implementation",
    },
    "FS-DELEGATE-VERIFY": {
        "skill": "distribution-only",
        "purpose": "Audit external success claim against brief and evidence.",
        "classification": "atomic-flow-implementation",
    },
    "FS-DELEGATE-RELAUNCH": {
        "skill": "silver-agent-worker",
        "purpose": "Relaunch delegate within repair.max_attempts with NEXT_RETRY_PROMPT.",
        "classification": "atomic-flow-implementation",
    },
    "FS-DELEGATE-MENTOR": {
        "skill": "silver-agent-codex|silver-agent-cursor|silver-agent-claude",
        "purpose": "Host mentor capture and user-facing report preparation.",
        "classification": "flow-step-skill",
    },
    "FS-DELEGATE-GUARD_OFF": {
        "skill": "distribution-only",
        "purpose": "Clear active delegation guard and session markers.",
        "classification": "atomic-flow-implementation",
    },
}

# Skill-dispatched alternate worker templates (runtime resolves via orchestrator-parent.sh).

def build_delegate_flow_steps() -> tuple[list[dict], list[dict]]:
    """Catalog-backed FS-DELEGATE-* steps for AF-AGENT-DELEGATE."""
    flow_steps: list[dict] = []
    evidence_records: list[dict] = []
    for step_id in DELEGATE_FLOW_STEP_ORDER:
        meta = DELEGATE_STEP_DEFS[step_id]
        ev_id = f"EV-{step_id}"
        v_id = f"VL-{step_id}"
        evidence_class = "inspection"
        evidence_records.append(
            evidence_record(ev_id, step_id, v_id, evidence_class, f".planning/agent-<host>/<task-id>/")
        )
        flow_steps.append({
            "id": step_id,
            "skill": meta["skill"],
            "purpose": meta["purpose"],
            "hierarchy_level": "flow_step",
            "classification": meta["classification"],
            "inputs": ["delegation brief", "host selection", "ownership scope"],
            "outputs": ["step evidence", "delegate.log excerpt or checkpoint"],
            "v_loop": {
                "id": v_id,
                "rollup_target": "flow_step",
                "input_contract": f"{step_id} receives bounded delegation context from AF-AGENT-DELEGATE.",
                "work_product": meta["purpose"],
                "verification": {"methods": ["inspection", "analysis"], "artifact_refs": ["ART-AGENT-DELEGATE"]},
                "validation": {"target": "delegation brief intent", "methods": ["trace to brief and ownership scope"]},
                "repair": {"behavior": "rerun delegate sub-loop via native worker", "max_attempts": 2},
                "escalation": {"condition": "step cannot satisfy contract after repair", "blocker_artifact": ".planning/BLOCKERS.md"},
                "evidence_refs": [ev_id],
            },
            "reusable_by_flows": ["AF-AGENT-DELEGATE"],
            "canonical_catalog_entity": "AF-AGENT-DELEGATE",
        })
    evidence_records.append(
        evidence_record(
            "EV-DELEGATE-DEGRADED-FALLBACK",
            "AF-AGENT-DELEGATE",
            "VL-AF-AGENT-DELEGATE",
            "command_evidence",
            ".planning/agent-<host>/<task-id>/degraded-fallback.jsonl",
        )
    )
    return flow_steps, evidence_records





def merge_delegate_catalog(
    flow_steps: list[dict],
    flow_to_steps: dict[str, list[str]],
    step_evidence: list[dict],
    atomic_flows: list[dict],
    artifacts: list[dict],
    flow_evidence: list[dict],
) -> None:
    delegate_steps, delegate_evidence = build_delegate_flow_steps()
    delegate_ids = {step["id"] for step in delegate_steps}
    flow_steps[:] = [step for step in flow_steps if step["id"] not in delegate_ids]
    flow_steps.extend(delegate_steps)
    flow_steps.sort(key=lambda item: item["id"])
    flow_to_steps["AF-AGENT-DELEGATE"] = list(DELEGATE_FLOW_STEP_ORDER)
    # Drop skill-path orphans and replace AF evidence with ART-backed record.
    step_evidence[:] = [rec for rec in step_evidence if rec.get("producer") not in delegate_ids]
    step_evidence.extend(delegate_evidence)
    artifacts.append({
        "id": "ART-AGENT-DELEGATE",
        "path_pattern": ".planning/agent-<host>/<task-id>/*",
        "schema_or_sections": "brief.md,delegate.log,result.md,checkpoints/,retry-prompt.md,STATUS block",
        "producer": "AF-AGENT-DELEGATE",
        "verifier": "AF-AGENT-DELEGATE",
        "stale_conditions": ["brief hash changes", "task_id reuse with different scope"],
    })
    flow_evidence[:] = [rec for rec in flow_evidence if rec.get("id") != "EV-AF-AGENT-DELEGATE"]
    flow_evidence.append(
        evidence_record(
            "EV-AF-AGENT-DELEGATE",
            "AF-AGENT-DELEGATE",
            "VL-AF-AGENT-DELEGATE",
            "artifact_review",
            "ART-AGENT-DELEGATE",
        )
    )
    for flow in atomic_flows:
        if flow.get("id") != "AF-AGENT-DELEGATE":
            continue
        flow["owning_skills"] = ["silver-agent-codex", "silver-agent-cursor", "silver-agent-claude"]
        flow["flow_steps"] = list(DELEGATE_FLOW_STEP_ORDER)
        # These legacy host steps remain catalog entities, but still roll up to
        # the sole canonical external-agent delegation atomic flow.
        for step in flow_steps:
            if step["id"] in {"FS-SILVER_AGENT_OPENCODE", "FS-SILVER_AGENT_PI"}:
                step["reusable_by_flows"] = ["AF-AGENT-DELEGATE"]
        flow["artifacts"] = ["ART-AGENT-DELEGATE"]
        flow["execution"]["parallelizable"] = False
        flow["dedup_gate"] = {
            "equivalence_review": "AF-AGENT-DELEGATE is the sole canonical external-agent delegation AF; per-host AFs are not promoted.",
            "granularity_review": "capability spans brief through guard cleanup; larger than a skill step",
            "usage_review": "referenced by WF-AGENT-DELEGATE-ENTRY and on-demand host skills",
            "v_loop_review": "VL-AF-AGENT-DELEGATE defines full V-loop with repair.max_attempts 2",
            "step_review": "FS-DELEGATE-* / FS-SILVER_AGENT_* steps have local V-loops and EV-{step_id} evidence refs",
        }
        # Keep degraded-fallback evidence referenced by the AF V-loop (not an orphan record).
        v_loop = flow.setdefault("v_loop", {})
        refs = list(v_loop.get("evidence_refs") or [])
        if "EV-AF-AGENT-DELEGATE" not in refs:
            refs.append("EV-AF-AGENT-DELEGATE")
        if "EV-DELEGATE-DEGRADED-FALLBACK" not in refs:
            refs.append("EV-DELEGATE-DEGRADED-FALLBACK")
        v_loop["evidence_refs"] = refs
        flow["dedup_gate_status"] = "passed"
