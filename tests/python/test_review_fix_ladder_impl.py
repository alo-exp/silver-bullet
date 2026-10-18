"""Unit tests for scripts/_review_fix_ladder_impl.py (host-aware RFL rung resolver)."""
from __future__ import annotations

import contextlib
import io
import json
import os
import runpy
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from sbtest import REPO_ROOT, load_module

r = load_module("scripts/_review_fix_ladder_impl.py")


class ImportPathTest(unittest.TestCase):
    LIB = str(REPO_ROOT / "scripts" / "lib")

    def test_lib_dir_is_added_to_sys_path_when_absent(self):
        trimmed = [p for p in sys.path if p != self.LIB]
        with mock.patch.object(sys, "path", trimmed):
            load_module("scripts/_review_fix_ladder_impl.py", name="rfl_impl_fresh_a")
            self.assertEqual(trimmed[0], self.LIB)

    def test_lib_dir_not_duplicated_when_present(self):
        path = [self.LIB] + [p for p in sys.path if p != self.LIB]
        with mock.patch.object(sys, "path", path):
            load_module("scripts/_review_fix_ladder_impl.py", name="rfl_impl_fresh_b")
            self.assertEqual(path.count(self.LIB), 1)


class TmpCase(unittest.TestCase):
    """Per-test scratch dir with HOME, cwd and RFL env isolated."""

    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.tmp = Path(tmp.name).resolve()
        self.home = self.tmp / "home"
        self.home.mkdir()
        self.proj = self.tmp / "proj"
        self.proj.mkdir()
        env = {"HOME": str(self.home), "PATH": os.environ.get("PATH", "/usr/bin:/bin")}
        p = mock.patch.dict(os.environ, env, clear=True)
        p.start()
        self.addCleanup(p.stop)

    def write_json(self, path, obj):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(obj if isinstance(obj, str) else json.dumps(obj), encoding="utf-8")
        return path


class DetectHostTest(TmpCase):
    def check(self, expected, **env):
        with mock.patch.dict(os.environ, env):
            self.assertEqual(r.detect_host(), expected)

    def test_explicit_runtime(self):
        self.check("codex", SILVER_BULLET_RUNTIME=" Codex ")
        self.check("cursor", SILVER_BULLET_RUNTIME="cursor")
        self.check("claude", SILVER_BULLET_RUNTIME="claude", CODEX_CI="1")

    def test_unknown_runtime_falls_through(self):
        self.check("claude", SILVER_BULLET_RUNTIME="opencode")
        self.check("codex", SILVER_BULLET_RUNTIME="opencode", CODEX_THREAD_ID="t")

    def test_codex_markers(self):
        for key in ("CODEX_CI", "CODEX_THREAD_ID", "CODEX_INTERNAL_ORIGINATOR_OVERRIDE"):
            self.check("codex", **{key: "1"})

    def test_cursor_marker(self):
        self.check("cursor", CURSOR_PLUGIN_ROOT="/x")

    def test_plugin_root_paths(self):
        self.check("codex", CLAUDE_PLUGIN_ROOT="/h/.codex/plugins/sb")
        self.check("cursor", CLAUDE_PLUGIN_ROOT="/h/.cursor/plugins/sb")
        self.check("claude", CLAUDE_PLUGIN_ROOT="/h/.claude/plugins/sb")

    def test_default(self):
        self.check("claude")


class NamingAndFamilyTest(unittest.TestCase):
    def test_names(self):
        self.assertEqual(r.sanitize_model_for_agent_name("gpt-5.5"), "gpt-5-5")
        self.assertEqual(r.subagent_name_for("grok-4.5", "high"), "sb-grok-4-5-high")
        self.assertEqual(r.subagent_name_for("m", "low", "x"), "x-m-low")

    def test_family(self):
        for slug, fam in (("opus-4", "claude"), ("claude-opus", "claude"), ("sb-opus-4", "claude"),
                          (" SB-Claude-x ", "claude"), ("gpt-5.5", "gpt"), ("chatgpt-4", "gpt"),
                          ("sb-gpt-5", "gpt"), ("composer-2.5", None), ("", None), (None, None)):
            self.assertEqual(r.subscription_family_for_model(slug), fam, slug)

    def test_first_regex_match(self):
        self.assertEqual(r._first_regex_match(r.HASH_MISMATCH_RE, "x HASH   MISMATCH y"), "HASH   MISMATCH")
        self.assertIsNone(r._first_regex_match(r.HASH_MISMATCH_RE, "fine"))
        self.assertIsNone(r._first_regex_match(r.HASH_MISMATCH_RE, None))

    def test_subscription_fields(self):
        none = r.subscription_fields_for_model("composer-2.5")
        self.assertFalse(none["subscription_first"])
        self.assertIsNone(none["subscription_invoke"])
        gpt = r.subscription_fields_for_model("gpt-5.5")
        self.assertEqual(gpt["subscription_host"], "codex")
        self.assertEqual(gpt["subscription_invoke"], "scripts/agent-codex/invoke.sh")
        self.assertEqual(gpt["cursor_fallback"], "quota-exhaustion-only")
        cl = r.subscription_fields_for_model("claude-opus-4-7")
        self.assertEqual(cl["subscription_skill"], "silver-agent-claude")


