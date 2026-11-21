#!/usr/bin/env python3
"""RFL Policy C + failure-management artifact schema and asserts (read side; rfl_native writes run state)."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parent))
import rfl_json  # noqa: E402

RFL_SEVERITIES = ("HIGH", "MED", "LOW", "NIT")

POLICY_C_SCHEMA = "rfl.policy_c.v1"
POLICY_C_JSON = "POLICY-C.json"
POLICY_C_MD = "POLICY-C.md"
LADDER_STATUS_FILENAME = "LADDER-STATUS.json"
QUOTA_CLASSIFY_JSON = "QUOTA-CLASSIFY.json"
VERIFY_1_NAMES = ("verify-1.md", "verify_1.md")
VERIFY_2_NAMES = ("verify-2.md", "verify_2.md")

VERDICTS = frozenset({"CLEAN", "NOT CLEAN", "BLOCKED", "SKIPPED"})
DISPOSITIONS = frozenset({"ACCEPT-apply", "REJECT-as-wrong", "HOLD", "SKIP"})
TRIAGE_DECISIONS = frozenset({"ACCEPT", "REJECT-as-wrong", "REJECT"})
EFFORTS = frozenset({"high", "extra high", "extra-high", "xhigh", "max", "medium", "low"})
NONE_TOKENS = frozenset({"none", "n/a", "na"})
NEXT_ACTIONS = frozenset(
    {"task", "verify_1", "verify_2", "next_rung_review", "mark_completed", "stop"}
)
CONSECUTIVE_CLEAN_REQUIRED = 2
QUOTA_HINT_RE = re.compile(
    r"(429|401|quota|usage[_\s-]?limit|rate[_\s-]?limit|insufficient)",
    re.IGNORECASE,
)
STOP_CHECK_RE = re.compile(r'(?im)(?:^check\s*:|"check"\s*:)\s*\S+')
RUNG_DIR_RE = re.compile(r"^rung-\d+", re.IGNORECASE)


def _read_json(path: Path) -> dict[str, Any]:
    """{} when the file is absent; raises rfl_json.BadJson when it is oversized, too deep or not an object."""
    if not path.is_file():
        return {}
    return rfl_json.read_bounded(path)


def _read_text(path: Path) -> str:
    """Read a text file, returning "" when it is unreadable or not valid UTF-8."""
    try:
        return path.read_text(encoding="utf-8")
    except (OSError, ValueError):
        return ""


def _is_none(value: Any) -> bool:
    if value is None:
        return False
    if isinstance(value, str):
        return value.strip().lower() in NONE_TOKENS
    return False


def _as_rows(value: Any) -> list[dict[str, Any]] | None:
    if _is_none(value):
        return []
    if isinstance(value, list):
        rows = [row for row in value if isinstance(row, dict)]
        if len(rows) != len(value):
            return None
        return rows
    return None


def _require_none_or_rows(payload: dict[str, Any], key: str, errors: list[str]) -> list[dict[str, Any]]:
    if key not in payload:
        errors.append(f"missing {key} none-row")
        return []
    value = payload[key]
    if isinstance(value, list) and len(value) == 0:
        errors.append(f"{key} empty list omitted none-row")
        return []
    rows = _as_rows(value)
    if rows is None:
        errors.append(f"{key} must be \"none\" or a non-empty list")
        return []
    return rows


def policy_c_paths(rung_dir: Path) -> tuple[Path, Path]:
    root = Path(rung_dir)
    return root / POLICY_C_JSON, root / POLICY_C_MD


def ladder_status_path(run_dir: Path) -> Path:
    return Path(run_dir) / LADDER_STATUS_FILENAME


def load_ladder_status(run_dir: Path) -> dict[str, Any]:
    return _read_json(ladder_status_path(run_dir))

def _triage_accept_count(payload: dict[str, Any] | None) -> int:
    if not payload:
        return 0
    rows = _as_rows(payload.get("triage")) or []
    return sum(
        1
        for row in rows
        if _normalize_decision(str(row.get("decision") or "")) == "ACCEPT"
    )


def review_pass_is_clean(payload: dict[str, Any] | None) -> bool:
    """True when this review has zero ACCEPT-worthy (valid) findings."""
    if not payload:
        return False
    verdict = str(payload.get("verdict") or "").strip().upper().replace("_", " ")
    if verdict in {"BLOCKED", "SKIPPED"}:
        return False
    return _triage_accept_count(payload) == 0


def get_consecutive_clean_reviews(status: dict[str, Any], rung_id: str | None = None) -> int:
    """Captured-clean streak that rfl_native derives and signs into LADDER-STATUS.json."""
    rid = str(rung_id or status.get("current_rung") or "").strip()
    if rid and str(status.get("consecutive_clean_rung") or "").strip() != rid:
        return 0
    try:
        return max(0, int(status.get("consecutive_clean_reviews") or 0))
    except (TypeError, ValueError):
        return 0


def _skipped_allows_advance(rung_dir: Path, payload: dict[str, Any]) -> bool:
    verdict = str(payload.get("verdict") or "").strip().upper().replace("_", " ")
    disposition = str(payload.get("disposition") or "").strip()
    if verdict == "SKIPPED" or disposition == "SKIP":
        return _file_nonempty(Path(rung_dir) / "SKIPPED.md")
    return False


def _assert_consecutive_clean_reviews(
    run_dir: Path,
    status: dict[str, Any],
    *,
    action: str,
    rung_dir: Path | str | None,
) -> list[str]:
    if action not in {"next_rung_review", "mark_completed"}:
        return []
    target = resolve_rung_dir(run_dir, rung_dir)
    if target is None and status.get("current_rung"):
        target = resolve_rung_dir(run_dir, status.get("current_rung"))
    if target is None:
        return []
    try:
        payload = load_policy_c(target) or {}
    except rfl_json.BadJson as exc:
        return [f"{POLICY_C_JSON} unreadable: {exc}"]
    if _skipped_allows_advance(target, payload):
        return []
    if action == "mark_completed" and not review_returned(target) and not policy_c_json_path(target).is_file():
        return []
    rid = str(status.get("current_rung") or target.name)
    n = get_consecutive_clean_reviews(status, rid)
    if n < CONSECUTIVE_CLEAN_REQUIRED:
        return [
            (
                f"consecutive_clean_reviews={n} < {CONSECUTIVE_CLEAN_REQUIRED}; "
                "do not start the next ladder model until two consecutive reviews "
                "have zero ACCEPT findings at an unchanged worktree (REJECT does not "
                "break the streak; an applied fix resets it to 0). The encoder derives "
                "the streak from captured reviews: issue another review ticket."
            )
        ]
    return []




def discover_active_rfl_runs(project_root: Path) -> list[Path]:
    planning = Path(project_root) / ".planning"
    if not planning.is_dir():
        return []
    found: list[Path] = []
    for path in sorted(planning.glob("rfl-*/" + LADDER_STATUS_FILENAME)):
        try:
            payload = _read_json(path)
        except rfl_json.BadJson:
            continue
        if str(payload.get("status") or "").strip().lower() == "active":
            found.append(path.parent)
    return found


def list_rung_dirs(run_dir: Path) -> list[Path]:
    root = Path(run_dir)
    if not root.is_dir():
        return []
    return sorted(
        path
        for path in root.iterdir()
        if path.is_dir() and RUNG_DIR_RE.match(path.name)
    )


def resolve_rung_dir(run_dir: Path, rung_dir: Path | str | None = None) -> Path | None:
    if rung_dir is not None:
        candidate = Path(rung_dir)
        if candidate.is_dir():
            return candidate
        named = Path(run_dir) / str(rung_dir)
        if named.is_dir():
            return named
    status = load_ladder_status(run_dir)
    current = str(status.get("current_rung") or "").strip()
    if current:
        named = Path(run_dir) / current
        if named.is_dir():
            return named
        as_path = Path(current)
        if as_path.is_dir():
            return as_path
        if current.isdigit():
            number = int(current)
            for path in list_rung_dirs(run_dir):
                name = path.name
                if name.startswith(f"rung-{number:02d}-") or name.startswith(f"rung-{number}-"):
                    return path
    rungs = list_rung_dirs(run_dir)
    missing = [path for path in rungs if review_returned(path) and not policy_c_json_path(path).is_file()]
    if missing:
        return missing[0]
    if rungs:
        return rungs[-1]
    return None


def policy_c_json_path(rung_dir: Path) -> Path:
    return Path(rung_dir) / POLICY_C_JSON


def review_returned(rung_dir: Path) -> bool:
    return (Path(rung_dir) / "review.md").is_file()


def _first_existing(rung_dir: Path, names: tuple[str, ...]) -> Path | None:
    root = Path(rung_dir)
    for name in names:
        path = root / name
        if path.is_file() and path.stat().st_size > 0:
            return path
    return None


def _phase_is_fix_parallel(phase: str | None) -> bool:
    text = str(phase or "").strip().lower()
    return "fix_parallel" in text or text.endswith("fix")


def _normalize_decision(raw: str) -> str:
    key = (raw or "").strip()
    upper = key.upper().replace("_", "-")
    if upper in {"REJECT", "REJECT-AS-WRONG", "REJECT AS WRONG"}:
        return "REJECT-as-wrong"
    if upper == "ACCEPT":
        return "ACCEPT"
    return key


def _effort_ok(raw: str) -> bool:
    return raw.strip().lower() in EFFORTS


def validate_policy_c(
    payload: dict[str, Any],
    *,
    current_phase: str | None = None,
    require_resolved_complete: bool = False,
) -> list[str]:
    errors: list[str] = []
    schema = str(payload.get("schema") or "").strip()
    if schema and schema != POLICY_C_SCHEMA:
        errors.append(f"unsupported schema {schema!r}")

    identity = payload.get("rung_identity")
    if not isinstance(identity, dict):
        errors.append("missing rung_identity")
        identity = {}
    family = str(identity.get("family") or "").strip()
    effort = str(identity.get("effort") or identity.get("reasoning") or "").strip()
    display = str(identity.get("display") or "").strip()
    if not family:
        errors.append("rung_identity.family required")
    if not effort or not _effort_ok(effort):
        errors.append("rung_identity.effort must be High / Extra High / Max / medium / low")
    if not display:
        errors.append("rung_identity.display required")

    verdict = str(payload.get("verdict") or "").strip().upper()
    if verdict == "NOT_CLEAN":
        verdict = "NOT CLEAN"
    if verdict not in VERDICTS:
        errors.append("verdict must be CLEAN | NOT CLEAN | BLOCKED | SKIPPED")

    disposition = str(payload.get("disposition") or "").strip()
    if disposition not in DISPOSITIONS:
        errors.append("disposition must be ACCEPT-apply | REJECT-as-wrong | HOLD | SKIP")

    issues = payload.get("issues")
    if not isinstance(issues, dict):
        errors.append("issues must be an object with HIGH/MED/LOW/NIT")
        issues = {}
    issue_rows: list[dict[str, Any]] = []
    for sev in RFL_SEVERITIES:
        if sev not in issues:
            errors.append(f"missing {sev} none-row")
            continue
        value = issues[sev]
        if isinstance(value, list) and len(value) == 0:
            errors.append(f"{sev} empty list omitted none-row")
            continue
        rows = _as_rows(value)
        if rows is None:
            errors.append(f"{sev} must be \"none\" or a non-empty list")
            continue
        for row in rows:
            issue_rows.append({"severity": sev, **row})

    if "triage" not in payload:
        errors.append("missing triage")
    else:
        triage_rows = _require_none_or_rows(payload, "triage", errors)
        if issue_rows and _is_none(payload.get("triage")):
            errors.append("triage n/a only when there are no findings")
        for row in triage_rows:
            decision = _normalize_decision(str(row.get("decision") or ""))
            if decision not in {"ACCEPT", "REJECT-as-wrong"}:
                errors.append("triage decision must be ACCEPT or REJECT-as-wrong")
            if not str(row.get("reason") or "").strip() and decision == "REJECT-as-wrong":
                errors.append("REJECT-as-wrong requires reason")

    for key in ("blockers", "highs", "mediums"):
        _require_none_or_rows(payload, key, errors)

    if verdict == "BLOCKED" and disposition not in {"HOLD", "SKIP"}:
        errors.append("BLOCKED requires HOLD (or SKIP) disposition")
    if verdict == "SKIPPED" and disposition != "SKIP":
        errors.append("SKIPPED requires SKIP disposition")

    if "resolved" in payload:
        resolved_val = payload.get("resolved")
        if isinstance(resolved_val, str) and resolved_val.strip().lower() == "pending":
            if require_resolved_complete or not _phase_is_fix_parallel(current_phase):
                errors.append("resolved pending only allowed during rung_N_fix_parallel")
        elif not _is_none(resolved_val):
            resolved_rows = _require_none_or_rows(payload, "resolved", errors)
            for row in resolved_rows:
                flag = str(row.get("resolved") or "").strip().lower()
                if flag == "pending" and (
                    require_resolved_complete or not _phase_is_fix_parallel(current_phase)
                ):
                    errors.append("resolved pending only allowed during rung_N_fix_parallel")
                if require_resolved_complete and flag in {"", "pending", "no"}:
                    errors.append("resolved table incomplete before next-rung review")
    elif require_resolved_complete and disposition == "ACCEPT-apply" and issue_rows:
        errors.append("resolved table required before next-rung review")

    return errors


def render_policy_c_md(payload: dict[str, Any]) -> str:
    identity = payload.get("rung_identity") if isinstance(payload.get("rung_identity"), dict) else {}
    display = str(identity.get("display") or "unknown rung")
    family = str(identity.get("family") or "unknown")
    effort = str(identity.get("effort") or identity.get("reasoning") or "unknown")
    verdict = str(payload.get("verdict") or "")
    disposition = str(payload.get("disposition") or "")

    issues = payload.get("issues") if isinstance(payload.get("issues"), dict) else {}
    issue_rows: list[dict[str, Any]] = []
    for sev in RFL_SEVERITIES:
        rows = _as_rows(issues.get(sev, "none")) or []
        for row in rows:
            issue_rows.append(
                {
                    "id": row.get("id", ""),
                    "title": row.get("title", ""),
                    "severity": sev,
                }
            )

    triage_rows = _as_rows(payload.get("triage", "none")) or []
    normalized_triage = []
    for row in triage_rows:
        item = dict(row)
        item["decision"] = _normalize_decision(str(item.get("decision") or ""))
        normalized_triage.append(item)

    resolved_val = payload.get("resolved", "none")
    if isinstance(resolved_val, str) and resolved_val.strip().lower() == "pending":
        resolved_rows = [
            {
                "id": "—",
                "severity": "LOW",
                "title": "pending APPLY",
                "decision": "ACCEPT",
                "resolved": "pending",
            }
        ]
    else:
        resolved_rows = _as_rows(resolved_val) or []

    def _group_md(label: str, value: Any) -> str:
        rows = _as_rows(value) if not _is_none(value) else []
        if _is_none(value) or not rows:
            return f"- **{label}:** none"
        lines = [f"- **{label}:**"]
        for row in rows:
            ident = row.get("id") or row.get("title") or row
            lines.append(f"  - {ident}")
        return "\n".join(lines)

    parts = [
        f"# Policy C — {display}",
        "",
        f"- **Rung identity:** {display} (`{family}` / `{effort}`)",
        f"- **Verdict:** {verdict}",
        f"- **Disposition:** {disposition}",
        "",
        "## Blockers / Highs / Mediums",
        "",
        _group_md("Blockers", payload.get("blockers", "none")),
        _group_md("Highs", payload.get("highs", "none")),
        _group_md("Mediums", payload.get("mediums", "none")),
        "",
        _render_issue_table(issue_rows).rstrip(),
        "",
        _render_triage_table(normalized_triage).rstrip(),
        "",
        _render_resolved_table(resolved_rows).rstrip(),
        "",
    ]
    return "\n".join(parts) + "\n"


def _render_issue_table(issue_rows: list[dict[str, Any]]) -> str:
    from rfl_launcher_policy import render_issue_table

    return render_issue_table(issue_rows)


def _render_triage_table(rows: list[dict[str, Any]]) -> str:
    from rfl_launcher_policy import render_triage_table

    return render_triage_table(rows)


def _render_resolved_table(rows: list[dict[str, Any]]) -> str:
    from rfl_launcher_policy import render_resolved_table

    return render_resolved_table(rows)


def write_policy_c(
    rung_dir: Path,
    payload: dict[str, Any],
    *,
    current_phase: str | None = None,
) -> dict[str, Any]:
    root = Path(rung_dir)
    root.mkdir(parents=True, exist_ok=True)
    data = dict(payload)
    data.setdefault("schema", POLICY_C_SCHEMA)
    errors = validate_policy_c(data, current_phase=current_phase)
    json_path, md_path = policy_c_paths(root)
    json_path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    md = render_policy_c_md(data)
    md_path.write_text(md, encoding="utf-8")
    return {
        "ok": not errors,
        "errors": errors,
        "json_path": str(json_path),
        "md_path": str(md_path),
        "markdown": md,
        "payload": data,
    }


def triage_rows(payload: dict[str, Any]) -> list[dict[str, Any]]:
    """The triage rows of a Policy C payload ([] for 'none' or a malformed value)."""
    return _as_rows(payload.get("triage")) or []


def accept_rows(rung_dir: Path) -> list[dict[str, Any]]:
    """Triage rows decided ACCEPT in the rung's POLICY-C.json."""
    payload = load_policy_c(rung_dir) or {}
    return [r for r in triage_rows(payload) if _normalize_decision(str(r.get("decision") or "")) == "ACCEPT"]


