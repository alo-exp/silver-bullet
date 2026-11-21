#!/usr/bin/env python3
"""Hook entry point of the review-fix ladder (called by hooks/review-fix-ladder-guard.sh).

``run_hook(stdin_text, project_root)`` returns ``{"output": <hook JSON or None>, "audit": <record or None>}``.
Only plugin code runs here, from the plugin's own copy; nothing from the project is executed or
injected. A run is *live* only when this session started or resumed it (the runtime pointer written by
``--start``/``--resume``), so a repo-shipped ``.planning/rfl-*`` is inert. While a run is live, any error
fails closed (deny / block); with no live run every error allows.
"""

from __future__ import annotations

import os
import re
from pathlib import Path
from typing import Any

import quota_window
import rfl_json
import rfl_native as native
import rfl_policy_c

AGENT_TOOLS = frozenset({"Task", "Subagent", "Agent"})
EDIT_TOOLS = frozenset({"Edit", "Write", "MultiEdit", "apply_patch"})
ABORT_RE = re.compile(r"^\s*RFL ABORT ([A-Za-z0-9._-]{1,64})\s*$")
PATCH_FILE_RE = re.compile(r"^\*\*\* (?:Add|Update|Delete) File: (.+)$|^\*\*\* Move to: (.+)$", re.M)
PROTECTED_NAMES = ("LADDER-STATUS.json", "QUOTA-CLASSIFY.json")
NOTICE_STATUSES = frozenset({"active", "paused_quota"})
MAX_NOTICES = 5
MAX_PAYLOAD = 8_000_000


def _deny(event: str, reason: str) -> dict[str, Any]:
    if event == "PreToolUse":
        out = {"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny",
                                      "permissionDecisionReason": reason}}
    else:
        out = {"decision": "block", "reason": reason}
    return {"output": out, "audit": {"decision": "deny", "reason": reason}}


def _context(event: str, text: str) -> dict[str, Any]:
    return {"output": {"hookSpecificOutput": {"hookEventName": event, "additionalContext": text}}, "audit": None}


NOOP: dict[str, Any] = {"output": None, "audit": None}


def _subagent(payload: dict[str, Any]) -> tuple[str, str]:
    agent_id, agent_type = payload.get("agent_id"), payload.get("agent_type")
    return (agent_id if isinstance(agent_id, str) else "", agent_type if isinstance(agent_type, str) else "")


# ------------------------------------------------------------------------------ SessionStart
def _notice_line(run_dir: Path) -> str | None:
    match = native.RUN_ID_RE.match(run_dir.name[len("rfl-"):])
    if not match:
        return None
    try:
        data = rfl_json.read_bounded(run_dir / native.STATUS_FILE)
    except rfl_json.BadJson:
        return None
    legacy = data.get("schema") != native.SCHEMA
    status = str(data.get("status") or "")
    if status not in NOTICE_STATUSES:
        return None
    raw_rung = data.get("rung_index") if not legacy else (re.match(r"^rung-(\d+)", str(data.get("current_rung") or "")) or [None, "1"])[1]
    rung = int(raw_rung) if str(raw_rung).isdigit() and int(raw_rung) < 1000 else 1
    after = quota_window.parse_iso_datetime(str(data.get("resume_after") or ""))
    parts = [f"RFL run {match.group(0)} is {'legacy ' if legacy else ''}{status} at rung {rung}"]
    if after is not None:
        parts.append(f"(resume after {quota_window.isoformat_z(after)})")
    return " ".join(parts) + f". Resume with /sb:review-fix-ladder --resume {match.group(0)}."


def session_start(payload: dict[str, Any], root: Path) -> dict[str, Any]:
    if payload.get("source") in ("startup", "clear"):
        native.clear_live()
        (native.state_dir() / "review-fix-ladder-state.json").unlink(missing_ok=True)
    lines = []
    for status_file in sorted((root / ".planning").glob("rfl-*/" + native.STATUS_FILE)):
        line = _notice_line(status_file.parent)
        if line:
            lines.append(line)
    if not lines:
        return NOOP
    return _context("SessionStart", " ".join(lines[:MAX_NOTICES]))


