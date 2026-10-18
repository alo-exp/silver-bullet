"""Behavioral tests for multi_ai_cli, json_hash, capability_spike, cursor_host_adapter, ocg_pool_cohort."""

from __future__ import annotations

import contextlib
import hashlib
import importlib
import io
import json
import os
import runpy
import subprocess
import sys
import unittest
from pathlib import Path
from unittest import mock

from cov_helpers import SCRIPTS, HermeticCase

import capability_spike
import cursor_host_adapter as cha
import json_hash
import live_dispatch
import multi_ai_cli
import ocg_pool_cohort as oc


def run_main(fn, argv: list[str]) -> tuple[int, str, str]:
    out, err = io.StringIO(), io.StringIO()
    with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
        rc = fn(argv)
    return rc, out.getvalue(), err.getvalue()


class JsonHashTests(HermeticCase):
    def test_canonical_json_is_sorted_and_compact(self) -> None:
        self.assertEqual(json_hash.canonical_json_bytes({"b": 1, "a": [1, 2]}), b'{"a":[1,2],"b":1}')
        self.assertEqual(json_hash.canonical_json_bytes("é"), '"\\u00e9"'.encode())

    def test_sha256_helpers_agree_with_hashlib(self) -> None:
        self.assertEqual(json_hash.sha256_bytes(b"abc"), hashlib.sha256(b"abc").hexdigest())
        path = self.tmp / "f.bin"
        path.write_bytes(b"file-bytes")
        self.assertEqual(json_hash.sha256_file(path), hashlib.sha256(b"file-bytes").hexdigest())
        self.assertEqual(json_hash.sha256_json({"b": 1, "a": 2}), json_hash.sha256_json({"a": 2, "b": 1}))
        self.assertEqual(json_hash.sha256_json([1]), hashlib.sha256(b"[1]").hexdigest())
        with self.assertRaises(FileNotFoundError):
            json_hash.sha256_file(self.tmp / "missing")


