#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
import textwrap
from pathlib import Path
from shutil import which
from typing import Any


STATE_DIR = ".silver-bullet"
STATE_FILE = "scan-state.json"
LOCAL_ISSUES_DIR = Path("docs/issues")
KNOWLEDGE_DIR = Path("docs/knowledge")
LEARNINGS_DIR = Path("docs/learnings")
LEGACY_LESSONS_DIR = Path("docs/lessons")

SECTION_DEFERRED = {
    "needs human review",
    "needs review",
    "human review",
}
SECTION_AUTONOMOUS = {
    "autonomous decisions",
    "autonomous decision",
}
SECTION_KNOWLEDGE = {
    "knowledge & learnings additions",
    "knowledge and learnings additions",
    "knowledge & lessons additions",
    "knowledge and lessons additions",
}
SECTION_ITEMS_FILED = {
    "items filed",
}

DEFERRED_PATTERNS = [
    r"\bTODO\b",
    r"\bFIXME\b",
    r"\bXXX\b",
    r"\bHACK\b",
    r"\btech[- ]debt\b",
    r"\bdeferred\b",
    r"\bout of scope\b",
    r"\bunfinished\b",
    r"\bfollow[- ]?up\b",
    r"\blater\b",
    r"\bskip(ped|ping)?\b",
    r"\bincomplete\b",
    r"\bnot complete\b",
    r"\bwill revisit\b",
    r"\bblocked\b",
    r"\bfailing\b",
    r"\bfailed\b",
    r"\bbroken\b",
    r"\bregression\b",
    r"\bunresolved\b",
    r"\bhuman review\b",
    r"\bquestion\b",
    r"\bopen question\b",
]

BUG_PATTERNS = [
    r"\bbug\b",
    r"\bfailing test\b",
    r"\bfailing integration test\b",
    r"\bci\b",
    r"\btest failure\b",
    r"\bcrash\b",
    r"\berror\b",
    r"\bregression\b",
    r"\bbroken\b",
]

DOC_PATTERNS = [
    r"\bdocs?\b",
    r"\bdocumentation\b",
    r"\breadme\b",
    r"\bcopy\b",
    r"\bwording\b",
    r"\btypo\b",
]

TECH_DEBT_PATTERNS = [
    r"\btech[- ]debt\b",
    r"\brefactor\b",
    r"\bworkaround\b",
    r"\bhack\b",
]

ENHANCEMENT_PATTERNS = [
    r"\benhanc(e|ement)\b",
    r"\bfeature\b",
    r"\bimprov(e|ement)\b",
    r"\bpolish\b",
    r"\badd\b",
    r"\bimplement\b",
    r"\bfollow[- ]?up\b",
    r"\blater\b",
]

CHORE_PATTERNS = [
    r"\bcleanup\b",
    r"\bclean up\b",
    r"\brename\b",
    r"\breorgani[sz]e\b",
    r"\bhousekeeping\b",
    r"\bmaintenance\b",
]


def now_iso() -> str:
    return subprocess.run(
        [
            sys.executable,
            "-c",
            "from datetime import datetime; print(datetime.now().astimezone().isoformat(timespec='seconds'))",
        ],
        check=True,
        text=True,
        capture_output=True,
    ).stdout.strip()


def local_date() -> str:
    return subprocess.run(
        [sys.executable, "-c", "from datetime import datetime; print(datetime.now().strftime('%Y-%m-%d'))"],
        check=True,
        text=True,
        capture_output=True,
    ).stdout.strip()


def local_month() -> str:
    return subprocess.run(
        [sys.executable, "-c", "from datetime import datetime; print(datetime.now().strftime('%Y-%m'))"],
        check=True,
        text=True,
        capture_output=True,
    ).stdout.strip()


def sha256_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def normalize_text(text: str) -> str:
    text = text.lower().replace("—", "-")
    text = re.sub(r"`([^`]*)`", r"\1", text)
    text = re.sub(r"\s+", " ", text)
    return text.strip(" \t\r\n-:;,.")


def rel_path(path: Path, root: Path) -> str:
    try:
        return str(path.resolve().relative_to(root.resolve()))
    except Exception:
        return str(path)


def short_title(text: str, limit: int = 72) -> str:
    title = re.sub(r"^\s*(?:[-*+]\s+|\d+[.)]\s+)", "", text.strip())
    title = re.sub(r"\s+", " ", title)
    if len(title) <= limit:
        return title
    return textwrap.shorten(title, width=limit, placeholder="...")


def short_context(text: str, limit: int = 280) -> str:
    return textwrap.shorten(re.sub(r"\s+", " ", text.strip()), width=limit, placeholder="...")


def atomic_write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(text, encoding="utf-8")
    tmp.replace(path)


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def load_json(path: Path) -> Any:
    return json.loads(read_text(path))


def save_json(path: Path, data: Any) -> None:
    atomic_write(path, json.dumps(data, indent=2, sort_keys=True) + "\n")


def find_project_root(start: Path) -> tuple[Path, bool]:
    current = start.resolve()
    while True:
        if (current / ".silver-bullet.json").is_file():
            return current, True
        if current.parent == current:
            return start.resolve(), False
        current = current.parent


def load_config(root: Path) -> dict[str, Any]:
    config_path = root / ".silver-bullet.json"
    if not config_path.is_file():
        return {}
    try:
        data = load_json(config_path)
        return data if isinstance(data, dict) else {}
    except Exception:
        return {}


def load_state(root: Path) -> dict[str, Any]:
    path = root / STATE_DIR / STATE_FILE
    if not path.is_file():
        return {
            "schema_version": 1,
            "project_root": str(root),
            "sources": {},
            "fingerprints": {},
            "candidates_by_id": {},
        }
    try:
        data = load_json(path)
        if not isinstance(data, dict):
            raise ValueError("invalid state")
    except Exception:
        data = {}
    data.setdefault("schema_version", 1)
    data.setdefault("project_root", str(root))
    data.setdefault("sources", {})
    data.setdefault("fingerprints", {})
    data.setdefault("candidates_by_id", {})
    return data


def save_state(root: Path, state: dict[str, Any]) -> None:
    state_path = root / STATE_DIR / STATE_FILE
    state["project_root"] = str(root)
    state["last_scan_at"] = now_iso()
    state_path.parent.mkdir(parents=True, exist_ok=True)
    save_json(state_path, state)


