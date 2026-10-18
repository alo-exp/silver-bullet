"""Unit tests for scripts/lib/rfl_policy_c.py (real temp run dirs, no clock needed)."""
from __future__ import annotations

import copy
import json
import os
import tempfile
import unittest
from pathlib import Path

from sbtest import load_module

pc = load_module("scripts/lib/rfl_policy_c.py", "rfl_policy_c")
load_module("scripts/lib/rfl_launcher_policy.py", "rfl_launcher_policy")


def valid_payload(**over):
    payload = {
        "schema": "rfl.policy_c.v1",
        "rung_identity": {"family": "gpt", "effort": "high", "display": "GPT High"},
        "verdict": "CLEAN",
        "disposition": "ACCEPT-apply",
        "issues": {"HIGH": "none", "MED": "none", "LOW": "none", "NIT": "none"},
        "triage": "none",
        "blockers": "none",
        "highs": "none",
        "mediums": "none",
        "resolved": "none",
    }
    payload.update(over)
    return payload


class TmpCase(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.tmp = Path(self._tmp.name)
        self.run_dir = self.tmp / "rfl-1"
        self.run_dir.mkdir()

    def write(self, rel, text="x"):
        path = self.run_dir / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        if isinstance(text, (dict, list)):
            text = json.dumps(text)
        path.write_text(text)
        return path

    def rung(self, name="rung-01-gpt", policy=None, review=True, **files):
        d = self.run_dir / name
        d.mkdir(parents=True, exist_ok=True)
        if review:
            (d / "review.md").write_text("review")
        if policy is not None:
            (d / "POLICY-C.json").write_text(json.dumps(policy))
        for fname, content in files.items():
            (d / fname).write_text(content)
        return d

    def status(self, **fields):
        self.write("LADDER-STATUS.json", fields)


class ReadHelpersTest(TmpCase):

    def test_read_json(self):
        self.assertEqual(pc._read_json(self.tmp / "none.json"), {})
        self.assertEqual(pc._read_json(self.tmp), {})  # directory
        self.assertEqual(pc._read_json(self.write("bad.json", "{x")), {})
        self.assertEqual(pc._read_json(self.write("list.json", "[1]")), {})
        self.assertEqual(pc._read_json(self.write("ok.json", '{"a": 1}')), {"a": 1})

    def test_read_json_undecodable_bytes_is_empty(self):
        path = self.run_dir / "bin.json"
        path.write_bytes(b"\xff\xfe\x00")
        self.assertEqual(pc._read_json(path), {})

    def test_is_none_and_as_rows(self):
        for v in ("none", " N/A ", "NA"):
            self.assertTrue(pc._is_none(v), v)
        for v in (None, "", "x", 0, [], ["none"]):
            self.assertFalse(pc._is_none(v), v)
        self.assertEqual(pc._as_rows("none"), [])
        self.assertEqual(pc._as_rows([{"a": 1}]), [{"a": 1}])
        self.assertEqual(pc._as_rows([]), [])
        self.assertIsNone(pc._as_rows([{"a": 1}, "x"]))
        self.assertIsNone(pc._as_rows("something"))
        self.assertIsNone(pc._as_rows(None))
        self.assertIsNone(pc._as_rows({"a": 1}))

    def test_require_none_or_rows(self):
        errs = []
        self.assertEqual(pc._require_none_or_rows({}, "k", errs), [])
        self.assertEqual(errs, ["missing k none-row"])
        errs = []
        self.assertEqual(pc._require_none_or_rows({"k": []}, "k", errs), [])
        self.assertEqual(errs, ["k empty list omitted none-row"])
        errs = []
        self.assertEqual(pc._require_none_or_rows({"k": "bogus"}, "k", errs), [])
        self.assertEqual(errs, ['k must be "none" or a non-empty list'])
        errs = []
        self.assertEqual(pc._require_none_or_rows({"k": "none"}, "k", errs), [])
        self.assertEqual(pc._require_none_or_rows({"k": [{"a": 1}]}, "k", errs), [{"a": 1}])
        self.assertEqual(errs, [])

    def test_paths_and_ladder_status_io(self):
        j, m = pc.policy_c_paths(str(self.tmp))
        self.assertEqual((j.name, m.name), ("POLICY-C.json", "POLICY-C.md"))
        self.assertEqual(pc.ladder_status_path(self.tmp).name, "LADDER-STATUS.json")
        self.assertEqual(pc.load_ladder_status(self.tmp / "nope"), {})
        target = self.tmp / "deep" / "run"
        path = pc.write_ladder_status(target, {"a": 1})
        self.assertEqual(path, target / "LADDER-STATUS.json")
        self.assertEqual(path.read_text(), '{\n  "a": 1\n}\n')
        self.assertEqual(pc.load_ladder_status(target), {"a": 1})


class StreakTest(TmpCase):

    def test_bucket_key(self):
        self.assertEqual(pc._rung_bucket_key("rung-03-x"), "rung_3")
        self.assertEqual(pc._rung_bucket_key(" RUNG-007"), "rung_7")
        self.assertEqual(pc._rung_bucket_key("other"), "")
        self.assertEqual(pc._rung_bucket_key(None), "")

    def test_triage_accept_count_and_clean(self):
        self.assertEqual(pc._triage_accept_count(None), 0)
        self.assertEqual(pc._triage_accept_count({}), 0)
        self.assertEqual(pc._triage_accept_count({"triage": "none"}), 0)
        self.assertEqual(pc._triage_accept_count({"triage": "bogus"}), 0)
        self.assertEqual(pc._triage_accept_count({"triage": [
            {"decision": "accept"}, {"decision": "REJECT"}, {"decision": "ACCEPT"}, {}]}), 2)
        self.assertFalse(pc.review_pass_is_clean(None))
        self.assertFalse(pc.review_pass_is_clean({}))
        self.assertTrue(pc.review_pass_is_clean({"verdict": "CLEAN"}))
        self.assertTrue(pc.review_pass_is_clean({"verdict": "NOT_CLEAN",
                                                 "triage": [{"decision": "REJECT"}]}))
        self.assertFalse(pc.review_pass_is_clean({"triage": [{"decision": "ACCEPT"}]}))
        for verdict in ("blocked", "SKIPPED", "Blocked"):
            self.assertFalse(pc.review_pass_is_clean({"verdict": verdict}), verdict)

    def test_stored_streak_top_level_field(self):
        f = pc._stored_streak_for_rung
        self.assertEqual(f({"consecutive_clean_reviews": 3, "consecutive_clean_rung": "r"}, "r"), 3)
        self.assertEqual(f({"consecutive_clean_reviews": "2", "current_rung": "r"}, "r"), 2)
        self.assertEqual(f({"consecutive_clean_reviews": -4, "current_rung": "r"}, "r"), 0)
        self.assertEqual(f({"consecutive_clean_reviews": "x", "current_rung": "r"}, "r"), 0)
        self.assertEqual(f({"consecutive_clean_reviews": [1], "current_rung": "r"}, "r"), 0)
        # field set for a different rung -> not used
        self.assertEqual(f({"consecutive_clean_reviews": 3, "consecutive_clean_rung": "other"}, "r"), 0)
        # no field -> not used
        self.assertEqual(f({"consecutive_clean_rung": "r"}, "r"), 0)
        # blank rid never matches the top-level field
        self.assertEqual(f({"consecutive_clean_reviews": 3, "current_rung": ""}, ""), 0)

    def test_stored_streak_bucket_and_rungs_list(self):
        f = pc._stored_streak_for_rung
        self.assertEqual(f({"rung_2": {"consecutive_clean_reviews": 1}}, "rung-02-x"), 1)  # leading zeros
        self.assertEqual(f({"rung_2": {"consecutive_clean_reviews": 1}}, "rung-3-x"), 0)  # wrong bucket
        self.assertEqual(f({"rung_2": {"consecutive_clean_reviews": 1}}, "rung-2-x"), 1)
        self.assertEqual(f({"rung_2": {"consecutive_clean_reviews": "bad"}}, "rung-2"), 0)
        self.assertEqual(f({"rung_2": {"consecutive_clean_reviews": None}}, "rung-2"), 0)
        self.assertEqual(f({"rung_2": {"consecutive_clean_reviews": -1}}, "rung-2"), 0)
        # non-dict bucket falls through to the rungs list
        st = {"rung_2": "oops", "rungs": ["junk", {"id": "rung-2", "consecutive_clean_reviews": 2}]}
        self.assertEqual(f(st, "rung-2"), 2)
        st = {"rungs": [{"id": "rung-2", "consecutive_clean_reviews": "x"}]}
        self.assertEqual(f(st, "rung-2"), 0)
        st = {"rungs": [{"id": "other", "consecutive_clean_reviews": 5}]}
        self.assertEqual(f(st, "rung-2"), 0)
        self.assertEqual(f({"rungs": "notalist"}, "rung-2"), 0)
        self.assertEqual(f({}, "plain"), 0)
        # bucket TypeError (list value) is swallowed and falls through to rungs
        st = {"rung_2": {"consecutive_clean_reviews": [1]},
              "rungs": [{"id": "rung-2", "consecutive_clean_reviews": 4}]}
        self.assertEqual(f(st, "rung-2"), 4)

    def test_get_consecutive_clean_reviews(self):
        g = pc.get_consecutive_clean_reviews
        self.assertEqual(g({"consecutive_clean_reviews": 5}), 5)
        self.assertEqual(g({"consecutive_clean_reviews": "x"}), 0)
        self.assertEqual(g({"consecutive_clean_reviews": None}), 0)
        self.assertEqual(g({"consecutive_clean_reviews": -2}), 0)
        self.assertEqual(g({"consecutive_clean_reviews": 5, "current_rung": "r"}), 5)
        self.assertEqual(g({"consecutive_clean_reviews": 5, "current_rung": "r"}, "z"), 0)
        self.assertEqual(g({"rung_1": {"consecutive_clean_reviews": 2}}, "rung-1"), 2)

    def test_mirror_streak(self):
        st = {"rungs": ["x", {"id": "other"}, {"id": "rung-1"}, {"id": "rung-1", "n": 1}]}
        pc._mirror_streak(st, "rung-1", 2)
        self.assertEqual(st["consecutive_clean_reviews"], 2)
        self.assertEqual(st["consecutive_clean_rung"], "rung-1")
        self.assertEqual(st["rung_1"], {"consecutive_clean_reviews": 2})
        self.assertEqual(st["rungs"][2]["consecutive_clean_reviews"], 2)
        self.assertNotIn("consecutive_clean_reviews", st["rungs"][3])  # first match only
        self.assertNotIn("consecutive_clean_reviews", st["rungs"][1])
        st = {"rung_1": "notadict"}
        pc._mirror_streak(st, "rung-1", 1)
        self.assertEqual(st["rung_1"], {"consecutive_clean_reviews": 1})
        st = {"rung_1": {"keep": 1}}
        pc._mirror_streak(st, "rung-1", 0)
        self.assertEqual(st["rung_1"], {"keep": 1, "consecutive_clean_reviews": 0})
        st = {"rungs": [{"id": "other"}, "junk"]}
        pc._mirror_streak(st, "rung-9", 1)
        self.assertEqual(st["rungs"], [{"id": "other"}, "junk"])
        st = {"rungs": "x"}
        pc._mirror_streak(st, "", 3)
        self.assertEqual(st, {"rungs": "x", "consecutive_clean_reviews": 3})
        st = {}
        pc._mirror_streak(st, None, 1)
        self.assertEqual(st, {"consecutive_clean_reviews": 1})

    def test_record_outcome_sequence(self):
        r = pc.record_rung_review_outcome(self.run_dir, "clean", rung_id="rung-1-gpt")
        self.assertEqual((r["consecutive_clean_reviews"], r["outcome"], r["rung_id"], r["required"]),
                         (1, "clean", "rung-1-gpt", 2))
        r = pc.record_rung_review_outcome(self.run_dir, " CLEAN ", rung_id="rung-1-gpt")
        self.assertEqual(r["consecutive_clean_reviews"], 2)
        self.assertEqual(r["path"], str(self.run_dir / "LADDER-STATUS.json"))
        r = pc.record_rung_review_outcome(self.run_dir, "accept_apply", rung_id="rung-1-gpt")
        self.assertEqual((r["consecutive_clean_reviews"], r["outcome"]), (0, "accept-apply"))
        for outcome in ("reset", "Accept-Apply"):
            r = pc.record_rung_review_outcome(self.run_dir, outcome, rung_id="rung-1-gpt")
            self.assertEqual((r["consecutive_clean_reviews"], r["outcome"]), (0, "accept-apply"))
        stored = pc.load_ladder_status(self.run_dir)
        self.assertEqual(stored["consecutive_clean_reviews"], 0)

    def test_record_outcome_uses_current_rung_and_new_rung_restarts(self):
        self.status(current_rung="rung-2-x", consecutive_clean_reviews=1,
                    consecutive_clean_rung="rung-2-x", keep="me")
        r = pc.record_rung_review_outcome(self.run_dir, "clean")
        self.assertEqual((r["rung_id"], r["consecutive_clean_reviews"]), ("rung-2-x", 2))
        r = pc.record_rung_review_outcome(self.run_dir, "clean", rung_id="rung-3-y")
        self.assertEqual(r["consecutive_clean_reviews"], 1)  # streak is per-rung
        self.assertEqual(pc.load_ladder_status(self.run_dir)["keep"], "me")

    def test_record_outcome_invalid(self):
        for bad in ("", None, "dirty", "clean!"):
            with self.assertRaisesRegex(ValueError, "unsupported review outcome"):
                pc.record_rung_review_outcome(self.run_dir, bad)
        self.assertFalse((self.run_dir / "LADDER-STATUS.json").exists())


class RungDirTest(TmpCase):

    def test_discover_active_runs(self):
        root = self.tmp / "proj"
        self.assertEqual(pc.discover_active_rfl_runs(root), [])
        (root / ".planning").mkdir(parents=True)
        self.assertEqual(pc.discover_active_rfl_runs(root), [])
        for name, status in (("rfl-b", "active"), ("rfl-a", " ACTIVE "), ("rfl-c", "completed"),
                             ("rfl-d", None), ("other", "active")):
            d = root / ".planning" / name
            d.mkdir()
            if status is not None:
                (d / "LADDER-STATUS.json").write_text(json.dumps({"status": status}))
        (root / ".planning" / "rfl-e").mkdir()
        (root / ".planning" / "rfl-e" / "LADDER-STATUS.json").write_text("{bad")
        found = pc.discover_active_rfl_runs(root)
        self.assertEqual([p.name for p in found], ["rfl-a", "rfl-b"])

    def test_list_rung_dirs(self):
        self.assertEqual(pc.list_rung_dirs(self.tmp / "none"), [])
        for name in ("rung-02-b", "rung-01-a", "RUNG-3", "rung-x", "notes"):
            (self.run_dir / name).mkdir()
        (self.run_dir / "rung-09-file").write_text("f")
        self.assertEqual([p.name for p in pc.list_rung_dirs(self.run_dir)],
                         ["RUNG-3", "rung-01-a", "rung-02-b"])

    def test_resolve_explicit_dir_or_name(self):
        a = self.rung("rung-01-a")
        self.assertEqual(pc.resolve_rung_dir(self.run_dir, a), a)
        self.assertEqual(pc.resolve_rung_dir(self.run_dir, "rung-01-a"), a)
        self.assertEqual(pc.resolve_rung_dir(self.run_dir, str(a)), a)
        # unknown explicit value falls through to the other strategies
        self.assertEqual(pc.resolve_rung_dir(self.run_dir, "ghost"), a)

    def test_resolve_from_status(self):
        a = self.rung("rung-01-a")
        b = self.rung("rung-02-b", review=False)
        self.status(current_rung="rung-01-a")
        self.assertEqual(pc.resolve_rung_dir(self.run_dir), a)
        self.status(current_rung=str(b))
        self.assertEqual(pc.resolve_rung_dir(self.run_dir), b)
        self.status(current_rung="2")
        self.assertEqual(pc.resolve_rung_dir(self.run_dir), b)
        c = self.rung("rung-3-c")
        self.status(current_rung="3")
        self.assertEqual(pc.resolve_rung_dir(self.run_dir), c)
        # relative path resolved against the process cwd (not the run dir)
        elsewhere = self.tmp / "elsewhere" / "rung-77-z"
        elsewhere.mkdir(parents=True)
        self.status(current_rung="elsewhere/rung-77-z")
        old = os.getcwd()
        os.chdir(self.tmp)
        try:
            self.assertEqual(pc.resolve_rung_dir(self.run_dir), Path("elsewhere/rung-77-z"))
        finally:
            os.chdir(old)
        self.status(current_rung="9")  # no such rung -> fallback heuristics
        self.assertEqual(pc.resolve_rung_dir(self.run_dir), a)
        self.status(current_rung="ghost")
        self.assertEqual(pc.resolve_rung_dir(self.run_dir), a)

    def test_resolve_prefers_review_without_policy_then_last(self):
        a = self.rung("rung-01-a", policy={"x": 1})
        b = self.rung("rung-02-b", review=True)
        c = self.rung("rung-03-c", review=False)
        self.assertEqual(pc.resolve_rung_dir(self.run_dir), b)
        (b / "POLICY-C.json").write_text("{}")
        self.assertEqual(pc.resolve_rung_dir(self.run_dir), c)
        self.assertIsNone(pc.resolve_rung_dir(self.tmp / "empty-run"))
        self.assertTrue(a.is_dir())

    def test_small_path_helpers(self):
        d = self.rung("rung-01-a")
        self.assertTrue(pc.review_returned(d))
        self.assertFalse(pc.review_returned(self.run_dir))
        self.assertEqual(pc.policy_c_json_path(d), d / "POLICY-C.json")
        self.assertIsNone(pc._first_existing(d, ("a.md", "b.md")))
        (d / "a.md").write_text("")
        self.assertIsNone(pc._first_existing(d, ("a.md",)))
        (d / "b.md").write_text("x")
        self.assertEqual(pc._first_existing(d, ("a.md", "b.md")), d / "b.md")
        self.assertTrue(pc._file_nonempty(d / "b.md"))
        self.assertFalse(pc._file_nonempty(d / "a.md"))
        self.assertFalse(pc._file_nonempty(d / "none.md"))

    def test_phase_and_normalizers(self):
        for phase in ("rung_1_fix_parallel", "RUNG_2_FIX", "fix"):
            self.assertTrue(pc._phase_is_fix_parallel(phase), phase)
        for phase in (None, "", "rung_1_verify_1", "prefix_x"):
            self.assertFalse(pc._phase_is_fix_parallel(phase), phase)
        for raw in ("reject", "REJECT_as_wrong", "reject as wrong", " Reject-As-Wrong "):
            self.assertEqual(pc._normalize_decision(raw), "REJECT-as-wrong", raw)
        self.assertEqual(pc._normalize_decision(" accept "), "ACCEPT")
        self.assertEqual(pc._normalize_decision(" hold "), "hold")
        self.assertEqual(pc._normalize_decision(None), "")
        self.assertTrue(pc._effort_ok(" High "))
        self.assertTrue(pc._effort_ok("extra-high"))
        self.assertFalse(pc._effort_ok("ultra"))


class ValidateTest(unittest.TestCase):
    def v(self, payload=None, **kw):
        return pc.validate_policy_c(payload if payload is not None else valid_payload(), **kw)

    def mutate(self, **over):
        payload = valid_payload()
        for key, value in over.items():
            if value is KeyError:
                payload.pop(key, None)
            else:
                payload[key] = value
        return payload

    def test_valid_payload_has_no_errors(self):
        self.assertEqual(self.v(), [])
        self.assertEqual(self.v(self.mutate(schema=KeyError)), [])  # schema optional

    def test_schema(self):
        self.assertEqual(self.v(self.mutate(schema="other.v2")),
                         ["unsupported schema 'other.v2'"])

    def test_rung_identity(self):
        self.assertEqual(self.v(self.mutate(rung_identity="x")), [
            "missing rung_identity", "rung_identity.family required",
            "rung_identity.effort must be High / Extra High / Max / medium / low",
            "rung_identity.display required"])
        errs = self.v(self.mutate(rung_identity={"family": "g", "effort": "ultra", "display": "D"}))
        self.assertEqual(errs, ["rung_identity.effort must be High / Extra High / Max / medium / low"])
        errs = self.v(self.mutate(rung_identity={"family": "g", "reasoning": "xhigh", "display": "D"}))
        self.assertEqual(errs, [])

    def test_verdict_and_disposition(self):
        self.assertEqual(self.v(self.mutate(verdict="NOT_CLEAN")), [])
        self.assertEqual(self.v(self.mutate(verdict="clean")), [])
        self.assertEqual(self.v(self.mutate(verdict="MAYBE")),
                         ["verdict must be CLEAN | NOT CLEAN | BLOCKED | SKIPPED"])
        self.assertEqual(self.v(self.mutate(disposition="accept-apply")),
                         ["disposition must be ACCEPT-apply | REJECT-as-wrong | HOLD | SKIP"])
        self.assertEqual(self.v(self.mutate(verdict=KeyError)),
                         ["verdict must be CLEAN | NOT CLEAN | BLOCKED | SKIPPED"])

    def test_blocked_and_skipped_dispositions(self):
        self.assertEqual(self.v(self.mutate(verdict="BLOCKED", disposition="HOLD")), [])
        self.assertEqual(self.v(self.mutate(verdict="BLOCKED", disposition="SKIP")), [])
        self.assertEqual(self.v(self.mutate(verdict="BLOCKED", disposition="ACCEPT-apply")),
                         ["BLOCKED requires HOLD (or SKIP) disposition"])
        self.assertEqual(self.v(self.mutate(verdict="SKIPPED", disposition="SKIP")), [])
        self.assertEqual(self.v(self.mutate(verdict="SKIPPED", disposition="HOLD")),
                         ["SKIPPED requires SKIP disposition"])

    def test_issues(self):
        self.assertEqual(self.v(self.mutate(issues="x"))[:1],
                         ["issues must be an object with HIGH/MED/LOW/NIT"])
        errs = self.v(self.mutate(issues={"HIGH": [], "MED": "bogus", "LOW": "none"}))
        self.assertEqual(errs, ["HIGH empty list omitted none-row",
                                'MED must be "none" or a non-empty list', "missing NIT none-row"])
        ok = self.mutate(issues={"HIGH": [{"id": "H1"}], "MED": "n/a", "LOW": "none", "NIT": "NA"},
                         triage=[{"id": "H1", "decision": "ACCEPT"}])
        self.assertEqual(self.v(ok), [])

    def test_triage(self):
        self.assertEqual(self.v(self.mutate(triage=KeyError)), ["missing triage"])
        self.assertEqual(self.v(self.mutate(triage=[])), ["triage empty list omitted none-row"])
        self.assertEqual(self.v(self.mutate(triage="bogus")),
                         ['triage must be "none" or a non-empty list'])
        findings = {"HIGH": [{"id": "H1"}], "MED": "none", "LOW": "none", "NIT": "none"}
        self.assertEqual(self.v(self.mutate(issues=findings, triage="n/a")),
                         ["triage n/a only when there are no findings"])
        rows = [{"id": "a", "decision": "hold"}, {"id": "b", "decision": "reject"},
                {"id": "c", "decision": "REJECT-as-wrong", "reason": "  "},
                {"id": "d", "decision": "reject", "reason": "because"},
                {"id": "e", "decision": "accept"}]
        errs = self.v(self.mutate(triage=rows))
        self.assertEqual(errs, [
            "triage decision must be ACCEPT or REJECT-as-wrong",
            "REJECT-as-wrong requires reason", "REJECT-as-wrong requires reason"])

    def test_group_keys(self):
        for key in ("blockers", "highs", "mediums"):
            self.assertEqual(self.v(self.mutate(**{key: KeyError})), [f"missing {key} none-row"])
            self.assertEqual(self.v(self.mutate(**{key: []})), [f"{key} empty list omitted none-row"])
            self.assertEqual(self.v(self.mutate(**{key: [{"id": "x"}]})), [])

    def test_resolved_pending_rules(self):
        msg = "resolved pending only allowed during rung_N_fix_parallel"
        self.assertEqual(self.v(self.mutate(resolved="pending"), current_phase="rung_1_fix_parallel"), [])
        self.assertEqual(self.v(self.mutate(resolved="pending")), [msg])
        self.assertEqual(self.v(self.mutate(resolved="pending"), current_phase="rung_1_fix_parallel",
                                require_resolved_complete=True), [msg])
        rows = [{"id": "a", "resolved": "pending"}]
        self.assertEqual(self.v(self.mutate(resolved=rows), current_phase="x_fix"), [])
        self.assertEqual(self.v(self.mutate(resolved=rows), current_phase="x"), [msg])
        self.assertEqual(self.v(self.mutate(resolved=rows), current_phase="x_fix",
                                require_resolved_complete=True),
                         [msg, "resolved table incomplete before next-rung review"])

    def test_resolved_shapes_and_completeness(self):
        self.assertEqual(self.v(self.mutate(resolved="bogus")),
                         ['resolved must be "none" or a non-empty list'])
        self.assertEqual(self.v(self.mutate(resolved=[])), ["resolved empty list omitted none-row"])
        self.assertEqual(self.v(self.mutate(resolved=None)),
                         ['resolved must be "none" or a non-empty list'])
        done = [{"id": "a", "resolved": "yes"}, {"id": "b", "resolved": "n/a"}]
        self.assertEqual(self.v(self.mutate(resolved=done), require_resolved_complete=True), [])
        for flag in ("", "no", None):
            errs = self.v(self.mutate(resolved=[{"id": "a", "resolved": flag}]),
                          require_resolved_complete=True)
            self.assertEqual(errs, ["resolved table incomplete before next-rung review"], flag)
        self.assertEqual(self.v(self.mutate(resolved=[{"id": "a", "resolved": "no"}])), [])

    def test_resolved_required_for_accept_apply_with_findings(self):
        findings = {"HIGH": [{"id": "H1"}], "MED": "none", "LOW": "none", "NIT": "none"}
        base = self.mutate(issues=findings, triage=[{"id": "H1", "decision": "ACCEPT"}],
                           resolved=KeyError)
        self.assertEqual(self.v(base), [])
        self.assertEqual(self.v(base, require_resolved_complete=True),
                         ["resolved table required before next-rung review"])
        base["disposition"] = "REJECT-as-wrong"
        self.assertEqual(self.v(base, require_resolved_complete=True), [])
        nofind = self.mutate(resolved=KeyError)
        self.assertEqual(self.v(nofind, require_resolved_complete=True), [])


class RenderAndWriteTest(TmpCase):

    def test_render_markdown_full(self):
        payload = valid_payload(
            issues={"HIGH": [{"id": "H1", "title": "Bad thing"}], "MED": "none",
                    "LOW": [{"id": "L1"}], "NIT": "n/a"},
            triage=[{"id": "H1", "severity": "high", "decision": "accept", "reason": "valid"},
                    {"id": "L1", "severity": "low", "decision": "reject", "reason": "wrong"}],
            blockers=[{"id": "B1"}, {"title": "T only"}, {"other": 1}],
            highs="none",
            resolved=[{"id": "H1", "severity": "high", "title": "Bad thing",
                       "decision": "ACCEPT", "resolved": True}],
        )
        md = pc.render_policy_c_md(payload)
        self.assertTrue(md.startswith("# Policy C — GPT High\n\n"))
        self.assertTrue(md.endswith("\n"))
        self.assertIn("- **Rung identity:** GPT High (`gpt` / `high`)\n", md)
        self.assertIn("- **Verdict:** CLEAN\n- **Disposition:** ACCEPT-apply\n", md)
        self.assertIn("- **Blockers:**\n  - B1\n  - T only\n  - {'other': 1}\n", md)
        self.assertIn("- **Highs:** none\n", md)
        self.assertIn("- **Mediums:** none\n", md)
        self.assertIn("| H1 | Bad thing |", md)
        self.assertIn("| L1 |  |", md)
        self.assertIn("| H1 | HIGH | ACCEPT | valid |", md)
        self.assertIn("| L1 | LOW | REJECT-AS-WRONG | wrong |", md)
        self.assertIn("| H1 | HIGH | Bad thing | ACCEPT | yes |", md)

    def test_render_markdown_defaults_and_invalid_shapes(self):
        md = pc.render_policy_c_md({"rung_identity": "x", "issues": "x", "triage": [1, {"id": "a"}],
                                    "resolved": "pending", "blockers": [1], "highs": "bogus"})
        self.assertIn("# Policy C — unknown rung", md)
        self.assertIn("(`unknown` / `unknown`)", md)
        self.assertIn("- **Verdict:** \n", md)
        self.assertIn("- **Blockers:** none\n", md)  # mixed list -> invalid -> none
        self.assertIn("- **Highs:** none\n", md)
        self.assertIn("- **Mediums:** none\n", md)  # key missing -> default none
        self.assertIn("| — | LOW | pending APPLY | ACCEPT | pending |", md)
        self.assertEqual(md.count("**none**"), 5)
        md = pc.render_policy_c_md({"rung_identity": {"family": "f", "reasoning": "r", "display": "D"},
                                    "resolved": "bogus"})
        self.assertIn("(`f` / `r`)", md)
        self.assertIn("| — | — | — | — | **none** |", md)

    def test_write_policy_c_valid_and_defaults_schema(self):
        rung = self.tmp / "rungs" / "rung-01"
        payload = valid_payload(schema=None)
        del payload["schema"]
        before = copy.deepcopy(payload)
        res = pc.write_policy_c(rung, payload)
        self.assertEqual(payload, before)  # input not mutated
        self.assertTrue(res["ok"])
        self.assertEqual(res["errors"], [])
        data = json.loads((rung / "POLICY-C.json").read_text())
        self.assertEqual(data["schema"], "rfl.policy_c.v1")
        self.assertEqual((rung / "POLICY-C.md").read_text(), res["markdown"])
        self.assertEqual(res["json_path"], str(rung / "POLICY-C.json"))
        self.assertEqual(res["payload"], data)

    def test_write_policy_c_invalid_is_still_written_but_reported(self):
        rung = self.tmp / "r"
        res = pc.write_policy_c(rung, {"verdict": "CLEAN"})
        self.assertFalse(res["ok"])
        self.assertIn("missing rung_identity", res["errors"])
        self.assertTrue((rung / "POLICY-C.json").is_file())
        res = pc.write_policy_c(rung, valid_payload(resolved="pending"),
                                current_phase="rung_1_fix_parallel")
        self.assertTrue(res["ok"])
        res = pc.write_policy_c(rung, valid_payload(resolved="pending"))
        self.assertFalse(res["ok"])

    def test_load_policy_c(self):
        rung = self.rung(review=False)
        self.assertIsNone(pc.load_policy_c(rung))
        (rung / "POLICY-C.json").write_text("{}")
        self.assertIsNone(pc.load_policy_c(rung))
        (rung / "POLICY-C.json").write_text("{bad")
        self.assertIsNone(pc.load_policy_c(rung))
        (rung / "POLICY-C.json").write_text('{"a": 1}')
        self.assertEqual(pc.load_policy_c(rung), {"a": 1})

    def test_assert_policy_c(self):
        rung = self.rung(review=False)
        res = pc.assert_policy_c(rung)
        self.assertFalse(res["ok"])
        self.assertEqual(res["errors"], ["missing POLICY-C.json", "missing POLICY-C.md"])
        self.assertEqual(res["payload"], {})
        (rung / "POLICY-C.json").write_text("{bad")
        (rung / "POLICY-C.md").write_text("md")
        res = pc.assert_policy_c(rung)
        self.assertEqual(res["errors"], ["POLICY-C.json invalid or empty"])
        pc.write_policy_c(rung, valid_payload(resolved="pending"))
        res = pc.assert_policy_c(rung, current_phase="rung_1_fix_parallel")
        self.assertEqual((res["ok"], res["errors"]), (True, []))
        self.assertEqual(res["rung_dir"], str(rung))
        res = pc.assert_policy_c(rung, current_phase="rung_1_fix_parallel",
                                 require_resolved_complete=True)
        self.assertEqual(res["errors"], ["resolved pending only allowed during rung_N_fix_parallel"])
        (rung / "POLICY-C.md").unlink()
        self.assertEqual(
            pc.assert_policy_c(rung, current_phase="x_fix")["errors"], ["missing POLICY-C.md"])


class QuotaAndInferTest(TmpCase):

    def test_quota_classify_ok(self):
        rung = self.rung(review=False)
        self.assertEqual(pc._quota_classify_ok(rung), ["missing QUOTA-CLASSIFY.json"])
        q = rung / "QUOTA-CLASSIFY.json"
        q.write_text("{}")
        self.assertEqual(pc._quota_classify_ok(rung), [
            "QUOTA-CLASSIFY.json missing should_schedule", "QUOTA-CLASSIFY.json missing quota_class"])
        q.write_text('{"should_schedule": false}')
        self.assertEqual(pc._quota_classify_ok(rung), ["QUOTA-CLASSIFY.json missing quota_class"])
        q.write_text('{"should_schedule": false, "quota_class": null}')
        self.assertEqual(pc._quota_classify_ok(rung), [])

    def test_blocked_needs_quota(self):
        rung = self.rung(review=False)
        self.assertFalse(pc._blocked_needs_quota(rung, {}))
        self.assertTrue(pc._blocked_needs_quota(rung, {"quota": True}))
        self.assertFalse(pc._blocked_needs_quota(rung, {"quota": "yes"}))
        b = rung / "BLOCKED.md"
        b.write_text("model crashed")
        self.assertFalse(pc._blocked_needs_quota(rung, {}))
        for text in ("HTTP 429", "usage limit hit", "Rate_Limit", "insufficient funds", "401"):
            b.write_text(text)
            self.assertTrue(pc._blocked_needs_quota(rung, {}), text)

    def test_blocked_needs_quota_undecodable_file_is_not_fatal(self):
        rung = self.rung(review=False)
        (rung / "BLOCKED.md").write_bytes(b"\xff\xfe\x00")
        self.assertFalse(pc._blocked_needs_quota(rung, {}))

    def test_infer_next_action(self):
        i = pc.infer_next_action
        self.assertEqual(i("run Verify-2 now"), "verify_2")
        self.assertEqual(i("rung_N_verify_2"), "verify_2")
        self.assertEqual(i("x", "verify_1"), "verify_1")
        self.assertEqual(i("do verify-1"), "verify_1")
        self.assertEqual(i("start the next rung"), "next_rung_review")
        self.assertEqual(i("rung_n+1_review"), "next_rung_review")
        self.assertEqual(i("n+1_review"), "next_rung_review")
        self.assertEqual(i("mark-ladder-status completed"), "mark_completed")
        self.assertEqual(i("mark_ladder_status"), "mark_completed")
        self.assertEqual(i("", "Stop"), "stop")
        self.assertEqual(i("something", "other"), "task")
        self.assertEqual(i(), "task")
        # verify_2 outranks verify_1 and next rung
        self.assertEqual(i("verify_1 verify_2 next rung"), "verify_2")
        self.assertEqual(i("verify_1 next rung"), "verify_1")


FINDINGS = {"HIGH": [{"id": "H1", "title": "t"}], "MED": "none", "LOW": "none", "NIT": "none"}


class SkippedAndStreakAssertTest(TmpCase):

    def test_skipped_allows_advance(self):
        rung = self.rung(review=False)
        f = pc._skipped_allows_advance
        self.assertFalse(f(rung, {"verdict": "CLEAN"}))
        self.assertFalse(f(rung, {"verdict": "SKIPPED"}))  # no SKIPPED.md
        (rung / "SKIPPED.md").write_text("")
        self.assertFalse(f(rung, {"verdict": "SKIPPED"}))
        (rung / "SKIPPED.md").write_text("why")
        self.assertTrue(f(rung, {"verdict": "skipped"}))
        self.assertTrue(f(rung, {"disposition": "SKIP"}))
        self.assertFalse(f(rung, {"disposition": "HOLD"}))

    def call(self, status, action, rung_dir=None):
        return pc._assert_consecutive_clean_reviews(
            self.run_dir, status, action=action, rung_dir=rung_dir)

    def test_other_actions_not_checked(self):
        self.rung()
        for action in ("task", "verify_1", "verify_2", "stop"):
            self.assertEqual(self.call({}, action), [], action)

    def test_no_rung_to_check(self):
        self.assertEqual(self.call({}, "next_rung_review"), [])
        # status passed in names a directory even though the run dir has no rungs
        other = self.tmp / "elsewhere"
        other.mkdir()
        errs = self.call({"current_rung": str(other)}, "next_rung_review")
        self.assertEqual(len(errs), 1)
        self.assertIn("consecutive_clean_reviews=0 < 2", errs[0])

    def test_streak_threshold(self):
        self.rung("rung-01-a", policy=valid_payload())
        errs = self.call({"current_rung": "rung-01-a", "consecutive_clean_reviews": 1},
                         "next_rung_review")
        self.assertEqual(len(errs), 1)
        self.assertTrue(errs[0].startswith("consecutive_clean_reviews=1 < 2; do not start"))
        self.assertIn("--record-rung-review-outcome clean|accept-apply", errs[0])
        self.assertEqual(self.call({"current_rung": "rung-01-a",
                                    "consecutive_clean_reviews": 2}, "next_rung_review"), [])
        self.assertEqual(self.call({"current_rung": "rung-01-a",
                                    "consecutive_clean_reviews": 9}, "mark_completed"), [])
        # without current_rung the resolved directory name is the rung id
        self.assertEqual(len(self.call({}, "mark_completed")), 1)

    def test_skip_with_artifact_allows_advance(self):
        rung = self.rung("rung-01-a", policy=valid_payload(verdict="SKIPPED", disposition="SKIP"))
        self.assertEqual(len(self.call({}, "next_rung_review")), 1)
        (rung / "SKIPPED.md").write_text("skipped")
        self.assertEqual(self.call({}, "next_rung_review"), [])

    def test_mark_completed_without_any_review_is_not_checked(self):
        self.rung("rung-01-a", review=False)
        self.assertEqual(self.call({}, "mark_completed"), [])
        self.assertEqual(len(self.call({}, "next_rung_review")), 1)


class FailureArtifactsTest(TmpCase):
    def check(self, rung, payload, action="task", phase=None):
        return pc._assert_rung_failure_artifacts(
            rung, payload, next_action=action, current_phase=phase)

    def test_blocked_requires_blocked_md(self):
        rung = self.rung(review=False)
        payload = {"verdict": "BLOCKED", "disposition": "SKIP"}
        self.assertEqual(self.check(rung, payload), ["missing BLOCKED.md"])
        (rung / "BLOCKED.md").write_text("crashed")
        self.assertEqual(self.check(rung, payload), [])

    def test_blocked_with_quota_needs_classification(self):
        rung = self.rung(review=False, **{"BLOCKED.md": "HTTP 429 from provider"})
        payload = {"verdict": "BLOCKED", "disposition": "SKIP"}
        self.assertEqual(self.check(rung, payload), ["missing QUOTA-CLASSIFY.json"])
        self.assertEqual(self.check(rung, {**payload, "quota": True}),
                         ["missing QUOTA-CLASSIFY.json"])
        (rung / "QUOTA-CLASSIFY.json").write_text('{"should_schedule": true, "quota_class": "five_hour"}')
        self.assertEqual(self.check(rung, payload), [])

    def test_hold_blocks_advancing_only(self):
        rung = self.rung(review=False, **{"BLOCKED.md": "stuck"})
        payload = {"verdict": "NOT CLEAN", "disposition": "HOLD"}
        self.assertEqual(self.check(rung, payload, "task"), [])
        self.assertEqual(self.check(rung, payload, "next_rung_review")[0],
                         "HOLD/BLOCKED cannot start next rung without skip or quota retry")
        blocked_skip = {"verdict": "BLOCKED", "disposition": "SKIP"}
        self.assertEqual(self.check(rung, blocked_skip, "mark_completed"), ["missing SKIPPED.md"])

    def test_skipped_requires_skipped_md_when_advancing(self):
        rung = self.rung(review=False)
        payload = {"verdict": "SKIPPED", "disposition": "SKIP"}
        self.assertEqual(self.check(rung, payload, "task"), [])
        self.assertEqual(self.check(rung, payload, "next_rung_review"), ["missing SKIPPED.md"])
        (rung / "SKIPPED.md").write_text("ok")
        self.assertEqual(self.check(rung, payload, "next_rung_review"), [])
        # disposition alone also counts
        self.assertEqual(self.check(rung, {"disposition": "SKIP"}, "verify_1"), [])

    def test_compliance_stop_phase(self):
        rung = self.rung(review=False)
        errs = self.check(rung, {}, "stop", phase="compliance_stop")
        self.assertEqual(errs, ["missing STOP.md"])
        (rung / "STOP.md").write_text("no check info")
        self.assertEqual(self.check(rung, {}, "stop", phase="STOP"),
                         ["STOP.md missing which check failed"])
        (rung / "STOP.md").write_text("check: ci-status")
        self.assertEqual(self.check(rung, {}, "stop", phase="stop"), [])
        for action in ("verify_1", "verify_2", "next_rung_review", "task"):
            errs = self.check(rung, {}, action, phase="compliance_stop")
            self.assertIn("compliance STOP blocks advance", errs, action)
        skipped = {"verdict": "SKIPPED", "disposition": "SKIP"}
        (rung / "SKIPPED.md").write_text("skipped")
        self.assertEqual(self.check(rung, skipped, "mark_completed", phase="stop"), [])

    def test_stop_md_present_blocks_advance(self):
        rung = self.rung(review=False)
        (rung / "STOP.md").write_text('{"check": "ci"}')
        self.assertEqual(self.check(rung, {}, "task"), [])
        self.assertEqual(self.check(rung, {}, "stop"), [])
        for action in ("next_rung_review", "verify_1", "verify_2"):
            errs = self.check(rung, {"verdict": "SKIPPED", "disposition": "SKIP"}, action)
            self.assertIn("STOP.md present — do not advance", errs, action)
            self.assertNotIn("STOP.md missing which check failed", errs)
        (rung / "STOP.md").write_text("nothing useful")
        errs = self.check(rung, {"verdict": "BLOCKED", "disposition": "SKIP"}, "verify_1")
        self.assertIn("STOP.md missing which check failed", errs)
        self.assertIn("STOP.md present — do not advance", errs)

    def test_undecodable_stop_md_reports_missing_check_instead_of_crashing(self):
        rung = self.rung(review=False)
        (rung / "STOP.md").write_bytes(b"\xff\xfe")
        errs = self.check(rung, {}, "stop", phase="stop")
        self.assertEqual(errs, ["STOP.md missing which check failed"])
        skipped = {"verdict": "SKIPPED", "disposition": "SKIP"}
        errs = self.check(rung, skipped, "verify_1")
        self.assertIn("STOP.md missing which check failed", errs)
        self.assertIn("STOP.md present — do not advance", errs)

    def test_accept_apply_needs_apply_md_or_complete_resolved(self):
        rung = self.rung(review=False)
        (rung / "verify-1.md").write_text("v1")
        base = {"verdict": "NOT CLEAN", "disposition": "ACCEPT-apply", "issues": FINDINGS}
        msg = "missing APPLY.md (or complete resolved table) before next-rung review"
        self.assertEqual(self.check(rung, base, "next_rung_review"), [msg])
        self.assertEqual(self.check(rung, base, "task"), [])
        self.assertEqual(self.check(rung, {**base, "resolved": "none"}, "mark_completed"), [msg])
        done = [{"resolved": "yes"}, {"resolved": "N/A"}, {"resolved": "na"}]
        self.assertEqual(self.check(rung, {**base, "resolved": done}, "next_rung_review"), [])
        part = [{"resolved": "yes"}, {"resolved": "pending"}]
        self.assertEqual(self.check(rung, {**base, "resolved": part}, "next_rung_review"), [msg])
        self.assertEqual(self.check(rung, {**base, "resolved": "bogus"}, "next_rung_review"), [msg])
        (rung / "APPLY.md").write_text("applied")
        self.assertEqual(self.check(rung, base, "next_rung_review"), [])

    def test_accept_apply_without_findings_or_with_bad_issues(self):
        rung = self.rung(review=False)
        (rung / "verify-1.md").write_text("v1")
        none_issues = {"HIGH": "none", "MED": "n/a", "LOW": "NA", "NIT": "none"}
        payload = {"verdict": "NOT CLEAN", "disposition": "ACCEPT-apply", "issues": none_issues}
        self.assertEqual(self.check(rung, payload, "next_rung_review"), [])
        # a missing/None severity is not the "none" token, so it counts as a finding
        for bad in ("bogus", {"HIGH": None}):
            payload["issues"] = bad
            self.assertEqual(len(self.check(rung, payload, "next_rung_review")), 1, bad)

    def test_verify_files_required_when_advancing(self):
        rung = self.rung(review=False)
        clean = {"verdict": "CLEAN", "disposition": "REJECT-as-wrong"}
        self.assertEqual(self.check(rung, clean, "task"), [])
        self.assertEqual(self.check(rung, clean, "next_rung_review"),
                         ["missing verify-1.md", "missing verify-2.md"])
        (rung / "verify_1.md").write_text("v1")
        self.assertEqual(self.check(rung, clean, "mark_completed"), ["missing verify-2.md"])
        (rung / "verify-2.md").write_text("v2")
        self.assertEqual(self.check(rung, clean, "mark_completed"), [])
        notclean = {"verdict": "NOT CLEAN", "disposition": "REJECT-as-wrong"}
        (rung / "verify_1.md").unlink()
        self.assertEqual(self.check(rung, notclean, "next_rung_review"), ["missing verify-1.md"])
        (rung / "verify-1.md").write_text("")  # empty file does not count
        self.assertEqual(self.check(rung, notclean, "next_rung_review"), ["missing verify-1.md"])
        for verdict in ("SKIPPED", "BLOCKED"):
            self.assertNotIn("missing verify-1.md", self.check(
                rung, {"verdict": verdict, "disposition": "SKIP"}, "next_rung_review"))


class AssertAdvanceTest(TmpCase):
    def advance(self, run_dir="default", **kw):
        run_dir = self.run_dir if run_dir == "default" else run_dir
        return pc.assert_rfl_advance(run_dir, **kw)

    def full_rung(self, name="rung-01-a", **payload_over):
        rung = self.rung(name, policy=valid_payload(**payload_over))
        (rung / "POLICY-C.md").write_text("md")
        (rung / "verify-1.md").write_text("v1")
        (rung / "verify-2.md").write_text("v2")
        return rung

    def test_no_run_dir_or_project(self):
        res = pc.assert_rfl_advance()
        self.assertEqual(res, {"ok": True, "skipped": "no_run_dir", "errors": [],
                               "next_action": "task"})
        res = pc.assert_rfl_advance(None, prompt="start verify-1")
        self.assertEqual(res["next_action"], "verify_1")

    def test_project_root_discovery(self):
        proj = self.tmp / "proj"
        (proj / ".planning").mkdir(parents=True)
        res = pc.assert_rfl_advance(project_root=proj)
        self.assertEqual((res["ok"], res["skipped"]), (True, "no_active_run"))
        run = proj / ".planning" / "rfl-x"
        run.mkdir()
        (run / "LADDER-STATUS.json").write_text('{"status": "active"}')
        res = pc.assert_rfl_advance(project_root=proj)
        self.assertEqual((res["ok"], res["run_dirs"], res["checked"]), (True, [str(run)], []))

    def test_run_dir_wins_over_project_root(self):
        proj = self.tmp / "proj"
        (proj / ".planning").mkdir(parents=True)
        res = pc.assert_rfl_advance(self.run_dir, project_root=proj)
        self.assertEqual(res["run_dirs"], [str(self.run_dir)])

    def test_action_resolution(self):
        r = self.advance(next_action="bogus", prompt="please verify-2")
        self.assertEqual(r["next_action"], "verify_2")
        r = self.advance(next_action="task", prompt="go to the next rung")
        self.assertEqual(r["next_action"], "next_rung_review")
        r = self.advance(next_action="verify_1", prompt="verify-2")
        self.assertEqual(r["next_action"], "verify_1")
        r = self.advance(next_action="bogus")
        self.assertEqual(r["next_action"], "task")

    def test_inactive_run_is_skipped_unless_marking_completed(self):
        self.status(status="completed")
        self.rung()
        res = self.advance(next_action="verify_1")
        self.assertEqual((res["ok"], res["checked"]), (True, []))
        res = self.advance(next_action="mark_completed")
        self.assertFalse(res["ok"])
        self.assertTrue(res["checked"])

    def test_clean_rung_advances(self):
        rung = self.full_rung()
        self.status(status="active", current_rung="rung-01-a", consecutive_clean_reviews=2,
                    consecutive_clean_rung="rung-01-a")
        res = self.advance(next_action="next_rung_review")
        self.assertEqual((res["ok"], res["errors"], res["checked"]), (True, [], [str(rung)]))
        res = self.advance(next_action="mark_completed")
        self.assertEqual((res["ok"], res["errors"]), (True, []))

    def test_streak_blocks_next_rung(self):
        self.full_rung()
        self.status(status="active", current_rung="rung-01-a", consecutive_clean_reviews=1,
                    consecutive_clean_rung="rung-01-a")
        res = self.advance(next_action="next_rung_review")
        self.assertFalse(res["ok"])
        self.assertTrue(res["errors"][0].startswith("consecutive_clean_reviews=1 < 2"))

    def test_review_prompt_promotes_task_to_next_rung_review(self):
        self.full_rung()
        self.status(status="active", current_rung="rung-01-a")
        res = self.advance(prompt="Review the rung output")
        self.assertEqual(res["next_action"], "next_rung_review")
        self.assertFalse(res["ok"])  # streak is 0
        # a prompt mentioning verify keeps the task action
        res = self.advance(prompt="review then verify")
        self.assertEqual(res["next_action"], "task")
        # no policy JSON yet: stays a task
        (self.run_dir / "rung-01-a" / "POLICY-C.json").unlink()
        res = self.advance(prompt="review it")
        self.assertEqual(res["next_action"], "task")

    def test_ladder_status_type_errors(self):
        self.rung()
        self.status(status="active", current_rung=3, current_phase=["x"])
        res = self.advance(next_action="stop")
        self.assertIn("LADDER-STATUS.json current_rung must be a single string", res["errors"])
        self.assertIn("LADDER-STATUS.json current_phase must be a single string", res["errors"])

    def test_compliance_stop(self):
        self.rung()
        self.status(status="active", compliance_stop=True)
        res = self.advance(next_action="verify_1")
        self.assertIn("compliance_stop set but STOP.md missing", res["errors"])
        self.assertIn("compliance STOP blocks advance", res["errors"])
        stop = self.run_dir / "rung-01-gpt" / "STOP.md"
        stop.write_text("nope")
        res = self.advance(next_action="stop")
        self.assertIn("STOP.md missing which check failed", res["errors"])
        self.assertNotIn("compliance STOP blocks advance", res["errors"])
        stop.write_text("check: lint")
        res = self.advance(next_action="stop")
        self.assertNotIn("STOP.md missing which check failed", res["errors"])
        self.assertNotIn("compliance_stop set but STOP.md missing", res["errors"])
        # no rung dirs: STOP.md is looked up in the run dir itself
        (self.tmp / "norungs").mkdir()
        (self.tmp / "norungs" / "LADDER-STATUS.json").write_text(
            '{"status": "active", "compliance_stop": true}')
        res = pc.assert_rfl_advance(self.tmp / "norungs", next_action="stop")
        self.assertEqual(res["errors"], ["compliance_stop set but STOP.md missing"])

    def test_compliance_stop_with_undecodable_stop_md(self):
        rung = self.rung()
        (rung / "STOP.md").write_bytes(b"\xff\xfe")
        self.status(status="active", compliance_stop=True)
        res = self.advance(next_action="stop")
        self.assertIn("STOP.md missing which check failed", res["errors"])

    def test_mark_completed_targets(self):
        self.status(status="active", current_rung="rung-09-z")
        res = self.advance(next_action="mark_completed")
        self.assertEqual(res["errors"], ["current rung missing Policy C"])
        self.rung("rung-01-a", review=False)  # neither review nor policy nor current
        res = self.advance(next_action="mark_completed")
        self.assertEqual(res["checked"], [str(self.run_dir / "rung-01-a")])
        self.status(status="active")  # no current_rung and nothing to check
        res = self.advance(next_action="mark_completed")
        self.assertEqual(res["checked"], [])
        # a rung that has a review is checked; current rung already in list is not duplicated
        self.rung("rung-02-b")
        self.status(status="active", current_rung="rung-02-b")
        res = self.advance(next_action="mark_completed")
        self.assertEqual(res["checked"].count(str(self.run_dir / "rung-02-b")), 1)
        self.assertIn("missing POLICY-C.json", res["errors"])

    def test_task_and_stop_skip_rungs_without_review_or_policy(self):
        self.rung("rung-01-a", review=False)
        self.status(status="active")
        for action in ("task", "stop"):
            res = self.advance(next_action=action)
            self.assertEqual((res["ok"], res["errors"]), (True, []), action)
        # policy JSON without review.md under a plain task is not validated either
        self.rung("rung-02-b", policy={"broken": True}, review=False)
        res = self.advance(next_action="task")
        self.assertEqual((res["ok"], res["errors"]), (True, []))
        # ... but verify actions validate it
        res = self.advance(next_action="verify_1")
        self.assertFalse(res["ok"])
        self.assertIn("missing POLICY-C.md", res["errors"])
        self.assertIn("missing rung_identity", res["errors"])

    def test_task_with_review_validates_policy_c(self):
        self.rung("rung-01-a")
        self.status(status="active")
        res = self.advance(next_action="task")
        self.assertEqual(res["errors"][:2], ["missing POLICY-C.json", "missing POLICY-C.md"])

    def test_explicit_rung_dir_and_dedup(self):
        a = self.rung("rung-01-a")
        self.rung("rung-02-b")
        self.status(status="active")
        res = self.advance(next_action="verify_1", rung_dir="rung-01-a")
        self.assertEqual(res["checked"], [str(a)])
        self.assertEqual(len(res["errors"]), len(set(res["errors"])))
        # two active runs reporting the same error are de-duplicated
        proj = self.tmp / "proj"
        for name in ("rfl-a", "rfl-b"):
            run = proj / ".planning" / name
            (run / "rung-01-x").mkdir(parents=True)
            (run / "rung-01-x" / "review.md").write_text("r")
            (run / "LADDER-STATUS.json").write_text('{"status": "active"}')
        res = pc.assert_rfl_advance(project_root=proj, next_action="verify_1")
        self.assertEqual(res["errors"].count("missing POLICY-C.json"), 1)
        self.assertEqual(len(res["run_dirs"]), 2)

    def test_resolved_must_be_complete_before_next_rung(self):
        rung = self.full_rung(disposition="ACCEPT-apply", issues=FINDINGS,
                              triage=[{"id": "H1", "decision": "ACCEPT"}], verdict="NOT CLEAN",
                              resolved=[{"id": "H1", "resolved": "no"}])
        self.status(status="active", current_rung="rung-01-a", consecutive_clean_reviews=2,
                    consecutive_clean_rung="rung-01-a")
        res = self.advance(next_action="next_rung_review")
        self.assertIn("resolved table incomplete before next-rung review", res["errors"])
        self.assertIn("missing APPLY.md (or complete resolved table) before next-rung review",
                      res["errors"])
        (rung / "APPLY.md").write_text("done")
        res = self.advance(next_action="next_rung_review")
        self.assertIn("resolved table incomplete before next-rung review", res["errors"])

    def test_assert_run_ready_for_complete(self):
        self.full_rung()
        self.status(status="active", current_rung="rung-01-a", consecutive_clean_reviews=2,
                    consecutive_clean_rung="rung-01-a")
        res = pc.assert_run_ready_for_complete(str(self.run_dir))
        self.assertEqual((res["ok"], res["next_action"]), (True, "mark_completed"))
        (self.run_dir / "rung-01-a" / "verify-2.md").unlink()
        res = pc.assert_run_ready_for_complete(self.run_dir)
        self.assertEqual(res["errors"], ["missing verify-2.md"])


if __name__ == "__main__":
    unittest.main()