class MultiAiCliTests(HermeticCase):
    def test_parse_args_defaults(self) -> None:
        args = multi_ai_cli.parse_args([])
        self.assertEqual((args.ocg_pool, args.cursor_pool, args.max_agents, args.timeout_sec), ("lite", "default", 11, 600))
        self.assertEqual((args.cursor_subscription, args.include_only, args.exclude, args.dry_run), ("auto", [], [], False))
        parsed = multi_ai_cli.parse_args(["--include-only", "a", "--include-only", "b", "--exclude", "c", "--phase-id", "DR-CRITIQUE"])
        self.assertEqual((parsed.include_only, parsed.exclude, parsed.phase_id), (["a", "b"], ["c"], "DR-CRITIQUE"))
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
            multi_ai_cli.parse_args(["--phase-id", "NOPE"])

    def test_live_dispatch_requires_output_root(self) -> None:
        rc, out, _ = run_main(multi_ai_cli.main, [])
        self.assertEqual(rc, 2)
        self.assertEqual(json.loads(out)["error_code"], "OUTPUT_ROOT_REQUIRED")

    def test_dry_run_prints_report(self) -> None:
        rc, out, _ = run_main(multi_ai_cli.main, ["--dry-run", "--include-only", "composer-2.5"])
        self.assertEqual(rc, 0)
        report = json.loads(out)
        self.assertTrue(report["ok"] and report["dry_run"])
        self.assertEqual(report["resolved_count"], 1)

    def test_dry_run_failure_exit_code(self) -> None:
        rc, out, _ = run_main(multi_ai_cli.main, ["--dry-run", "--max-agents", "1"])
        self.assertEqual(rc, 1)
        self.assertEqual(json.loads(out)["error_code"], "MAX_AGENTS_EXCEEDED")

    def test_unsupported_host_blocks_live_dispatch(self) -> None:
        with mock.patch.dict(os.environ, {"CLAUDECODE": "1"}), mock.patch.object(multi_ai_cli, "run_multi_ai_live") as live:
            rc, out, _ = run_main(multi_ai_cli.main, ["--output-root", str(self.tmp / "o")])
        live.assert_not_called()
        self.assertEqual(rc, 2)
        payload = json.loads(out)
        self.assertEqual(payload["error_code"], "SB_MULTI_AI_UNSUPPORTED_HOST")
        self.assertFalse(payload["ok"])
        self.assertFalse((self.tmp / "o").exists())

    def test_stub_mode_blocks_live_dispatch_on_supported_host(self) -> None:
        with mock.patch.dict(os.environ, {"SB_HOST": "cursor", "SB_MULTI_AI_STUB": "1"}), \
                mock.patch.object(multi_ai_cli, "run_multi_ai_live") as live:
            rc, out, _ = run_main(multi_ai_cli.main, ["--output-root", str(self.tmp / "o")])
        live.assert_not_called()
        self.assertEqual(rc, 2)
        self.assertEqual(json.loads(out)["error_code"], "MULTI_AI_LIVE_DISPATCH_NOT_READY")

    def test_live_dispatch_forwards_arguments_and_maps_exit_code(self) -> None:
        argv = [
            "--output-root", str(self.tmp / "o"), "--task-prompt", "TP", "--phase-id", "DR-TRIANGULATE",
            "--ocg-pool", "regular", "--cursor-pool", "none", "--include-only", "ocg-minimax-m3",
            "--exclude", "x", "--cursor-subscription", "subscribed", "--timeout-sec", "33",
        ]
        with mock.patch.dict(os.environ, {"SB_HOST": "cursor"}):
            with mock.patch.object(multi_ai_cli, "run_multi_ai_live", return_value={"ok": True, "run_id": "r"}) as live:
                rc, out, _ = run_main(multi_ai_cli.main, argv)
            kwargs = live.call_args.kwargs
            self.assertEqual((rc, json.loads(out)), (0, {"ok": True, "run_id": "r"}))
            self.assertEqual(kwargs["output_root"], self.tmp / "o")
            self.assertEqual((kwargs["task_prompt"], kwargs["phase_id"], kwargs["timeout_sec"]), ("TP", "DR-TRIANGULATE", 33))
            selection = kwargs["selection"]
            self.assertEqual(
                (selection.ocg_pool, selection.cursor_pool, selection.include_only, selection.exclude, selection.cursor_subscription),
                ("regular", "none", ["ocg-minimax-m3"], ["x"], "subscribed"),
            )
            with mock.patch.object(multi_ai_cli, "run_multi_ai_live", return_value={"ok": False}):
                rc, _, _ = run_main(multi_ai_cli.main, argv)
            self.assertEqual(rc, 1)

    def test_script_entry_point_exit_status(self) -> None:
        with mock.patch.object(sys, "argv", ["multi_ai_cli.py", "--dry-run", "--include-only", "grok-4.5"]):
            with contextlib.redirect_stdout(io.StringIO()) as out, self.assertRaises(SystemExit) as ctx:
                runpy.run_path(str(SCRIPTS / "multi_ai_cli.py"), run_name="__main__")
        self.assertEqual(ctx.exception.code, 0)
        self.assertTrue(json.loads(out.getvalue())["ok"])


