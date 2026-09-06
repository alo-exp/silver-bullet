#!/usr/bin/env python3
"""Live multi-AI dispatch — Cursor agent CLI + OCG opencode backends."""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from json_hash import sha256_json
from multi_ai_core import (
    SPINE,
    BudgetPolicy,
    PoolSelection,
    build_result_index,
    build_work_item_manifest,
    detect_host,
    empty_ledger,
    family_for_logical,
    new_attempt_id,
    new_run_id,
    new_work_item_id,
    resolve_pool,
)

CURSOR_BIN = os.environ.get("SB_CURSOR_BIN", shutil.which("cursor") or "cursor")
OPENCODE_BIN = os.environ.get("SB_OPENCODE_BIN", os.path.expanduser("~/.opencode/bin/opencode"))
REPO_ROOT = Path(__file__).resolve().parents[3]
AGENT_OPENCODE_DELEGATE = REPO_ROOT / "scripts" / "agent-opencode-delegate.sh"
AGENT_CODEX_INVOKE = REPO_ROOT / "scripts" / "agent-codex" / "invoke.sh"
AGENT_CLAUDE_INVOKE = REPO_ROOT / "scripts" / "agent-claude" / "invoke.sh"

# Logical pool IDs use dotted versions; Cursor CLI slugs use hyphenated segments.
CURSOR_MODEL_MAP: dict[str, str] = {
    "composer-2.5": "composer-2.5",
    "grok-4.5": "cursor-grok-4.5-high",
    "gpt-5.6-sol-medium": "gpt-5.6-sol-medium",
    "claude-opus-4.8-medium": "claude-opus-4-8-medium",
    "gemini-3.5-flash": "gemini-3.5-flash",
    "glm-5.2": "glm-5.2-high",
}

# Tier fallbacks tried in order when the primary slug fails (invalid or quota-blocked).
CURSOR_MODEL_FALLBACKS: dict[str, list[str]] = {
    "claude-opus-4.8-medium": [
        "claude-opus-4-8-medium-fast",
        "claude-opus-4-8-low",
        "claude-opus-4-8-thinking-medium",
    ],
    "gpt-5.6-sol-medium": [
        "gpt-5.6-sol-low",
        "gpt-5.6-sol-none",
        "gpt-5.5-medium",
    ],
    "gemini-3.5-flash": ["gemini-3-flash"],
    "glm-5.2": ["glm-5.2-max"],
}

# agent-codex / agent-claude delegate env (logical_id → CLI model + effort).
CODEX_DELEGATE_MODEL: dict[str, tuple[str, str]] = {
    "gpt-5.6-luna-medium": ("gpt-5.6-luna", "medium"),
}
CLAUDE_DELEGATE_MODEL: dict[str, tuple[str, str]] = {
    "claude-opus-4.8-medium": ("claude-opus-4-8", "medium"),
}

OCG_MODEL_MAP: dict[str, str] = {
    "ocg-minimax-m3": "opencode-go/minimax-m3",
    "ocg-qwen3.7-max": "opencode-go/qwen3.7-max",
    "ocg-qwen3.7-plus": "opencode-go/qwen3.7-plus",
    "ocg-deepseek-v4-pro": "opencode-go/deepseek-v4-pro",
    "ocg-deepseek-v4-flash": "opencode-go/deepseek-v4-flash",
    "ocg-kimi-k2.6": "opencode-go/kimi-k2.6",
    "ocg-kimi-k2.7-code": "opencode-go/kimi-k2.7-code",
    "ocg-mimo-v2.5-pro": "opencode-go/mimo-v2.5-pro",
    "ocg-mimo-v2.5": "opencode-go/mimo-v2.5",
    "ocg-glm-5.2": "opencode-go/glm-5.2",
}

PHASE_INSTRUCTIONS: dict[str, str] = {
    "DR-RETRIEVE": (
        "DR-RETRIEVE phase: gather authoritative sources and evidence for the research query. "
        "Return JSON only with keys: sources (array of {title, url, relevance}), "
        "evidence (array of {claim, source_ref, confidence})."
    ),
    "DR-TRIANGULATE": (
        "DR-TRIANGULATE phase: cross-check prior evidence and produce claim candidates. "
        "Return JSON only with keys: claim_candidates (array of {text, confidence, supporting_sources}), "
        "cross_checks (array of {claim, status, notes})."
    ),
    "DR-CRITIQUE": (
        "DR-CRITIQUE phase: critique the landscape analysis for gaps, bias, and missing competitors. "
        "Return JSON only with keys: critiques (array of {target, severity, finding}), "
        "gaps (array of {area, description, suggested_action})."
    ),
}