def parse_jsonl(path: Path) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for raw in read_text(path).splitlines():
        raw = raw.strip()
        if not raw:
            continue
        try:
            row = json.loads(raw)
        except Exception:
            continue
        if isinstance(row, dict):
            rows.append(row)
    return rows


def collect_text(value: Any, out: list[str], key: str | None = None) -> None:
    if isinstance(value, str):
        if key is None or key in {"body", "content", "description", "message", "notes", "prompt", "summary", "text", "title"}:
            text = value.strip()
            if text:
                out.append(text)
        return
    if isinstance(value, list):
        for item in value:
            collect_text(item, out, key)
        return
    if isinstance(value, dict):
        for child_key, child_value in value.items():
            collect_text(child_value, out, child_key)


def transcript_text(path: Path) -> str:
    if path.suffix == ".jsonl":
        chunks: list[str] = []
        for row in parse_jsonl(path):
            collect_text(row, chunks)
        return "\n".join(chunks)
    return read_text(path)


def source_hash(path: Path, text: str) -> str:
    stat = path.stat()
    return sha256_text(f"{stat.st_mtime_ns}:{sha256_text(text)}")


def project_matches_source(row: dict[str, Any], root: Path) -> bool:
    root_real = str(root.resolve())
    root_text = str(root)
    candidates = {
        str(row.get("cwd_real") or "").strip(),
        str(row.get("cwd_display") or "").strip(),
        str(row.get("cwd") or "").strip(),
        str(row.get("git_project_root") or "").strip(),
        str(row.get("work_dir_real") or "").strip(),
        str(row.get("work_dir") or "").strip(),
        str(row.get("project_root") or "").strip(),
    }
    return root_real in candidates or root_text in candidates


def discover_sources(root: Path) -> list[dict[str, Any]]:
    sources: list[dict[str, Any]] = []
    seen: set[str] = set()

    def add(kind: str, path: Path, metadata: dict[str, Any] | None = None) -> None:
        try:
            if not path.is_file():
                return
            resolved = str(path.resolve())
            if resolved in seen:
                return
            text = transcript_text(path)
            stat = path.stat()
        except Exception:
            return
        seen.add(resolved)
        sources.append(
            {
                "kind": kind,
                "path": path,
                "text": text,
                "hash": source_hash(path, text),
                "mtime_ns": stat.st_mtime_ns,
                "metadata": metadata or {},
            }
        )

    for pattern in (
        "docs/sessions/*.md",
        "docs/handoffs/*.md",
        "docs/handoff/*.md",
        "docs/handoff*.md",
        "*handoff*.md",
    ):
        for path in sorted(root.glob(pattern)):
            add("markdown-session", path)

    catalog_path = Path.home() / ".code" / "sessions" / "index" / "catalog.jsonl"

    if catalog_path.is_file():
        for row in parse_jsonl(catalog_path):
            if row.get("deleted") or not project_matches_source(row, root):
                continue
            rollout_path = str(row.get("rollout_path") or "").strip()
            if rollout_path:
                rollout_candidate = Path(rollout_path)
                if not rollout_candidate.is_absolute():
                    rollout_candidate = Path.home() / ".code" / rollout_candidate
                add("codex-transcript", rollout_candidate, row)

    runtime_name = (
        os.environ.get("SILVER_BULLET_RUNTIME")
        or os.environ.get("SB_RUNTIME_NAME")
        or ("codex" if (os.environ.get("CODEX_CI") or os.environ.get("CODEX_THREAD_ID") or os.environ.get("CODEX_INTERNAL_ORIGINATOR_OVERRIDE")) else "claude")
    )
    runtime_home_root = Path(os.environ.get("SB_RUNTIME_HOME_ROOT", str(Path.home() / f".{runtime_name}")))
    runtime_projects_root = runtime_home_root / "projects"
    if runtime_projects_root.is_dir():
        for transcript_path in sorted(runtime_projects_root.rglob("*.jsonl")):
            try:
                rows = parse_jsonl(transcript_path)
            except Exception:
                continue
            if any(project_matches_source(row, root) for row in rows):
                add(f"{runtime_name}-session", transcript_path)

    return sources


def parse_sections(text: str) -> list[dict[str, Any]]:
    sections: list[dict[str, Any]] = []
    current: dict[str, Any] | None = None
    for line_no, line in enumerate(text.splitlines(), 1):
        match = re.match(r"^(#{2,6})\s+(.*\S)\s*$", line)
        if match and len(match.group(1)) == 2:
            if current is not None:
                sections.append(current)
            current = {
                "title": normalize_text(match.group(2)),
                "raw_title": match.group(2).strip(),
                "lines": [],
            }
            continue
        if current is not None:
            current["lines"].append((line_no, line))
    if current is not None:
        sections.append(current)
    return sections


def split_blocks(lines: list[tuple[int, str]]) -> list[tuple[int, str]]:
    blocks: list[tuple[int, str]] = []
    current: list[str] = []
    current_start = 0
    in_code = False

    for line_no, line in lines:
        stripped = line.strip()
        if stripped.startswith("```"):
            in_code = not in_code
            continue
        if in_code:
            continue
        if not stripped:
            if current:
                blocks.append((current_start or line_no, "\n".join(current).strip()))
                current = []
                current_start = 0
            continue
        if re.match(r"^\s*#{2,6}\s+", stripped):
            if current:
                blocks.append((current_start or line_no, "\n".join(current).strip()))
                current = []
                current_start = 0
            continue
        bullet = re.match(r"^\s*(?:[-*+]\s+|\d+[.)]\s+)", line) is not None
        if bullet and current:
            blocks.append((current_start or line_no, "\n".join(current).strip()))
            current = [line]
            current_start = line_no
        else:
            if not current:
                current_start = line_no
            current.append(line)

    if current:
        blocks.append((current_start or 1, "\n".join(current).strip()))
    return blocks


def strip_prefix(text: str) -> str:
    lines = text.splitlines()
    if not lines:
        return ""
    lines[0] = re.sub(r"^\s*(?:[-*+]\s+|\d+[.)]\s+)", "", lines[0]).strip()
    return "\n".join(lines).strip()