class CapabilitySpikeTests(HermeticCase):
    def test_stub_and_live_snapshots(self) -> None:
        stub = capability_spike.build_capabilities_stub()
        self.assertEqual(stub["schema_id"], "backend-capabilities-v1")
        self.assertEqual((stub["backends"]["cursor"]["status"], stub["backends"]["ocg"]["status"]), ("stub", "stub"))
        self.assertIn("stub spike only", stub["backends"]["cursor"]["disable_reason"])
        self.assertIn("stub spike only", stub["backends"]["ocg"]["disable_reason"])
        live = capability_spike.build_capabilities_stub(live=True)
        for name in ("cursor", "ocg"):
            self.assertEqual(live["backends"][name]["status"], "disabled")
            self.assertIsNone(live["backends"][name]["disable_reason"])
            self.assertFalse(live["backends"][name]["evidence"]["cancellation_proven"])

    def test_validate_profile(self) -> None:
        capability_spike.validate_profile("ocg-minimax-m3", "lite")
        capability_spike.validate_profile("ocg-qwen3.7-max", "regular")
        with self.assertRaisesRegex(ValueError, "not in allowlisted lite registry pool"):
            capability_spike.validate_profile("ocg-qwen3.7-max", "lite")
        with self.assertRaisesRegex(ValueError, "allowlisted regular registry pool"):
            capability_spike.validate_profile("nope", "regular")

    def test_main_writes_output_creating_parents(self) -> None:
        target = self.tmp / "deep" / "dir" / "caps.json"
        rc, out, _ = run_main(capability_spike.main, ["--output", str(target), "--live", "--validate-profile", "ocg-mimo-v2.5"])
        self.assertEqual(rc, 0)
        self.assertEqual(json.loads(out), {"ok": True, "output": str(target), "live": True})
        written = json.loads(target.read_text())
        self.assertEqual(written["backends"]["cursor"]["status"], "disabled")
        self.assertTrue(target.read_text().endswith("}\n"))

    def test_main_invalid_profile_writes_nothing(self) -> None:
        target = self.tmp / "caps.json"
        with self.assertRaises(ValueError):
            run_main(capability_spike.main, ["--output", str(target), "--validate-profile", "bogus"])
        self.assertFalse(target.exists())
        with self.assertRaises(ValueError):
            run_main(capability_spike.main, ["--output", str(target), "--validate-profile", "ocg-qwen3.7-max", "--pool", "lite"])
        self.assertFalse(target.exists())
        rc, _, _ = run_main(capability_spike.main, ["--output", str(target), "--validate-profile", "ocg-qwen3.7-max", "--pool", "regular"])
        self.assertEqual(rc, 0)

    def test_script_entry_point(self) -> None:
        target = self.tmp / "e" / "caps.json"
        with mock.patch.object(sys, "argv", ["capability_spike.py", "--output", str(target)]):
            with contextlib.redirect_stdout(io.StringIO()), self.assertRaises(SystemExit) as ctx:
                runpy.run_path(str(SCRIPTS / "capability_spike.py"), run_name="__main__")
        self.assertEqual(ctx.exception.code, 0)
        self.assertTrue(target.is_file())


def launch_request(**overrides: object) -> cha.LaunchRequest:
    base = dict(
        idempotency_key="idem", run_id="run-1", work_item_id="work-1", logical_model_id="composer-2.5",
        attempt_id="att-1", requested_model_id="composer-2.5", effective_model_id="composer-2.5",
        output_root="", deadline="2030-01-01T00:00:00Z", hard_token_ceiling=50_000,
    )
    base.update(overrides)
    return cha.LaunchRequest(**base)  # type: ignore[arg-type]


