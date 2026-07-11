#!/usr/bin/env python3
"""Shared evidence normalization and audit-finding fingerprints for Silver Bullet."""
from __future__ import annotations

import hashlib
import re


def normalize_text(text: str) -> str:
    """Canonical normalization for fingerprints (aligned with silver-scan.py)."""
    text = text.lower().replace("—", "-")
    text = re.sub(r"`([^`]*)`", r"\1", text)
    text = re.sub(r"\s+", " ", text)
    return text.strip(" \t\r\n-:;,.")


def sha256_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def audit_fingerprint(domain: str, scope: str, finding: str) -> str:
    """Stable fingerprint for structured audit findings (silver:add dedup)."""
    payload = (
        f"{normalize_text(domain)}\n"
        f"{normalize_text(scope)}\n"
        f"{normalize_text(finding)}"
    )
    return sha256_text(payload)


def scan_fingerprint(title: str, context: str) -> str:
    """Stable fingerprint for silver-scan deferred-work candidates."""
    payload = f"{normalize_text(title)}\n{normalize_text(context)}"
    return sha256_text(payload)