def any_match(text: str, patterns: list[str]) -> bool:
    lowered = text.lower()
    return any(re.search(pattern, lowered, re.I) for pattern in patterns)


def classify_deferred(text: str) -> tuple[str, str]:
    lowered = normalize_text(text)
    if any_match(text, BUG_PATTERNS) or (
        re.search(r"\bfix(?:ing)?\b", lowered, re.I)
        and re.search(r"\b(failing|broken|error|test|tests|ci|bug|regression|crash|issue)\b", lowered, re.I)
    ):
        return "bug", "high"
    if any_match(text, DOC_PATTERNS):
        return "docs", "medium"
    if any_match(text, TECH_DEBT_PATTERNS):
        return "tech debt", "medium"
    if any_match(text, ENHANCEMENT_PATTERNS):
        return "enhancement", "medium"
    if any_match(text, CHORE_PATTERNS):
        return "chore", "medium"
    if any_match(text, DEFERRED_PATTERNS):
        return "question", "medium"
    return "chore", "low"


def classify_insight(text: str, root: Path, config: dict[str, Any]) -> tuple[str, str]:
    lowered = normalize_text(text)
    project_tokens = {
        root.name.lower(),
        str((config.get("project") or {}).get("name") or "").lower(),
        "silver-bullet",
    }
    if any(token and token in lowered for token in project_tokens):
        return "knowledge", "high"
    if re.search(r"(/|\.md\b|\.sh\b|\.json\b|docs/|src/)", lowered):
        return "knowledge", "high"
    return "learning", "medium"


def build_candidate(
    root: Path,
    source: dict[str, Any],
    section_title: str,
    block_text: str,
    line_no: int,
    config: dict[str, Any],
) -> dict[str, Any] | None:
    text = strip_prefix(block_text).strip()
    if not text or text.lower() in {"(none)", "none", "*(none)*", "n/a"}:
        return None

    if section_title in SECTION_DEFERRED or section_title in SECTION_AUTONOMOUS:
        kind = "deferred"
        classification, confidence = classify_deferred(text)
        routing_target = "issue" if classification in {"bug", "question"} else "backlog"
    elif section_title in SECTION_KNOWLEDGE:
        kind = "knowledge"
        classification, confidence = classify_insight(text, root, config)
        routing_target = classification
    else:
        return None

    title = short_title(text)
    context = short_context(text)
    source_rel = rel_path(source["path"], root)
    candidate_id = sha256_text(f"{normalize_text(source_rel)}\n{normalize_text(title)}\n{normalize_text(context)}")
    fingerprint = sha256_text(f"{normalize_text(title)}\n{normalize_text(context)}")

    return {
        "candidate_id": candidate_id,
        "fingerprint": fingerprint,
        "kind": kind,
        "classification": classification,
        "category": classification,
        "confidence": confidence,
        "routing_target": routing_target,
        "title": title,
        "context": context,
        "source_kind": source["kind"],
        "source_path": source_rel,
        "source_line": line_no,
        "source_refs": [{"path": source_rel, "line": line_no}],
        "status": "pending",
    }


def candidate_seen(state: dict[str, Any], candidate: dict[str, Any]) -> bool:
    record = state.get("fingerprints", {}).get(candidate["fingerprint"])
    if isinstance(record, dict) and record.get("status") in {"seen", "filed", "recorded", "rejected", "tracked", "weakly-tracked"}:
        return True
    return False


def update_state_for_candidate(state: dict[str, Any], candidate: dict[str, Any], status: str, filed_ref: str | None = None) -> None:
    timestamp = now_iso()
    fingerprint = candidate["fingerprint"]
    state.setdefault("fingerprints", {})[fingerprint] = {
        "candidate_id": candidate["candidate_id"],
        "kind": candidate["kind"],
        "classification": candidate["classification"],
        "category": candidate.get("category", candidate["classification"]),
        "confidence": candidate["confidence"],
        "status": status,
        "updated_at": timestamp,
        "filed_ref": filed_ref,
        "source_refs": candidate.get("source_refs", []),
    }
    state.setdefault("candidates_by_id", {})[candidate["candidate_id"]] = {
        "fingerprint": fingerprint,
        "kind": candidate["kind"],
        "classification": candidate["classification"],
        "category": candidate.get("category", candidate["classification"]),
        "confidence": candidate["confidence"],
        "status": status,
        "updated_at": timestamp,
        "filed_ref": filed_ref,
        "source_refs": candidate.get("source_refs", []),
        "title": candidate["title"],
        "context": candidate["context"],
        "source_kind": candidate["source_kind"],
    }


def local_tracker_text(root: Path) -> str:
    chunks: list[str] = []
    for pattern in [
        "docs/issues/ISSUES.md",
        "docs/issues/BACKLOG.md",
        "docs/knowledge/*.md",
        "docs/learnings/*.md",
        "docs/lessons/*.md",
    ]:
        for path in sorted(root.glob(pattern)):
            if path.is_file():
                try:
                    chunks.append(read_text(path))
                except Exception:
                    continue
    return "\n".join(chunks)


def local_tracker_matches(candidate: dict[str, Any], tracker_text: str) -> bool:
    if not tracker_text:
        return False
    lowered = normalize_text(tracker_text)
    if candidate["candidate_id"] in tracker_text or candidate["fingerprint"] in tracker_text:
        return True
    title = normalize_text(candidate["title"])
    context = normalize_text(candidate["context"])
    return bool((title and title in lowered) or (context and context[:120] in lowered))


def github_available() -> bool:
    return which("gh") is not None


def run_command(args: list[str], cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, cwd=str(cwd) if cwd else None, text=True, capture_output=True)


def repo_slug_from_origin(root: Path) -> str:
    proc = run_command(["git", "remote", "get-url", "origin"], cwd=root)
    if proc.returncode != 0:
        return "unknown/unknown"
    remote = proc.stdout.strip()
    remote = re.sub(r"^https://github.com/", "", remote)
    remote = re.sub(r"^git@github.com:", "", remote)
    remote = re.sub(r"\.git$", "", remote)
    remote = remote.replace(":", "/", 1) if ":" in remote and "/" not in remote else remote
    return remote or "unknown/unknown"


