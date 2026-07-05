#!/usr/bin/env python3
"""Generate APO catalog data."""

from __future__ import annotations

import json
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
SKILLS_DIR = REPO_ROOT / "skills"
CATALOG_PATH = REPO_ROOT / "docs" / "apo-catalog.json"

EVIDENCE_CLASSES = [
    "inspection",
    "analysis",
    "demonstration",
    "testing",
    "artifact_review",
    "command_evidence",
    "tool_evidence",
]

ATOMIC_SPECS = [
    ("AF-ROUTE", "ROUTE", "route_intent", "templates/orchestrator-workers/ROUTER.md", "Classified user intent and selected workflow route."),
    ("AF-BOOTSTRAP", "BOOTSTRAP", "project_bootstrap", "templates/orchestrator-workers/BOOTSTRAP.md", "Initialized or migrated Silver Bullet project surface."),
    ("AF-ORIENT", "ORIENT", "context_orientation", "templates/orchestrator-workers/ORIENT.md", "Current codebase, planning, git, and runtime context map."),
    ("AF-CLARIFY", "CLARIFY", "scope_clarification", "templates/orchestrator-workers/CLARIFY.md", "Resolved scope, assumptions, boundaries, and next route."),
    ("AF-DECIDE", "DECIDE", "decision_research", "templates/orchestrator-workers/DECIDE.md", "Decision record with rationale, tradeoffs, and risks."),
    ("AF-SPECIFY", "SPECIFY", "requirements_specification", "templates/orchestrator-workers/SPECIFY.md", "Specification, requirements, and ingestion evidence."),
    ("AF-PLAN", "PLAN", "execution_planning", "templates/orchestrator-workers/PLAN.md", "Accepted implementation or operations plan."),
    ("AF-DESIGN-CONTRACT", "DESIGN_CONTRACT", "design_contract", "templates/orchestrator-workers/DESIGN-CONTRACT.md", "UI/design contract or documented non-UI rationale."),
    ("AF-EXECUTE", "EXECUTE", "implementation_execution", "templates/orchestrator-workers/EXECUTE.md", "Scoped implementation changes and local execution notes."),
    ("AF-UI-QUALITY", "UI_QUALITY", "ui_quality_review", "templates/orchestrator-workers/UI-QUALITY.md", "UI review findings, fixes, or accepted residual risk."),
    ("AF-REVIEW-REQUEST", "REVIEW_REQUEST", "review_request", "templates/orchestrator-workers/REVIEW-REQUEST.md", "Review request package with scope and evidence pointers."),
    ("AF-REVIEW", "REVIEW", "artifact_and_code_review", "templates/orchestrator-workers/REVIEW.md", "Review findings across code, artifacts, and domain gates."),
    ("AF-REVIEW-TRIAGE", "REVIEW_TRIAGE", "review_triage_and_fix", "templates/orchestrator-workers/REVIEW-TRIAGE.md", "Triaged findings, applied fixes, and dismissed-risk rationale."),
    ("AF-VERIFY", "VERIFY", "verification_and_testing", "templates/orchestrator-workers/VERIFY.md", "Fresh verification evidence for behavior, tests, and artifacts."),
    ("AF-SECURE", "SECURE", "security_and_llm_safety", "templates/orchestrator-workers/SECURE.md", "Security and AI-safety review evidence."),
    ("AF-QUALITY-GATE", "QUALITY_GATE", "cross_cutting_quality_gate", "templates/orchestrator-workers/QUALITY-GATE.md", "Quality dimension gate results and required repairs."),
    ("AF-SHIP", "SHIP", "ship_readiness", "templates/orchestrator-workers/SHIP.md", "Branch, PR, CI, deploy, or ship-readiness outcome."),
    ("AF-BRANCH-FINISH", "BRANCH_FINISH", "branch_hygiene", "templates/orchestrator-workers/BRANCH-FINISH.md", "Branch hygiene, commit readiness, and traceability evidence."),
    ("AF-COMPLETION-AUDIT", "COMPLETION_AUDIT", "completion_audit", "templates/orchestrator-workers/COMPLETION-AUDIT.md", "Completion audit proving claimed outcomes are supported."),
    ("AF-DEBUG", "DEBUG", "failure_diagnosis", "templates/orchestrator-workers/DEBUG.md", "Root-cause diagnosis and fix strategy for failing behavior."),
    ("AF-DOCUMENT", "DOCUMENT", "durable_documentation", "templates/orchestrator-workers/DOCUMENT.md", "Durable documentation, handoff, or knowledge-capture artifact."),
    ("AF-RELEASE", "RELEASE", "release_management", "templates/orchestrator-workers/RELEASE.md", "Release notes, versioning decision, tag, and release artifact."),
    ("AF-BLAST-RADIUS", "BLAST_RADIUS", "blast_radius_assessment", "templates/orchestrator-workers/BLAST-RADIUS.md", "Change blast-radius analysis and rollback/risk controls."),
    ("AF-DEVOPS-ROUTE", "DEVOPS_ROUTE", "devops_toolchain_routing", "templates/orchestrator-workers/DEVOPS-SKILL-ROUTER.md", "DevOps provider/toolchain route and required gates."),
    ("AF-VALIDATE", "VALIDATE", "gap_validation", "templates/orchestrator-workers/VALIDATE.md", "Gap analysis with pass/fail status and repair inputs."),
    ("AF-PHASE-MANAGE", "PHASE_MANAGE", "phase_and_state_management", "templates/orchestrator-workers/PHASE.md", "Phase, backlog, thread, or state transition record."),
    ("AF-FAST-PATH", "FAST_PATH", "bounded_fast_path", "templates/orchestrator-workers/FAST.md", "Minimal safe workflow route for narrow low-risk work."),
    ("AF-AGENT-DELEGATE", "AGENT_DELEGATE", "external_agent_delegation", "templates/orchestrator-workers/AGENT-DELEGATE.md", "Audited delegation result with evidence-backed success claim."),
]

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
        "evidence_suffix": "BRIEF",
    },
    "FS-DELEGATE-GUARD_ON": {
        "skill": "distribution-only",
        "purpose": "Activate session-scoped delegation guard for parent supervision tier.",
        "classification": "atomic-flow-implementation",
        "evidence_suffix": "GUARD_ON",
    },
    "FS-DELEGATE-LAUNCH": {
        "skill": "silver-agent-worker",
        "purpose": "Native worker launches external CLI with implementer contract.",
        "classification": "atomic-flow-implementation",
        "evidence_suffix": "LAUNCH",
    },
    "FS-DELEGATE-CODEX-LAUNCH": {
        "skill": "silver-agent-codex",
        "purpose": "Spawn agent-codex-delegate.sh with CODEX_HOME isolation and hook-trust.",
        "classification": "flow-step-skill",
        "evidence_suffix": "LAUNCH",
    },
    "FS-DELEGATE-CODEX-ROUTE": {
        "skill": "silver-agent-codex",
        "purpose": "Inject $silver:* route syntax into external agent brief.",
        "classification": "flow-step-skill",
        "evidence_suffix": "LAUNCH",
    },
    "FS-DELEGATE-CURSOR-LAUNCH": {
        "skill": "silver-agent-cursor",
        "purpose": "Spawn agent-cursor-delegate.sh with Keychain auth and model policy.",
        "classification": "flow-step-skill",
        "evidence_suffix": "LAUNCH",
    },
    "FS-DELEGATE-CURSOR-ROUTE": {
        "skill": "silver-agent-cursor",
        "purpose": "Inject /silver:* route syntax into external agent brief.",
        "classification": "flow-step-skill",
        "evidence_suffix": "LAUNCH",
    },
    "FS-DELEGATE-CURSOR-SUBAGENT-POLICY": {
        "skill": "silver-agent-cursor",
        "purpose": "Enforce composer-2.5 only (never Fast) on nested Task spawns.",
        "classification": "flow-step-skill",
        "evidence_suffix": "LAUNCH",
    },
    "FS-DELEGATE-CLAUDE-LAUNCH": {
        "skill": "silver-agent-claude",
        "purpose": "Spawn agent-claude-delegate.sh with CLAUDE_CONFIG_DIR isolation and OAuth auth.",
        "classification": "flow-step-skill",
        "evidence_suffix": "LAUNCH",
    },
    "FS-DELEGATE-CLAUDE-ROUTE": {
        "skill": "silver-agent-claude",
        "purpose": "Inject /silver:* route syntax into external agent brief.",
        "classification": "flow-step-skill",
        "evidence_suffix": "LAUNCH",
    },
    "FS-DELEGATE-CHECKPOINT": {
        "skill": "distribution-only",
        "purpose": "Record checkpoint evidence from delegate supervision.",
        "classification": "atomic-flow-implementation",
        "evidence_suffix": "CHECKPOINT",
    },
    "FS-DELEGATE-VERIFY": {
        "skill": "distribution-only",
        "purpose": "Audit external success claim against brief and evidence.",
        "classification": "atomic-flow-implementation",
        "evidence_suffix": "VERIFY",
    },
    "FS-DELEGATE-RELAUNCH": {
        "skill": "silver-agent-worker",
        "purpose": "Relaunch delegate within repair.max_attempts with NEXT_RETRY_PROMPT.",
        "classification": "atomic-flow-implementation",
        "evidence_suffix": "RELAUNCH",
    },
    "FS-DELEGATE-MENTOR": {
        "skill": "silver-agent-codex|silver-agent-cursor|silver-agent-claude",
        "purpose": "Host mentor capture and user-facing report preparation.",
        "classification": "flow-step-skill",
        "evidence_suffix": "MENTOR",
    },
    "FS-DELEGATE-GUARD_OFF": {
        "skill": "distribution-only",
        "purpose": "Clear active delegation guard and session markers.",
        "classification": "atomic-flow-implementation",
        "evidence_suffix": "GUARD_OFF",
    },
}