@dataclass
class WorkerResult:
    logical_model_id: str
    backend: str
    attempt_id: str
    status: str
    envelope: dict[str, Any] | None
    raw_output: str
    error: str | None = None
    usage: dict[str, Any] | None = None
    effective_model_id: str | None = None


def stub_mode() -> bool:
    return os.environ.get("SB_MULTI_AI_STUB", "").strip() in {"1", "true", "yes"}


def cursor_model_for(logical_id: str) -> str:
    return CURSOR_MODEL_MAP.get(logical_id, logical_id)


def cursor_last_resort_model() -> str | None:
    raw = os.environ.get("SB_CURSOR_MODEL_LAST_RESORT", "").strip()
    if not raw or raw.lower() in {"none", "off", "false", "0"}:
        return None
    return raw


def cursor_models_to_try(logical_id: str) -> list[str]:
    primary = cursor_model_for(logical_id)
    fallbacks = list(CURSOR_MODEL_FALLBACKS.get(logical_id, []))
    last = cursor_last_resort_model()
    seen: set[str] = set()
    ordered: list[str] = []
    for model in [primary, *fallbacks, *( [last] if last else [] )]:
        if model not in seen:
            seen.add(model)
            ordered.append(model)
    return ordered


CURSOR_TRANSIENT_MARKERS = (
    "ENOTFOUND",
    "Connection lost",
    "reconnecting",
    "ECONNRESET",
    "ETIMEDOUT",
    "network",
)

CURSOR_CLI_FAILURE_MARKERS = (
    "ActionRequiredError:",
    "Cannot use this model:",
    "You've hit your usage limit",
    "usage limit for Opus",
)


def cursor_failure_transient(raw: str) -> bool:
    lower = raw.lower()
    return any(marker.lower() in lower for marker in CURSOR_TRANSIENT_MARKERS)


def cursor_output_is_failure(raw: str) -> bool:
    return any(marker in raw for marker in CURSOR_CLI_FAILURE_MARKERS)


def cursor_allow_model_fallback() -> bool:
    return os.environ.get("SB_CURSOR_MODEL_ALLOW_FALLBACK", "").strip().lower() in {"1", "true", "yes"}


def cursor_attempt_succeeded(*, returncode: int, raw: str) -> bool:
    return returncode == 0 and not cursor_output_is_failure(raw)


def parse_cursor_cli_failure(raw: str) -> str:
    for line in raw.splitlines():
        stripped = line.strip()
        if not stripped:
            continue
        if "ActionRequiredError:" in stripped:
            return stripped.split("ActionRequiredError:", 1)[-1].strip()
        if stripped.startswith("Cannot use this model:"):
            return stripped
        if stripped.startswith("Error:"):
            return stripped
    compact = raw.strip().replace("\n", " ")
    return compact[:500] if compact else "cursor agent failed"


def ocg_model_for(logical_id: str) -> str:
    if logical_id in OCG_MODEL_MAP:
        return OCG_MODEL_MAP[logical_id]
    if logical_id.startswith("ocg-"):
        slug = logical_id.removeprefix("ocg-")
        return f"opencode-go/{slug}"
    raise ValueError(f"unknown OCG logical model: {logical_id}")


def extract_json_payload(text: str) -> dict[str, Any]:
    text = text.strip()
    if not text:
        return {}
    try:
        parsed = json.loads(text)
        if isinstance(parsed, dict):
            return parsed
    except json.JSONDecodeError:
        pass
    fence = re.search(r"```(?:json)?\s*(\{.*?\})\s*```", text, re.DOTALL)
    if fence:
        try:
            parsed = json.loads(fence.group(1))
            if isinstance(parsed, dict):
                return parsed
        except json.JSONDecodeError:
            pass
    brace = re.search(r"(\{.*\})", text, re.DOTALL)
    if brace:
        try:
            parsed = json.loads(brace.group(1))
            if isinstance(parsed, dict):
                return parsed
        except json.JSONDecodeError:
            pass
    return {"raw_text": text[:8000]}