class CursorHostAdapterTests(HermeticCase):
    def test_live_status_follows_stub_env(self) -> None:
        self.assertEqual(cha.live_status(), "live")
        for value in ("1", "true", "yes"):
            with mock.patch.dict(os.environ, {"SB_MULTI_AI_STUB": value}):
                self.assertEqual(cha.live_status(), "not-live", value)
        with mock.patch.dict(os.environ, {"SB_MULTI_AI_STUB": "off"}):
            self.assertEqual(cha.live_status(), "live")

    def test_import_time_default_tracks_environment(self) -> None:
        with mock.patch.dict(os.environ, {"SB_MULTI_AI_STUB": "1"}):
            reloaded = importlib.reload(cha)
            self.assertEqual(reloaded.LIVE_STATUS, "not-live")
        reloaded = importlib.reload(cha)
        self.assertEqual(reloaded.LIVE_STATUS, "live")

    def test_stubbed_launch_runs_nothing(self) -> None:
        req = launch_request(output_root=str(self.tmp / "never"))
        with mock.patch.dict(os.environ, {"SB_MULTI_AI_STUB": "1"}), mock.patch.object(live_dispatch, "run_cursor_worker") as worker:
            out = cha.launch(req)
        worker.assert_not_called()
        self.assertEqual((out["ok"], out["live_status"], out["error_code"]), (False, "not-live", "CURSOR_HOST_ADAPTER_NOT_LIVE"))
        self.assertEqual(out["handles"], {})
        self.assertEqual(out["launch"]["attempt_id"], "att-1")
        self.assertFalse((self.tmp / "never").exists())

    def _live_launch(self, result: live_dispatch.WorkerResult, **overrides: object):
        out_dir = self.tmp / "nested" / "out"
        req = launch_request(output_root=str(out_dir), **overrides)
        with mock.patch.object(live_dispatch, "run_cursor_worker", return_value=result) as worker:
            return cha.launch(req), worker, out_dir

    def test_live_launch_completed(self) -> None:
        result = live_dispatch.WorkerResult(
            "composer-2.5", "cursor", "a", "completed", None, '{"sources": []}', None, usage={"total_tokens": 7}
        )
        out, worker, out_dir = self._live_launch(result, task_prompt="CUSTOM", phase_id="DR-CRITIQUE", hard_token_ceiling=50_000)
        kwargs = worker.call_args.kwargs
        self.assertEqual((kwargs["prompt"], kwargs["timeout_sec"], kwargs["output_dir"]), ("CUSTOM", 500, out_dir))
        self.assertTrue(out_dir.is_dir())
        self.assertTrue(out["ok"])
        self.assertEqual(out["live_status"], "live")
        self.assertEqual(out["result"]["status"], "completed")
        self.assertEqual(out["result"]["payload"], {"sources": []})
        self.assertEqual(out["result"]["usage"], {"total_tokens": 7})
        self.assertEqual(out["result"]["effective_model_id"], "composer-2.5")
        self.assertIsNone(out["result"]["error"])
        self.assertEqual(out["handles"], {"raw_output": str(out_dir)})

    def test_live_launch_builds_prompt_and_caps_timeout(self) -> None:
        result = live_dispatch.WorkerResult("grok-4.5", "cursor", "a", "failed", None, "", "boom")
        out, worker, _ = self._live_launch(result, logical_model_id="grok-4.5", hard_token_ceiling=10_000_000)
        prompt = worker.call_args.kwargs["prompt"]
        self.assertIn("DR-RETRIEVE phase", prompt)
        self.assertIn("work_item=work-1", prompt)
        self.assertIn("(grok-4.5)", prompt)
        self.assertEqual(worker.call_args.kwargs["timeout_sec"], 900)
        self.assertFalse(out["ok"])
        self.assertEqual(out["result"]["status"], "failed")
        self.assertEqual(out["result"]["error"], "boom")
        self.assertEqual(out["result"]["usage"], {"input_tokens": 0, "output_tokens": 0, "total_tokens": 0})
        self.assertEqual(out["result"]["effective_model_id"], "cursor-grok-4.5-high")

    def test_live_launch_partial_is_ok_but_reported_failed(self) -> None:
        result = live_dispatch.WorkerResult("composer-2.5", "cursor", "a", "partial", None, "", "timeout")
        out, _, _ = self._live_launch(result)
        self.assertTrue(out["ok"])
        self.assertEqual(out["result"]["status"], "failed")

    def test_launch_adds_script_dir_to_sys_path_when_absent(self) -> None:
        result = live_dispatch.WorkerResult("composer-2.5", "cursor", "a", "completed", None, "{}")
        script_dir = str(Path(cha.__file__).resolve().parent)
        trimmed = [p for p in sys.path if p != script_dir]
        with mock.patch.object(sys, "path", trimmed):
            self._live_launch(result)
            self.assertEqual(trimmed[0], script_dir)

    def test_cancel_and_cas(self) -> None:
        live = cha.cancel("a", "k")
        self.assertEqual((live["ok"], live["live_status"], live["child_liveness_verified"]), (True, "live", True))
        with mock.patch.dict(os.environ, {"SB_MULTI_AI_STUB": "1"}):
            stub = cha.cancel("a", "k")
        self.assertEqual((stub["live_status"], stub["child_liveness_verified"], stub["cancellation_acknowledged"]), ("not-live", False, True))
        conflict = cha.cas_select_authoritative_attempt(3, 2, "x")
        self.assertEqual((conflict["ok"], conflict["error_code"], conflict["current_generation"], conflict["expected_generation"]),
                         (False, "CAS_GENERATION_CONFLICT", 3, 2))
        won = cha.cas_select_authoritative_attempt(2, 2, None)
        self.assertEqual((won["ok"], won["generation"], won["authoritative_attempt_id"]), (True, 3, None))

    def test_cli_subcommands(self) -> None:
        rc, out, _ = run_main(cha.main, ["cancel", "--attempt-id", "a1", "--idempotency-key", "k1"])
        self.assertEqual((rc, json.loads(out)["cancellation_acknowledged"]), (0, True))
        rc, out, _ = run_main(cha.main, ["cas", "--current-generation", "1", "--expected-generation", "1", "--authoritative-attempt-id", "a9"])
        self.assertEqual((rc, json.loads(out)["authoritative_attempt_id"], json.loads(out)["generation"]), (0, "a9", 2))
        rc, out, _ = run_main(cha.main, ["cas", "--current-generation", "1", "--expected-generation", "0"])
        self.assertEqual((rc, json.loads(out)["error_code"]), (0, "CAS_GENERATION_CONFLICT"))
        rc, out, _ = run_main(cha.main, ["cas", "--current-generation", "0", "--expected-generation", "0"])
        self.assertIsNone(json.loads(out)["authoritative_attempt_id"])
        payload = {k: v for k, v in launch_request().__dict__.items()}
        with mock.patch.dict(os.environ, {"SB_MULTI_AI_STUB": "1"}):
            rc, out, _ = run_main(cha.main, ["launch", "--request-json", json.dumps(payload)])
        self.assertEqual((rc, json.loads(out)["error_code"]), (0, "CURSOR_HOST_ADAPTER_NOT_LIVE"))

    def test_cli_rejects_bad_input(self) -> None:
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as ctx:
            cha.main([])
        self.assertEqual(ctx.exception.code, 2)
        with self.assertRaises(json.JSONDecodeError):
            run_main(cha.main, ["launch", "--request-json", "{nope"])
        with self.assertRaises(TypeError):
            run_main(cha.main, ["launch", "--request-json", '{"unexpected": 1}'])

    def test_script_entry_point(self) -> None:
        with mock.patch.object(sys, "argv", ["cursor_host_adapter.py", "cancel", "--attempt-id", "a", "--idempotency-key", "k"]):
            with contextlib.redirect_stdout(io.StringIO()), self.assertRaises(SystemExit) as ctx:
                runpy.run_path(str(SCRIPTS / "cursor_host_adapter.py"), run_name="__main__")
        self.assertEqual(ctx.exception.code, 0)