def load_policy_c(rung_dir: Path) -> dict[str, Any] | None:
    path = policy_c_json_path(rung_dir)
    if not path.is_file():
        return None
    payload = _read_json(path)
    return payload or None


def assert_policy_c(
    rung_dir: Path,
    *,
    current_phase: str | None = None,
    require_resolved_complete: bool = False,
) -> dict[str, Any]:
    root = Path(rung_dir)
    json_path, md_path = policy_c_paths(root)
    errors: list[str] = []
    if not json_path.is_file():
        errors.append(f"missing {POLICY_C_JSON}")
    if not md_path.is_file():
        errors.append(f"missing {POLICY_C_MD}")
    try:
        payload = load_policy_c(root) or {}
    except rfl_json.BadJson as exc:
        payload = {}
        errors.append(f"{POLICY_C_JSON} unreadable: {exc}")
    else:
        if json_path.is_file() and not payload:
            errors.append(f"{POLICY_C_JSON} invalid or empty")
    if payload:
        errors.extend(
            validate_policy_c(
                payload,
                current_phase=current_phase,
                require_resolved_complete=require_resolved_complete,
            )
        )
    return {
        "ok": not errors,
        "errors": errors,
        "rung_dir": str(root),
        "json_path": str(json_path),
        "md_path": str(md_path),
        "payload": payload,
    }


