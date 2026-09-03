"""Shared APO catalog helpers used by generator modules."""

from __future__ import annotations


def evidence_record(ev_id: str, producer: str, ref: str, cls: str, artifact: str) -> dict:
    """Build a catalog evidence_record object."""
    return {
        "id": ev_id,
        "producer": producer,
        "artifact_or_tool_ref": artifact,
        "sufficiency_class": cls,
        "staleness_key": "catalog-version+entity-contract",
        "satisfies_v_loop_ref": ref,
    }