class OcgPoolCohortTests(HermeticCase):
    def setUp(self) -> None:
        super().setUp()
        p = mock.patch.object(oc, "OPENCODE_BIN", "/oc/opencode")
        p.start()
        self.addCleanup(p.stop)
        self.work = self.subdir("work")

    def profile(self, outcome, progress: Path | None = None, logical: str = "ocg-minimax-m3"):
        def fake(cmd, **kwargs):  # noqa: ANN001
            self.captured = (cmd, kwargs)
            if isinstance(outcome, BaseException):
                raise outcome
            return outcome

        with mock.patch.object(oc.subprocess, "run", side_effect=fake), contextlib.redirect_stderr(io.StringIO()) as err:
            result = oc.run_profile(logical_model_id=logical, prompt="P", work_dir=self.work, timeout_sec=4, progress_path=progress)
        self.stderr = err.getvalue()
        return result

    def test_log_writes_stderr_and_optional_file(self) -> None:
        err = io.StringIO()
        with contextlib.redirect_stderr(err):
            oc._log(None, "hello")
            progress = self.tmp / "p.log"
            oc._log(progress, "one")
            oc._log(progress, "two")
        self.assertEqual(err.getvalue().count("\n"), 3)
        lines = progress.read_text().splitlines()
        self.assertEqual(len(lines), 2)
        self.assertTrue(lines[0].endswith("] one") and lines[1].endswith("] two"))
        self.assertTrue(lines[0].startswith("[20"))

    def test_load_request(self) -> None:
        path = self.tmp / "req.json"
        path.write_text('{"a": 1}')
        self.assertEqual(oc.load_request(path), {"a": 1})
        path.write_text("{bad")
        with self.assertRaises(json.JSONDecodeError):
            oc.load_request(path)

    def test_run_profile_success(self) -> None:
        progress = self.tmp / "prog.log"
        out = self.profile(proc_ok('{"a": 1}', "warn"), progress, logical="ocg-kimi-k2.6")
        self.assertEqual((out["status"], out["payload"], out["error"], out["backend"]), ("completed", {"a": 1}, None, "ocg"))
        self.assertEqual(out["effective_model_id"], "opencode-go/kimi-k2.6")
        self.assertEqual(out["raw_output_path"], "ocg-kimi-k2.6-opencode-go-kimi-k2.6.raw.txt")
        self.assertEqual((self.work / out["raw_output_path"]).read_text(), '{"a": 1}\nwarn')
        cmd, kwargs = self.captured
        self.assertEqual(cmd, ["/oc/opencode", "run", "--dir", str(self.work), "-m", "opencode-go/kimi-k2.6", "--auto", "P"])
        self.assertEqual((kwargs["timeout"], kwargs["cwd"]), (4, str(self.work)))
        log = progress.read_text()
        self.assertIn("START ocg-kimi-k2.6", log)
        self.assertIn("DONE ocg-kimi-k2.6 status=completed", log)

    def test_run_profile_truncates_raw_output(self) -> None:
        out = self.profile(proc_ok("x" * 60000 + '{"a": 1}'))
        self.assertEqual(out["status"], "completed")  # the payload follows the noise, so the brace fallback still finds it
        self.assertEqual(len((self.work / out["raw_output_path"]).read_text()), 50000)

    def test_run_profile_completed_without_payload_is_failed(self) -> None:
        out = self.profile(proc_ok("   "))
        self.assertEqual((out["status"], out["payload"], out["error"]), ("failed", {}, "exit 0"))

    def test_run_profile_nonzero_exit(self) -> None:
        out = self.profile(proc_ok('{"a": 1}', "", 7))
        self.assertEqual((out["status"], out["payload"], out["error"]), ("failed", {}, "exit 7"))
        self.assertIn("exit=7", self.stderr)

    def test_run_profile_timeout(self) -> None:
        out = self.profile(subprocess.TimeoutExpired("x", 4))
        self.assertEqual((out["status"], out["error"], out["raw_output_path"], out["payload"]), ("partial", "timeout", "", {}))
        self.assertIn("TIMEOUT ocg-minimax-m3", self.stderr)

    def test_run_profile_missing_cli(self) -> None:
        out = self.profile(FileNotFoundError("opencode"))
        self.assertEqual((out["status"], out["error"], out["elapsed_sec"]), ("failed", "opencode CLI not found", 0))
        self.assertIn("opencode CLI not found", self.stderr)

    def test_run_profile_unknown_model_raises(self) -> None:
        with self.assertRaises(ValueError):
            self.profile(proc_ok("{}"), logical="composer-2.5")

    def test_run_cohort(self) -> None:
        work = self.tmp / "cohort-work"
        outcomes = {
            "ocg-minimax-m3": proc_ok('{"a": 1}'),
            "ocg-mimo-v2.5": proc_ok("", "", 2),
        }

        def fake(cmd, **kwargs):  # noqa: ANN001
            model = cmd[cmd.index("-m") + 1]
            self.prompts = getattr(self, "prompts", []) + [cmd[-1]]
            return outcomes["ocg-" + model.split("/")[1]]

        request = {
            "phase_id": "DR-RETRIEVE", "query": "Q?", "context": json.dumps([{"k": 1, "raw_text": "n"}]),
            "logical_model_ids": ["ocg-minimax-m3", "ocg-mimo-v2.5"], "work_dir": str(work), "timeout_sec": 9999,
            "attempt_id": "att7", "pool": "regular",
        }
        with mock.patch.object(oc.subprocess, "run", side_effect=fake) as run, contextlib.redirect_stderr(io.StringIO()):
            result = oc.run_cohort(request)
        self.assertFalse(result["ok"])
        self.assertEqual(result["schema_id"], "ocg-pool-cohort-result-v1")
        self.assertEqual((result["pool"], result["phase_id"]), ("regular", "DR-RETRIEVE"))
        self.assertEqual([c["status"] for c in result["contributions"]], ["completed", "failed"])
        self.assertEqual(result["progress_log"], "ocg-cohort-progress-att7.log")
        self.assertEqual(result["model_map_keys"], sorted(live_dispatch.OCG_MODEL_MAP))
        # Per-model timeout is clamped to the default.
        self.assertEqual(run.call_args.kwargs["timeout"], oc.DEFAULT_PER_MODEL_TIMEOUT)
        self.assertTrue(all("Do NOT use tools" in p and '"k": 1' in p and "raw_text" not in p for p in self.prompts))
        log = (work / "ocg-cohort-progress-att7.log").read_text()
        self.assertIn("COHORT_START phase=DR-RETRIEVE models=2", log)
        self.assertIn("COHORT_END ok=False completed=1/2", log)

    def test_run_cohort_defaults_and_all_ok(self) -> None:
        request = {"phase_id": "DR-CRITIQUE", "query": "Q", "logical_model_ids": ["ocg-minimax-m3"], "work_dir": str(self.tmp / "w2")}
        with mock.patch.object(oc.subprocess, "run", return_value=proc_ok('{"a": 1}')) as run, contextlib.redirect_stderr(io.StringIO()):
            result = oc.run_cohort(request)
        self.assertTrue(result["ok"])
        self.assertEqual(result["pool"], "lite")
        self.assertEqual(result["progress_log"], "ocg-cohort-progress-run.log")
        self.assertEqual(run.call_args.kwargs["timeout"], oc.DEFAULT_PER_MODEL_TIMEOUT)

    def test_run_cohort_partial_with_payload_is_ok(self) -> None:
        request = {"phase_id": "DR-RETRIEVE", "query": "Q", "logical_model_ids": ["ocg-minimax-m3"], "work_dir": str(self.tmp / "w3")}
        with mock.patch.object(oc, "run_profile", return_value={"status": "partial", "payload": {"p": 1}}), \
                contextlib.redirect_stderr(io.StringIO()):
            self.assertTrue(oc.run_cohort(request)["ok"])
        with mock.patch.object(oc, "run_profile", return_value={"status": "partial", "payload": {}}), \
                contextlib.redirect_stderr(io.StringIO()):
            self.assertFalse(oc.run_cohort(request)["ok"])

    def test_main_stdout_and_output_file(self) -> None:
        req = self.tmp / "req.json"
        req.write_text(json.dumps({"phase_id": "p", "query": "q", "logical_model_ids": ["ocg-minimax-m3"], "work_dir": str(self.tmp / "w4")}))
        with mock.patch.object(oc.subprocess, "run", return_value=proc_ok('{"a": 1}')), contextlib.redirect_stderr(io.StringIO()):
            rc, out, _ = run_main(oc.main, ["--request", str(req)])
            self.assertEqual(rc, 0)
            self.assertTrue(json.loads(out)["ok"])
            target = self.tmp / "result.json"
            rc, out, _ = run_main(oc.main, ["--request", str(req), "--output", str(target)])
            self.assertEqual((rc, out), (0, ""))
            self.assertTrue(json.loads(target.read_text())["ok"])
        with mock.patch.object(oc.subprocess, "run", return_value=proc_ok("", "", 1)), contextlib.redirect_stderr(io.StringIO()):
            rc, out, _ = run_main(oc.main, ["--request", str(req)])
        self.assertEqual(rc, 1)
        self.assertFalse(json.loads(out)["ok"])

    def test_script_entry_point(self) -> None:
        req = self.tmp / "req.json"
        req.write_text(json.dumps({"phase_id": "p", "query": "q", "logical_model_ids": [], "work_dir": str(self.tmp / "w5")}))
        with mock.patch.object(sys, "argv", ["ocg_pool_cohort.py", "--request", str(req)]):
            with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as ctx:
                runpy.run_path(str(SCRIPTS / "ocg_pool_cohort.py"), run_name="__main__")
        # An empty cohort is vacuously ok.
        self.assertEqual(ctx.exception.code, 0)


def proc_ok(stdout: str = "", stderr: str = "", returncode: int = 0) -> mock.Mock:
    return mock.Mock(returncode=returncode, stdout=stdout, stderr=stderr)


if __name__ == "__main__":
    unittest.main()