def sanitize_phase_context(context: str, *, max_chars: int = 2000) -> str:
    """Strip noisy raw agent output from prior-phase context passed to workers."""
    if not context:
        return ""
    try:
        parsed = json.loads(context)
        if isinstance(parsed, list):
            cleaned: list[dict[str, Any]] = []
            for item in parsed:
                if not isinstance(item, dict):
                    continue
                payload = {k: v for k, v in item.items() if k != "raw_text"}
                if payload:
                    cleaned.append(payload)
            context = json.dumps(cleaned, indent=2)
    except json.JSONDecodeError:
        pass
    return context[:max_chars]


def build_worker_prompt(*, phase_id: str, query: str, logical_model_id: str, context: str = "", backend: str = "cursor") -> str:
    parts = [
        f"You are a Silver Bullet DR multi-AI worker ({logical_model_id}).",
        PHASE_INSTRUCTIONS.get(phase_id, f"Execute phase {phase_id}."),
        f"Research query: {query}",
    ]
    if backend == "ocg":
        parts.append(
            "IMPORTANT: Do NOT use tools, web fetch, or file reads. "
            "Answer from the query and prior context only. Return JSON immediately."
        )
    if context:
        parts.append(f"Prior context:\n{sanitize_phase_context(context)}")
    parts.append(
        "Respond with a single JSON object matching the phase schema. "
        "No markdown wrapper unless fenced. Be concise but substantive."
    )
    return "\n\n".join(parts)


def run_cursor_worker(*, logical_model_id: str, prompt: str, output_dir: Path, timeout_sec: int = 600) -> WorkerResult:
    attempt_id = new_attempt_id()
    out_file = output_dir / f"{logical_model_id.replace('.', '-')}-{attempt_id}.txt"
    models = cursor_models_to_try(logical_model_id)
    failures: list[str] = []
    last_raw = ""

    try:
        for model in models:
            cmd = [
                CURSOR_BIN,
                "agent",
                "--print",
                "--output-format",
                "text",
                "--model",
                model,
                "--force",
                "--trust",
                prompt,
            ]
            proc = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout_sec, cwd=str(output_dir))
            raw = (proc.stdout or "") + ("\n" + proc.stderr if proc.stderr else "")
            last_raw = raw
            if cursor_attempt_succeeded(returncode=proc.returncode, raw=raw):
                requested = models[0]
                used_fallback = model != requested
                if used_fallback and not cursor_allow_model_fallback():
                    failures.append(f"{model}: fallback disabled (requested {requested})")
                    continue
                note = None
                status = "completed"
                if used_fallback:
                    note = f"fallback from {requested} to {model}"
                    status = "fallback"
                out_file.write_text(raw, encoding="utf-8")
                return WorkerResult(
                    logical_model_id,
                    "cursor",
                    attempt_id,
                    status,
                    None,
                    raw,
                    note,
                    effective_model_id=model,
                )
            failure = parse_cursor_cli_failure(raw)
            if cursor_failure_transient(raw) and model == models[-1]:
                time.sleep(3)
                proc_retry = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout_sec, cwd=str(output_dir))
                raw_retry = (proc_retry.stdout or "") + ("\n" + proc_retry.stderr if proc_retry.stderr else "")
                last_raw = raw_retry
                if cursor_attempt_succeeded(returncode=proc_retry.returncode, raw=raw_retry):
                    requested = models[0]
                    used_fallback = model != requested
                    if used_fallback and not cursor_allow_model_fallback():
                        failure = f"fallback disabled after retry (requested {requested}, got {model})"
                    else:
                        note = f"retry after transient error ({model})"
                        status = "completed"
                        if used_fallback:
                            note = f"fallback from {requested} to {model}; {note}"
                            status = "fallback"
                        out_file.write_text(raw_retry, encoding="utf-8")
                        return WorkerResult(
                            logical_model_id,
                            "cursor",
                            attempt_id,
                            status,
                            None,
                            raw_retry,
                            note,
                            effective_model_id=model,
                        )
                failure = parse_cursor_cli_failure(raw_retry)
            failures.append(f"{model}: {failure}")

        out_file.write_text(last_raw, encoding="utf-8")
        return WorkerResult(
            logical_model_id,
            "cursor",
            attempt_id,
            "failed",
            None,
            last_raw,
            "; ".join(failures) if failures else "exit 1",
            effective_model_id=models[-1] if models else None,
        )
    except subprocess.TimeoutExpired as exc:
        partial = (exc.stdout or b"").decode("utf-8", errors="replace") if exc.stdout else ""
        return WorkerResult(logical_model_id, "cursor", attempt_id, "partial", None, partial, "timeout")
    except FileNotFoundError:
        return WorkerResult(logical_model_id, "cursor", attempt_id, "failed", None, "", "cursor CLI not found")