class ClassifyAndDecideTest(unittest.TestCase):
    def test_classify(self):
        self.assertEqual(r.classify_subscription_attempt(0, "429")["reason"], "success")
        self.assertEqual(r.classify_subscription_attempt("0", None)["reason"], "success")
        miss = r.classify_subscription_attempt(1, "bash: codex: command not found")
        self.assertEqual((miss["reason"], miss["signal"], miss["cursor_fallback"]),
                         ("missing-cli", "command not found", False))
        # missing CLI wins over a quota word
        self.assertEqual(r.classify_subscription_attempt(1, "CLI not found; quota")["reason"], "missing-cli")
        hm = r.classify_subscription_attempt(2, "HASH MISMATCH in 429")
        self.assertEqual(hm["reason"], "hash-mismatch")
        self.assertFalse(hm["cursor_fallback"])
        q = r.classify_subscription_attempt(1, "Error 429 Too Many")
        self.assertEqual((q["reason"], q["signal"], q["quota_exhaustion"], q["cursor_fallback"]),
                         ("quota-exhaustion", "429", True, True))
        for text in ("rate-limit hit", "usage cap", "out of quota", "billed quota", "token plan"):
            self.assertTrue(r.classify_subscription_attempt(1, text)["quota_exhaustion"], text)
        other = r.classify_subscription_attempt(1, "segfault")
        self.assertEqual(other["reason"], "non-quota-failure")
        self.assertIsNone(other["signal"])
        self.assertEqual(r.classify_subscription_attempt(3, None)["reason"], "non-quota-failure")

    def test_decide_non_subscription(self):
        p = r.decide_launch("composer-2.5", "medium")
        self.assertEqual((p["action"], p["reason"], p["cursor_fallback"]),
                         ("cursor_task", "non-subscription-family", False))
        self.assertEqual(p["subagent_name"], "sb-composer-2-5-medium")

    def test_decide_subscription_first(self):
        p = r.decide_launch("gpt-5.5", "high", prefix="zz")
        self.assertEqual((p["action"], p["reason"]), ("invoke_subscription", "subscription-first"))
        self.assertEqual(p["subagent_name"], "zz-gpt-5-5-high")
        self.assertEqual(p["cursor_fallback"], "quota-exhaustion-only")

    def test_decide_after_attempt(self):
        ok = r.decide_launch("gpt-5.5", "high", subscription_exit=0)
        self.assertEqual(ok["action"], "accept_subscription")
        self.assertIs(ok["cursor_fallback"], False)
        fb = r.decide_launch("claude-opus-4-7", "high", subscription_exit=1, subscription_output="rate limit")
        self.assertEqual((fb["action"], fb["cursor_fallback"]), ("cursor_fallback", True))
        fail = r.decide_launch("gpt-5.5", "high", subscription_exit=1, subscription_output="boom")
        self.assertEqual((fail["action"], fail["reason"]), ("fail", "non-quota-failure"))


class StateFileTest(TmpCase):
    def test_rfl_state_file(self):
        self.assertEqual(r.rfl_state_file(), Path("/tmp/review-fix-ladder-state.json"))
        with mock.patch.dict(os.environ, {"SB_RUNTIME_STATE_DIR": str(self.tmp / "st")}):
            self.assertEqual(r.rfl_state_file(), self.tmp / "st" / "review-fix-ladder-state.json")

    def test_mark_quota_fallback_creates_and_merges(self):
        state_dir = self.tmp / "st"
        with mock.patch.dict(os.environ, {"SB_RUNTIME_STATE_DIR": str(state_dir)}):
            out = r.mark_quota_cursor_fallback(host="codex", signal="429")
            self.assertEqual(out["subscription_quota_host"], "codex")
            self.assertEqual(out["state_file"], str(state_dir / "review-fix-ladder-state.json"))
            saved = json.loads((state_dir / "review-fix-ladder-state.json").read_text())
            self.assertEqual(saved, {"subscription_quota_fallback": True,
                                     "subscription_quota_host": "codex", "subscription_quota_signal": "429"})
            # second call keeps unrelated and earlier keys, adds nothing when args are empty
            saved["other"] = 1
            (state_dir / "review-fix-ladder-state.json").write_text(json.dumps(saved))
            out = r.mark_quota_cursor_fallback()
            self.assertEqual(out["subscription_quota_host"], "codex")
            again = json.loads((state_dir / "review-fix-ladder-state.json").read_text())
            self.assertEqual(again["other"], 1)

    def test_mark_quota_fallback_without_host_or_signal(self):
        with mock.patch.dict(os.environ, {"SB_RUNTIME_STATE_DIR": str(self.tmp / "st2")}):
            out = r.mark_quota_cursor_fallback()
        self.assertIsNone(out["subscription_quota_host"])
        self.assertIsNone(out["subscription_quota_signal"])

    def test_load_json_file(self):
        self.assertIsNone(r.load_json_file(self.tmp / "missing.json"))
        self.assertIsNone(r.load_json_file(self.write_json(self.tmp / "bad.json", "{nope")))
        self.assertIsNone(r.load_json_file(self.write_json(self.tmp / "list.json", "[1]")))
        self.assertEqual(r.load_json_file(self.write_json(self.tmp / "ok.json", {"a": 1})), {"a": 1})

    def test_load_json_file_unreadable(self):
        p = self.write_json(self.tmp / "x.json", {"a": 1})
        with mock.patch.object(Path, "read_text", side_effect=OSError("denied")):
            self.assertIsNone(r.load_json_file(p))