def gh_issue_list(root: Path, query: str) -> list[dict[str, Any]]:
    if not github_available():
        return []
    proc = run_command(
        [
            "gh",
            "issue",
            "list",
            "--state",
            "all",
            "--search",
            query,
            "--json",
            "number,title,body,state,url",
            "--limit",
            "20",
        ],
        cwd=root,
    )
    if proc.returncode != 0:
        return []
    try:
        data = json.loads(proc.stdout or "[]")
    except Exception:
        return []
    return data if isinstance(data, list) else []


def github_issue_exists(root: Path, candidate: dict[str, Any]) -> bool:
    if not github_available():
        return False
    for query in [candidate["candidate_id"], candidate["fingerprint"], candidate["title"]]:
        if not query:
            continue
        for issue in gh_issue_list(root, query):
            combined = f"{issue.get('title') or ''}\n{issue.get('body') or ''}"
            if candidate["candidate_id"] in combined or candidate["fingerprint"] in combined:
                return True
            title = normalize_text(candidate["title"])
            if title and title in normalize_text(combined):
                return True
    return False


def git_or_changelog_match(root: Path, candidate: dict[str, Any]) -> bool:
    words = normalize_text(candidate["title"]).split()
    if not words:
        return False
    phrase = " ".join(words[: min(5, len(words))])
    if not phrase:
        return False
    proc = run_command(["git", "log", "--oneline", "--fixed-strings", f"--grep={phrase}", "--"], cwd=root)
    if proc.returncode == 0 and proc.stdout.strip():
        return True
    changelog = root / "CHANGELOG.md"
    if changelog.is_file() and phrase in read_text(changelog):
        return True
    return False


def parse_candidates(root: Path, source: dict[str, Any], config: dict[str, Any], tracker_text: str) -> tuple[list[dict[str, Any]], int]:
    sections = parse_sections(source["text"])
    raw_candidates: list[dict[str, Any]] = []
    duplicate_count = 0
    recorded_insights: set[str] = set()

    for section in sections:
        title = section["title"]
        blocks = split_blocks(section["lines"])
        if title in SECTION_ITEMS_FILED:
            for _line_no, block_text in blocks:
                text = strip_prefix(block_text).strip()
                normalized = normalize_text(text)
                if (
                    text.lower().startswith("- [knowledge]:")
                    or text.lower().startswith("- [learnings]:")
                    or text.lower().startswith("- [lessons]:")
                ):
                    recorded_insights.add(normalized)
            continue

        if title not in SECTION_DEFERRED and title not in SECTION_AUTONOMOUS and title not in SECTION_KNOWLEDGE:
            continue

        for line_no, block_text in blocks:
            candidate = build_candidate(root, source, title, block_text, line_no, config)
            if candidate is None:
                continue
            if candidate["kind"] == "knowledge" and normalize_text(candidate["context"]) in recorded_insights:
                duplicate_count += 1
                continue
            raw_candidates.append(candidate)

    # Keyword sweep for loose ends and unresolved work.
    in_code = False
    lines = source["text"].splitlines()
    for idx, line in enumerate(lines, 1):
        stripped = line.strip()
        if stripped.startswith("```"):
            in_code = not in_code
            continue
        if in_code or not stripped or stripped.startswith("#"):
            continue
        if not any(re.search(pattern, stripped, re.I) for pattern in DEFERRED_PATTERNS):
            continue
        title = short_title(stripped)
        context = short_context("\n".join(lines[max(0, idx - 2) : min(len(lines), idx + 1)]))
        candidate = {
            "candidate_id": sha256_text(f"{normalize_text(rel_path(source['path'], root))}\n{normalize_text(title)}\n{normalize_text(context)}"),
            "fingerprint": sha256_text(f"{normalize_text(title)}\n{normalize_text(context)}"),
            "kind": "deferred",
            "classification": classify_deferred(stripped)[0],
            "confidence": classify_deferred(stripped)[1],
            "routing_target": "issue" if classify_deferred(stripped)[0] in {"bug", "question"} else "backlog",
            "title": title,
            "context": context,
            "source_kind": source["kind"],
            "source_path": rel_path(source["path"], root),
            "source_line": idx,
            "source_refs": [{"path": rel_path(source["path"], root), "line": idx}],
            "status": "pending",
        }
        raw_candidates.append(candidate)

    deduped: dict[str, dict[str, Any]] = {}
    for candidate in raw_candidates:
        fingerprint = candidate["fingerprint"]
        if fingerprint in deduped:
            duplicate_count += 1
            existing = deduped[fingerprint]
            existing.setdefault("source_refs", [])
            for ref in candidate.get("source_refs", []):
                if ref not in existing["source_refs"]:
                    existing["source_refs"].append(ref)
            existing.setdefault("candidate_ids", [])
            if candidate["candidate_id"] not in existing["candidate_ids"]:
                existing["candidate_ids"].append(candidate["candidate_id"])
            continue
        deduped[fingerprint] = candidate

    final_candidates = list(deduped.values())
    for candidate in final_candidates:
        if local_tracker_matches(candidate, tracker_text):
            candidate["status"] = "tracked"
            candidate["dedupe_reason"] = "local-tracker"
        elif config.get("issue_tracker") == "github" and github_issue_exists(root, candidate):
            candidate["status"] = "tracked"
            candidate["dedupe_reason"] = "github-issues"
        elif git_or_changelog_match(root, candidate):
            candidate["status"] = "weakly-tracked"
            candidate["dedupe_reason"] = "gitlog-or-changelog"

    return final_candidates, duplicate_count


def append_local_entry(target: Path, entry_id: str, candidate: dict[str, Any]) -> None:
    if not target.exists():
        target.parent.mkdir(parents=True, exist_ok=True)
        header = "# Issues" if target.name == "ISSUES.md" else "# Backlog"
        note = (
            "Items tracked by Silver Bullet. IDs are sequential (SB-I-N). Do not renumber."
            if target.name == "ISSUES.md"
            else "Items tracked by Silver Bullet. IDs are sequential (SB-B-N). Do not renumber."
        )
        target.write_text(f"{header}\n\n{note}\n\n---\n\n", encoding="utf-8")

    source_line = ", ".join(f"{ref['path']}:{ref['line']}" for ref in candidate.get("source_refs", []))
    block = [
        f"### {entry_id} — {candidate['title']}",
        "",
        f"**Type:** {candidate['classification']}",
        f"**Filed:** {local_date()}",
        f"**Source:** {source_line or '(unknown)'}",
        f"**Candidate-ID:** {candidate['candidate_id']}",
        f"**Fingerprint:** {candidate['fingerprint']}",
        f"**Status:** open",
        "",
        candidate["context"],
        "",
        "---",
        "",
    ]
    with target.open("a", encoding="utf-8") as handle:
        handle.write("\n".join(block))


