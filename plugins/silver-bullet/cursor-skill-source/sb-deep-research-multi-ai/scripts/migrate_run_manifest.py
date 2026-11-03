#!/usr/bin/env python3
"""Migrate run_manifest.json from strict-v3 or host-v3 dialect to v4."""

from __future__ import annotations

import argparse
import fcntl
import hashlib
import json
import os
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from generated_files import atomic_write_text
from skill_paths import ensure_scripts_on_path

ensure_scripts_on_path("silver-multi-ai-task", marker="json_hash.py")

from json_hash import canonical_json_bytes, sha256_bytes  # noqa: E402

MIGRATOR_VERSION = "1.1.0"
SPINE = "multi-ai-task-v2"
# Budget caps the live runner applies; a v3 manifest without a budget gets these and the
# migration record says so. Metering and pricing are never assumed (R12-25).
DEFAULT_BUDGET_CAPS = {"currency_micro_usd_cap": 5_000_000, "total_tokens_cap": 2_000_000}


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


def _work_item_ref(research_root: Path, wid: str) -> dict[str, Any] | None:
    """A ref only for a work-item manifest that exists, hashed from its bytes."""
    rel = f"work-items/{wid}/multi-ai-work-item-manifest-v1.json"
    path = research_root / rel
    if not path.is_file():
        return None
    return {"work_item_id": wid, "manifest_path": rel, "manifest_sha256": sha256_bytes(path.read_bytes())}


def migrate_v3_to_v4(
    source: dict[str, Any],
    *,
    research_root: Path,
    source_sha256: str,
    source_mtime: str | None = None,
) -> dict[str, Any]:
    """Map a v3 manifest to v4 without inventing provenance.

    Unknown metering/pricing stay false, work-item refs exist only for manifests on disk,
    a missing started_at falls back to the source file's mtime (recorded as such) and the
    caps a v3 budget lacked are listed in migration.defaults_applied.
    """
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
        ref = _work_item_ref(Path(research_root), wid)
        if ref:
            work_item_refs.append(ref)

    started_at = source.get("started_at")
    started_at_source = "source"
    if not started_at:
        if not source_mtime:
            raise ValueError("source manifest has no started_at; pass source_mtime (the file's mtime)")
        started_at, started_at_source = source_mtime, "source-file-mtime"

    budget = source.get("budget") or {}
    defaults_applied = sorted(k for k in DEFAULT_BUDGET_CAPS if k not in budget)
    return {
        "schema_id": "deep-research-run-manifest-v4",
        "version": "4.0.0",
        "spine": SPINE,
        "run_id": run_id,
        "query": source.get("query") or source.get("question") or "",
        "mode": source.get("mode", "deep"),
        "research_type": source.get("research_type", "default"),
        "started_at": started_at,
        "finished_at": source.get("finished_at"),
        "report_dir": str(research_root),
        "workflow_id": "WF-SILVER-DEEP-RESEARCH-MULTI-AI",
        "multi_ai": {
            "budget": {
                "currency_micro_usd_cap": budget.get("currency_micro_usd_cap", DEFAULT_BUDGET_CAPS["currency_micro_usd_cap"]),
                "total_tokens_cap": budget.get("total_tokens_cap", DEFAULT_BUDGET_CAPS["total_tokens_cap"]),
                "currency_micro_usd_actual": budget.get("currency_micro_usd_actual", 0),
                "total_tokens_actual": budget.get("total_tokens_actual", 0),
                "price_known": bool(budget.get("price_known", False)),
                "usage_metered": bool(budget.get("usage_metered", False)),
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
            "started_at_source": started_at_source,
            "defaults_applied": defaults_applied,
        },
    }


def atomic_write(path: Path, content: str) -> None:
    atomic_write_text(path, content)


def append_audit_record(audit_path: Path, make_record) -> dict[str, Any]:
    """Append one hash-chained record under an exclusive lock (read head + append are atomic)."""
    audit_path.parent.mkdir(parents=True, exist_ok=True)
    with audit_path.open("a+", encoding="utf-8") as fh:
        fcntl.flock(fh, fcntl.LOCK_EX)
        try:
            fh.seek(0)
            lines = [ln for ln in fh.read().splitlines() if ln.strip()]
            prior_head = json.loads(lines[-1]).get("record_hash") if lines else None
            record = make_record(prior_head)
            fh.seek(0, os.SEEK_END)
            fh.write(json.dumps(record, sort_keys=True) + "\n")
            fh.flush()
            os.fsync(fh.fileno())
        finally:
            fcntl.flock(fh, fcntl.LOCK_UN)
    return record


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

    mtime = datetime.fromtimestamp(in_path.stat().st_mtime, tz=timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    target = migrate_v3_to_v4(source, research_root=root, source_sha256=source_sha, source_mtime=mtime)
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

    # Audit first (locked, fsynced), then replace the manifest atomically: a failed or
    # concurrent migration leaves a record whose target hash does not match, never a gap.
    audit_path = Path(args.audit_out) if args.audit_out else root / "migration" / "run-manifest-migration-audit-v1.jsonl"
    record = append_audit_record(
        audit_path,
        lambda prior_head: build_audit_record(
            source_dialect=target["migration"]["source_dialect"],
            source_sha256=source_sha,
            source_path=str(archive_path),
            target_sha256=target_sha,
            target_path=str(target_path),
            prior_head=prior_head,
        ),
    )
    atomic_write(target_path, target_json)

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