# Skill-dispatched alternate worker templates (runtime resolves via orchestrator-parent.sh).
SKILL_WORKER_TEMPLATES: dict[str, dict[str, str]] = {
    "AF-DOCUMENT": {
        "silver-handoff": "templates/orchestrator-workers/DESIGN-HANDOFF.md",
        "FLOW-DESIGN-HANDOFF": "templates/orchestrator-workers/DESIGN-HANDOFF.md",
    },
    "AF-SECURE": {
        "security": "templates/orchestrator-workers/SECURITY.md",
    },
}

SKILL_TO_FLOW = {
    "silver": "AF-ROUTE",
    "silver-orchestrator": "AF-ROUTE",
    "silver-init": "AF-BOOTSTRAP",
    "silver-bootstrap-project": "AF-BOOTSTRAP",
    "silver-bootstrap-milestone": "AF-BOOTSTRAP",
    "silver-orient": "AF-ORIENT",
    "silver-scan": "AF-ORIENT",
    "silver-context": "AF-ORIENT",
    "silver-review-stats": "AF-ORIENT",
    "silver-clarify": "AF-CLARIFY",
    "silver-deep-research": "AF-DECIDE",
    "silver-doctor": "AF-PHASE-MANAGE",
    "review-research": "AF-DECIDE",
    "silver-spec": "AF-SPECIFY",
    "silver-ingest": "AF-SPECIFY",
    "review-spec": "AF-SPECIFY",
    "review-requirements": "AF-SPECIFY",
    "review-ingestion-manifest": "AF-SPECIFY",
    "silver-plan": "AF-PLAN",
    "review-plan": "AF-PLAN",
    "review-context": "AF-PLAN",
    "silver-ui-contract": "AF-DESIGN-CONTRACT",
    "review-design": "AF-DESIGN-CONTRACT",
    "silver-execute": "AF-EXECUTE",
    "tdd": "AF-EXECUTE",
    "silver-worktree": "AF-EXECUTE",
    "silver-refactor": "AF-EXECUTE",
    "silver-spike": "AF-EXECUTE",
    "silver-ui-review": "AF-UI-QUALITY",
    "usability": "AF-UI-QUALITY",
    "silver-ui": "AF-UI-QUALITY",
    "silver-review-request": "AF-REVIEW-REQUEST",
    "silver-review": "AF-REVIEW",
    "artifact-reviewer": "AF-REVIEW",
    "artifact-review-assessor": "AF-REVIEW",
    "silver-domain-audit": "AF-REVIEW",
    "review-cross-artifact": "AF-REVIEW",
    "review-roadmap": "AF-REVIEW",
    "review-uat": "AF-REVIEW",
    "silver-review-triage": "AF-REVIEW-TRIAGE",
    "silver-review-fix-ladder": "AF-REVIEW-TRIAGE",
    "silver-verify": "AF-VERIFY",
    "verify-tests": "AF-VERIFY",
    "review-verification": "AF-VERIFY",
    "silver-test": "AF-VERIFY",
    "testability": "AF-VERIFY",
    "silver-secure": "AF-SECURE",
    "security": "AF-SECURE",
    "ai-llm-safety": "AF-SECURE",
    "silver-quality-gates": "AF-QUALITY-GATE",
    "devops-quality-gates": "AF-QUALITY-GATE",
    "reliability": "AF-QUALITY-GATE",
    "scalability": "AF-QUALITY-GATE",
    "modularity": "AF-QUALITY-GATE",
    "reusability": "AF-QUALITY-GATE",
    "extensibility": "AF-QUALITY-GATE",
    "silver-ship": "AF-SHIP",
    "silver-deploy": "AF-SHIP",
    "silver-canary": "AF-SHIP",
    "silver-branch-finish": "AF-BRANCH-FINISH",
    "silver-completion-audit": "AF-COMPLETION-AUDIT",
    "silver-debug": "AF-DEBUG",
    "silver-forensics": "AF-DEBUG",
    "silver-bugfix": "AF-DEBUG",
    "silver-ensure-docs": "AF-DOCUMENT",
    "silver-handoff": "AF-DOCUMENT",
    "silver-content": "AF-DOCUMENT",
    "silver-retro": "AF-DOCUMENT",
    "silver-release": "AF-RELEASE",
    "silver-create-release": "AF-RELEASE",
    "silver-blast-radius": "AF-BLAST-RADIUS",
    "devops-skill-router": "AF-DEVOPS-ROUTE",
    "silver-devops": "AF-DEVOPS-ROUTE",
    "silver-validate": "AF-VALIDATE",
    "silver-phase": "AF-PHASE-MANAGE",
    "silver-thread": "AF-PHASE-MANAGE",
    "silver-undo": "AF-PHASE-MANAGE",
    "silver-add": "AF-PHASE-MANAGE",
    "silver-remove": "AF-PHASE-MANAGE",
    "silver-rem": "AF-PHASE-MANAGE",
    "silver-update": "AF-PHASE-MANAGE",
    "silver-migrate": "AF-PHASE-MANAGE",
    "silver-fast": "AF-FAST-PATH",
    "silver-new-workflow": "AF-PLAN",
    "silver-feature": "AF-FAST-PATH",
    "silver-benchmark": "AF-FAST-PATH",
    "silver-incident": "AF-FAST-PATH",
    "silver-agent-codex": "AF-AGENT-DELEGATE",
    "silver-agent-cursor": "AF-AGENT-DELEGATE",
    "silver-agent-claude": "AF-AGENT-DELEGATE",
    "silver-agent-worker": "AF-AGENT-DELEGATE",
}