def next_local_number(target: Path, prefix: str) -> int:
    if not target.exists():
        return 1
    numbers = [int(match.group(1)) for match in re.finditer(rf"{re.escape(prefix)}-(\d+)", read_text(target))]
    return max(numbers, default=0) + 1


def issue_kind(candidate: dict[str, Any]) -> str:
    return "issue" if candidate["classification"] in {"bug", "question"} else "backlog"


def file_local_candidate(root: Path, candidate: dict[str, Any], state: dict[str, Any]) -> dict[str, Any]:
    target = root / (LOCAL_ISSUES_DIR / ("ISSUES.md" if issue_kind(candidate) == "issue" else "BACKLOG.md"))
    prefix = "SB-I" if issue_kind(candidate) == "issue" else "SB-B"
    entry_id = f"{prefix}-{next_local_number(target, prefix)}"
    append_local_entry(target, entry_id, candidate)
    update_state_for_candidate(state, candidate, "filed", entry_id)
    return {"candidate": {**candidate, "status": "filed", "filed_ref": entry_id}, "filed_ref": entry_id, "target_file": str(target.relative_to(root))}


def issue_labels(category: str) -> list[str]:
    labels = ["filed-by-silver-bullet"]
    labels.append(
        {
            "bug": "bug",
            "question": "question",
            "enhancement": "enhancement",
            "tech debt": "tech-debt",
            "chore": "chore",
            "docs": "documentation",
        }.get(category, "chore")
    )
    return labels


def github_body(candidate: dict[str, Any], root: Path) -> str:
    source_lines = "\n".join(f"- {ref['path']}:{ref['line']}" for ref in candidate.get("source_refs", []))
    return "\n".join(
        [
            "## Description",
            candidate["context"],
            "",
            "## Source",
            source_lines or "- (unknown)",
            "",
            "## Metadata",
            f"- Candidate-ID: {candidate['candidate_id']}",
            f"- Fingerprint: {candidate['fingerprint']}",
            f"- Classification: {candidate['classification']}",
            f"- Kind: {candidate['kind']}",
            f"- Source kind: {candidate['source_kind']}",
            f"- Tracker: {load_config(root).get('issue_tracker', 'github')}",
            f"- Filed: {local_date()}",
            "",
            "## Notes",
            "Captured by silver:scan from untrusted session content.",
        ]
    )


def github_issue_create(root: Path, candidate: dict[str, Any], state: dict[str, Any]) -> dict[str, Any]:
    if not github_available():
        raise RuntimeError("gh CLI is not available")
    proc = run_command(
        [
            "gh",
            "issue",
            "create",
            "--repo",
            repo_slug_from_origin(root),
            "--title",
            candidate["title"],
            "--body",
            github_body(candidate, root),
            *[flag for label in issue_labels(candidate["classification"]) for flag in ("--label", label)],
        ],
        cwd=root,
    )
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or "gh issue create failed")
    output = (proc.stdout or "").strip()
    match = re.search(r"https://github\.com/[^\s]+/issues/\d+", output)
    issue_url = match.group(0) if match else output.splitlines()[-1].strip()
    update_state_for_candidate(state, candidate, "filed", issue_url)
    return {"candidate": {**candidate, "status": "filed", "filed_ref": issue_url}, "filed_ref": issue_url, "target_file": issue_url}


def record_target_month_file(root: Path, candidate: dict[str, Any]) -> tuple[Path, bool]:
    month = local_month()
    if candidate["classification"] == "knowledge":
        return root / KNOWLEDGE_DIR / f"{month}.md", True
    return root / LEARNINGS_DIR / f"{month}.md", False


def ensure_knowledge_index(root: Path, month: str, kind: str) -> None:
    index = root / KNOWLEDGE_DIR / "INDEX.md"
    if not index.exists():
        index.parent.mkdir(parents=True, exist_ok=True)
        index.write_text(
            "\n".join(
                [
                    "# Project Knowledge Index",
                    "",
                    "Quick-reference pointer to current project docs. Updated when docs are added/removed.",
                    "",
                    "| Doc | Path | Purpose |",
                    "|-----|------|---------|",
                    "| Architecture | `docs/ARCHITECTURE.md` | Components, layers, design principles |",
                    "| Testing | `docs/TESTING.md` | Test pyramid, coverage goals |",
                    "| CI/CD | `docs/CICD.md` | Pipeline stages (if CI exists) |",
                    "| Task Log | `docs/CHANGELOG.md` | Rolling task log (50 entries max) |",
                    "| Decisions (ADR) | `docs/ADR/` | Durable architecture/packaging/runtime decisions |",
                    "| Glossary | `docs/GLOSSARY.md` | Canonical terminology (when needed) |",
                    "| Runtime Compatibility | `docs/RUNTIME-COMPATIBILITY.md` | Claude/Codex/Kay parity (**plugin-dev projects only**) |",
                    "| Session Logs | `docs/sessions/` | Per-session work logs (30 max) |",
                    "| Design Specs | `docs/specs/` | Point-in-time design specs |",
                    "| Active Workflow | `docs/workflows/full-dev-cycle.md` | Dev cycle steps |",
                    "| Git Repo | {{GIT_REPO}} | — |",
                    "",
                    "Latest knowledge: `(none)`",
                    "Latest learnings: `(none)`",
                    "",
                ]
            ),
            encoding="utf-8",
        )
    content = read_text(index)
    if kind == "knowledge":
        row = f"| {month} | [`{month}.md`](../knowledge/{month}.md) | Knowledge for this month |"
        if row not in content:
            content = content.replace("| Git Repo | {{GIT_REPO}} | — |\n", "| Git Repo | {{GIT_REPO}} | — |\n" + row + "\n")
        content = re.sub(r"^Latest knowledge: .*?$", f"Latest knowledge: `docs/knowledge/{month}.md`", content, flags=re.M)
    else:
        content = re.sub(r"^Latest learnings: .*?$", f"Latest learnings: `docs/learnings/{month}.md`", content, flags=re.M)
    atomic_write(index, content if content.endswith("\n") else content + "\n")