def _file_nonempty(path: Path) -> bool:
    return path.is_file() and path.stat().st_size > 0


def _quota_classify_ok(rung_dir: Path) -> list[str]:
    path = Path(rung_dir) / QUOTA_CLASSIFY_JSON
    if not path.is_file():
        return [f"missing {QUOTA_CLASSIFY_JSON}"]
    try:
        payload = _read_json(path)
    except rfl_json.BadJson as exc:
        return [f"{QUOTA_CLASSIFY_JSON} unreadable: {exc}"]
    errors: list[str] = []
    if "should_schedule" not in payload:
        errors.append(f"{QUOTA_CLASSIFY_JSON} missing should_schedule")
    if "quota_class" not in payload:
        errors.append(f"{QUOTA_CLASSIFY_JSON} missing quota_class")
    return errors


def _blocked_needs_quota(rung_dir: Path, payload: dict[str, Any]) -> bool:
    if payload.get("quota") is True:
        return True
    blocked = Path(rung_dir) / "BLOCKED.md"
    if blocked.is_file():
        if QUOTA_HINT_RE.search(_read_text(blocked)):
            return True
    return False


def _assert_rung_failure_artifacts(
    rung_dir: Path,
    payload: dict[str, Any],
    *,
    next_action: str,
    current_phase: str | None,
) -> list[str]:
    errors: list[str] = []
    verdict = str(payload.get("verdict") or "").strip().upper().replace("_", " ")
    disposition = str(payload.get("disposition") or "").strip()
    advancing = next_action in {"next_rung_review", "mark_completed"}

    if verdict == "BLOCKED" or disposition == "HOLD":
        if not _file_nonempty(Path(rung_dir) / "BLOCKED.md"):
            errors.append("missing BLOCKED.md")
        if _blocked_needs_quota(rung_dir, payload):
            errors.extend(_quota_classify_ok(rung_dir))
        if advancing and disposition == "HOLD":
            errors.append("HOLD/BLOCKED cannot start next rung without skip or quota retry")

    if verdict == "SKIPPED" or disposition == "SKIP":
        if advancing and not _file_nonempty(Path(rung_dir) / "SKIPPED.md"):
            errors.append("missing SKIPPED.md")

    if current_phase and str(current_phase).strip().lower() in {"stop", "compliance_stop"}:
        stop_path = Path(rung_dir) / "STOP.md"
        if not _file_nonempty(stop_path):
            errors.append("missing STOP.md")
        elif not STOP_CHECK_RE.search(_read_text(stop_path)):
            errors.append("STOP.md missing which check failed")
        if next_action in {"verify_1", "verify_2", "next_rung_review", "task"}:
            errors.append("compliance STOP blocks advance")

    stop_path = Path(rung_dir) / "STOP.md"
    if stop_path.is_file() and next_action in {"next_rung_review", "verify_1", "verify_2"}:
        if not STOP_CHECK_RE.search(_read_text(stop_path)):
            errors.append("STOP.md missing which check failed")
        errors.append("STOP.md present — do not advance")

    if advancing and verdict not in {"SKIPPED", "BLOCKED"} and disposition == "ACCEPT-apply":
        issues = payload.get("issues") if isinstance(payload.get("issues"), dict) else {}
        has_findings = any(not _is_none(issues.get(sev)) for sev in RFL_SEVERITIES)
        if has_findings and not _file_nonempty(Path(rung_dir) / "APPLY.md"):
            resolved = payload.get("resolved")
            resolved_complete = False
            rows = _as_rows(resolved) if not _is_none(resolved) else []
            if rows and all(str(row.get("resolved") or "").lower() in {"yes", "n/a", "na"} for row in rows):
                resolved_complete = True
            if not resolved_complete:
                errors.append("missing APPLY.md (or complete resolved table) before next-rung review")

    if advancing and verdict not in {"SKIPPED", "BLOCKED"}:
        if _first_existing(rung_dir, VERIFY_1_NAMES) is None:
            errors.append("missing verify-1.md")
        # Canonical overlay: verify_2 required on CLEAN; skipped on already-triaged NOT CLEAN.
        if verdict == "CLEAN" and _first_existing(rung_dir, VERIFY_2_NAMES) is None:
            errors.append("missing verify-2.md")

    return errors


