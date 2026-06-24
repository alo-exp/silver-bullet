#!/usr/bin/env python3
"""Generate APO catalog views from docs/apo-catalog.json."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
CATALOG_PATH = REPO_ROOT / "docs" / "apo-catalog.json"
CONTRACTS_PATH = REPO_ROOT / "docs" / "composable-flows-contracts.md"
MATRIX_PATH = REPO_ROOT / "docs" / "workflow-composition-matrix.md"
INDEX_PATH = REPO_ROOT / "docs" / "generated" / "atomic-flow-index.json"


def load_catalog() -> dict:
    return json.loads(CATALOG_PATH.read_text(encoding="utf-8"))


def composition_refs(nodes: list[dict], depth: int = 0) -> list[str]:
    lines: list[str] = []
    prefix = "  " * depth
    for node in nodes:
        kind = node.get("kind", "")
        ref = node.get("ref", "")
        label = f" ({node['label']})" if node.get("label") else ""
        optional = " optional" if node.get("optional") else ""
        condition = f" when {node['condition']}" if node.get("condition") else ""
        lines.append(f"{prefix}- {kind}: `{ref}`{label}{optional}{condition}")
        children = node.get("children") or []
        if children:
            lines.extend(composition_refs(children, depth + 1))
    return lines


def render_contracts(catalog: dict) -> str:
    flows = {flow["id"]: flow for flow in catalog["atomic_flows"]}
    steps = {step["id"]: step for step in catalog["flow_steps"]}
    lines = [
        "# Composable Flows - Generated Contract Reference",
        "",
        "> Generated from `docs/apo-catalog.json` by `scripts/generate-apo-artifacts.py`.",
        "> Do not hand-edit workflow composition here; the catalog is the sole authority.",
        "",
        "## APO Hierarchy",
        "",
        "Silver Bullet owns the default software-engineering lifecycle across routing, context, planning, execution, review, verification, security, shipping, release, and documentation.",
        "Silver Bullet models delivery as `Process > Workflow > Atomic Flow > Flow Step/Skill`.",
        "Workflow nesting is represented only by `workflow.composition_tree` references in the catalog.",
        "Every atomic flow is one subagent work package with a local V-loop; every flow step has its own V-loop that rolls up into the parent flow gate.",
        "",
        "## Legacy FLOW Compatibility",
        "",
        "Legacy FLOW 1-18 labels are migration aliases only; canonical execution uses AF-* entities and reusable workflow components from the catalog.",
        "",
        "| Legacy FLOW | Canonical Capability | Catalog Entity |",
        "|-------------|----------------------|----------------|",
        "| FLOW 1 | BOOTSTRAP | `AF-BOOTSTRAP` |",
        "| FLOW 2 | ORIENT | `AF-ORIENT` |",
        "| FLOW 3 | CLARIFY | `AF-CLARIFY` |",
        "| FLOW 4 | DECIDE | `AF-DECIDE` |",
        "| FLOW 5 | SPECIFY | `AF-SPECIFY` |",
        "| FLOW 6 | PLAN | `AF-PLAN` |",
        "| FLOW 7 | DESIGN CONTRACT | `AF-DESIGN-CONTRACT` |",
        "| FLOW 8 | EXECUTE | `AF-EXECUTE` |",
        "| FLOW 9 | UI QUALITY | `AF-UI-QUALITY` |",
        "| FLOW 10 | REVIEW TRIAD | `WF-REVIEW-TRIAD` |",
        "| FLOW 11 | SECURE | `AF-SECURE` |",
        "| FLOW 12 | VERIFY | `AF-VERIFY` |",
        "| FLOW 13 | QUALITY GATE | `AF-QUALITY-GATE` |",
        "| FLOW 14 | SHIP READINESS | `WF-SHIP-READINESS` |",
        "| FLOW 15 | DEBUG | `AF-DEBUG` |",
        "| FLOW 16 | DOCUMENT | `AF-DOCUMENT` |",
        "| FLOW 17 | DOCUMENT | `AF-DOCUMENT` |",
        "| FLOW 18 | RELEASE | `AF-RELEASE` |",
        "",
        "Ship readiness composes `silver:branch-finish` before `silver:completion-audit` before `silver:ship`.",
        "Release audit artifacts remain `RELEASE-UAT-AUDIT` for FLOW 12 verification and `RELEASE-MILESTONE-AUDIT` for FLOW 18 release readiness.",
        "",
        "## Atomic Flow Catalog",
        "",
        "| Atomic Flow | Capability Class | Worker Template | Primary Skills |",
        "|-------------|------------------|-----------------|----------------|",
    ]
    for flow in catalog["atomic_flows"]:
        skills = ", ".join(f"`{skill}`" for skill in flow.get("owning_skills", []))
        lines.append(
            f"| `{flow['id']}` | {flow['capability_class']} | "
            f"`{flow['execution']['worker_template']}` | {skills} |"
        )

    lines.extend([
        "",
        "## Workflow Composition",
        "",
    ])
    for workflow in catalog["workflows"]:
        lines.append(f"### `{workflow['id']}`")
        lines.append("")
        lines.append(f"- Slug: `{workflow['slug']}`")
        lines.append(f"- Type: `{workflow['type']}`")
        lines.append(f"- Final intent gate: `{workflow['final_intent_gate']}`")
        lines.append("")
        lines.extend(composition_refs(workflow.get("composition_tree", [])) or ["- (empty)"])
        lines.append("")

    lines.extend([
        "## Runtime Queue Tokens",
        "",
        "| Runtime Token | Catalog Entity |",
        "|---------------|----------------|",
    ])
    for token, entity in sorted(catalog.get("migration_map", {}).get("runtime_queue_tokens", {}).items()):
        lines.append(f"| `{token}` | `{entity}` |")

    lines.extend([
        "",
        "## Flow Step V-Loops",
        "",
        "| Flow Step | Skill | Reusable By | Evidence |",
        "|-----------|-------|-------------|----------|",
    ])
    for step in catalog["flow_steps"]:
        reusable_by = ", ".join(f"`{ref}`" for ref in step.get("reusable_by_flows", []))
        evidence = ", ".join(f"`{ref}`" for ref in step.get("v_loop", {}).get("evidence_refs", []))
        lines.append(f"| `{step['id']}` | `{step['skill']}` | {reusable_by} | {evidence} |")

    lines.extend([
        "",
        "## Legacy Migration Map",
        "",
        "| Legacy Surface | Catalog Entity |",
        "|----------------|----------------|",
    ])
    for group in ("legacy_flows", "skill_to_entity", "gsd_alias_to_entity"):
        for source, target in sorted(catalog.get("migration_map", {}).get(group, {}).items()):
            lines.append(f"| `{source}` | `{target}` |")

    return "\n".join(lines) + "\n"


def render_matrix(catalog: dict) -> str:
    lines = [
        "# Workflow Composition Matrix",
        "",
        "> Generated from `docs/apo-catalog.json`; workflow trees are catalog-owned.",
        "",
        "| Workflow | Type | Reusable | Composition | Dynamic Ops |",
        "|----------|------|----------|-------------|-------------|",
    ]
    for workflow in catalog["workflows"]:
        refs = []

        def flatten(nodes: list[dict]) -> None:
            for node in nodes:
                ref = node.get("ref", "")
                if ref:
                    refs.append(f"{node.get('kind')}:{ref}")
                flatten(node.get("children") or [])

        flatten(workflow.get("composition_tree", []))
        composition = "<br>".join(f"`{ref}`" for ref in refs)
        dynamic_ops = ", ".join(f"`{op}`" for op in workflow.get("allowed_dynamic_operations", []))
        lines.append(
            f"| `{workflow['id']}` | `{workflow['type']}` | "
            f"{str(workflow.get('reusable_as_component', False)).lower()} | {composition} | {dynamic_ops} |"
        )
    return "\n".join(lines) + "\n"


def build_index(catalog: dict) -> dict:
    flow_by_id = {flow["id"]: flow for flow in catalog["atomic_flows"]}
    step_to_flows = {
        step["id"]: step.get("reusable_by_flows", [])
        for step in catalog.get("flow_steps", [])
    }
    token_map = catalog.get("migration_map", {}).get("runtime_queue_tokens", {})
    workflow_queues = {
        workflow["slug"]: workflow.get("enforcement_queue", [])
        for workflow in catalog.get("workflows", [])
        if workflow.get("enforcement_queue")
    }
    return {
        "source_of_truth": "docs/apo-catalog.json",
        "catalog_version": catalog["catalog_version"],
        "atomic_flow_ids": sorted(flow_by_id),
        "worker_templates": {
            flow_id: flow["execution"]["worker_template"]
            for flow_id, flow in sorted(flow_by_id.items())
        },
        "runtime_queue_tokens": token_map,
        "workflow_enforcement_queues": workflow_queues,
        "step_to_flows": step_to_flows,
    }


def write_outputs(catalog: dict) -> None:
    INDEX_PATH.parent.mkdir(parents=True, exist_ok=True)
    CONTRACTS_PATH.write_text(render_contracts(catalog), encoding="utf-8")
    MATRIX_PATH.write_text(render_matrix(catalog), encoding="utf-8")
    INDEX_PATH.write_text(json.dumps(build_index(catalog), indent=2, sort_keys=True) + "\n", encoding="utf-8")


def check_outputs(catalog: dict) -> bool:
    expected = {
        CONTRACTS_PATH: render_contracts(catalog),
        MATRIX_PATH: render_matrix(catalog),
        INDEX_PATH: json.dumps(build_index(catalog), indent=2, sort_keys=True) + "\n",
    }
    stale = [path.relative_to(REPO_ROOT) for path, content in expected.items() if not path.exists() or path.read_text(encoding="utf-8") != content]
    if stale:
        for path in stale:
            print(f"STALE: {path}", file=sys.stderr)
        return False
    return True


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="fail if generated outputs are stale")
    args = parser.parse_args()

    catalog = load_catalog()
    if args.check:
        return 0 if check_outputs(catalog) else 1
    write_outputs(catalog)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