def learning_category(text: str) -> str:
    lowered = normalize_text(text)
    if any(token in lowered for token in ("bash", "shell", "jq", "git", "grep", "tmpfile", "atomic", "cli")):
        return "stack:bash"
    if any(token in lowered for token in ("test", "workflow", "automation", "release")):
        return "practice:workflow"
    if any(token in lowered for token in ("deploy", "infra", "iam", "cloud", "monitor")):
        return "devops:operations"
    if any(token in lowered for token in ("ui", "ux", "layout", "accessibility", "design")):
        return "design:ux"
    return "practice:workflow"


def write_record_entry(root: Path, candidate: dict[str, Any], target: Path, is_knowledge: bool) -> None:
    month = local_month()
    if not target.exists():
        target.parent.mkdir(parents=True, exist_ok=True)
        if is_knowledge:
            project_name = str((load_config(root).get("project") or {}).get("name") or "unknown")
            target.write_text(
                "\n".join(
                    [
                        "---",
                        f"project: {project_name}",
                        f"period: {month}",
                        "type: knowledge",
                        "---",
                        "",
                        f"# Project Knowledge - {month}",
                        "",
                        "## Architecture Patterns",
                        "",
                        "## Known Gotchas",
                        "",
                        "## Key Decisions",
                        "",
                        "## Recurring Patterns",
                        "",
                        "## Open Questions",
                        "",
                    ]
                ),
                encoding="utf-8",
            )
        else:
            target.write_text(
                "\n".join(
                    [
                        "---",
                        f"period: {month}",
                        "type: learnings",
                        "categories: []",
                        "---",
                        "",
                        f"# Learnings - {month}",
                        "",
                        "## domain:{area}",
                        "",
                        "## stack:{technology}",
                        "",
                        "## practice:{area}",
                        "",
                        "## devops:{area}",
                        "",
                        "## design:{area}",
                        "",
                    ]
                ),
                encoding="utf-8",
            )

    content = read_text(target)
    if is_knowledge:
        heading = {
            "knowledge": "## Architecture Patterns",
            "learning": "## Architecture Patterns",
        }.get(candidate["classification"], "## Architecture Patterns")
        lower = normalize_text(candidate["context"])
        if "question" in lower or "open question" in lower:
            heading = "## Open Questions"
        elif "decision" in lower or "because" in lower or "choose" in lower:
            heading = "## Key Decisions"
        elif "pattern" in lower or "repeated" in lower:
            heading = "## Recurring Patterns"
        elif "gotcha" in lower or "avoid" in lower or "must" in lower:
            heading = "## Known Gotchas"
        entry = f"{local_date()} - {candidate['context']} [candidate-id:{candidate['candidate_id']}]"
        if heading not in content:
            content = content.rstrip() + f"\n\n{heading}\n\n{entry}\n"
        else:
            lines = content.splitlines()
            for idx, line in enumerate(lines):
                if line.strip() == heading:
                    lines.insert(idx + 1, "")
                    lines.insert(idx + 2, entry)
                    content = "\n".join(lines).rstrip() + "\n"
                    break
        atomic_write(target, content if content.endswith("\n") else content + "\n")
        ensure_knowledge_index(root, month, "knowledge")
    else:
        heading = learning_category(candidate["context"])
        entry = f"{local_date()} - {candidate['context']} [candidate-id:{candidate['candidate_id']}]"
        if f"## {heading}" not in content:
            content = content.rstrip() + f"\n\n## {heading}\n\n{entry}\n"
        else:
            lines = content.splitlines()
            for idx, line in enumerate(lines):
                if line.strip() == f"## {heading}":
                    lines.insert(idx + 1, "")
                    lines.insert(idx + 2, entry)
                    content = "\n".join(lines).rstrip() + "\n"
                    break
        atomic_write(target, content if content.endswith("\n") else content + "\n")
        ensure_knowledge_index(root, month, "learnings")


def record_candidate(root: Path, candidate: dict[str, Any], state: dict[str, Any]) -> dict[str, Any]:
    target, is_knowledge = record_target_month_file(root, candidate)
    write_record_entry(root, candidate, target, is_knowledge)
    update_state_for_candidate(state, candidate, "recorded", str(target.relative_to(root)))
    return {"candidate": {**candidate, "status": "recorded", "filed_ref": str(target.relative_to(root))}, "filed_ref": str(target.relative_to(root)), "target_file": str(target.relative_to(root))}


def reject_candidate(candidate: dict[str, Any], state: dict[str, Any]) -> dict[str, Any]:
    update_state_for_candidate(state, candidate, "rejected", None)
    return {"candidate": {**candidate, "status": "rejected"}, "filed_ref": "", "target_file": ""}


def reconstruct_candidate(state: dict[str, Any], candidate_id: str) -> dict[str, Any]:
    by_id = state.get("candidates_by_id", {}).get(candidate_id)
    if isinstance(by_id, dict):
        refs = by_id.get("source_refs") or []
        first_ref = refs[0] if refs else {"path": "", "line": 0}
    return {
        "candidate_id": candidate_id,
        "fingerprint": by_id.get("fingerprint", ""),
        "kind": by_id.get("kind", "deferred"),
        "classification": by_id.get("classification", "chore"),
        "category": by_id.get("category", by_id.get("classification", "chore")),
        "confidence": by_id.get("confidence", "medium"),
        "routing_target": by_id.get("routing_target", "backlog"),
        "title": by_id.get("title", "session candidate"),
        "context": by_id.get("context", ""),
            "source_kind": by_id.get("source_kind", "unknown"),
            "source_path": first_ref.get("path", ""),
            "source_line": first_ref.get("line", 0),
            "source_refs": refs,
            "status": by_id.get("status", "pending"),
        }
    for fingerprint, record in state.get("fingerprints", {}).items():
        if isinstance(record, dict) and record.get("candidate_id") == candidate_id:
            refs = record.get("source_refs") or []
            first_ref = refs[0] if refs else {"path": "", "line": 0}
            return {
                "candidate_id": candidate_id,
                "fingerprint": fingerprint,
                "kind": record.get("kind", "deferred"),
                "classification": record.get("classification", "chore"),
                "category": record.get("category", record.get("classification", "chore")),
                "confidence": record.get("confidence", "medium"),
                "routing_target": "issue" if record.get("classification") in {"bug", "question"} else "backlog",
                "title": record.get("title", "session candidate"),
                "context": record.get("context", ""),
                "source_kind": record.get("source_kind", "unknown"),
                "source_path": first_ref.get("path", ""),
                "source_line": first_ref.get("line", 0),
                "source_refs": refs,
                "status": record.get("status", "pending"),
            }
    raise KeyError(candidate_id)