class ConfigTest(TmpCase):
    def test_defaults(self):
        cfg = r.load_cursor_sb_agents_config(self.proj)
        self.assertEqual(cfg, r.CURSOR_SB_AGENTS_DEFAULTS)

    def test_returned_config_does_not_alias_module_defaults(self):
        cfg = r.load_cursor_sb_agents_config(self.proj)
        cfg["selected_models"].append("mutated")
        cfg["effort_levels"].clear()
        again = r.load_cursor_sb_agents_config(self.proj)
        self.assertEqual(again["selected_models"], list(r.DEFAULT_CURSOR_MODELS))
        self.assertEqual(again["effort_levels"], list(r.DEFAULT_CURSOR_EFFORTS))
        self.assertEqual(r.CURSOR_SB_AGENTS_DEFAULTS["selected_models"], list(r.DEFAULT_CURSOR_MODELS))

    def test_defaults_use_cwd(self):
        old = os.getcwd()
        os.chdir(self.proj)
        try:
            self.write_json(self.proj / ".silver-bullet.json", {"cursor_sb_agents": {"agent_name_prefix": "cwd"}})
            self.assertEqual(r.load_cursor_sb_agents_config()["agent_name_prefix"], "cwd")
        finally:
            os.chdir(old)

    def test_project_config_wins_and_skips_global(self):
        self.write_json(self.proj / ".silver-bullet.json",
                        {"cursor_sb_agents": {"selected_models": ["a"], "agent_name_prefix": "p"}})
        self.write_json(self.home / ".config/silver-bullet/cursor-sb-agents.json", {"agent_name_prefix": "g"})
        cfg = r.load_cursor_sb_agents_config(self.proj)
        self.assertEqual((cfg["agent_name_prefix"], cfg["selected_models"]), ("p", ["a"]))

    def test_project_key_present_but_not_dict_blocks_global(self):
        self.write_json(self.proj / ".silver-bullet.json", {"cursor_sb_agents": "oops"})
        self.write_json(self.home / ".config/silver-bullet/cursor-sb-agents.json", {"agent_name_prefix": "g"})
        self.assertEqual(r.load_cursor_sb_agents_config(self.proj)["agent_name_prefix"], "sb")

    def test_global_config_used_when_project_lacks_key(self):
        self.write_json(self.home / ".config/silver-bullet/cursor-sb-agents.json", {"agent_name_prefix": "g"})
        self.assertEqual(r.load_cursor_sb_agents_config(self.proj)["agent_name_prefix"], "g")
        self.write_json(self.proj / ".silver-bullet.json", {"other": 1})
        self.assertEqual(r.load_cursor_sb_agents_config(self.proj)["agent_name_prefix"], "g")

    def test_empty_lists_are_reset_to_defaults(self):
        self.write_json(self.proj / ".silver-bullet.json",
                        {"cursor_sb_agents": {"selected_models": [], "effort_levels": "high"}})
        cfg = r.load_cursor_sb_agents_config(self.proj)
        self.assertEqual(cfg["selected_models"], list(r.DEFAULT_CURSOR_MODELS))
        self.assertEqual(cfg["effort_levels"], list(r.DEFAULT_CURSOR_EFFORTS))

    def test_catalog_ids(self):
        self.assertEqual(r.load_catalog_ids(self.proj), set(r.KNOWN_COMPOSITE_SLUGS))
        self.write_json(self.proj / ".silver-bullet/cursor-models-catalog.json",
                        {"models": [{"id": "m1"}, {"id": ""}, {"nope": 1}, "str", {"id": 7}]})
        self.write_json(self.home / ".config/silver-bullet/cursor-models-catalog.json", {"models": "bad"})
        ids = r.load_catalog_ids(self.proj)
        self.assertEqual(ids - r.KNOWN_COMPOSITE_SLUGS, {"m1", "7"})
        self.write_json(self.home / ".config/silver-bullet/cursor-models-catalog.json", {"models": [{"id": "g1"}]})
        self.assertIn("g1", r.load_catalog_ids(self.proj))

    def test_catalog_ids_default_root_is_cwd(self):
        old = os.getcwd()
        os.chdir(self.proj)
        try:
            self.write_json(self.proj / ".silver-bullet/cursor-models-catalog.json", {"models": [{"id": "cw"}]})
            self.assertIn("cw", r.load_catalog_ids())
        finally:
            os.chdir(old)


class ModelParamTest(unittest.TestCase):
    def test_resolution(self):
        self.assertEqual(r.resolve_model_param("composer-2.5", "high"), "composer-2.5")
        self.assertEqual(r.resolve_model_param("composer-2.5-fast", "high"), "composer-2.5")
        self.assertEqual(r.resolve_model_param("grok-4.5", "high"), "grok-4.5-high")
        self.assertEqual(r.resolve_model_param("grok-4.5", "low"), "grok-4.5-low")
        self.assertEqual(r.resolve_model_param("grok-4.5-beta", "medium"), "grok-4.5-medium")
        self.assertEqual(r.resolve_model_param("grok-4.5-fast", "high"), "grok-4.5-fast")
        self.assertEqual(r.resolve_model_param("gpt-5.5", "high"), "gpt-5.5-high")  # known composite
        self.assertEqual(r.resolve_model_param("gpt-5.5", "low"), "gpt-5.5")
        self.assertEqual(r.resolve_model_param("x", "high", {"x-high"}), "x-high")
        self.assertEqual(r.resolve_model_param("x", "high", {"x[effort=high]"}), "x[effort=high]")
        self.assertEqual(r.resolve_model_param("x", "high", set()), "x")  # empty catalog -> known slugs
        self.assertEqual(r.resolve_model_param("x", "high", None), "x")

    def test_enrich_rung(self):
        rung = r.enrich_cursor_sb_rung("gpt-5.5", "high", prefix="p")
        self.assertEqual(rung["subagent_name"], "p-gpt-5-5-high")
        self.assertEqual(rung["model_param"], "gpt-5.5-high")
        self.assertEqual(rung["delegation"], "custom-subagent")
        self.assertTrue(rung["subscription_first"])
        self.assertIsNone(rung["task_slug"])

    def test_cursor_rungs(self):
        rungs = r.cursor_sb_agents_rungs({"selected_models": ["composer-2.5", 7], "effort_levels": ["low"],
                                          "agent_name_prefix": ""})
        self.assertEqual([x["subagent_name"] for x in rungs], ["sb-composer-2-5-low", "sb-7-low"])
        defaults = r.cursor_sb_agents_rungs({})
        self.assertEqual(len(defaults), len(r.DEFAULT_CURSOR_MODELS) * len(r.DEFAULT_CURSOR_EFFORTS))