PRECOMPOSED = {
    "silver-feature", "silver-ui", "silver-devops", "silver-bugfix", "silver-deep-research",
    "silver-release", "silver-fast", "silver-new-workflow", "silver-incident", "silver-deploy", "silver-canary",
    "silver-content", "silver-retro", "silver-benchmark", "silver-refactor",
    "silver-test", "silver-forensics",
}
ROUTERS = {"silver", "silver-orchestrator"}
QUALITY = {
    "reliability", "scalability", "modularity", "reusability", "extensibility",
    "security", "testability", "usability", "ai-llm-safety",
}


def evidence_record(ev_id: str, producer: str, ref: str, cls: str, artifact: str) -> dict:
    return {
        "id": ev_id,
        "producer": producer,
        "artifact_or_tool_ref": artifact,
        "sufficiency_class": cls,
        "staleness_key": "catalog-version+entity-contract",
        "satisfies_v_loop_ref": ref,
    }


def classify_skill(name: str) -> str:
    if name in PRECOMPOSED:
        return "precomposed-workflow"
    if name in ROUTERS:
        return "process-router"
    if name.startswith("review-") or name.startswith("artifact-review"):
        return "reviewer-pack"
    if name in QUALITY:
        return "quality-dimension-step"
    return "flow-step-skill"


def composition_node(ref: str, kind: str = "atomic_flow", **kwargs: object) -> dict:
    node = {"kind": kind, "ref": ref}
    node.update(kwargs)
    return node


def workflow(
    workflow_id: str,
    slug: str,
    workflow_type: str,
    tree: list[dict],
    *,
    owner: str | None = None,
    reusable: bool = False,
    triggers: list[str] | None = None,
    queue: list[str] | None = None,
    ops: list[str] | None = None,
) -> dict:
    doc = {
        "id": workflow_id,
        "slug": slug,
        "type": workflow_type,
        "triggers": triggers or [slug],
        "composition_tree": tree,
        "reusable_as_component": reusable,
        "allowed_dynamic_operations": ops if ops is not None else ["prune", "insert", "substitute", "parallelize", "loop"],
        "final_intent_gate": "INTENT-GATE-DEFAULT",
    }
    if queue:
        doc["enforcement_queue"] = queue
    if owner:
        doc["owning_skill"] = owner
    return doc


def build_flow_steps(skill_names: list[str]) -> tuple[list[dict], dict[str, list[str]], list[dict]]:
    flow_to_steps = {flow_id: [] for flow_id, *_ in ATOMIC_SPECS}
    flow_steps = []
    evidence_records = []
    for idx, name in enumerate(skill_names):
        flow_id = SKILL_TO_FLOW[name]
        step_id = "FS-" + name.upper().replace("-", "_")
        v_id = "VL-" + step_id
        ev_id = "EV-" + step_id
        evidence_class = EVIDENCE_CLASSES[idx % len(EVIDENCE_CLASSES)]
        flow_to_steps[flow_id].append(step_id)
        evidence_records.append(evidence_record(ev_id, step_id, v_id, evidence_class, f"skills/{name}/SKILL.md"))
        step = {
            "id": step_id,
            "skill": name,
            "purpose": f"Execute the {name} skill as a catalog-backed step in {flow_id}.",
            "hierarchy_level": "flow_step",
            "classification": classify_skill(name),
            "inputs": ["parent atomic-flow input", "current user intent", "relevant artifacts and state"],
            "outputs": [f"{name} work product or routing decision", "local step evidence"],
            "v_loop": {
                "id": v_id,
                "rollup_target": "flow_step",
                "input_contract": f"{name} receives the parent flow intent and only the artifacts needed for its local responsibility.",
                "work_product": f"{name} produces its documented skill output and evidence marker.",
                "verification": {"methods": [evidence_class], "artifact_refs": [f"skills/{name}/SKILL.md"]},
                "validation": {"target": "parent atomic-flow input and current user intent", "methods": ["compare step output to parent flow contract"]},
                "repair": {"behavior": "rerun or revise the step until the local V-check passes", "max_attempts": 2},
                "escalation": {"condition": "step cannot satisfy its local contract with available context", "blocker_artifact": ".planning/BLOCKERS.md"},
                "evidence_refs": [ev_id],
            },
            "reusable_by_flows": [flow_id],
            "canonical_catalog_entity": flow_id,
        }
        if name == "silver-deep-research":
            step["purpose"] = "Execute the nested SB deep-research workflow as FS-SILVER_DEEP_RESEARCH inside AF-DECIDE."
            step["outputs"] = [
                "research_report.md",
                "decision-record.md",
                "handoff.md",
                "sources.jsonl",
                "evidence.jsonl",
                "claims.jsonl",
                "vloop-rollup.json",
            ]
            step["v_loop"]["work_product"] = "Phase-level deep research artifacts plus ART-DECIDE rollup under .planning/research/."
            step["v_loop"]["verification"]["artifact_refs"] = [
                "skills/silver-deep-research/SKILL.md",
                ".planning/research/<date>-<slug>/vloop-rollup.json",
                ".planning/research/<date>-<slug>/decision-record.md",
            ]
            step["v_loop"]["validation"]["methods"] = [
                "confirm nested DR-* phase V-loops passed or were mode-skipped",
                "trace decision-record.md to parent AF-DECIDE input",
            ]
        flow_steps.append(step)
    return sorted(flow_steps, key=lambda item: item["id"]), flow_to_steps, evidence_records