def handle_file(root: Path, config: dict[str, Any], state: dict[str, Any], candidate_id: str) -> dict[str, Any]:
    candidate = reconstruct_candidate(state, candidate_id)
    if candidate["kind"] == "knowledge":
        return record_candidate(root, candidate, state)
    if config.get("issue_tracker") == "github":
        if not github_available():
            raise RuntimeError("gh CLI is not available")
        proc = run_command(
            [
                "gh",
                "issue",
                "create",
                "--repo",
                repo_slug_from_origin(root),
                "--title",
                candidate["title"],
                "--body",
                github_body(candidate, root),
                *[flag for label in issue_labels(candidate["classification"]) for flag in ("--label", label)],
            ],
            cwd=root,
        )
        if proc.returncode != 0:
            raise RuntimeError(proc.stderr.strip() or "gh issue create failed")
        output = (proc.stdout or "").strip()
        match = re.search(r"https://github\.com/[^\s]+/issues/\d+", output)
        issue_url = match.group(0) if match else output.splitlines()[-1].strip()
        update_state_for_candidate(state, candidate, "filed", issue_url)
        return {"candidate": {**candidate, "status": "filed", "filed_ref": issue_url}, "filed_ref": issue_url, "target_file": issue_url}
    return file_local_candidate(root, candidate, state)


def handle_record(root: Path, state: dict[str, Any], candidate_id: str) -> dict[str, Any]:
    candidate = reconstruct_candidate(state, candidate_id)
    return record_candidate(root, candidate, state)


def handle_reject(state: dict[str, Any], candidate_id: str) -> dict[str, Any]:
    candidate = reconstruct_candidate(state, candidate_id)
    return reject_candidate(candidate, state)


def should_autofile(candidate: dict[str, Any], mode: str) -> bool:
    if mode != "autonomous":
        return False
    if candidate["kind"] == "knowledge":
        return True
    return candidate["confidence"] == "high"


def parse_candidate_stream(root: Path, source: dict[str, Any], config: dict[str, Any], tracker_text: str) -> tuple[list[dict[str, Any]], int]:
    sections = parse_sections(source["text"])
    candidates: list[dict[str, Any]] = []
    duplicate_count = 0
    recorded_insights: set[str] = set()

    for section in sections:
        title = section["title"]
        blocks = split_blocks(section["lines"])
        if title in SECTION_ITEMS_FILED:
            for _line_no, block_text in blocks:
                text = strip_prefix(block_text).strip()
                if (
                    text.lower().startswith("- [knowledge]:")
                    or text.lower().startswith("- [learnings]:")
                    or text.lower().startswith("- [lessons]:")
                ):
                    recorded_insights.add(normalize_text(re.sub(r"^- \[(knowledge|learnings|lessons)\]:\s*", "", text, flags=re.I)))
            continue
        if title not in SECTION_DEFERRED and title not in SECTION_AUTONOMOUS and title not in SECTION_KNOWLEDGE:
            continue
        for line_no, block_text in blocks:
            candidate = build_candidate(root, source, title, block_text, line_no, config)
            if candidate is None:
                continue
            if candidate["kind"] == "knowledge" and normalize_text(candidate["context"]) in recorded_insights:
                duplicate_count += 1
                continue
            candidates.append(candidate)

    lines = source["text"].splitlines()
    in_code = False
    for idx, line in enumerate(lines, 1):
        stripped = line.strip()
        if stripped.startswith("```"):
            in_code = not in_code
            continue
        if in_code or not stripped or stripped.startswith("#"):
            continue
        if not any(re.search(pattern, stripped, re.I) for pattern in DEFERRED_PATTERNS):
            continue
        classification, confidence = classify_deferred(stripped)
        title = short_title(stripped)
        context = short_context("\n".join(lines[max(0, idx - 2) : min(len(lines), idx + 1)]))
        candidate = {
            "candidate_id": sha256_text(f"{normalize_text(rel_path(source['path'], root))}\n{normalize_text(title)}\n{normalize_text(context)}"),
            "fingerprint": sha256_text(f"{normalize_text(title)}\n{normalize_text(context)}"),
            "kind": "deferred",
            "classification": classification,
            "category": classification,
            "confidence": confidence,
            "routing_target": "issue" if classification in {"bug", "question"} else "backlog",
            "title": title,
            "context": context,
            "source_kind": source["kind"],
            "source_path": rel_path(source["path"], root),
            "source_line": idx,
            "source_refs": [{"path": rel_path(source["path"], root), "line": idx}],
            "status": "pending",
        }
        candidates.append(candidate)

    deduped: dict[str, dict[str, Any]] = {}
    for candidate in candidates:
        fp = candidate["fingerprint"]
        if fp in deduped:
            duplicate_count += 1
            existing = deduped[fp]
            existing.setdefault("candidate_ids", [])
            if candidate["candidate_id"] not in existing["candidate_ids"]:
                existing["candidate_ids"].append(candidate["candidate_id"])
            for ref in candidate.get("source_refs", []):
                if ref not in existing.setdefault("source_refs", []):
                    existing["source_refs"].append(ref)
            continue
        deduped[fp] = candidate

    final_candidates = list(deduped.values())
    for candidate in final_candidates:
        if local_tracker_matches(candidate, tracker_text):
            candidate["status"] = "tracked"
            candidate["dedupe_reason"] = "local-tracker"
        elif config.get("issue_tracker") == "github" and github_issue_exists(root, candidate):
            candidate["status"] = "tracked"
            candidate["dedupe_reason"] = "github-issues"
        elif git_or_changelog_match(root, candidate):
            candidate["status"] = "weakly-tracked"
            candidate["dedupe_reason"] = "gitlog-or-changelog"

    return final_candidates, duplicate_count