# ------------------------------------------------------------------------------ UserPromptSubmit
def prompt_submit(payload: dict[str, Any], root: Path) -> dict[str, Any]:
    prompt = payload.get("prompt")
    match = ABORT_RE.match(prompt) if isinstance(prompt, str) else None
    if not match or _subagent(payload)[0]:
        return NOOP
    run_id = match.group(1)
    try:
        native.load_status(root, native.run_path(root, run_id))
    except native.RflError as exc:
        return {"output": None, "audit": {"decision": "ignore", "reason": f"RFL ABORT {run_id} refused: {exc}"}}
    native.write_abort_token(root, run_id)
    result = _context("UserPromptSubmit", f"RFL ABORT {run_id} accepted for 30 minutes. Run: review-fix-ladder.py --abort {run_id}")
    result["audit"] = {"decision": "allow", "reason": f"RFL ABORT {run_id} token written from a user message"}
    return result


# ------------------------------------------------------------------------------ PreToolUse / PostToolUse
def check_spawn(root: Path, run_dir: Path, status: dict[str, Any], payload: dict[str, Any]) -> str | None:
    if _subagent(payload)[0] or not status["open_ticket"] or status["status"] != "active":
        return None
    ticket = native.read_ticket(root, run_dir, status["open_ticket"])
    spec = payload.get("tool_input")
    spec = spec if isinstance(spec, dict) else {}
    kind = str(spec.get("subagent_type") or spec.get("subagent") or "")
    if ticket["spawned"]:
        return f"RFL ticket {ticket['ticket']} already launched its subagent; wait for its result (one subagent at a time)"
    if kind != ticket["role"] and not kind.endswith(":" + ticket["role"]):
        return f"RFL ticket {ticket['ticket']} requires subagent_type {ticket['role']} (got {kind or 'none'})"
    if str(spec.get("model") or "").lower() != ticket["model"] or str(spec.get("effort") or "").lower() != ticket["effort"]:
        return f"RFL ticket {ticket['ticket']} requires model {ticket['model']} with effort {ticket['effort']}"
    if spec.get("run_in_background"):
        return "RFL review and verify subagents run in the foreground (run_in_background must be absent or false)"
    if native.sha256_text(str(spec.get("prompt") or "").strip()) != ticket["brief_sha256"]:
        return f"RFL ticket {ticket['ticket']} requires the exact brief returned by --issue-ticket (the prompt differs)"
    ticket["spawned"] = True
    native.save_ticket(root, run_dir, ticket)
    return None


def payload_paths(spec: dict[str, Any]) -> list[str]:
    paths = [str(spec[k]) for k in ("file_path", "path", "notebook_path") if isinstance(spec.get(k), str)]
    for edit in spec.get("edits") if isinstance(spec.get("edits"), list) else []:
        if isinstance(edit, dict) and isinstance(edit.get("file_path"), str):
            paths.append(edit["file_path"])
    for key in ("input", "patch", "command"):
        if isinstance(spec.get(key), str):
            paths += [a or b for a, b in PATCH_FILE_RE.findall(spec[key])]
    return paths


def check_edit(root: Path, run_dir: Path, payload: dict[str, Any]) -> str | None:
    spec = payload.get("tool_input")
    spec = spec if isinstance(spec, dict) else {}
    cwd = Path(str(payload.get("cwd") or root))
    rels = []
    for raw in payload_paths(spec):
        target = Path(raw) if Path(raw).is_absolute() else cwd / raw
        try:
            rels.append(Path(os.path.normpath(target)).relative_to(root.resolve()))
        except ValueError:
            continue
    _, agent_type = _subagent(payload)
    if agent_type.split(":")[-1] in native.ROLES.values() and rels:
        return "RFL reviewers and verifiers are read-only: they must not edit files"
    for rel in rels:
        parts = rel.parts
        if len(parts) > 2 and parts[0] == ".planning" and parts[1].startswith("rfl-") and (
            rel.name in PROTECTED_NAMES or "tickets" in parts[2:-1] or rel.name.endswith(".capture.json")
            or (rel.name.startswith("signals-") and rel.name.endswith(".json"))
        ):
            return f"{rel} is an encoder-owned review-fix-ladder artifact; only review-fix-ladder.py writes it"
    try:
        status = native.load_status(root, run_dir)
        scope = native.load_charter(run_dir)["scope"]
    except native.RflError:
        return None
    if status["open_ticket"]:
        for rel in rels:
            if any(rel == Path(s) or Path(s) in rel.parents for s in scope):
                return f"a review-fix-ladder subagent is running (ticket {status['open_ticket']}): do not edit in-scope files until it returns"
    return None