def _delegate_work_dir(output_dir: Path) -> Path:
    """DR workers run in repo root; phase artifacts land in output_dir."""
    return REPO_ROOT


def _resolve_codex_bin() -> str:
    explicit = os.environ.get("CODEX_BIN", "").strip()
    if explicit and Path(explicit).is_file():
        return explicit
    candidates = [
        "/Applications/ChatGPT.app/Contents/Resources/codex",
        "/Applications/Codex.app/Contents/Resources/codex",
        shutil.which("codex") or "",
    ]
    for candidate in candidates:
        if candidate and Path(candidate).is_file() and Path(candidate).name == "codex":
            return candidate
    return explicit or "codex"


def run_codex_worker(*, logical_model_id: str, prompt: str, output_dir: Path, timeout_sec: int = 600) -> WorkerResult:
    """Dispatch via /sb:agent-codex → scripts/agent-codex/invoke.sh (--use-exec)."""
    attempt_id = new_attempt_id()
    slug = logical_model_id.replace(".", "-")
    out_file = output_dir / f"{slug}-{attempt_id}.txt"
    log_file = output_dir / f"codex-delegate-{attempt_id}.log"
    model, effort = CODEX_DELEGATE_MODEL.get(logical_model_id, (logical_model_id, "medium"))
    if not AGENT_CODEX_INVOKE.is_file():
        return WorkerResult(logical_model_id, "codex", attempt_id, "failed", None, "", f"missing {AGENT_CODEX_INVOKE}")

    work_dir = _delegate_work_dir(output_dir)
    env = os.environ.copy()
    env.update(
        {
            "SB_ROOT": str(REPO_ROOT),
            "SB_HOST": "cursor",
            "CODEX_BIN": _resolve_codex_bin(),
            "CODEX_MODEL": model,
            "CODEX_REASONING_EFFORT": effort,
            "SB_AGENT_CODEX_DELEGATE": "1",
            "SB_AGENT_CODEX_LIGHTWEIGHT": "1",
            "SB_ORCHESTRATOR_WORKER": "1",
            "SB_ORCHESTRATOR_PARENT": "0",
        }
    )
    cmd = [
        "bash",
        str(AGENT_CODEX_INVOKE),
        "--skip-preflight",
        "--work-dir",
        str(work_dir),
        "--prompt",
        prompt,
        "--use-exec",
        "--log",
        str(log_file),
        "--mode",
        "permissive",
        "--sb-root",
        str(REPO_ROOT),
    ]
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout_sec, cwd=str(work_dir), env=env)
        raw = (proc.stdout or "") + ("\n" + proc.stderr if proc.stderr else "")
        out_file.write_text(raw, encoding="utf-8")
        if proc.returncode != 0:
            return WorkerResult(
                logical_model_id,
                "codex",
                attempt_id,
                "failed",
                None,
                raw,
                f"agent-codex exit {proc.returncode}",
                effective_model_id=f"{model}-{effort}",
            )
        return WorkerResult(
            logical_model_id,
            "codex",
            attempt_id,
            "completed",
            None,
            raw,
            effective_model_id=f"{model}-{effort}",
        )
    except subprocess.TimeoutExpired as exc:
        partial = (exc.stdout or b"").decode("utf-8", errors="replace") if exc.stdout else ""
        return WorkerResult(logical_model_id, "codex", attempt_id, "partial", None, partial, "timeout")
    except FileNotFoundError:
        return WorkerResult(logical_model_id, "codex", attempt_id, "failed", None, "", "agent-codex invoke not found")