def build_delegate_flow_steps() -> tuple[list[dict], list[dict], list[dict]]:
    """Catalog-backed FS-DELEGATE-* steps for AF-AGENT-DELEGATE."""
    flow_steps: list[dict] = []
    evidence_records: list[dict] = []
    for step_id in DELEGATE_FLOW_STEP_ORDER:
        meta = DELEGATE_STEP_DEFS[step_id]
        ev_suffix = meta["evidence_suffix"]
        ev_id = f"EV-FS-DELEGATE-{ev_suffix}"
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
    step_evidence.extend(delegate_evidence)
    artifacts.append({
        "id": "ART-AGENT-DELEGATE",
        "path_pattern": ".planning/agent-<host>/<task-id>/*",
        "schema_or_sections": "brief.md,delegate.log,result.md,checkpoints/,retry-prompt.md,STATUS block",
        "producer": "AF-AGENT-DELEGATE",
        "verifier": "AF-AGENT-DELEGATE",
        "stale_conditions": ["brief hash changes", "task_id reuse with different scope"],
    })
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
        flow["artifacts"] = ["ART-AGENT-DELEGATE"]
        flow["execution"]["parallelizable"] = False
        flow["dedup_gate"] = {
            "equivalence_review": "AF-AGENT-DELEGATE is the sole canonical external-agent delegation AF; per-host AFs are not promoted.",
            "granularity_review": "capability spans brief through guard cleanup; larger than a skill step",
            "usage_review": "referenced by WF-AGENT-DELEGATE-ENTRY and on-demand host skills",
            "v_loop_review": "VL-AF-AGENT-DELEGATE defines full V-loop with repair.max_attempts 2",
            "step_review": "FS-DELEGATE-* steps have local V-loops and shared EV-FS-DELEGATE-* evidence refs",
        }
        flow["dedup_gate_status"] = "passed"


def build_atomic_flows(flow_steps: list[dict], flow_to_steps: dict[str, list[str]]) -> tuple[list[dict], list[dict]]:
    evidence_records = []
    atomic_flows = []
    steps_by_id = {step["id"]: step for step in flow_steps}
    for idx, (flow_id, slug, capability, worker, product) in enumerate(ATOMIC_SPECS):
        v_id = "VL-" + flow_id
        ev_id = "EV-" + flow_id
        evidence_class = EVIDENCE_CLASSES[idx % len(EVIDENCE_CLASSES)]
        evidence_records.append(evidence_record(ev_id, flow_id, v_id, evidence_class, worker))
        step_ids = sorted(flow_to_steps[flow_id])
        owning_skills = [steps_by_id[step_id]["skill"] for step_id in step_ids[:4]]
        atomic_flows.append({
            "id": flow_id,
            "slug": slug,
            "capability_class": capability,
            "legacy_flow_id": "migrated-from-flow-spine",
            "trigger": f"Workflow composition selects {flow_id} when {capability.replace('_', ' ')} is required.",
            "prerequisites": ["upstream V-gates passed or explicit catalog-backed dynamic insertion"],
            "inputs": ["material user intent", "upstream artifacts", "current repository/runtime state"],
            "work_product": product,
            "artifacts": [f"ART-{slug}"],
            "v_loop": {
                "id": v_id,
                "rollup_target": "atomic_flow",
                "input_contract": f"{flow_id} receives a bounded need, required upstream artifacts, and selected flow steps.",
                "work_product": product,
                "verification": {"methods": [evidence_class, "inspection"], "artifact_refs": [f"ART-{slug}"]},
                "validation": {"target": "the user intent claim or workflow precondition that selected this atom", "methods": ["trace output to intent ledger claim", "confirm all owned step V-loops passed"]},
                "repair": {"behavior": "rerun the same atomic-flow subagent with failed V-gate evidence; insert repair atoms only through dynamic rules", "max_attempts": 2},
                "escalation": {"condition": "verification or validation fails after repair attempts or a required tool/evidence source is blocked", "blocker_artifact": ".planning/BLOCKERS.md"},
                "evidence_refs": [ev_id],
            },
            "tools": (
                ["TP-GRAPHIFY", "TP-SEARCH-CLI"]
                if flow_id == "AF-DECIDE"
                else (["TP-GRAPHIFY"] if flow_id in {"AF-ORIENT", "AF-PLAN", "AF-VERIFY"} else [])
            ),
            "owning_skills": owning_skills,
            "flow_steps": step_ids,
            "exit_condition": "all owned flow-step V-loops pass, the flow V-gate passes, and evidence is recorded for workflow rollup",
            "execution": {
                "dispatch_mode": "subagent",
                "worker_template": worker,
                **(
                    {"skill_worker_templates": SKILL_WORKER_TEMPLATES[flow_id]}
                    if flow_id in SKILL_WORKER_TEMPLATES
                    else {}
                ),
                "parallelizable": flow_id not in {"AF-ROUTE", "AF-SHIP", "AF-RELEASE", "AF-BRANCH-FINISH", "AF-COMPLETION-AUDIT", "AF-AGENT-DELEGATE"},
                "dependencies": ["catalog-selected upstream refs"],
                "mutation_scopes": ["declared artifacts", "scoped repository paths"],
                "join_condition": "join only after every owned step V-loops pass and roll up before the parent atomic-flow V-gate passes",
                "retry_policy": {"max_attempts": 2, "on_failure": "repair_loop"},
                "dispatch_record_shape": "subagent_id, atomic_flow_id, inputs, outputs, step_v_loop_status, v_gate_result, retries, join_status",
                "merge_behavior": "merge only declared artifacts and scoped changes after V-gate pass; conflicts require parent scheduler decision",
            },
            "dedup_gate_status": "passed",
            "dedup_gate": {
                "equivalence_review": f"{capability} is represented only by {flow_id}; overlapping legacy FLOW concepts are mapped here or to flow steps.",
                "granularity_review": "capability is larger than a single skill step and smaller than a full workflow",
                "usage_review": "referenced by at least one catalog workflow or reusable component",
                "v_loop_review": f"{v_id} defines input, work product, verification, validation, repair, escalation, and evidence",
                "step_review": "owned flow steps have local V-loops and evidence refs before catalog promotion",
            },
        })
    return atomic_flows, evidence_records