def assert_rfl_advance(
    run_dir: Path | None = None,
    *,
    rung_dir: Path | str | None = None,
    project_root: Path | None = None,
    next_action: str = "task",
    current_phase: str | None = None,
) -> dict[str, Any]:
    action = next_action if next_action in NEXT_ACTIONS else "task"
    errors: list[str] = []
    checked: list[str] = []

    run_dirs: list[Path] = []
    if run_dir is not None:
        run_dirs.append(Path(run_dir))
    elif project_root is not None:
        run_dirs.extend(discover_active_rfl_runs(project_root))
    else:
        return {"ok": True, "skipped": "no_run_dir", "errors": [], "next_action": action}

    if not run_dirs:
        return {"ok": True, "skipped": "no_active_run", "errors": [], "next_action": action}

    for active in run_dirs:
        try:
            status = load_ladder_status(active)
        except rfl_json.BadJson as exc:
            errors.append(f"{active.name}: {LADDER_STATUS_FILENAME} unreadable ({exc}); run --resume <run-id> to re-validate")
            continue
        status_name = str(status.get("status") or "").strip().lower()
        if action != "mark_completed" and status_name and status_name != "active":
            continue
        phase = current_phase or str(status.get("current_phase") or "")
        current_rung = status.get("current_rung")
        errors.extend(
            _assert_consecutive_clean_reviews(
                active,
                status,
                action=action,
                rung_dir=rung_dir,
            )
        )
        if current_rung is not None and not isinstance(current_rung, str):
            errors.append("LADDER-STATUS.json current_rung must be a single string")
        if status.get("current_phase") is not None and not isinstance(status.get("current_phase"), str):
            errors.append("LADDER-STATUS.json current_phase must be a single string")

        if status.get("compliance_stop") is True:
            target = resolve_rung_dir(active, rung_dir) or active
            stop_path = Path(target) / "STOP.md"
            if not _file_nonempty(stop_path):
                errors.append("compliance_stop set but STOP.md missing")
            elif not STOP_CHECK_RE.search(_read_text(stop_path)):
                errors.append("STOP.md missing which check failed")
            if action != "stop":
                errors.append("compliance STOP blocks advance")

        targets: list[Path] = []
        if action == "mark_completed":
            targets = [
                path
                for path in list_rung_dirs(active)
                if review_returned(path) or policy_c_json_path(path).is_file() or path.name == str(current_rung or "")
            ]
            if str(current_rung or "").strip():
                resolved = resolve_rung_dir(active, current_rung)
                if resolved is not None and resolved not in targets:
                    targets.append(resolved)
            if not targets and str(current_rung or "").strip():
                errors.append("current rung missing Policy C")
        else:
            resolved = resolve_rung_dir(active, rung_dir)
            if resolved is not None:
                targets = [resolved]

        for target in targets:
            checked.append(str(target))
            needs_policy_c = review_returned(target) or action in {
                "verify_1",
                "verify_2",
                "next_rung_review",
                "mark_completed",
            }
            if action in {"task", "stop"} and not review_returned(target) and not policy_c_json_path(target).is_file():
                continue
            if not needs_policy_c and not review_returned(target):
                continue
            require_resolved = action in {"next_rung_review", "mark_completed"}
            result = assert_policy_c(
                target,
                current_phase=phase,
                require_resolved_complete=require_resolved,
            )
            errors.extend(result["errors"])
            payload = result.get("payload") or {}
            if result["ok"] or payload:
                errors.extend(
                    _assert_rung_failure_artifacts(
                        target,
                        payload,
                        next_action=action,
                        current_phase=phase,
                    )
                )

    # Deduplicate while preserving order
    seen: set[str] = set()
    uniq: list[str] = []
    for item in errors:
        if item not in seen:
            seen.add(item)
            uniq.append(item)
    return {
        "ok": not uniq,
        "errors": uniq,
        "next_action": action,
        "checked": checked,
        "run_dirs": [str(path) for path in run_dirs],
    }