class AgentChecksTest(TmpCase):
    def agent_dirs(self):
        (self.home / ".cursor/agents").mkdir(parents=True)
        (self.proj / ".cursor/agents").mkdir(parents=True)

    def test_search_dirs_and_file_exists(self):
        self.assertEqual(r.agent_search_dirs(self.proj), [])
        self.assertFalse(r.agent_file_exists("sb-x", self.proj))
        self.agent_dirs()
        self.assertEqual(r.agent_search_dirs(self.proj), [self.home / ".cursor/agents", self.proj / ".cursor/agents"])
        (self.proj / ".cursor/agents/sb-x.md").write_text("x")
        self.assertTrue(r.agent_file_exists("sb-x", self.proj))
        self.assertFalse(r.agent_file_exists("sb-y", self.proj))

    def make_probe(self, body, exit_code=0):
        probe = self.proj / "scripts/lib/cursor-sb-agents/probe-global-agents.sh"
        probe.parent.mkdir(parents=True, exist_ok=True)
        probe.write_text(f"#!/usr/bin/env bash\n{body}\nexit {exit_code}\n")
        return probe

    def test_probe_absent(self):
        self.assertIsNone(r.probe_agents_via_script(self.proj, {}))

    def test_probe_success_receives_config(self):
        self.make_probe('printf \'{"ok": true, "found_names": ["a"], "cfg": %s, "args": "%s"}\' "$SB_CURSOR_SB_AGENTS_CONFIG" "$*"')
        out = r.probe_agents_via_script(self.proj, {"k": 1})
        self.assertEqual(out["cfg"], {"k": 1})
        self.assertEqual(out["args"], "--json --skip-status")

    def test_probe_exit_one_is_accepted_other_codes_rejected(self):
        self.make_probe("echo '{\"ok\": false}'", exit_code=1)
        self.assertEqual(r.probe_agents_via_script(self.proj, {}), {"ok": False})
        self.make_probe("echo '{\"ok\": false}'", exit_code=2)
        self.assertIsNone(r.probe_agents_via_script(self.proj, {}))

    def test_probe_bad_output(self):
        self.make_probe("echo not-json")
        self.assertIsNone(r.probe_agents_via_script(self.proj, {}))
        self.make_probe("echo '[1]'")
        self.assertIsNone(r.probe_agents_via_script(self.proj, {}))

    def test_probe_oserror_and_timeout(self):
        self.make_probe("echo '{}'")
        with mock.patch.object(r.subprocess, "run", side_effect=OSError("nobash")):
            self.assertIsNone(r.probe_agents_via_script(self.proj, {}))
        with mock.patch.object(r.subprocess, "run",
                               side_effect=subprocess.TimeoutExpired(cmd="x", timeout=10)):
            self.assertIsNone(r.probe_agents_via_script(self.proj, {}))

    def test_check_agents_inline(self):
        self.agent_dirs()
        cfg = {"selected_models": ["composer-2.5"], "effort_levels": ["low", "high"]}
        with mock.patch.dict(os.environ, {"SB_CURSOR_SB_AGENTS_SKIP_PROBE": "1"}):
            res = r.check_agents(cfg, self.proj)
            self.assertEqual(res["source"], "inline")
            self.assertFalse(res["ok"])
            self.assertEqual(res["missing"], ["sb-composer-2-5-low", "sb-composer-2-5-high"])
            self.assertEqual(res["expected_count"], 2)
            for n in res["expected_names"]:
                (self.proj / ".cursor/agents" / f"{n}.md").write_text("x")
            res = r.check_agents(cfg, self.proj)
            self.assertTrue(res["ok"])
            self.assertEqual(res["missing"], [])

    def test_check_agents_probe_without_skip_falls_back_when_probe_missing(self):
        res = r.check_agents({"selected_models": ["composer-2.5"], "effort_levels": ["low"]}, self.proj)
        self.assertEqual(res["source"], "inline")

    def test_check_agents_via_probe(self):
        cfg = {"selected_models": ["composer-2.5"], "effort_levels": ["low", "high"]}
        self.make_probe('echo \'{"ok": true, "found_names": ["sb-composer-2-5-low", "sb-composer-2-5-high"]}\'')
        res = r.check_agents(cfg, self.proj)
        self.assertEqual((res["source"], res["ok"], res["missing"]), ("probe-global-agents.sh", True, []))
        self.make_probe('echo \'{"ok": true, "found_names": ["sb-composer-2-5-low"]}\'')
        res = r.check_agents(cfg, self.proj)
        self.assertFalse(res["ok"])
        self.assertEqual(res["missing"], ["sb-composer-2-5-high"])
        self.make_probe('echo \'{"found_names": ["sb-composer-2-5-low", "sb-composer-2-5-high"]}\'')
        self.assertFalse(r.check_agents(cfg, self.proj)["ok"])  # probe did not say ok
        self.make_probe("echo '{}'")
        self.assertFalse(r.check_agents(cfg, self.proj)["ok"])  # no found_names at all

    def test_enforcement_required(self):
        self.assertTrue(r.agents_enforcement_required({}))
        self.assertFalse(r.agents_enforcement_required({"enforcement_suspended": True}))
        self.assertFalse(r.agents_enforcement_required({"enabled_by_user": False}))
        self.assertFalse(r.agents_enforcement_required({"enabled": False}))
        self.assertTrue(r.agents_enforcement_required({"enabled": True, "enabled_by_user": None}))


