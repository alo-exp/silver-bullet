#!/usr/bin/env python3
"""Migrate run_manifest.json from strict-v3 or host-v3 dialect to v4."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import secrets
from pathlib import Path
from typing import Any

from skill_paths import ensure_scripts_on_path

ensure_scripts_on_path("silver-multi-ai-task", marker="json_hash.py")

from json_hash import canonical_json_bytes, sha256_bytes  # noqa: E402

MIGRATOR_VERSION = "1.0.0"
SPINE = "multi-ai-task-v2"


def classify_v3(source: dict[str, Any]) -> str:
    schema_id = source.get("schema_id", "")
    version = source.get("version", "")
    if version != "3.0.0":
        raise ValueError(f"unsupported manifest version: {version!r}")
    if schema_id == "deep-research-run-manifest-strict-v3":
        return "run-manifest-strict-v3.schema.json"
    if schema_id == "deep-research-run-manifest-host-v3":
        return "run-manifest-host-v3.schema.json"
    raise ValueError(f"unknown v3 schema_id: {schema_id!r}")


def deterministic_run_id(dialect: str, source_sha256: str) -> str:
    payload = f"sb-dr-v3-to-v4\0{dialect}\0{source_sha256}".encode("utf-8")
    return f"run-{hashlib.sha256(payload).hexdigest()[:32]}"


def deterministic_work_item_id(run_id: str, phase_id: str, phase_config_hash: str) -> str:
    payload = f"{run_id}\0{phase_id}\0{phase_config_hash}".encode("utf-8")
    return f"work-{hashlib.sha256(payload).hexdigest()[:32]}"


def build_audit_record(
    *,
    source_dialect: str,
    source_sha256: str,
    source_path: str,
    target_sha256: str,
    target_path: str,
    prior_head: str | None,
) -> dict[str, Any]:
    body = {
        "schema_id": "run-manifest-migration-audit-v1",
        "version": "1.0.0",
        "migrator_version": MIGRATOR_VERSION,
        "source": {
            "dialect": source_dialect,
            "schema_version": "3.0.0",
            "sha256": source_sha256,
            "path": source_path,
        },
        "target": {
            "schema_id": "deep-research-run-manifest-v4",
            "version": "4.0.0",
            "sha256": target_sha256,
            "path": target_path,
        },
        "prior_audit_head": prior_head,
    }
    body["record_hash"] = sha256_bytes(canonical_json_bytes({k: v for k, v in body.items() if k != "record_hash"}))
    return body


def migrate_v3_to_v4(
    source: dict[str, Any],
    *,
    research_root: Path,
    source_sha256: str,
) -> dict[str, Any]:
    dialect = classify_v3(source)
    run_id = source.get("run_id") or deterministic_run_id(dialect, source_sha256)

    phases_in = source.get("phases") or []
    phase_config_hash = sha256_bytes(canonical_json_bytes(phases_in))
    phases_out = []
    work_item_refs = []
    for phase in phases_in:
        phase_id = phase.get("phase_id") or phase.get("id")
        if not phase_id:
            continue
        wid = phase.get("work_item_id") or deterministic_work_item_id(run_id, phase_id, phase_config_hash)
        phases_out.append({"phase_id": phase_id, "work_item_id": wid, "parallel": bool(phase.get("parallel", True))})
        work_item_refs.append(
            {
                "work_item_id": wid,
                "manifest_path": f"work-items/{wid}/multi-ai-work-item-manifest-v1.json",
                "manifest_sha256": "0" * 64,
            }
        )

    budget = source.get("budget") or {}
    return {
        "schema_id": "deep-research-run-manifest-v4",
        "version": "4.0.0",
        "spine": SPINE,
        "run_id": run_id,
        "query": source.get("query") or source.get("question") or "",
        "mode": source.get("mode", "deep"),
        "research_type": source.get("research_type", "default"),
        "started_at": source.get("started_at", "2026-01-01T00:00:00Z"),
        "finished_at": source.get("finished_at"),
        "report_dir": str(research_root),
        "workflow_id": "WF-SILVER-DEEP-RESEARCH-MULTI-AI",
        "multi_ai": {
            "budget": {
                "currency_micro_usd_cap": budget.get("currency_micro_usd_cap", 25_000_000),
                "total_tokens_cap": budget.get("total_tokens_cap", 2_000_000),
                "currency_micro_usd_actual": budget.get("currency_micro_usd_actual", 0),
                "total_tokens_actual": budget.get("total_tokens_actual", 0),
                "price_known": budget.get("price_known", True),
                "usage_metered": budget.get("usage_metered", True),
                "budget_stop_reason": budget.get("budget_stop_reason"),
            },
            "phases": phases_out,
            "work_item_refs": work_item_refs,
            "result_index_path": None,
            "result_index_sha256": None,
        },
        "artifact_paths": source.get("artifact_paths")
        or {
            "report": "consolidated/research_report.md",
            "report_html": "report.html",
            "landscape_report_html": "landscape-report.html",
        },
        "migration": {
            "source_dialect": dialect,
            "source_sha256": source_sha256,
        },
    }


def atomic_write(path: Path, content: str) -> None:
    tmp = path.with_suffix(path.suffix + f".tmp-{secrets.token_hex(4)}")
    tmp.write_text(content, encoding="utf-8")
    os.replace(tmp, path)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Migrate run_manifest v3 → v4")
    parser.add_argument("--input", required=True, help="Source run_manifest.json (v3)")
    parser.add_argument("--research-root", required=True, help="Research output root")
    parser.add_argument("--audit-out", help="Append migration audit JSONL path")
    parser.add_argument(
        "--force",
        action="store_true",
        help="Overwrite an existing v4 run_manifest.json at research-root",
    )
    args = parser.parse_args(argv)

    in_path = Path(args.input)
    root = Path(args.research_root)
    source_bytes = in_path.read_bytes()
    source = json.loads(source_bytes.decode("utf-8"))

    # Preserve byte-identical source
    source_sha = sha256_bytes(source_bytes)
    archive_dir = root / "migration" / "sources"
    archive_dir.mkdir(parents=True, exist_ok=True)
    archive_path = archive_dir / f"{source_sha}.json"
    if not archive_path.exists():
        archive_path.write_bytes(source_bytes)

    target = migrate_v3_to_v4(source, research_root=root, source_sha256=source_sha)
    target_path = root / "run_manifest.json"
    if target_path.exists() and not args.force:
        try:
            existing = json.loads(target_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            raise SystemExit(f"refusing to overwrite unreadable {target_path}: {exc}") from exc
        if existing.get("schema_id") == "deep-research-run-manifest-v4":
            raise SystemExit(
                f"refusing to overwrite existing v4 manifest at {target_path}; pass --force to replace"
            )
    target_json = json.dumps(target, indent=2) + "\n"
    target_sha = sha256_bytes(target_json.encode("utf-8"))

    atomic_write(target_path, target_json)

    prior_head = None
    audit_path = Path(args.audit_out) if args.audit_out else root / "migration" / "run-manifest-migration-audit-v1.jsonl"
    if audit_path.exists():
        lines = [ln for ln in audit_path.read_text(encoding="utf-8").splitlines() if ln.strip()]
        if lines:
            prior_head = json.loads(lines[-1]).get("record_hash")

    record = build_audit_record(
        source_dialect=target["migration"]["source_dialect"],
        source_sha256=source_sha,
        source_path=str(archive_path),
        target_sha256=target_sha,
        target_path=str(target_path),
        prior_head=prior_head,
    )
    audit_path.parent.mkdir(parents=True, exist_ok=True)
    with audit_path.open("a", encoding="utf-8") as fh:
        fh.write(json.dumps(record, sort_keys=True) + "\n")

    print(
        json.dumps(
            {
                "ok": True,
                "run_id": target["run_id"],
                "source_sha256": source_sha,
                "target_sha256": target_sha,
                "audit_record_hash": record["record_hash"],
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