def run_claude_worker(*, logical_model_id: str, prompt: str, output_dir: Path, timeout_sec: int = 600) -> WorkerResult:
    """Dispatch via /sb:agent-claude → scripts/agent-claude/invoke.sh (--use-print)."""
    attempt_id = new_attempt_id()
    slug = logical_model_id.replace(".", "-")
    out_file = output_dir / f"{slug}-{attempt_id}.txt"
    log_file = output_dir / f"claude-delegate-{attempt_id}.log"
    model, effort = CLAUDE_DELEGATE_MODEL.get(logical_model_id, ("sonnet", "low"))
    if not AGENT_CLAUDE_INVOKE.is_file():
        return WorkerResult(logical_model_id, "claude", attempt_id, "failed", None, "", f"missing {AGENT_CLAUDE_INVOKE}")

    work_dir = _delegate_work_dir(output_dir)
    env = os.environ.copy()
    env.update(
        {
            "SB_ROOT": str(REPO_ROOT),
            "SB_HOST": "cursor",
            "CLAUDE_BIN": os.environ.get("CLAUDE_BIN", shutil.which("claude") or "/Users/shafqat/.local/bin/claude"),
            "CLAUDE_MODEL": model,
            "CLAUDE_EFFORT": effort,
            "CLAUDE_PRINT_VERBOSE": "0",
            "SB_AGENT_CLAUDE_DELEGATE": "1",
            "SB_AGENT_CLAUDE_LIGHTWEIGHT": "1",
            "SB_ORCHESTRATOR_WORKER": "1",
            "SB_ORCHESTRATOR_PARENT": "0",
        }
    )
    cmd = [
        "bash",
        str(AGENT_CLAUDE_INVOKE),
        "--skip-preflight",
        "--work-dir",
        str(work_dir),
        "--prompt",
        prompt,
        "--use-print",
        "--log",
        str(log_file),
        "--mode",
        "permissive",
        "--sb-root",
        str(REPO_ROOT),
    ]
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout_sec, cwd=str(work_dir), env=env)
        raw = (proc.stdout or "") + ("\n" + proc.stderr if proc.stderr else "")
        out_file.write_text(raw, encoding="utf-8")
        if proc.returncode != 0:
            return WorkerResult(
                logical_model_id,
                "claude",
                attempt_id,
                "failed",
                None,
                raw,
                f"agent-claude exit {proc.returncode}",
                effective_model_id=f"{model}-{effort}",
            )
        return WorkerResult(
            logical_model_id,
            "claude",
            attempt_id,
            "completed",
            None,
            raw,
            effective_model_id=f"{model}-{effort}",
        )
    except subprocess.TimeoutExpired as exc:
        partial = (exc.stdout or b"").decode("utf-8", errors="replace") if exc.stdout else ""
        return WorkerResult(logical_model_id, "claude", attempt_id, "partial", None, partial, "timeout")
    except FileNotFoundError:
        return WorkerResult(logical_model_id, "claude", attempt_id, "failed", None, "", "agent-claude invoke not found")


def run_ocg_worker(*, logical_model_id: str, prompt: str, output_dir: Path, timeout_sec: int = 600) -> WorkerResult:
    """Deprecated per-agent path — retained for tests; production uses run_ocg_pool_cohort."""
    attempt_id = new_attempt_id()
    model = ocg_model_for(logical_model_id)
    out_file = output_dir / f"{logical_model_id}-{attempt_id}.txt"
    cmd = [OPENCODE_BIN, "run", "--model", model, prompt]
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout_sec, cwd=str(output_dir))
        raw = (proc.stdout or "") + ("\n" + proc.stderr if proc.stderr else "")
        out_file.write_text(raw, encoding="utf-8")
        if proc.returncode != 0:
            return WorkerResult(logical_model_id, "ocg", attempt_id, "failed", None, raw, f"exit {proc.returncode}")
        return WorkerResult(logical_model_id, "ocg", attempt_id, "completed", None, raw)
    except subprocess.TimeoutExpired as exc:
        partial = (exc.stdout or b"").decode("utf-8", errors="replace") if exc.stdout else ""
        return WorkerResult(logical_model_id, "ocg", attempt_id, "partial", None, partial, "timeout")
    except FileNotFoundError:
        return WorkerResult(logical_model_id, "ocg", attempt_id, "failed", None, "", "opencode CLI not found")


def _parse_ocg_cohort_output(raw: str) -> dict[str, Any] | None:
    text = raw.strip()
    if not text:
        return None
    try:
        parsed = json.loads(text)
        if isinstance(parsed, dict) and parsed.get("schema_id") == "ocg-pool-cohort-result-v1":
            return parsed
    except json.JSONDecodeError:
        pass
    fence = re.search(r"```(?:json)?\s*(\{.*?\})\s*```", text, re.DOTALL)
    if fence:
        try:
            parsed = json.loads(fence.group(1))
            if isinstance(parsed, dict) and parsed.get("schema_id") == "ocg-pool-cohort-result-v1":
                return parsed
        except json.JSONDecodeError:
            pass
    brace = re.search(r"(\{[^{}]*\"schema_id\"\s*:\s*\"ocg-pool-cohort-result-v1\".*\})", text, re.DOTALL)
    if brace:
        try:
            parsed = json.loads(brace.group(1))
            if isinstance(parsed, dict):
                return parsed
        except json.JSONDecodeError:
            pass
    return None