class LaddersTest(TmpCase):
    def models_cache(self, models):
        return self.write_json(self.tmp / "codex/models_cache.json", {"models": models})

    def test_reasoning_levels(self):
        self.assertEqual(r.reasoning_levels_for_model({}), list(r.REASONING_ORDER))
        m = {"supported_reasoning_levels": [{"effort": "high"}, {"effort": "low"}, {"effort": ""},
                                            "junk", {"effort": "weird"}]}
        self.assertEqual(r.reasoning_levels_for_model(m), ["low", "high"])
        self.assertEqual(r.reasoning_levels_for_model({"supported_reasoning_levels": [{"effort": "weird"}]}),
                         list(r.REASONING_ORDER))

    def test_expand(self):
        self.assertEqual(r.expand_model_rungs(["a", "b"], ["x", "y"]),
                         [{"model": "a", "reasoning": "x"}, {"model": "a", "reasoning": "y"},
                          {"model": "b", "reasoning": "x"}, {"model": "b", "reasoning": "y"}])
        self.assertEqual(r.expand_model_rungs([], ["x"]), [])

    def test_fallbacks(self):
        self.assertEqual(len(r.codex_fallback_rungs()), 2 * 4)
        self.assertEqual(r.claude_fallback_rungs()[0], {"model": "claude-sonnet-4-6", "reasoning": "medium"})
        self.assertEqual(len(r.claude_fallback_rungs()), 3 * 3)

    def test_codex_dynamic_rungs(self):
        self.assertIsNone(r.codex_dynamic_rungs(self.tmp / "nope.json"))
        bad = self.write_json(self.tmp / "bad.json", "{nope")
        self.assertIsNone(r.codex_dynamic_rungs(bad))
        for payload in ({"models": []}, {"models": "x"}, {}):
            self.assertIsNone(r.codex_dynamic_rungs(self.write_json(self.tmp / "p.json", payload)))
        hidden = [{"slug": "a", "visibility": "hide"}]
        self.assertIsNone(r.codex_dynamic_rungs(self.write_json(self.tmp / "p.json", {"models": hidden})))
        mini = [{"slug": r.CODEX_MINI_SLUG, "visibility": "list"}]
        self.assertIsNone(r.codex_dynamic_rungs(self.write_json(self.tmp / "p.json", {"models": mini})))
        blank = [{"slug": "  ", "visibility": "list"}, {"visibility": "list"}]
        self.assertIsNone(r.codex_dynamic_rungs(self.write_json(self.tmp / "p.json", {"models": blank})))

    def test_codex_dynamic_rungs_sorted_by_priority_and_filtered(self):
        cache = self.models_cache([
            {"slug": "low-prio", "visibility": "list", "priority": 1,
             "supported_reasoning_levels": [{"effort": "xhigh"}, {"effort": "medium"}]},
            {"slug": r.CODEX_MINI_SLUG, "visibility": "list", "priority": 99},
            {"slug": "hidden", "visibility": "hide", "priority": 50},
            {"slug": "top", "visibility": "list", "priority": "7"},
            {"slug": "", "visibility": "list", "priority": 5},
        ])
        rungs = r.codex_dynamic_rungs(cache)
        self.assertEqual([x["model"] for x in rungs],
                         ["top"] * 4 + ["low-prio"] * 2)
        self.assertEqual([x["reasoning"] for x in rungs[-2:]], ["medium", "xhigh"])

    def test_resolve_cursor_ladder_flags_missing_agents(self):
        with mock.patch.dict(os.environ, {"SB_CURSOR_SB_AGENTS_SKIP_PROBE": "1"}):
            p = r.resolve_cursor_ladder(self.proj)
        self.assertEqual((p["host"], p["source"]), ("cursor", "cursor_sb_agents"))
        self.assertEqual(p["total_rungs"], len(p["rungs"]))
        self.assertTrue(p["agents_missing"])
        self.assertEqual(p["d21_hint"], "bash scripts/install-cursor-sb-agents.sh --fix")

    def test_resolve_cursor_ladder_when_suspended_or_complete(self):
        self.write_json(self.proj / ".silver-bullet.json", {"cursor_sb_agents": {"enforcement_suspended": True}})
        with mock.patch.dict(os.environ, {"SB_CURSOR_SB_AGENTS_SKIP_PROBE": "1"}):
            p = r.resolve_cursor_ladder(self.proj)
        self.assertNotIn("agents_missing", p)
        self.write_json(self.proj / ".silver-bullet.json", {"cursor_sb_agents": {
            "selected_models": ["composer-2.5"], "effort_levels": ["low"]}})
        (self.proj / ".cursor/agents").mkdir(parents=True)
        (self.proj / ".cursor/agents/sb-composer-2-5-low.md").write_text("x")
        with mock.patch.dict(os.environ, {"SB_CURSOR_SB_AGENTS_SKIP_PROBE": "1"}):
            self.assertNotIn("agents_missing", r.resolve_cursor_ladder(self.proj))

    def test_resolve_cursor_ladder_default_root(self):
        old = os.getcwd()
        os.chdir(self.proj)
        try:
            with mock.patch.dict(os.environ, {"SB_CURSOR_SB_AGENTS_SKIP_PROBE": "1"}):
                self.assertEqual(r.resolve_cursor_ladder()["host"], "cursor")
        finally:
            os.chdir(old)

    def test_resolve_ladder_hosts(self):
        with mock.patch.dict(os.environ, {"SB_CURSOR_SB_AGENTS_SKIP_PROBE": "1"}):
            self.assertEqual(r.resolve_ladder("CURSOR", project_root=self.proj)["host"], "cursor")
        claude = r.resolve_ladder("claude")
        self.assertEqual((claude["host"], claude["source"], claude["total_rungs"]), ("claude", "fallback", 9))
        self.assertEqual(r.resolve_ladder("anything-else")["host"], "claude")
        cache = self.models_cache([{"slug": "m", "visibility": "list", "priority": 1}])
        dyn = r.resolve_ladder("codex", codex_home=cache.parent)
        self.assertEqual((dyn["source"], dyn["total_rungs"]), ("dynamic", 4))
        fb = r.resolve_ladder("codex", codex_home=self.tmp / "empty")
        self.assertEqual((fb["source"], fb["total_rungs"]), ("fallback", 8))

    def test_resolve_ladder_codex_home_from_env_and_default(self):
        cache = self.models_cache([{"slug": "env-model", "visibility": "list"}])
        with mock.patch.dict(os.environ, {"CODEX_HOME": str(cache.parent)}):
            self.assertEqual(r.resolve_ladder("codex")["rungs"][0]["model"], "env-model")
        self.write_json(self.home / ".codex/models_cache.json",
                        {"models": [{"slug": "home-model", "visibility": "list"}]})
        self.assertEqual(r.resolve_ladder("codex")["rungs"][0]["model"], "home-model")