def pre_tool(payload: dict[str, Any], root: Path, run_dir: Path) -> dict[str, Any]:
    tool = str(payload.get("tool_name") or "")
    if tool in AGENT_TOOLS:
        reason = check_spawn(root, run_dir, native.load_status(root, run_dir), payload)
    elif tool in EDIT_TOOLS:
        reason = check_edit(root, run_dir, payload)
    else:
        reason = None
    return _deny("PreToolUse", reason) if reason else NOOP


def post_tool(payload: dict[str, Any], root: Path, run_dir: Path) -> dict[str, Any]:
    if str(payload.get("tool_name") or "") not in AGENT_TOOLS or _subagent(payload)[0]:
        return NOOP
    result = native.capture_response(root, run_dir, str(payload.get("tool_name")), payload.get("tool_response"))
    outcome = result.get("outcome") or ("captured" if result.get("captured") else "")
    if not outcome:
        return NOOP
    return {"output": None, "audit": {"decision": "allow", "reason": f"RFL capture: {outcome}"}}


def stop(root: Path, run_dir: Path) -> dict[str, Any]:
    status = native.load_status(root, run_dir)
    if status["status"] != "active":
        return NOOP
    rung = status["rungs"][status["rung_index"] - 1]
    checked = rfl_policy_c.assert_rfl_advance(run_dir, next_action="stop")
    detail = " " + "; ".join(checked["errors"]) + "." if checked["errors"] else ""
    return _deny("Stop", (
        f"Review-fix ladder run {status['run_id']} is active (rung {rung['index']} {rung['model']}:{rung['effort']}, "
        f"next step {status['phase']}).{detail} Continue the ladder; only the user can end it early by typing "
        f"`RFL ABORT {status['run_id']}`."))


def handle(payload: dict[str, Any], root: Path) -> dict[str, Any]:
    event = str(payload.get("hook_event_name") or payload.get("hookEventName") or "")
    if event == "SessionStart":
        return session_start(payload, root)
    if event == "UserPromptSubmit":
        return prompt_submit(payload, root)
    run_id = native.live_run_id(root)
    if run_id is None:
        return NOOP
    run_dir = native.run_path(root, run_id)
    if event == "PreToolUse":
        return pre_tool(payload, root, run_dir)
    if event == "PostToolUse":
        return post_tool(payload, root, run_dir)
    if event == "Stop":
        return stop(root, run_dir)
    return NOOP


def run_hook(stdin_text: str, project_root: Path) -> dict[str, Any]:
    root = Path(project_root).resolve()
    event = ""
    try:
        payload = rfl_json.loads_bounded(stdin_text, max_bytes=MAX_PAYLOAD, max_depth=200)
        event = str(payload.get("hook_event_name") or payload.get("hookEventName") or "")
        return handle(payload, root)
    except Exception as exc:  # noqa: BLE001 - fail closed while a run is live, open otherwise
        try:
            live = native.live_run_id(root) is not None
        except Exception:  # noqa: BLE001
            live = True
        if live and event in ("PreToolUse", "Stop"):
            return _deny(event, f"Review-fix ladder guard could not check this event ({type(exc).__name__}: {exc}); "
                                "run review-fix-ladder.py --status, or --resume <run-id> to re-validate")
        return NOOP
