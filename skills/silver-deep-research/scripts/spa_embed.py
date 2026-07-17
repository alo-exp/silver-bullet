#!/usr/bin/env python3
"""Shared helpers for embedding JSON into SPA HTML <script> tags."""

from __future__ import annotations

import json
from typing import Any


def safe_json_payload(data: dict[str, Any]) -> str:
    """Serialize JSON for inline <script> embedding — escape chars that break scripts."""
    payload = json.dumps(data, ensure_ascii=False)
    payload = payload.replace("<", "\\u003c")
    payload = payload.replace("\u2028", "\\u2028")
    payload = payload.replace("\u2029", "\\u2029")
    return payload