class RungPhaseTest(unittest.TestCase):
    PAYLOAD = {"host": "cursor", "rungs": [
        {"model": "gpt-5.5", "reasoning": "high", "delegation": "d", "subagent_name": "n", "model_param": "mp"},
        {"model": "composer-2.5", "reasoning": "low"},
    ]}

    def test_phase_payload(self):
        out = r.resolve_rung_phase(self.PAYLOAD, 1, "review")
        self.assertEqual((out["rung"], out["rung_total"], out["phase"], out["delegation"]), (1, 2, "review", "d"))
        self.assertEqual((out["subagent_name"], out["model_param"]), ("n", "mp"))
        self.assertTrue(out["subscription_first"])
        plain = r.resolve_rung_phase(self.PAYLOAD, 2, "verify_2")
        self.assertEqual(plain["delegation"], "custom-subagent")
        self.assertIsNone(plain["subagent_name"])
        self.assertFalse(plain["subscription_first"])

    def test_errors(self):
        for idx in (0, 3, -1):
            with self.assertRaisesRegex(ValueError, r"out of range \(1\.\.2\)"):
                r.resolve_rung_phase(self.PAYLOAD, idx, "review")
        with self.assertRaisesRegex(ValueError, "unsupported phase 'bogus'"):
            r.resolve_rung_phase(self.PAYLOAD, 1, "bogus")
        with self.assertRaisesRegex(ValueError, r"out of range \(1\.\.0\)"):
            r.resolve_rung_phase({}, 1, "review")