def run_ocg_pool_cohort(
    *,
    ocg_items: list[dict[str, Any]],
    phase_id: str,
    query: str,
    run_id: str,
    work_item_id: str,
    output_dir: Path,
    context: str,
    pool: str,
    timeout_sec: int = 600,
) -> list[WorkerResult]:
    """Single agent-opencode handoff; OpenCode cohort script fans out all ocg-* profiles."""
    if not ocg_items:
        return []

    attempt_id = new_attempt_id()
    phase_dir = output_dir
    phase_dir.mkdir(parents=True, exist_ok=True)
    request_path = phase_dir / f"ocg-cohort-request-{attempt_id}.json"
    result_path = phase_dir / f"ocg-cohort-result-{attempt_id}.json"
    log_path = phase_dir / f"ocg-cohort-{attempt_id}.log"
    progress_path = phase_dir / f"ocg-cohort-progress-{attempt_id}.log"

    logical_ids = [item["logical_model_id"] for item in ocg_items]
    per_model = min(timeout_sec, int(os.environ.get("SB_OCG_PER_MODEL_TIMEOUT_SEC", "240")))
    cohort_timeout = len(logical_ids) * per_model + 300
    request = {
        "phase_id": phase_id,
        "query": query,
        "context": context,
        "logical_model_ids": logical_ids,
        "pool": pool,
        "work_dir": str(phase_dir.resolve()),
        "timeout_sec": per_model,
        "attempt_id": attempt_id,
        "run_id": run_id,
        "work_item_id": work_item_id,
    }
    request_path.write_text(json.dumps(request, indent=2) + "\n", encoding="utf-8")

    cohort_script = REPO_ROOT / "skills" / "silver-multi-ai-task" / "scripts" / "ocg_pool_cohort.py"
    if not AGENT_OPENCODE_DELEGATE.is_file():
        return [
            WorkerResult(
                lid,
                "ocg",
                attempt_id,
                "failed",
                None,
                "",
                f"missing agent-opencode delegate at {AGENT_OPENCODE_DELEGATE}",
            )
            for lid in logical_ids
        ]

    cmd = [
        "bash",
        str(AGENT_OPENCODE_DELEGATE),
        "--work-dir",
        str(phase_dir),
        "--sb-root",
        str(REPO_ROOT),
        "--delegation-mode",
        "multi-ai-pool-v1",
        "--multi-ai-pool",
        pool,
        "--cohort-request",
        str(request_path),
        "--cohort-output",
        str(result_path),
        "--log",
        str(log_path),
    ]

    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=cohort_timeout, cwd=str(REPO_ROOT))
        raw = (proc.stdout or "") + ("\n" + proc.stderr if proc.stderr else "")
        cohort_payload: dict[str, Any] | None = None
        if result_path.is_file():
            try:
                cohort_payload = json.loads(result_path.read_text(encoding="utf-8"))
            except json.JSONDecodeError:
                cohort_payload = None
        if cohort_payload is None:
            cohort_payload = _parse_ocg_cohort_output(raw)
        if cohort_payload is None:
            err = f"ocg cohort parse failed (exit {proc.returncode})"
            return [WorkerResult(lid, "ocg", attempt_id, "failed", None, raw, err) for lid in logical_ids]

        by_id = {c.get("logical_model_id"): c for c in cohort_payload.get("contributions", [])}
        results: list[WorkerResult] = []
        for item in ocg_items:
            lid = item["logical_model_id"]
            contrib = by_id.get(lid)
            if not contrib:
                results.append(WorkerResult(lid, "ocg", attempt_id, "failed", None, raw, "missing cohort contribution"))
                continue
            status = str(contrib.get("status", "failed"))
            payload = contrib.get("payload") or {}
            wr = WorkerResult(
                lid,
                "ocg",
                attempt_id,
                status,
                None,
                str(contrib.get("raw_output_path", "")),
                contrib.get("error"),
                effective_model_id=contrib.get("effective_model_id"),
            )
            if status in {"completed", "partial"} and payload:
                wr.envelope = build_envelope(
                    run_id=run_id,
                    work_item_id=work_item_id,
                    phase_id=phase_id,
                    logical_model_id=lid,
                    attempt_id=attempt_id,
                    payload=payload,
                )
            results.append(wr)
        return results
    except subprocess.TimeoutExpired:
        return [WorkerResult(lid, "ocg", attempt_id, "partial", None, "", "ocg cohort timeout") for lid in logical_ids]
    except FileNotFoundError:
        return [WorkerResult(lid, "ocg", attempt_id, "failed", None, "", "agent-opencode delegate not found") for lid in logical_ids]


