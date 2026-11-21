"""Shared fixtures for the review-fix-ladder native tests (project, state dirs, subagent replies)."""
from __future__ import annotations

import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from sbtest import REPO_ROOT, load_module

native = load_module("scripts/lib/rfl_native.py", name="rfl_native")
hook = load_module("scripts/lib/rfl_hook.py", name="rfl_hook")
rjson = load_module("scripts/lib/rfl_json.py", name="rfl_json")
pc = load_module("scripts/lib/rfl_policy_c.py", name="rfl_policy_c")
qw = load_module("scripts/lib/quota_window.py", name="quota_window")

ENV_KEYS = ("SB_RFL_NOW", "SILVER_BULLET_RUNTIME", "SB_RUNTIME_HOME_ROOT", "SB_RUNTIME_STATE_DIR", "SB_RFL_QUOTA_HOST",
            "PI_PROVIDER", "SB_RFL_MODEL", "PI_MODEL", "SB_RFL_SESSION_ID", "CLAUDE_SESSION_ID", "CLAUDE_CODE_SESSION_ID", "CODEX_THREAD_ID", "CODEX_CI")
CLEAN_POLICY = {
    "schema": "rfl.policy_c.v1",
    "rung_identity": {"family": "sonnet", "effort": "high", "display": "Sonnet High"},
    "verdict": "CLEAN", "issues": {"HIGH": "none", "MED": "none", "LOW": "none", "NIT": "none"},
    "triage": "none", "blockers": "none", "highs": "none", "mediums": "none",
    "disposition": "REJECT-as-wrong", "resolved": "none",
}


def accept_policy(ids=("F1",), rejected=(), file="src/a.py"):
    rows = [{"id": i, "severity": "HIGH", "decision": "ACCEPT", "reason": "valid", "file": file} for i in ids]
    rows += [{"id": i, "severity": "LOW", "decision": "REJECT-as-wrong", "reason": "wrong"} for i in rejected]
    issues = {"HIGH": [{"id": i, "title": "t"} for i in ids], "MED": "none", "LOW": [{"id": i, "title": "t"} for i in rejected] or "none", "NIT": "none"}
    return {**CLEAN_POLICY, "verdict": "NOT CLEAN", "issues": issues, "triage": rows,
            "disposition": "ACCEPT-apply" if ids else "REJECT-as-wrong",
            "resolved": [{"id": i, "severity": "HIGH", "title": "t", "decision": "ACCEPT", "resolved": "yes"} for i in ids] if ids else "none"}


def mint_token(root, kind, run_id, session_id="s1"):
    """What the UserPromptSubmit hook does for a message the user typed."""
    with native.hook_token_context():
        return native.write_user_token(root, kind, run_id, session_id=session_id, prompt_sha256="a" * 64)


class RflCase(unittest.TestCase):
    CHARTER = {"goal": "fix a", "scope": ["src"], "key_tasks": ["t1"],
               "signals": [{"id": "has-x", "argv": ["grep", "-q", "x", "src/a.py"]}]}

    def setUp(self):
        env = {k: v for k, v in os.environ.items() if k not in ENV_KEYS}
        patcher = mock.patch.dict(os.environ, env, clear=True)
        patcher.start()
        self.addCleanup(patcher.stop)
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.tmp = Path(tmp.name).resolve()
        os.environ["HOME"] = str(self.tmp / "home")
        os.environ["SB_RUNTIME_HOME_ROOT"] = str(self.tmp / "home" / ".claude")
        os.environ["SB_RUNTIME_STATE_DIR"] = str(self.tmp / "home" / ".claude" / ".silver-bullet")
        os.environ["SILVER_BULLET_RUNTIME"] = "claude"
        os.environ["CLAUDE_CODE_SESSION_ID"] = "s1"
        (self.tmp / "home").mkdir()
        self.root = self.tmp / "proj"
        (self.root / "src").mkdir(parents=True)
        (self.root / "src" / "a.py").write_text("x = 1\n")
        (self.root / ".silver-bullet.json").write_text('{"sb_initiated": true}\n')
        for cmd in (["init", "-q"], ["config", "user.email", "t@e"], ["config", "user.name", "t"], ["add", "-A"], ["commit", "-qm", "i"]):
            subprocess.run(["git", "-C", str(self.root)] + cmd, check=True, capture_output=True)

    # -- helpers -----------------------------------------------------------------------------
    def write_charter(self, **over):
        path = self.tmp / "charter.json"
        path.write_text(json.dumps({**self.CHARTER, **over}))
        return path

    def start(self, rungs="sonnet:high", run_id="demo", approve=True, **over):
        if rungs:
            native.record_user_rungs(self.root, rungs)  # what the UserPromptSubmit hook does for `rungs: ...`
        out = native.start_run(self.root, self.write_charter(**over), run_id=run_id, rungs_spec=rungs)
        self.run_dir = Path(out["run_dir"])
        if approve:
            self.approve()
        return out

    def approve(self):
        """The user types `RFL APPROVE <id>` (hook token), then the encoder records it."""
        run_id = self.run_dir.name[len("rfl-"):]
        mint_token(self.root, "approve", run_id)
        return native.approve(self.root, self.run_dir)

    def status(self):
        return native.load_status(self.root, self.run_dir)

    def rung_dir(self):
        return self.run_dir / self.status()["rungs"][self.status()["rung_index"] - 1]["dir"]

    def ticket(self, phase):
        return native.issue_ticket(self.root, self.run_dir, phase)

    def reply(self, ticket, body, tool="Agent"):
        text = f'thinking...\n<rfl-result ticket="{ticket}">{json.dumps(body)}</rfl-result>'
        return native.capture_response(self.root, self.run_dir, tool, {"content": [{"type": "text", "text": text}]})

    def spawn_payload(self, issued, **over):
        params = dict(issued["spawn"]["params"])
        params.update(over)
        return {"hook_event_name": "PreToolUse", "tool_name": "Agent", "tool_input": params, "cwd": str(self.root)}

    def write_policy(self, payload):
        result = pc.write_policy_c(self.rung_dir(), payload, current_phase="triage")
        self.assertTrue(result["ok"], result["errors"])

    def review(self, findings=None):
        issued = self.ticket("review")
        body = {"verdict": "NOT CLEAN" if findings else "CLEAN", "findings": findings or []}
        return issued, self.reply(issued["ticket"], body)

    def clean_cycle(self):
        """review (CLEAN) -> triage -> verify_1 -> signals_1 and report the status afterwards."""
        self.review()
        self.write_policy(CLEAN_POLICY)
        native.complete_triage(self.root, self.run_dir)
        issued = self.ticket("verify_1")
        self.reply(issued["ticket"], {"verdict": "VERIFY_PASS", "checks": [], "gaps": []})
        return native.run_signals(self.root, self.run_dir)

    def finish_rung(self):
        self.clean_cycle()
        self.clean_cycle()
        issued = self.ticket("verify_2")
        self.reply(issued["ticket"], {"verdict": "VERIFY_PASS", "checks": [], "gaps": []})
        native.run_signals(self.root, self.run_dir)

    def failed_launch(self, phase="review"):
        """A launch the HOOK observed failing: the ticket is issued and the Agent response carries no verdict."""
        self.ticket(phase)
        return native.capture_response(self.root, self.run_dir, "Agent", "no verdict here")