def build_workflows() -> list[dict]:
    n = composition_node
    feature_queue = [
        "FLOW-QUALITY-GATE", "silver-context", "silver-plan", "silver-validate",
        "silver-execute", "silver-review-request", "silver-review", "silver-review-triage",
        "silver-verify", "security", "silver-secure", "silver-validate",
        "FLOW-QUALITY-GATE-PRESHIP", "silver-branch-finish", "silver-completion-audit", "silver-ship",
    ]
    post_exec = workflow("WF-POST-EXEC-GATES", "post-exec-gates", "reusable_component", [
        n("AF-UI-QUALITY", optional=True, condition="ui_scope"),
        n("AF-REVIEW-REQUEST"), n("AF-REVIEW"), n("AF-REVIEW-TRIAGE"),
        n("AF-VERIFY"), n("AF-SECURE"), n("AF-VALIDATE", optional=True),
        n("AF-QUALITY-GATE", label="pre-ship"), n("AF-BRANCH-FINISH"),
        n("AF-COMPLETION-AUDIT"), n("AF-SHIP"),
    ], reusable=True, triggers=["after_execute"], ops=["insert", "parallelize", "loop"])
    core_prefix = [
        n("AF-BOOTSTRAP", optional=True), n("AF-ORIENT", optional=True),
        n("AF-CLARIFY", optional=True), n("AF-DECIDE", optional=True),
        n("AF-SPECIFY", optional=True), n("AF-QUALITY-GATE", label="pre-plan"),
        n("AF-PLAN"),
    ]
    workflows = [
        workflow("WF-SILVER-ROUTER", "silver", "dynamic_route", [n("AF-ROUTE"), n("WF-SILVER-FEATURE", "workflow", optional=True), n("WF-SILVER-FAST", "workflow", optional=True)], owner="silver", triggers=["/silver", "route"], queue=["silver-context"]),
        workflow("WF-SILVER-FEATURE", "silver-feature", "precomposed", core_prefix + [n("AF-DESIGN-CONTRACT", optional=True, condition="ui_scope"), n("AF-EXECUTE"), n("WF-POST-EXEC-GATES", "workflow")], owner="silver-feature", triggers=["feature", "implement", "build feature"], queue=feature_queue),
        post_exec,
        workflow("WF-VALIDATE-SUBSTEP", "validate-substep", "reusable_component", [n("AF-VALIDATE")], reusable=True, triggers=["gap_analysis"], ops=["loop"]),
        workflow("WF-REVIEW-TRIAD", "review-triad", "reusable_component", [n("AF-REVIEW-REQUEST"), n("AF-REVIEW"), n("AF-REVIEW-TRIAGE")], reusable=True, triggers=["legacy FLOW 10"], ops=["loop"]),
        workflow("WF-SHIP-READINESS", "ship-readiness", "reusable_component", [n("AF-BRANCH-FINISH"), n("AF-COMPLETION-AUDIT"), n("AF-SHIP")], reusable=True, triggers=["legacy FLOW 14"], ops=["loop"]),
        workflow("WF-SILVER-UI", "silver-ui", "precomposed", core_prefix + [n("AF-DESIGN-CONTRACT"), n("AF-EXECUTE"), n("WF-POST-EXEC-GATES", "workflow")], owner="silver-ui", triggers=["ui", "frontend"], queue=["FLOW-QUALITY-GATE", "silver-context", "silver-plan", "silver-ui-contract", "silver-validate", "silver-execute", "silver-ui-review"] + feature_queue[5:]),
        workflow("WF-SILVER-DEVOPS", "silver-devops", "precomposed", [n("AF-BLAST-RADIUS"), n("AF-DEVOPS-ROUTE"), n("AF-QUALITY-GATE"), n("AF-SECURE"), n("AF-ORIENT"), n("AF-PLAN"), n("AF-VALIDATE"), n("AF-EXECUTE"), n("WF-POST-EXEC-GATES", "workflow")], owner="silver-devops", triggers=["devops", "infra"], queue=["silver-blast-radius", "devops-skill-router", "devops-quality-gates", "security", "silver-context", "silver-plan", "silver-validate", "silver-execute"] + feature_queue[5:]),
        workflow("WF-SILVER-BUGFIX", "silver-bugfix", "precomposed", [n("AF-ORIENT", optional=True), n("AF-DEBUG"), n("AF-PLAN"), n("AF-EXECUTE"), n("WF-POST-EXEC-GATES", "workflow")], owner="silver-bugfix", triggers=["bug", "fix", "debug"], queue=["silver-debug", "silver-plan", "silver-execute"] + feature_queue[5:]),
        workflow("WF-SILVER-DEEP-RESEARCH", "silver-deep-research", "precomposed", [n("AF-CLARIFY"), n("AF-DECIDE"), n("AF-DOCUMENT"), n("AF-VALIDATE")], owner="silver-deep-research", triggers=["deep research", "research", "decide"], queue=["silver-clarify", "silver-deep-research", "silver-ensure-docs", "silver-validate"]),
        workflow(
            "WF-SILVER-NEW-WORKFLOW",
            "silver-new-workflow",
            "precomposed",
            [
                n("AF-CLARIFY"), n("AF-ORIENT"), n("AF-DECIDE"), n("AF-PLAN"),
                n("AF-REVIEW-TRIAGE"), n("AF-EXECUTE"), n("AF-VERIFY"), n("AF-VALIDATE"), n("AF-DOCUMENT"),
            ],
            owner="silver-new-workflow",
            triggers=["new workflow", "create workflow", "workflow authoring", "convert workflow"],
            queue=[
                "silver-clarify", "silver-scan", "silver-deep-research", "silver-plan",
                "silver-review-fix-ladder", "silver-execute", "silver-verify",
                "silver-validate", "silver-ensure-docs",
            ],
        ),
        workflow("WF-SILVER-FAST", "silver-fast", "precomposed", [n("AF-FAST-PATH"), n("AF-QUALITY-GATE"), n("AF-PLAN"), n("AF-VALIDATE"), n("AF-EXECUTE"), n("AF-VERIFY")], owner="silver-fast", triggers=["fast", "small change"], queue=["FLOW-QUALITY-GATE", "silver-plan", "silver-validate", "silver-execute", "silver-verify"]),
        workflow("WF-SILVER-RELEASE", "silver-release", "precomposed", [n("AF-QUALITY-GATE"), n("AF-REVIEW-REQUEST"), n("AF-REVIEW"), n("AF-REVIEW-TRIAGE"), n("AF-VERIFY"), n("AF-SECURE"), n("AF-VALIDATE"), n("AF-BRANCH-FINISH"), n("AF-COMPLETION-AUDIT"), n("AF-SHIP"), n("AF-RELEASE")], owner="silver-release", triggers=["release"], queue=["FLOW-QUALITY-GATE", "silver-review-request", "silver-review", "silver-review-triage", "silver-verify", "security", "silver-secure", "silver-validate", "silver-branch-finish", "silver-completion-audit", "silver-ship", "silver-create-release"]),
        workflow("WF-SILVER-DEPLOY", "silver-deploy", "specialized", [n("AF-BLAST-RADIUS"), n("AF-VERIFY"), n("AF-SECURE"), n("AF-SHIP")], owner="silver-deploy", triggers=["deploy"], queue=["silver-blast-radius", "devops-quality-gates", "silver-plan", "silver-execute", "silver-verify", "security", "silver-secure", "silver-ship"]),
        workflow("WF-SILVER-CANARY", "silver-canary", "specialized", [n("AF-BLAST-RADIUS"), n("AF-VERIFY"), n("AF-SHIP")], owner="silver-canary", triggers=["canary"], queue=["silver-blast-radius", "silver-plan", "silver-execute", "silver-verify", "silver-ship"]),
        workflow("WF-SILVER-INCIDENT", "silver-incident", "specialized", [n("AF-BLAST-RADIUS"), n("AF-DEBUG"), n("AF-SECURE"), n("AF-VERIFY"), n("AF-DOCUMENT")], owner="silver-incident", triggers=["incident"], queue=["silver-blast-radius", "silver-debug", "silver-plan", "silver-execute", "security", "silver-secure", "silver-verify", "silver-ensure-docs"]),
        workflow("WF-SILVER-CONTENT", "silver-content", "specialized", [n("AF-CLARIFY"), n("AF-SPECIFY"), n("AF-EXECUTE"), n("AF-VERIFY"), n("AF-DOCUMENT")], owner="silver-content", triggers=["content", "docs"], queue=["silver-clarify", "silver-plan", "silver-execute", "silver-verify", "silver-ensure-docs"]),
        workflow("WF-SILVER-RETRO", "silver-retro", "specialized", [n("AF-ORIENT"), n("AF-DOCUMENT"), n("AF-DECIDE")], owner="silver-retro", triggers=["retro"], queue=["silver-context", "silver-execute", "silver-ensure-docs"]),
        workflow("WF-SILVER-BENCHMARK", "silver-benchmark", "specialized", [n("AF-ORIENT"), n("AF-EXECUTE"), n("AF-VERIFY"), n("AF-DOCUMENT")], owner="silver-benchmark", triggers=["benchmark"], queue=["silver-context", "silver-plan", "silver-execute", "silver-verify", "silver-ensure-docs"]),
        workflow("WF-SILVER-REFACTOR", "silver-refactor", "specialized", [n("AF-PLAN"), n("AF-EXECUTE"), n("AF-VERIFY"), n("WF-POST-EXEC-GATES", "workflow")], owner="silver-refactor", triggers=["refactor"], queue=["silver-plan", "silver-validate", "silver-execute"] + feature_queue[5:]),
        workflow("WF-SILVER-TEST", "silver-test", "specialized", [n("AF-PLAN"), n("AF-EXECUTE"), n("AF-VERIFY")], owner="silver-test", triggers=["test", "test hardening"], queue=["silver-plan", "silver-validate", "silver-execute", "silver-verify"]),
        workflow("WF-SILVER-FORENSICS", "silver-forensics", "specialized", [n("AF-DEBUG"), n("AF-DOCUMENT"), n("AF-VALIDATE")], owner="silver-forensics", triggers=["forensics"], queue=["silver-debug", "silver-execute", "silver-ensure-docs", "silver-validate"]),
        workflow("WF-PROCESS-MAINTENANCE", "process-maintenance", "specialized", [n("AF-PHASE-MANAGE"), n("AF-DOCUMENT"), n("AF-VALIDATE")], triggers=["phase", "thread", "backlog", "migration"]),
        workflow("WF-AGENT-DELEGATE-ENTRY", "agent-delegate-entry", "specialized", [n("AF-AGENT-DELEGATE")], owner="silver-agent", triggers=["agent-delegate", "agent-codex", "agent-cursor", "agent-claude"]),
    ]
    return workflows