def build_envelope(
    *,
    run_id: str,
    work_item_id: str,
    phase_id: str,
    logical_model_id: str,
    attempt_id: str,
    payload: dict[str, Any],
    requested_model_id: str | None = None,
    effective_model_id: str | None = None,
    routing_note: str | None = None,
    authoritative: bool = True,
) -> dict[str, Any]:
    envelope = {
        "schema_id": "dr-phase-contribution-envelope-v1",
        "version": "1.0.0",
        "run_id": run_id,
        "work_item_id": work_item_id,
        "phase_id": phase_id,
        "logical_model_id": logical_model_id,
        "attempt_id": attempt_id,
        "model_family_id": family_for_logical(logical_model_id),
        "payload": payload,
        "authoritative": authoritative,
    }
    if requested_model_id or effective_model_id or routing_note:
        envelope["model_routing"] = {
            "requested_model_id": requested_model_id or cursor_model_for(logical_model_id),
            "effective_model_id": effective_model_id,
            "routing_note": routing_note,
        }
    return envelope


def dispatch_agent(item: dict[str, Any], *, phase_id: str, query: str, run_id: str, work_item_id: str, output_dir: Path, context: str, timeout_sec: int) -> WorkerResult:
    logical_id = item["logical_model_id"]
    backend = item.get("backend", "cursor")
    if backend == "ocg":
        raise ValueError("dispatch_agent does not dispatch OCG items — use run_ocg_pool_cohort")
    prompt = build_worker_prompt(
        phase_id=phase_id,
        query=query,
        logical_model_id=logical_id,
        context=context,
        backend="cursor" if backend in {"cursor", "codex", "claude"} else backend,
    )
    if backend == "codex":
        result = run_codex_worker(logical_model_id=logical_id, prompt=prompt, output_dir=output_dir, timeout_sec=timeout_sec)
    elif backend == "claude":
        result = run_claude_worker(logical_model_id=logical_id, prompt=prompt, output_dir=output_dir, timeout_sec=timeout_sec)
    else:
        result = run_cursor_worker(logical_model_id=logical_id, prompt=prompt, output_dir=output_dir, timeout_sec=timeout_sec)
    payload = extract_json_payload(result.raw_output)
    if result.status in {"completed", "partial", "fallback"} and payload:
        routing_note = result.error
        requested = logical_id
        if backend == "cursor":
            requested = cursor_model_for(logical_id)
        elif backend == "codex":
            m, e = CODEX_DELEGATE_MODEL.get(logical_id, (logical_id, "medium"))
            requested = f"{m}-{e}"
        elif backend == "claude":
            m, e = CLAUDE_DELEGATE_MODEL.get(logical_id, ("sonnet", "low"))
            requested = f"{m}-{e}"
        result.envelope = build_envelope(
            run_id=run_id,
            work_item_id=work_item_id,
            phase_id=phase_id,
            logical_model_id=logical_id,
            attempt_id=result.attempt_id,
            payload=payload,
            requested_model_id=requested,
            effective_model_id=result.effective_model_id,
            routing_note=routing_note,
            authoritative=result.status == "completed",
        )
    return result


def dispatch_phase_parallel(*, phase_id: str, query: str, run_id: str, work_item_id: str, resolved_pool: list[dict[str, Any]], output_dir: Path, context: str = "", concurrency: int = 3, timeout_sec: int = 600, ocg_pool: str = "lite") -> list[WorkerResult]:
    phase_dir = output_dir / "phases" / phase_id
    phase_dir.mkdir(parents=True, exist_ok=True)
    cursor_items = [item for item in resolved_pool if item.get("backend", "cursor") not in {"ocg"}]
    ocg_items = [item for item in resolved_pool if item.get("backend") == "ocg"]
    results: list[WorkerResult] = []
    worker_count = max(1, len(cursor_items) + (1 if ocg_items else 0))
    with ThreadPoolExecutor(max_workers=min(concurrency, worker_count)) as pool:
        futures = []
        for item in cursor_items:
            futures.append(
                pool.submit(
                    dispatch_agent,
                    item,
                    phase_id=phase_id,
                    query=query,
                    run_id=run_id,
                    work_item_id=work_item_id,
                    output_dir=phase_dir,
                    context=context,
                    timeout_sec=timeout_sec,
                )
            )
        if ocg_items:
            futures.append(
                pool.submit(
                    run_ocg_pool_cohort,
                    ocg_items=ocg_items,
                    phase_id=phase_id,
                    query=query,
                    run_id=run_id,
                    work_item_id=work_item_id,
                    output_dir=phase_dir,
                    context=context,
                    pool=ocg_pool,
                    timeout_sec=timeout_sec,
                )
            )
        for fut in as_completed(futures):
            outcome = fut.result()
            if isinstance(outcome, list):
                results.extend(outcome)
            else:
                results.append(outcome)
    return results