def handle_scan(root: Path, config: dict[str, Any], state: dict[str, Any], mode: str) -> dict[str, Any]:
    tracker_text = local_tracker_text(root)
    sources = discover_sources(root)
    summary = {
        "sessions_scanned": 0,
        "sessions_skipped_already_scanned": 0,
        "total_candidates": 0,
        "duplicates_filtered": 0,
        "auto_filed": 0,
        "issues_filed": 0,
        "local_backlog_filed": 0,
        "knowledge_recorded": 0,
        "manual_review_count": 0,
    }
    all_candidates: list[dict[str, Any]] = []
    seen_fingerprints: set[str] = set()

    for source in sources:
        rel = rel_path(source["path"], root)
        prev = state.get("sources", {}).get(rel)
        if isinstance(prev, dict) and prev.get("hash") == source["hash"]:
            summary["sessions_skipped_already_scanned"] += 1
            continue
        summary["sessions_scanned"] += 1
        state.setdefault("sources", {})[rel] = {
            "kind": source["kind"],
            "hash": source["hash"],
            "mtime_ns": source["mtime_ns"],
            "last_scanned_at": now_iso(),
        }
        parsed, dupes = parse_candidate_stream(root, source, config, tracker_text)
        summary["duplicates_filtered"] += dupes
        for candidate in parsed:
            if candidate.get("status") in {"tracked", "weakly-tracked"}:
                summary["duplicates_filtered"] += 1
                continue
            if candidate["fingerprint"] in seen_fingerprints:
                summary["duplicates_filtered"] += 1
                continue
            if candidate_seen(state, candidate):
                summary["duplicates_filtered"] += 1
                continue
            seen_fingerprints.add(candidate["fingerprint"])
            update_state_for_candidate(state, candidate, "seen", None)
            if should_autofile(candidate, mode):
                try:
                    if candidate["kind"] == "knowledge":
                        result = record_candidate(root, candidate, state)
                        candidate = result["candidate"]
                        summary["auto_filed"] += 1
                        summary["knowledge_recorded"] += 1
                    elif config.get("issue_tracker") == "github":
                        result = handle_file(root, config, state, candidate["candidate_id"])
                        candidate = result["candidate"]
                        summary["auto_filed"] += 1
                        summary["issues_filed"] += 1
                    elif issue_kind(candidate) == "issue":
                        result = file_local_candidate(root, candidate, state)
                        candidate = result["candidate"]
                        summary["auto_filed"] += 1
                        summary["issues_filed"] += 1
                    else:
                        result = file_local_candidate(root, candidate, state)
                        candidate = result["candidate"]
                        summary["auto_filed"] += 1
                        summary["local_backlog_filed"] += 1
                except Exception:
                    candidate["status"] = "pending"
            else:
                summary["manual_review_count"] += 1
            all_candidates.append(candidate)

    summary["total_candidates"] = len(all_candidates)
    save_state(root, state)
    return {
        "mode": mode,
        "project_root": str(root),
        "summary": summary,
        "sources": [
            {
                "kind": source["kind"],
                "path": rel_path(source["path"], root),
                "hash": source["hash"],
                "mtime_ns": source["mtime_ns"],
            }
            for source in sources
        ],
        "candidates": all_candidates,
        "state_path": str(root / STATE_DIR / STATE_FILE),
    }


def emit_json(result: dict[str, Any]) -> None:
    json.dump(result, sys.stdout, indent=2, sort_keys=True)
    sys.stdout.write("\n")


def emit_text(result: dict[str, Any]) -> None:
    summary = result.get("summary", {})
    print("silver-scan summary")
    print(f"  sessions scanned: {summary.get('sessions_scanned', 0)}")
    print(f"  sessions skipped: {summary.get('sessions_skipped_already_scanned', 0)}")
    print(f"  candidates: {summary.get('total_candidates', 0)}")
    print(f"  duplicates filtered: {summary.get('duplicates_filtered', 0)}")
    print(f"  auto filed: {summary.get('auto_filed', 0)}")
    for candidate in result.get("candidates", []):
        print(f"- [{candidate.get('status', 'pending')}] {candidate.get('kind')} {candidate.get('classification')}: {candidate.get('title')}")


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(prog="silver-scan")
    subparsers = parser.add_subparsers(dest="command", required=True)

    scan = subparsers.add_parser("scan")
    scan.add_argument("--mode", choices=["interactive", "autonomous"], default="interactive")
    scan.add_argument("--format", choices=["json", "text"], default="text")

    file_cmd = subparsers.add_parser("file")
    file_cmd.add_argument("--candidate-id", required=True)
    file_cmd.add_argument("--format", choices=["json", "text"], default="json")

    record_cmd = subparsers.add_parser("record")
    record_cmd.add_argument("--candidate-id", required=True)
    record_cmd.add_argument("--format", choices=["json", "text"], default="json")

    reject_cmd = subparsers.add_parser("reject")
    reject_cmd.add_argument("--candidate-id", required=True)
    reject_cmd.add_argument("--format", choices=["json", "text"], default="json")

    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    root, _ = find_project_root(Path.cwd())
    config = load_config(root)
    state = load_state(root)

    try:
        if args.command == "scan":
            result = handle_scan(root, config, state, args.mode)
        elif args.command == "file":
            result = handle_file(root, config, state, args.candidate_id)
            save_state(root, state)
        elif args.command == "record":
            result = handle_record(root, state, args.candidate_id)
            save_state(root, state)
        elif args.command == "reject":
            result = handle_reject(state, args.candidate_id)
            save_state(root, state)
        else:
            raise RuntimeError(f"unknown command: {args.command}")
    except KeyError as exc:
        emit_json({"error": f"candidate not found: {exc.args[0]}", "candidate": {"candidate_id": exc.args[0], "status": "missing"}})
        return 1
    except Exception as exc:
        emit_json({"error": str(exc), "candidate": {"candidate_id": getattr(args, "candidate_id", ""), "status": "error"}})
        return 1

    if getattr(args, "format", "json") == "text":
        emit_text(result)
    else:
        emit_json(result)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