class MainTest(TmpCase):
    def run_main(self, *argv, stdin=None):
        out, err = io.StringIO(), io.StringIO()
        with mock.patch.object(sys, "argv", ["review-fix-ladder.py", *map(str, argv)]), \
                contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            try:
                rc = r.main()
            except SystemExit as exc:
                rc = exc.code
        return rc, out.getvalue(), err.getvalue()

    # ---- quota-window family
    def test_classify_quota_window(self):
        with mock.patch.object(r.rfl_quota_claude5h, "classify_quota_window", return_value={"w": 1}) as c:
            rc, out, _ = self.run_main("--classify-quota-window", "--subscription-output", "text",
                                       "--quota-host", "claude", "--model", "opus",
                                       "--quota-now", "2026-01-02T03:04:05Z")
        self.assertEqual(rc, 0)
        self.assertEqual(json.loads(out), {"w": 1})
        args, kwargs = c.call_args
        self.assertEqual(args, ("text",))
        self.assertEqual((kwargs["host"], kwargs["model"]), ("claude", "opus"))
        self.assertEqual(kwargs["now"].year, 2026)

    def test_classify_quota_window_reads_output_file_and_defaults_model(self):
        f = self.tmp / "out.txt"
        f.write_text("from file")
        with mock.patch.object(r.rfl_quota_claude5h, "classify_quota_window", return_value={}) as c:
            self.run_main("--classify-quota-window", "--subscription-output-file", f)
        self.assertEqual(c.call_args[0], ("from file",))
        self.assertEqual(c.call_args[1]["model"], "")
        self.assertIsNone(c.call_args[1]["now"])

    def test_wake_requires_dir(self):
        rc, out, err = self.run_main("--quota-retry-wake")
        self.assertEqual(rc, 2)
        self.assertIn("--quota-retry-wake requires --run-dir or --project-root", err)

    def test_wake_prints_asks_and_result(self):
        result = {"asks": ["a1", "a2"], "n": 1}
        with mock.patch.object(r.rfl_quota_retry, "wake_due_jobs", return_value=result) as w:
            rc, out, err = self.run_main("--quota-retry-wake", "--project-root", self.proj)
        self.assertEqual(rc, 0)
        self.assertEqual(json.loads(out), result)
        self.assertEqual(err, "[rfl] ASK: a1\n[rfl] ASK: a2\n")
        self.assertEqual(w.call_args[1]["project_root"], self.proj)
        with mock.patch.object(r.rfl_quota_retry, "wake_due_jobs", return_value={"asks": None}):
            rc, out, err = self.run_main("--quota-retry-wake", "--run-dir", self.proj)
        self.assertEqual((rc, err), (0, ""))

    def test_run_dir_required(self):
        for flag in ("--quota-retry-due", "--schedule-quota-retry", "--activate-quota-retry"):
            rc, out, err = self.run_main(flag)
            self.assertEqual(rc, 2, flag)
            self.assertIn("quota-retry / ladder-status commands require --run-dir", err)

    def test_mark_ladder_status(self):
        run = self.tmp / "run-1"
        run.mkdir()
        rc, out, _ = self.run_main("--mark-ladder-status", "active", "--run-dir", run,
                                   "--rung-id", "R2", "--current-phase", "rung_2",
                                   "--quota-now", "2026-01-02T03:04:05Z")
        self.assertEqual(rc, 0)
        data = json.loads(out)
        self.assertEqual(json.loads((run / "LADDER-STATUS.json").read_text())["status"], "active")
        self.assertIsInstance(data, dict)

    def test_mark_ladder_status_passes_none_for_empty_optionals(self):
        with mock.patch.object(r.rfl_quota_retry, "mark_ladder_status", return_value={"ok": 1}) as m:
            self.run_main("--mark-ladder-status", "completed", "--run-dir", self.tmp)
        self.assertEqual(m.call_args[0], (self.tmp, "completed"))
        self.assertIsNone(m.call_args[1]["current_rung"])
        self.assertIsNone(m.call_args[1]["current_phase"])

    def test_mark_ladder_status_value_error_returns_2(self):
        with mock.patch.object(r.rfl_quota_retry, "mark_ladder_status", side_effect=ValueError("bad status")):
            rc, out, err = self.run_main("--mark-ladder-status", "active", "--run-dir", self.tmp)
        self.assertEqual((rc, out), (2, ""))
        self.assertEqual(err, "ERROR: bad status\n")

    def test_quota_retry_due(self):
        with mock.patch.object(r.rfl_quota_retry, "due_quota_retries", return_value=[{"job": 1}]) as d:
            rc, out, _ = self.run_main("--quota-retry-due", "--run-dir", self.tmp)
        self.assertEqual((rc, json.loads(out)), (0, [{"job": 1}]))
        self.assertEqual(d.call_args[0], (self.tmp,))

    def test_schedule_and_activate_need_rung_and_model(self):
        for flag in ("--schedule-quota-retry", "--activate-quota-retry"):
            rc, _, err = self.run_main(flag, "--run-dir", self.tmp, "--model", "m")
            self.assertEqual(rc, 2)
            self.assertIn("quota-retry schedule/activate require --rung-id and --model", err)
            rc, _, err = self.run_main(flag, "--run-dir", self.tmp, "--rung-id", "R")
            self.assertEqual(rc, 2)

    def test_schedule_quota_retry(self):
        run = self.tmp / "run-xyz"
        with mock.patch.object(r.rfl_quota_claude5h, "schedule_quota_retry", return_value={"s": 1}) as s:
            rc, out, _ = self.run_main("--schedule-quota-retry", "--run-dir", run, "--rung-id", "R3",
                                       "--model", "opus", "--subscription-output", "limit", "--quota-host", "claude")
        self.assertEqual((rc, json.loads(out)), (0, {"s": 1}))
        kw = s.call_args[1]
        self.assertEqual((kw["run_id"], kw["rung"], kw["model"], kw["output"], kw["host"]),
                         ("run-xyz", "R3", "opus", "limit", "claude"))
        with mock.patch.object(r.rfl_quota_claude5h, "schedule_quota_retry", return_value={}) as s:
            self.run_main("--schedule-quota-retry", "--run-dir", run, "--rung-id", "R3", "--model", "m",
                          "--run-id", "explicit")
        self.assertEqual(s.call_args[1]["run_id"], "explicit")

    def test_activate_quota_retry_ask_user_goes_to_stderr(self):
        res = {"action": "ask_user", "ask": "Ladder is over; retry?"}
        with mock.patch.object(r.rfl_quota_retry, "activate_quota_retry", return_value=res):
            rc, out, err = self.run_main("--activate-quota-retry", "--run-dir", self.tmp, "--rung-id", "R", "--model", "m")
        self.assertEqual(rc, 0)
        self.assertEqual(json.loads(out), res)
        self.assertEqual(err, "[rfl] ASK: Ladder is over; retry?\n")

    def test_activate_quota_retry_other_actions_are_silent(self):
        for res in ({"action": "retry"}, {"action": "ask_user"}):
            with mock.patch.object(r.rfl_quota_retry, "activate_quota_retry", return_value=res):
                rc, out, err = self.run_main("--activate-quota-retry", "--run-dir", self.tmp,
                                             "--rung-id", "R", "--model", "m")
            self.assertEqual((rc, err), (0, ""))

    # ---- quota classification / launch decisions
    def test_classify_quota(self):
        rc, out, _ = self.run_main("--classify-quota", "--subscription-output", "rate limit")
        self.assertEqual(json.loads(out)["reason"], "quota-exhaustion")  # exit code defaults to 1
        rc, out, _ = self.run_main("--classify-quota", "--subscription-exit", "0")
        self.assertEqual(json.loads(out)["reason"], "success")
        f = self.tmp / "o.txt"
        f.write_text("command not found")
        rc, out, _ = self.run_main("--classify-quota", "--subscription-output-file", f)
        self.assertEqual(json.loads(out)["reason"], "missing-cli")

    def test_mark_quota_fallback(self):
        with mock.patch.dict(os.environ, {"SB_RUNTIME_STATE_DIR": str(self.tmp / "st")}):
            rc, out, _ = self.run_main("--mark-quota-fallback", "--quota-host", "codex", "--quota-signal", "429")
        data = json.loads(out)
        self.assertEqual((rc, data["subscription_quota_host"], data["subscription_quota_signal"]), (0, "codex", "429"))

    def test_decide_launch(self):
        rc, out, _ = self.run_main("--decide-launch", "--model", "gpt-5.5", "--reasoning", "high")
        self.assertEqual((rc, json.loads(out)["action"]), (0, "invoke_subscription"))
        rc, out, _ = self.run_main("--decide-launch", "--model", "gpt-5.5", "--reasoning", "high",
                                   "--subscription-exit", "1", "--subscription-output", "429")
        self.assertEqual(json.loads(out)["action"], "cursor_fallback")
        for argv in (("--model", "m"), ("--reasoning", "r"), ()):
            rc, out, err = self.run_main("--decide-launch", *argv)
            self.assertEqual(rc, 2)
            self.assertIn("--decide-launch requires --model and --reasoning", err)

    # ---- ladder output
    def test_json_output_default_host(self):
        rc, out, _ = self.run_main("--json", "--host", "claude")
        data = json.loads(out)
        self.assertEqual((rc, data["host"], data["total_rungs"]), (0, "claude", 9))

    def test_detected_host_is_used(self):
        with mock.patch.dict(os.environ, {"SILVER_BULLET_RUNTIME": "codex"}):
            rc, out, _ = self.run_main("--json", "--codex-home", self.tmp / "none")
        self.assertEqual(json.loads(out)["host"], "codex")

    def test_text_output_non_cursor(self):
        rc, out, _ = self.run_main("--host", "claude")
        lines = out.splitlines()
        self.assertEqual(lines[:4], ["host: claude", "source: fallback", "total_rungs: 9", "rungs:"])
        self.assertEqual(lines[4], "  1. claude-sonnet-4-6 / medium")

    def test_text_output_cursor_shows_subscription_hint_only_when_first(self):
        with mock.patch.dict(os.environ, {"SB_CURSOR_SB_AGENTS_SKIP_PROBE": "1"}):
            self.write_json(self.proj / ".silver-bullet.json", {"cursor_sb_agents": {
                "selected_models": ["composer-2.5", "gpt-5.5"], "effort_levels": ["low"]}})
            rc, out, _ = self.run_main("--host", "cursor", "--project-root", self.proj)
        lines = out.splitlines()
        self.assertIn("  1. composer-2.5 / low (delegation: custom-subagent, subagent: sb-composer-2-5-low, "
                      "model_param: composer-2.5)", lines)
        self.assertIn("  2. gpt-5.5 / low (delegation: custom-subagent, subagent: sb-gpt-5-5-low, "
                      "model_param: gpt-5.5, subscription_first: codex)", lines)

    def test_text_output_uses_len_when_total_missing(self):
        payload = {"host": "claude", "source": "x", "rungs": [{"model": "m", "reasoning": "r"}]}
        with mock.patch.object(r, "resolve_ladder", return_value=payload):
            rc, out, _ = self.run_main("--host", "claude")
        self.assertIn("total_rungs: 1", out)

    # ---- check-agents
    def test_check_agents_skips_non_cursor(self):
        rc, out, _ = self.run_main("--check-agents", "--host", "codex", "--codex-home", self.tmp / "x")
        self.assertEqual((rc, json.loads(out)), (0, {"ok": True, "skipped": True, "reason": "not cursor host"}))

    def test_check_agents_cursor_exit_codes(self):
        with mock.patch.dict(os.environ, {"SB_CURSOR_SB_AGENTS_SKIP_PROBE": "1"}):
            rc, out, _ = self.run_main("--check-agents", "--host", "cursor", "--project-root", self.proj)
            self.assertEqual(rc, 1)
            self.assertFalse(json.loads(out)["ok"])
            self.write_json(self.proj / ".silver-bullet.json", {"cursor_sb_agents": {
                "selected_models": ["composer-2.5"], "effort_levels": ["low"]}})
            (self.proj / ".cursor/agents").mkdir(parents=True)
            (self.proj / ".cursor/agents/sb-composer-2-5-low.md").write_text("x")
            rc, out, _ = self.run_main("--check-agents", "--host", "cursor", "--project-root", self.proj)
            self.assertEqual((rc, json.loads(out)["ok"]), (0, True))

    # ---- rung/phase
    def test_rung_phase(self):
        rc, out, _ = self.run_main("--host", "claude", "--rung", 2, "--phase", "verify_1")
        data = json.loads(out)
        self.assertEqual((rc, data["rung"], data["phase"], data["model"]), (0, 2, "verify_1", "claude-sonnet-4-6"))

    def test_rung_phase_must_be_paired(self):
        for argv in (("--rung", 1), ("--phase", "review")):
            rc, _, err = self.run_main("--host", "claude", *argv)
            self.assertEqual(rc, 2)
            self.assertIn("--rung and --phase must be used together", err)

    def test_rung_out_of_range(self):
        rc, out, err = self.run_main("--host", "claude", "--rung", 99, "--phase", "review")
        self.assertEqual((rc, out), (2, ""))
        self.assertIn("ERROR: rung index 99 out of range (1..9)", err)

    def test_invalid_phase_choice_rejected_by_argparse(self):
        rc, _, err = self.run_main("--host", "claude", "--rung", 1, "--phase", "bogus")
        self.assertEqual(rc, 2)
        self.assertIn("invalid choice", err)

    def test_entrypoint(self):
        out = io.StringIO()
        with mock.patch.object(sys, "argv", ["x", "--json", "--host", "claude"]), contextlib.redirect_stdout(out):
            with self.assertRaises(SystemExit) as cm:
                runpy.run_path(str(REPO_ROOT / "scripts" / "_review_fix_ladder_impl.py"), run_name="__main__")
        self.assertEqual(cm.exception.code, 0)
        self.assertEqual(json.loads(out.getvalue())["host"], "claude")


if __name__ == "__main__":
    unittest.main()
