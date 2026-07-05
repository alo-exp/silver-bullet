#!/usr/bin/env python3
"""Named APO invariant checks used by shell test wrappers."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from collections import Counter
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
CATALOG_PATH = REPO_ROOT / "docs" / "apo-catalog.json"
INDEX_PATH = REPO_ROOT / "docs" / "generated" / "atomic-flow-index.json"
GENERATOR = REPO_ROOT / "scripts" / "generate-apo-artifacts.py"
SKILLS_DIR = REPO_ROOT / "skills"
WORKERS_DIR = REPO_ROOT / "templates" / "orchestrator-workers"
PLUGIN_WORKERS_DIR = REPO_ROOT / "plugins" / "silver-bullet" / "templates" / "orchestrator-workers"
# Composer-only worker prompts (not 1:1 with atomic-flow worker_template paths).
COMPOSER_ONLY_WORKER_TEMPLATES = frozenset({"NEW-WORKFLOW.md"})


def load_catalog() -> dict:
    return json.loads(CATALOG_PATH.read_text(encoding="utf-8"))


def known_entities(catalog: dict) -> set[str]:
    ids = set()
    for key in (
        "processes",
        "process_packs",
        "workflows",
        "atomic_flows",
        "flow_steps",
        "artifacts",
        "tool_policies",
        "dynamic_rules",
    ):
        ids.update(item.get("id") for item in catalog.get(key, []))
    return {item for item in ids if item}


def walk_nodes(nodes: list[dict]) -> list[dict]:
    out = []
    for node in nodes or []:
        out.append(node)
        out.extend(walk_nodes(node.get("children") or []))
    return out


def check(name: str, ok: bool, detail: str = "") -> tuple[str, str, str]:
    return ("PASS" if ok else "FAIL", name, detail)


def derived_views(catalog: dict) -> list[tuple[str, str, str]]:
    proc = subprocess.run([sys.executable, str(GENERATOR), "--check"], cwd=REPO_ROOT, text=True, capture_output=True)
    index = json.loads(INDEX_PATH.read_text(encoding="utf-8"))
    return [
        check("generated views are fresh", proc.returncode == 0, proc.stderr.strip()),
        check("derived index declares catalog SOT", index.get("source_of_truth") == "docs/apo-catalog.json", ""),
        check("derived index mirrors catalog version", index.get("catalog_version") == catalog.get("catalog_version"), ""),
    ]


def worker_template_parity(catalog: dict) -> list[tuple[str, str, str]]:
    workers = {Path(flow["execution"]["worker_template"]).name for flow in catalog["atomic_flows"]}
    for flow in catalog["atomic_flows"]:
        for tmpl in flow.get("execution", {}).get("skill_worker_templates", {}).values():
            workers.add(Path(tmpl).name)
    source = {path.name for path in WORKERS_DIR.glob("*.md")}
    plugin = {path.name for path in PLUGIN_WORKERS_DIR.glob("*.md")}
    source_af = source - COMPOSER_ONLY_WORKER_TEMPLATES
    return [
        check("one source worker template per atomic flow", workers == source_af, f"missing={sorted(workers-source_af)} extra={sorted(source_af-workers)}"),
        check("plugin worker mirror matches source", source == plugin, f"missing={sorted(source-plugin)} extra={sorted(plugin-source)}"),
    ]


def triple_alignment(catalog: dict) -> list[tuple[str, str, str]]:
    token_map = catalog["migration_map"]["runtime_queue_tokens"]
    bad = []
    for workflow in catalog["workflows"]:
        for token in workflow.get("enforcement_queue", []):
            if token not in token_map:
                bad.append(f"{workflow['id']}:{token}")
    guard = (REPO_ROOT / "hooks" / "workflow-chain-guard.sh").read_text(encoding="utf-8")
    state = (REPO_ROOT / "hooks" / "lib" / "orchestrator-state.sh").read_text(encoding="utf-8")
    return [
        check("all composer queue tokens map to catalog entities", not bad, ", ".join(bad)),
        check("workflow-chain guard covers catalog composers", all(slug in guard for slug in ("silver-feature", "silver-ui", "silver-devops", "silver-bugfix", "silver-fast", "silver-release")), ""),
        check("orchestrator state references catalog queue tokens", all(token in state for token in ("FLOW-QUALITY-GATE", "silver-review-request", "silver-completion-audit")), ""),
        check("workflow-chain guard resolves canonical catalog markers", "runtime_queue_tokens" in guard and "catalog_entity" in guard, ""),
    ]


def step_vloop_runtime_rollup(catalog: dict) -> list[tuple[str, str, str]]:
    bad_join = [
        flow["id"]
        for flow in catalog["atomic_flows"]
        if "step V-loops" not in flow["execution"]["join_condition"] or "step_v_loop_status" not in flow["execution"]["dispatch_record_shape"]
    ]
    rollup_text = " ".join(item["rollup_semantics"] for item in catalog.get("v_loop_rollups", []))
    return [
        check("atomic joins require step V-loop rollup", not bad_join, ", ".join(bad_join)),
        check("workflow rollup names step-before-flow ordering", "flow-step V-loops pass before parent atomic-flow gates" in rollup_text, ""),
    ]


def parallel_scheduling_safety(catalog: dict) -> list[tuple[str, str, str]]:
    flows = catalog["atomic_flows"]
    rules = catalog.get("dynamic_rules", [])
    bad_scopes = [flow["id"] for flow in flows if not flow["execution"].get("mutation_scopes")]
    return [
        check("catalog has parallelizable and serialized atoms", any(flow["execution"]["parallelizable"] for flow in flows) and any(not flow["execution"]["parallelizable"] for flow in flows), ""),
        check("parallelize dynamic rule is cataloged", any(rule["operation"] == "parallelize" for rule in rules), ""),
        check("all atoms declare mutation scopes", not bad_scopes, ", ".join(bad_scopes)),
    ]


def dynamic_composition_audit(catalog: dict) -> list[tuple[str, str, str]]:
    operations = {rule["operation"] for rule in catalog.get("dynamic_rules", [])}
    bad_logs = [
        log["id"]
        for log in catalog.get("composition_logs", [])
        if any(not op.get("catalog_rule_ref") or not op.get("rationale") for op in log.get("operations", []))
    ]
    return [
        check("dynamic rules cover prune insert substitute parallelize loop", {"prune", "insert", "substitute", "parallelize", "loop"} <= operations, ", ".join(sorted({"prune", "insert", "substitute", "parallelize", "loop"} - operations))),
        check("composition log operations require rule refs", not bad_logs, ", ".join(bad_logs)),
    ]


def nonredundancy(catalog: dict) -> list[tuple[str, str, str]]:
    classes = [flow["capability_class"] for flow in catalog["atomic_flows"]]
    duplicate_classes = [key for key, count in Counter(classes).items() if count > 1]
    workflow_signatures = Counter(
        tuple(
            (
                node["kind"],
                node["ref"],
                bool(node.get("optional")),
                node.get("condition", ""),
                node.get("label", ""),
            )
            for node in walk_nodes(workflow["composition_tree"])
        )
        for workflow in catalog["workflows"]
    )
    duplicate_workflows = [str(sig) for sig, count in workflow_signatures.items() if count > 1]
    return [
        check("atomic-flow capability classes are unique", not duplicate_classes, ", ".join(duplicate_classes)),
        check("workflow compositions are not duplicated", not duplicate_workflows, "; ".join(duplicate_workflows)),
    ]


def canonical_alias_mapping(catalog: dict) -> list[tuple[str, str, str]]:
    entities = known_entities(catalog)
    skill_names = {path.parent.name for path in SKILLS_DIR.glob("*/SKILL.md")}
    maps = catalog["migration_map"]
    bad_skill_coverage = sorted(skill_names - set(maps["skill_to_entity"]))
    bad_refs = []
    for group in ("legacy_flows", "skill_to_entity", "gsd_alias_to_entity", "runtime_queue_tokens"):
        for source, target in maps.get(group, {}).items():
            if target not in entities:
                bad_refs.append(f"{group}:{source}->{target}")
    return [
        check("every skill maps to one catalog entity", not bad_skill_coverage, ", ".join(bad_skill_coverage)),
        check("alias maps resolve to known catalog entities", not bad_refs, ", ".join(bad_refs)),
    ]


def hierarchy_integrity(catalog: dict) -> list[tuple[str, str, str]]:
    levels: dict[str, list[str]] = {}
    for level, key in (
        ("process", "processes"),
        ("process_pack", "process_packs"),
        ("workflow", "workflows"),
        ("atomic_flow", "atomic_flows"),
        ("flow_step", "flow_steps"),
    ):
        for item in catalog.get(key, []):
            levels.setdefault(item["id"], []).append(level)
    duplicate_levels = [f"{item}:{','.join(levels_)}" for item, levels_ in levels.items() if len(levels_) > 1]
    return [
        check("each catalog entity occupies one hierarchy level", not duplicate_levels, ", ".join(duplicate_levels)),
        check("no standalone nesting entity exists", not any(key in catalog for key in ("nesting", "workflow_nesting", "workflow_component", "nesting_entity")), ""),
    ]


def skill_hierarchy_classification(catalog: dict) -> list[tuple[str, str, str]]:
    allowed = {"flow-step-skill", "atomic-flow-implementation", "precomposed-workflow", "process-router", "reviewer-pack", "quality-dimension-step", "deprecated", "distribution-only"}
    bad = [step["id"] for step in catalog["flow_steps"] if step.get("hierarchy_level") != "flow_step" or step.get("classification") not in allowed]
    return [check("all flow steps have valid hierarchy classifications", not bad, ", ".join(bad))]


def composer_purity(catalog: dict) -> list[tuple[str, str, str]]:
    bad = []
    workflow_ids = {workflow["id"] for workflow in catalog["workflows"]}
    flow_ids = {flow["id"] for flow in catalog["atomic_flows"]}
    for workflow in catalog["workflows"]:
        for node in walk_nodes(workflow["composition_tree"]):
            if node["kind"] == "atomic_flow" and node["ref"] not in flow_ids:
                bad.append(f"{workflow['id']}:{node['ref']}")
            if node["kind"] == "workflow" and node["ref"] not in workflow_ids:
                bad.append(f"{workflow['id']}:{node['ref']}")
    return [check("composer trees reference only catalog flows/workflows", not bad, ", ".join(bad))]


def opted_in_tool_enforcement(catalog: dict) -> list[tuple[str, str, str]]:
    bad = [policy["id"] for policy in catalog.get("tool_policies", []) if policy.get("policy_name") != "once-opted-in-then-mandatory-when-relevant" or not policy.get("relevance_rules") or not policy.get("required_evidence")]
    policies = {policy["failure_policy"] for policy in catalog.get("tool_policies", [])}
    return [
        check("tool policies use once-opted-in semantics", not bad, ", ".join(bad)),
        check("tool policies cover warn repair block degrade", {"warn", "repair", "block", "degrade"} <= policies, ", ".join(sorted({"warn", "repair", "block", "degrade"} - policies))),
    ]


def user_intent_coverage(catalog: dict) -> list[tuple[str, str, str]]:
    entities = known_entities(catalog)
    bad = [ledger["id"] for ledger in catalog.get("intent_ledgers", []) if not ledger.get("material_claims") or not set(ledger.get("mapped_entities", [])) <= entities or not ledger.get("final_gate_result")]
    consumers = {consumer for ledger in catalog.get("intent_ledgers", []) for consumer in ledger.get("consumers", [])}
    return [
        check("intent ledgers cover material claims", not bad, ", ".join(bad)),
        check("completion and release consume intent ledger", {"AF-COMPLETION-AUDIT", "AF-RELEASE"} <= consumers, ""),
    ]


def router_coverage(catalog: dict) -> list[tuple[str, str, str]]:
    router = next((workflow for workflow in catalog["workflows"] if workflow["id"] == "WF-SILVER-ROUTER"), None)
    top_routes = {"WF-SILVER-FEATURE", "WF-SILVER-UI", "WF-SILVER-DEVOPS", "WF-SILVER-BUGFIX", "WF-SILVER-DEEP-RESEARCH", "WF-SILVER-RELEASE", "WF-SILVER-FAST"}
    workflows = {workflow["id"] for workflow in catalog["workflows"]}
    return [
        check("router workflow exists", router is not None, ""),
        check("default public routes are catalog workflows", top_routes <= workflows, ", ".join(sorted(top_routes - workflows))),
        check("router starts with AF-ROUTE", bool(router and router["composition_tree"][0]["ref"] == "AF-ROUTE"), ""),
    ]


def site_doc_freshness(catalog: dict) -> list[tuple[str, str, str]]:
    silver = (REPO_ROOT / "silver-bullet.md").read_text(encoding="utf-8")
    template = (REPO_ROOT / "templates" / "silver-bullet.md.base").read_text(encoding="utf-8")
    site = (REPO_ROOT / "site" / "help" / "workflows" / "index.html").read_text(encoding="utf-8")
    public_paths = [
        REPO_ROOT / "README.md",
        REPO_ROOT / "silver-bullet.md",
        REPO_ROOT / "templates" / "silver-bullet.md.base",
        *sorted((REPO_ROOT / "docs").glob("*.md")),
        *sorted((REPO_ROOT / "site").rglob("*.html")),
        REPO_ROOT / "site" / "help" / "search.js",
    ]
    stale_phrases = (
        "18 atomic flows",
        "18-flow catalog",
        "18-flow architecture",
        "18-flow composable",
        "full 18-flow",
        "catalog of 18 named paths",
    )
    stale_mentions = []
    for path in public_paths:
        if not path.exists():
            continue
        text = path.read_text(encoding="utf-8").lower()
        hits = [phrase for phrase in stale_phrases if phrase in text]
        if hits:
            stale_mentions.append(f"{path.relative_to(REPO_ROOT)}:{','.join(hits)}")
    return [
        check("silver-bullet docs mention APO catalog", "APO catalog" in silver and "docs/apo-catalog.json" in silver, ""),
        check("template docs mention APO catalog", "APO catalog" in template and "docs/apo-catalog.json" in template, ""),
        check("workflow help site mentions atomic flows", "atomic flow" in site.lower() and "apo" in site.lower(), ""),
        check("public docs avoid stale 18-flow atomic-flow count", not stale_mentions, "; ".join(stale_mentions)),
    ]


def agent_delegation_contract(catalog: dict) -> list[tuple[str, str, str]]:
    flows = {flow["id"] for flow in catalog.get("atomic_flows", [])}
    workflows = {workflow["id"] for workflow in catalog.get("workflows", [])}
    skill_map = catalog.get("migration_map", {}).get("skill_to_entity", {})
    artifacts = {item["id"] for item in catalog.get("artifacts", [])}
    steps = {step["id"] for step in catalog.get("flow_steps", [])}
    delegate_flow = next((f for f in catalog["atomic_flows"] if f["id"] == "AF-AGENT-DELEGATE"), None)
    worker_skill = (SKILLS_DIR / "silver-agent-worker" / "SKILL.md").exists()
    worker_template = (WORKERS_DIR / "AGENT-DELEGATE.md").exists()
    return [
        check("AF-AGENT-DELEGATE in catalog", "AF-AGENT-DELEGATE" in flows, ""),
        check("WF-AGENT-DELEGATE-ENTRY references delegation AF", "WF-AGENT-DELEGATE-ENTRY" in workflows, ""),
        check("silver-agent-worker maps to AF-AGENT-DELEGATE", skill_map.get("silver-agent-worker") == "AF-AGENT-DELEGATE", ""),
        check("silver-agent-codex maps to AF-AGENT-DELEGATE", skill_map.get("silver-agent-codex") == "AF-AGENT-DELEGATE", ""),
        check("silver-agent-cursor maps to AF-AGENT-DELEGATE", skill_map.get("silver-agent-cursor") == "AF-AGENT-DELEGATE", ""),
        check("silver-agent-claude maps to AF-AGENT-DELEGATE", skill_map.get("silver-agent-claude") == "AF-AGENT-DELEGATE", ""),
        check("ART-AGENT-DELEGATE registered", "ART-AGENT-DELEGATE" in artifacts, ""),
        check("core FS-DELEGATE steps present", {"FS-DELEGATE-BRIEF", "FS-DELEGATE-LAUNCH", "FS-DELEGATE-VERIFY"} <= steps, ""),
        check("delegation AF not parallelizable", bool(delegate_flow and not delegate_flow.get("execution", {}).get("parallelizable", True)), ""),
        check("silver-agent-worker skill exists", worker_skill, ""),
        check("AGENT-DELEGATE worker template exists", worker_template, ""),
    ]


CHECKS = {
    "derived-views": derived_views,
    "worker-template-parity": worker_template_parity,
    "triple-alignment": triple_alignment,
    "step-vloop-runtime-rollup": step_vloop_runtime_rollup,
    "parallel-scheduling-safety": parallel_scheduling_safety,
    "dynamic-composition-audit": dynamic_composition_audit,
    "atomic-flow-nonredundancy": nonredundancy,
    "canonical-alias-mapping": canonical_alias_mapping,
    "apo-hierarchy-integrity": hierarchy_integrity,
    "skill-hierarchy-classification": skill_hierarchy_classification,
    "composer-purity": composer_purity,
    "opted-in-tool-enforcement": opted_in_tool_enforcement,
    "user-intent-coverage": user_intent_coverage,
    "router-coverage": router_coverage,
    "site-doc-freshness": site_doc_freshness,
    "agent-delegation-contract": agent_delegation_contract,
}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("check", choices=sorted(CHECKS))
    args = parser.parse_args()
    catalog = load_catalog()
    results = CHECKS[args.check](catalog)
    failures = 0
    for status, label, detail in results:
        print(f"{status}\t{label}" + (f"\t{detail}" if detail else ""))
        failures += status == "FAIL"
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
