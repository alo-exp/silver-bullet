#!/usr/bin/env python3
"""Branch-correct GitHub SKILL.md raw URL resolution for landscape retrieval."""

from __future__ import annotations

import re
from typing import Any, Callable

FULL_NAME_RE = re.compile(r"^([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+)$")
GITHUB_URL_RE = re.compile(
    r"https?://github\.com/(?P<owner>[^/]+)/(?P<repo>[^/]+?)(?:\.git)?(?:/|$)"
)


def parse_github_full_name(value: str) -> tuple[str, str]:
    """Parse owner/repo from a full name or github.com URL."""
    value = value.strip()
    m = GITHUB_URL_RE.match(value)
    if m:
        return m.group("owner"), m.group("repo")
    m = FULL_NAME_RE.match(value)
    if not m:
        raise ValueError(f"Not a GitHub repo reference: {value!r}")
    return m.group(1), m.group(2)


BranchResolver = Callable[[str, str], str] | dict[str, str] | None


def resolve_default_branch(
    full_name: str,
    resolver: BranchResolver = None,
    *,
    fallback: str = "main",
) -> str:
    """Resolve default branch; inject resolver in tests, gh api in live runs."""
    owner, repo = parse_github_full_name(full_name)
    key = f"{owner}/{repo}"
    if isinstance(resolver, dict):
        return resolver.get(key, fallback)
    if resolver is not None:
        return resolver(owner, repo)
    return fallback


def build_skill_md_raw_url(
    owner: str,
    repo: str,
    branch: str,
    path: str = "SKILL.md",
) -> str:
    return f"https://raw.githubusercontent.com/{owner}/{repo}/{branch}/{path}"


def naive_skill_md_raw_url(owner: str, repo: str, path: str = "SKILL.md") -> str:
    """Anti-pattern helper: always assumes main (used to prove correction)."""
    return build_skill_md_raw_url(owner, repo, "main", path)


def skill_md_retrieval_plan(
    full_name: str,
    resolver: BranchResolver = None,
    *,
    path: str = "SKILL.md",
    fallback: str = "main",
) -> dict[str, Any]:
    """Return branch-correct SKILL.md URL and whether naive main fetch should be avoided."""
    owner, repo = parse_github_full_name(full_name)
    branch = resolve_default_branch(full_name, resolver, fallback=fallback)
    corrected = build_skill_md_raw_url(owner, repo, branch, path)
    naive = naive_skill_md_raw_url(owner, repo, path)
    return {
        "full_name": f"{owner}/{repo}",
        "default_branch": branch,
        "skill_md_url": corrected,
        "naive_main_url": naive,
        "use_corrected_url": corrected != naive,
    }


def enrich_github_search_hits(
    hits: list[dict[str, Any]],
    resolver: BranchResolver = None,
    *,
    path: str = "SKILL.md",
) -> list[dict[str, Any]]:
    """Attach branch-correct SKILL.md URLs to gh search repo hits."""
    enriched: list[dict[str, Any]] = []
    for hit in hits:
        full_name = hit.get("fullName") or hit.get("full_name") or ""
        if not full_name:
            enriched.append(dict(hit))
            continue
        plan = skill_md_retrieval_plan(full_name, resolver, path=path)
        row = dict(hit)
        row["default_branch"] = plan["default_branch"]
        row["skill_md_url"] = plan["skill_md_url"]
        row["skill_md_url_corrected"] = plan["use_corrected_url"]
        enriched.append(row)
    return enriched