def build_catalog() -> dict:
    skill_names = sorted(path.parent.name for path in SKILLS_DIR.glob("*/SKILL.md"))
    missing = sorted(set(skill_names) - set(SKILL_TO_FLOW))
    if missing:
        raise SystemExit(f"missing skill mapping: {missing}")
    # silver-agent-worker is mapped for migration_map but uses FS-DELEGATE-* catalog steps.
    flow_skill_names = [name for name in skill_names if name != "silver-agent-worker"]
    flow_steps, flow_to_steps, step_evidence = build_flow_steps(flow_skill_names)
    atomic_flows, flow_evidence = build_atomic_flows(flow_steps, flow_to_steps)
    atomic_ids = [flow_id for flow_id, *_ in ATOMIC_SPECS]
    artifacts = [
        {
            "id": f"ART-{slug}",
            "path_pattern": f".planning/apo/{slug.lower().replace('_', '-')}.*",
            "schema_or_sections": "catalog-defined flow evidence sections",
            "producer": flow_id,
            "verifier": flow_id,
            "stale_conditions": ["catalog_version changes", "producer artifact changes"],
        }
        for flow_id, slug, *_ in ATOMIC_SPECS
    ]
    merge_delegate_catalog(flow_steps, flow_to_steps, step_evidence, atomic_flows, artifacts, flow_evidence)
    artifacts.append({
        "id": "ART-INTENT-LEDGER",
        "path_pattern": ".planning/intent-ledger.json",
        "schema_or_sections": "material_claims,mapped_entities,validation_status,final_gate_result",
        "producer": "AF-ROUTE",
        "verifier": "AF-COMPLETION-AUDIT",
        "stale_conditions": ["user intent changes", "workflow composition changes"],
    })
    workflows = build_workflows()
    v_loop_rollup_children = [f"VL-{flow_id}" for flow_id in atomic_ids] + [step["v_loop"]["id"] for step in flow_steps]
    return {
        "catalog_version": "0.2.0-atomic-flow",
        "meta": {
            "source_of_truth": "docs/apo-catalog.json",
            "generated_views": ["docs/composable-flows-contracts.md", "docs/workflow-composition-matrix.md", "docs/generated/atomic-flow-index.json"],
            "description": "Authoritative APO catalog for canonical atomic flows, workflow composition, step V-loops, evidence, intent, process packs, and runtime alignment.",
        },
        "processes": [{
            "id": "PROC-SB-SE-DEVOPS",
            "name": "Silver Bullet Software Engineering and DevOps",
            "domain": "mixed",
            "default_workflows": ["WF-SILVER-FEATURE", "WF-SILVER-UI", "WF-SILVER-DEVOPS", "WF-SILVER-BUGFIX", "WF-SILVER-DEEP-RESEARCH", "WF-SILVER-RELEASE", "WF-SILVER-FAST"],
            "team_override_policy": "process packs may add, remove, gate, or reorder workflows without forking atomic flow definitions",
            "mandatory_gates": ["INTENT-GATE-DEFAULT", "VR-WORKFLOW-DEFAULT"],
        }],
        "process_packs": [{
            "id": "PP-SB-DEFAULT",
            "name": "Default Silver Bullet SE/DevOps Process Pack",
            "process_ref": "PROC-SB-SE-DEVOPS",
            "workflow_refs": ["WF-SILVER-FEATURE", "WF-SILVER-UI", "WF-SILVER-DEVOPS", "WF-SILVER-BUGFIX", "WF-SILVER-DEEP-RESEARCH", "WF-SILVER-RELEASE", "WF-SILVER-FAST"],
            "override_rules": ["teams may reorder workflows, mandate gates, require tools, and set risk thresholds", "teams must not define local atomic flows outside docs/apo-catalog.json"],
            "conflict_resolution": "catalog safety gates override user shortcuts; explicit user scope can choose a smaller workflow when dynamic rules permit",
            "versioning": "catalog_version governs migration; process pack changes require migration_map update",
        }],
        "workflows": workflows,
        "atomic_flows": atomic_flows,
        "flow_steps": flow_steps,
        "artifacts": artifacts,
        "v_loops": [
            {
                "id": f"VL-{flow_id}",
                "rollup_target": "atomic_flow",
                "input_contract": "registered inline on atomic_flow",
                "work_product": "registered inline on atomic_flow",
                "verification": {"methods": ["inspection"]},
                "validation": {"target": flow_id, "methods": ["catalog contract check"]},
                "repair": {"behavior": "rerun owning flow"},
                "escalation": {"condition": "owning flow blocked"},
                "evidence_refs": [f"EV-{flow_id}"],
            }
            for flow_id in atomic_ids
        ],
        "evidence_records": sorted(step_evidence + flow_evidence, key=lambda item: item["id"]),
        "intent_ledgers": [{
            "id": "IL-DEFAULT-USER-INTENT",
            "material_claims": ["requested outcome", "scope boundaries", "verification and release expectations"],
            "mapped_entities": ["WF-SILVER-FEATURE", "WF-SILVER-DEEP-RESEARCH", "WF-SILVER-RELEASE", "AF-COMPLETION-AUDIT", "AF-RELEASE"],
            "validation_status": "pending",
            "final_gate_result": "pending",
            "producers": ["AF-ROUTE", "AF-CLARIFY"],
            "consumers": ["AF-COMPLETION-AUDIT", "AF-RELEASE"],
        }],
        "v_loop_rollups": [{
            "id": "VR-WORKFLOW-DEFAULT",
            "parent_ref": "PROC-SB-SE-DEVOPS",
            "child_v_loop_refs": v_loop_rollup_children,
            "rollup_semantics": "all selected child flow-step V-loops pass before parent atomic-flow gates; all selected atomic-flow gates pass before workflow final intent gate",
            "intent_ledger_ref": "IL-DEFAULT-USER-INTENT",
            "producers": ["scheduler join gate", "AF-COMPLETION-AUDIT"],
            "consumers": ["AF-SHIP", "AF-RELEASE"],
        }],
        "composition_logs": [{
            "id": "CL-RUNTIME-COMPOSITION-TEMPLATE",
            "selected_workflow": "catalog-selected workflow id",
            "operations": [
                {"op": "dispatch", "target_ref": "AF-ROUTE", "catalog_rule_ref": "DR-PARALLELIZE-INDEPENDENT-ATOMS", "rationale": "dispatch records are required for every selected atomic flow"},
                {"op": "join", "target_ref": "VR-WORKFLOW-DEFAULT", "catalog_rule_ref": "DR-LOOP-FAILED-V-GATE", "rationale": "join only after child V-loops and flow gates pass"},
            ],
            "scheduler_decisions": ["selected smallest safe workflow tree", "serialized conflicting mutation scopes", "recorded host-native concurrency adapter"],
            "subagent_dispatch_records": [],
        }],
        "tool_policies": [
            {"id": "TP-GRAPHIFY", "tool_id": "graphify", "policy_name": "once-opted-in-then-mandatory-when-relevant", "opt_in_state_source": ".cursor/rules/graphify.mdc or project config", "relevance_rules": ["codebase orientation", "architecture tracing", "catalog drift analysis"], "required_evidence": "graphify query/path/update output or catalog-backed irrelevance rationale", "failure_policy": "block"},
            {"id": "TP-AGENTMEMORY", "tool_id": "agentmemory", "policy_name": "once-opted-in-then-mandatory-when-relevant", "opt_in_state_source": ".silver-bullet.json tools.agentmemory", "relevance_rules": ["long-lived project memory lookup", "knowledge capture"], "required_evidence": "memory lookup/write result or irrelevance rationale", "failure_policy": "warn"},
            {"id": "TP-BROWSER", "tool_id": "browser", "policy_name": "once-opted-in-then-mandatory-when-relevant", "opt_in_state_source": ".silver-bullet.json tools.browser", "relevance_rules": ["UI verification", "E2E demonstration"], "required_evidence": "snapshot, screenshot, or E2E command output", "failure_policy": "repair"},
            {"id": "TP-GITHUB", "tool_id": "github", "policy_name": "once-opted-in-then-mandatory-when-relevant", "opt_in_state_source": "repository remote and gh authentication", "relevance_rules": ["PR, CI, release, issue traceability"], "required_evidence": "gh command output or auth blocker", "failure_policy": "degrade"},
            {"id": "TP-SEARCH-CLI", "tool_id": "search_cli", "policy_name": "optional-primary-when-configured", "opt_in_state_source": ".silver-bullet.json recommended_tools.search_cli", "relevance_rules": ["deep research retrieval", "ultradeep state-of-the-art review", "external source triangulation"], "required_evidence": "run_manifest.json provider status or fallback rationale", "failure_policy": "degrade"},
        ],
        "dynamic_rules": [
            {"id": "DR-PRUNE-SATISFIED-ATOM", "workflow_ref": "WF-SILVER-FEATURE", "operation": "prune", "condition": "existing evidence proves selected atom already satisfied and not stale", "rationale_required": True},
            {"id": "DR-INSERT-MISSING-EVIDENCE", "workflow_ref": "WF-SILVER-FEATURE", "operation": "insert", "condition": "V-loop precondition lacks evidence or validation fails", "rationale_required": True},
            {"id": "DR-SUBSTITUTE-LEANER-WORKFLOW", "workflow_ref": "WF-SILVER-ROUTER", "operation": "substitute", "condition": "narrow low-risk intent can be satisfied by smaller reusable workflow", "rationale_required": True},
            {"id": "DR-PARALLELIZE-INDEPENDENT-ATOMS", "workflow_ref": "WF-SILVER-FEATURE", "operation": "parallelize", "condition": "dependency inputs are satisfied and mutation scopes do not conflict", "rationale_required": True},
            {"id": "DR-LOOP-FAILED-V-GATE", "workflow_ref": "WF-POST-EXEC-GATES", "operation": "loop", "condition": "step or flow V-gate fails with repairable evidence", "rationale_required": True},
        ],
        "migration_map": {
            "legacy_flows": {
                "FLOW 1": "AF-BOOTSTRAP", "FLOW 2": "AF-ORIENT", "FLOW 3": "AF-CLARIFY", "FLOW 4": "AF-DECIDE",
                "FLOW 5": "AF-SPECIFY", "FLOW 6": "AF-PLAN", "FLOW 7": "AF-DESIGN-CONTRACT", "FLOW 8": "AF-EXECUTE",
                "FLOW 9": "AF-UI-QUALITY", "FLOW 10": "WF-REVIEW-TRIAD", "FLOW 11": "AF-SECURE", "FLOW 12": "AF-VERIFY",
                "FLOW 13": "AF-QUALITY-GATE", "FLOW 14": "WF-SHIP-READINESS", "FLOW 15": "AF-DEBUG", "FLOW 16": "AF-DOCUMENT",
                "FLOW 17": "AF-DOCUMENT", "FLOW 18": "AF-RELEASE",
            },
            "skill_to_entity": {name: SKILL_TO_FLOW[name] for name in skill_names},
            "gsd_alias_to_entity": {
                "code-review": "AF-REVIEW", "finishing-a-development-branch": "AF-BRANCH-FINISH", "gsd-code-review": "WF-REVIEW-TRIAD",
                "gsd-discuss-phase": "AF-CLARIFY", "gsd-execute-phase": "AF-EXECUTE", "gsd-plan-phase": "AF-PLAN",
                "gsd-secure-phase": "AF-SECURE", "gsd-ship": "AF-SHIP", "gsd-validate-phase": "AF-VALIDATE",
                "gsd-verify-work": "AF-VERIFY", "receiving-code-review": "AF-REVIEW-TRIAGE", "requesting-code-review": "AF-REVIEW-REQUEST",
                "systematic-debugging": "AF-DEBUG", "test-driven-development": "FS-TDD", "verification-before-completion": "AF-COMPLETION-AUDIT",
                "writing-plans": "AF-PLAN",
            },
            "runtime_queue_tokens": {
                "FLOW-QUALITY-GATE": "AF-QUALITY-GATE", "FLOW-QUALITY-GATE-PRESHIP": "AF-QUALITY-GATE",
                "FLOW-DEVOPS-QUALITY-GATE-PRESHIP": "AF-QUALITY-GATE", "FLOW-DESIGN-HANDOFF": "AF-DOCUMENT",
                "FLOW-DOCUMENT": "AF-DOCUMENT",
                "ROUTER": "AF-ROUTE",
                "silver-quality-gates": "AF-QUALITY-GATE",
                "silver-context": "AF-ORIENT", "silver-plan": "AF-PLAN", "silver-validate": "AF-VALIDATE",
                "silver-execute": "AF-EXECUTE", "silver-review-request": "AF-REVIEW-REQUEST", "silver-review": "AF-REVIEW",
                "silver-review-triage": "AF-REVIEW-TRIAGE", "silver-verify": "AF-VERIFY", "security": "AF-SECURE",
                "silver-secure": "AF-SECURE", "silver-branch-finish": "AF-BRANCH-FINISH", "silver-completion-audit": "AF-COMPLETION-AUDIT",
                "silver-ship": "AF-SHIP", "silver-create-release": "AF-RELEASE", "silver-debug": "AF-DEBUG",
                "silver-ui-contract": "AF-DESIGN-CONTRACT", "silver-ui-review": "AF-UI-QUALITY", "silver-blast-radius": "AF-BLAST-RADIUS",
                "devops-quality-gates": "AF-QUALITY-GATE", "devops-skill-router": "AF-DEVOPS-ROUTE", "silver-spec": "AF-SPECIFY",
                "silver-clarify": "AF-CLARIFY", "silver-deep-research": "AF-DECIDE", "silver-ensure-docs": "AF-DOCUMENT",
                "silver-handoff": "AF-DOCUMENT", "silver-scan": "AF-ORIENT",
                "silver-review-fix-ladder": "AF-REVIEW-TRIAGE", "silver-new-workflow": "AF-PLAN",
            },
        },
    }


def main() -> int:
    catalog = build_catalog()
    CATALOG_PATH.write_text(json.dumps(catalog, indent=2) + "\n", encoding="utf-8")
    print(
        f"wrote {CATALOG_PATH.relative_to(REPO_ROOT)}: "
        f"{len(catalog['atomic_flows'])} atomic flows, "
        f"{len(catalog['workflows'])} workflows, "
        f"{len(catalog['flow_steps'])} flow steps"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