def run_multi_ai_live(*, output_root: Path, selection: PoolSelection, budget: BudgetPolicy | None = None, task_prompt: str = "", phase_id: str | None = None, timeout_sec: int = 600) -> dict[str, Any]:
    if stub_mode():
        return {"ok": False, "error_code": "MULTI_AI_LIVE_DISPATCH_NOT_READY", "message": "SB_MULTI_AI_STUB=1 — live dispatch disabled"}

    output_root.mkdir(parents=True, exist_ok=True)
    resolved = resolve_pool(selection)
    run_id = new_run_id()
    work_item_id = new_work_item_id()
    budget = budget or BudgetPolicy()
    input_hash = sha256_json({"task": task_prompt, "phase_id": phase_id, "pool": resolved})

    manifest = build_work_item_manifest(run_id, work_item_id, input_hash, resolved, budget)
    ledger = empty_ledger(run_id)
    index = build_result_index(run_id, ledger, resolved, work_item_id)

    effective_phase = phase_id or "DR-RETRIEVE"
    ocg_pool = selection.ocg_pool if selection.ocg_pool in {"lite", "regular"} else "lite"
    worker_results = dispatch_phase_parallel(
        phase_id=effective_phase,
        query=task_prompt or "multi-ai-task",
        run_id=run_id,
        work_item_id=work_item_id,
        resolved_pool=resolved,
        output_dir=output_root,
        timeout_sec=timeout_sec,
        ocg_pool=ocg_pool,
    )

    envelopes: list[dict[str, Any]] = []
    attempts = []
    for wr in worker_results:
        attempts.append(
            {
                "attempt_id": wr.attempt_id,
                "logical_model_id": wr.logical_model_id,
                "status": wr.status,
                "backend": wr.backend,
                "authoritative": wr.status == "completed",
                "effective_model_id": wr.effective_model_id,
                "error": wr.error,
            }
        )
        if wr.envelope:
            envelopes.append(wr.envelope)
        for entry in index["entries"]:
            if entry["logical_model_id"] == wr.logical_model_id:
                entry["status"] = wr.status
                entry["authoritative_attempt_id"] = wr.attempt_id if wr.status == "completed" else None
                entry["terminal_reason"] = wr.error

    manifest["attempts"] = attempts
    manifest["budget"]["usage_metered"] = True

    wi_dir = output_root / "work-items" / work_item_id
    wi_dir.mkdir(parents=True, exist_ok=True)
    manifest_path = wi_dir / "multi-ai-work-item-manifest-v1.json"
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

    envelopes_path = output_root / "contributions" / f"{work_item_id}.json"
    envelopes_path.parent.mkdir(parents=True, exist_ok=True)
    envelopes_path.write_text(json.dumps(envelopes, indent=2) + "\n", encoding="utf-8")

    index_path = output_root / "result-index.json"
    index_path.write_text(json.dumps(index, indent=2) + "\n", encoding="utf-8")

    ledger_path = output_root / "dispatch-ledger.json"
    ledger_path.write_text(json.dumps(ledger, indent=2) + "\n", encoding="utf-8")

    return {
        "ok": True,
        "host": detect_host(),
        "spine": SPINE,
        "run_id": run_id,
        "work_item_id": work_item_id,
        "phase_id": effective_phase,
        "resolved_count": len(resolved),
        "resolved_pool": resolved,
        "envelopes_count": len(envelopes),
        "manifest_path": str(manifest_path),
        "envelopes_path": str(envelopes_path),
        "worker_results": [{"logical_model_id": w.logical_model_id, "backend": w.backend, "status": w.status, "error": w.error} for w in worker_results],
        "live_dispatch": True,
    }
