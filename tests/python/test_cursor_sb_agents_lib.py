"""Unit tests for scripts/lib/cursor-sb-agents/cursor_sb_agents_lib.py."""
from __future__ import annotations

import contextlib
import io
import json
import subprocess
import tempfile
import unittest
import urllib.error
from pathlib import Path
from unittest import mock

from sbtest import load_module

lib = load_module("scripts/lib/cursor-sb-agents/cursor_sb_agents_lib.py")

TABLE = """\
# Models

| Model | Provider | Input | Cache Write | Cache Read | Output | Notes |
| --- | --- | --- | --- | --- | --- | --- |

| [Composer 2.5](https://x/y) | Cursor | $0.50 | - | $0.05 | $2.50 | fast |
| Auto | Cursor | - | - | - | - | |
| too | few | cols |
|  | Cursor | 1 | 1 | 1 | 1 | |
| Grok 4.5 | xAI | $2.00 | - | $0.20 | $10.00 | Requires Max Mode |
| Claude Opus 5 | Anthropic | n/a | | $1 | bogus | |

| Late | Cursor | 1 | 1 | 1 | 1 | |
"""


def model(mid, **kw):
    entry = {"id": mid, "agent_ids": [mid], "pricing": {}}
    entry.update(kw)
    return entry


class SmallHelpersTest(unittest.TestCase):
    def test_default_config_returns_fresh_lists(self):
        a, b = lib.default_config(), lib.default_config()
        a["selected_models"].append("x")
        a["effort_levels"].append("y")
        self.assertEqual(b["selected_models"], lib.DEFAULT_SELECTED_MODELS)
        self.assertEqual(b["effort_levels"], lib.DEFAULT_EFFORT_LEVELS)
        self.assertIs(b["enabled_by_user"], None)
        self.assertIs(b["include_fast"], False)
        self.assertIs(b["include_max"], False)
        self.assertIs(b["enabled"], True)
        self.assertEqual(b["agent_name_prefix"], "sb")

    def test_sanitize_and_agent_name(self):
        self.assertEqual(lib.sanitize_model("grok_4.5"), "grok-4-5")
        self.assertEqual(lib.agent_name("composer-2.5", "high"), "sb-composer-2-5-high")
        self.assertEqual(lib.agent_name("m", "low", "px"), "px-m-low")

    def test_fast_max_low_detection(self):
        self.assertTrue(lib.is_fast_id("gpt-5.5-fast-high"))
        self.assertTrue(lib.is_fast_id("fast"))
        self.assertFalse(lib.is_fast_id("breakfast-high"))
        self.assertTrue(lib.is_max_id("foo-max"))
        self.assertTrue(lib.is_max_id("foo[context=1m]"))
        self.assertTrue(lib.is_max_id("foo", "Requires MAX mode here"))
        self.assertFalse(lib.is_max_id("foo", "plain"))
        self.assertFalse(lib.is_max_id("foo"))
        self.assertTrue(lib.is_low_effort_slug("x-low"))
        self.assertTrue(lib.is_low_effort_slug("x-low-fast"))
        self.assertFalse(lib.is_low_effort_slug("x-lower"))

    def test_pool_and_price(self):
        self.assertEqual(lib.pool_for_provider(" Cursor "), "first-party")
        self.assertEqual(lib.pool_for_provider("OpenAI"), "api")
        self.assertEqual(lib.parse_price("$1.25"), 1.25)
        self.assertEqual(lib.parse_price(" 3 "), 3.0)
        self.assertIsNone(lib.parse_price(""))
        self.assertIsNone(lib.parse_price("-"))
        self.assertIsNone(lib.parse_price("n/a"))

    def test_slugify(self):
        self.assertEqual(lib.slugify_display_name("Cursor Composer 2.5"), "composer-2.5")
        self.assertEqual(lib.slugify_display_name("Composer 1"), "composer-1")
        self.assertEqual(lib.slugify_display_name("GPT-5.5"), "gpt-5.5")
        self.assertEqual(lib.slugify_display_name("Claude Opus 5 (x)"), "claude-opus-5-x")
        self.assertEqual(lib.slugify_display_name("  "), "")


class DocsTest(unittest.TestCase):
    def test_fetch_docs_markdown_uses_request_headers_and_decodes(self):
        resp = mock.MagicMock()
        resp.__enter__.return_value = resp
        resp.read.return_value = b"ok \xff"
        with mock.patch.object(lib.urllib.request, "urlopen", return_value=resp) as uo:
            text = lib.fetch_docs_markdown()
        self.assertEqual(text, "ok �")
        req = uo.call_args.args[0]
        self.assertEqual(req.full_url, lib.DOCS_URL)
        self.assertEqual(req.get_header("User-agent"), "silver-bullet/cursor-sb-agents/1.0")
        self.assertEqual(uo.call_args.kwargs["timeout"], 60)

    def test_parse_pricing_table(self):
        pricing = lib.parse_pricing_table(TABLE)
        self.assertEqual(sorted(pricing), ["claude-opus-5", "composer-2.5", "grok-4.5"])
        comp = pricing["composer-2.5"]
        self.assertEqual(comp["pool"], "first-party")
        self.assertEqual(comp["display_name"], "Composer 2.5")
        self.assertEqual(comp["notes"], "fast")
        self.assertEqual(comp["pricing"], {
            "input": 0.5, "cache_write": None, "cache_read": 0.05, "output": 2.5,
            "unit": "per_1M"})
        self.assertEqual(pricing["grok-4.5"]["pool"], "api")
        self.assertEqual(pricing["claude-opus-5"]["notes"], "")
        self.assertIsNone(pricing["claude-opus-5"]["pricing"]["input"])
        self.assertIsNone(pricing["claude-opus-5"]["pricing"]["output"])

    def test_parse_pricing_table_without_table(self):
        self.assertEqual(lib.parse_pricing_table("no table here\n| x | y |\n"), {})
        self.assertEqual(lib.parse_pricing_table(""), {})


class AgentModelsTest(unittest.TestCase):
    def proc(self, rc=0, out=""):
        return subprocess.CompletedProcess([], rc, stdout=out, stderr="")

    def test_parse_output(self):
        text = "Available models\n\nauto - Auto\nnot a model line\ncomposer-2.5 - Composer 2.5 \n x-high - X High\n"
        self.assertEqual(lib.parse_agent_models_output(text), [
            {"id": "composer-2.5", "display_name": "Composer 2.5"},
            {"id": "x-high", "display_name": "X High"},
        ])
        self.assertEqual(lib.parse_agent_models_output(""), [])

    def test_first_cli_success(self):
        with mock.patch.object(lib.subprocess, "run",
                               return_value=self.proc(0, "a - A\n")) as run:
            self.assertEqual(lib.run_agent_models(), ([{"id": "a", "display_name": "A"}], "agent"))
        self.assertEqual(run.call_count, 1)
        self.assertEqual(run.call_args.args[0], ["agent", "models"])

    def test_falls_back_through_failures_to_cursor_agent(self):
        side = [FileNotFoundError(), self.proc(0, "a - A\n")]
        with mock.patch.object(lib.subprocess, "run", side_effect=side):
            self.assertEqual(lib.run_agent_models()[1], "cursor-agent")

    def test_subprocess_invocation_is_bounded_and_captured(self):
        with mock.patch.object(lib.subprocess, "run", return_value=self.proc(0, "a - A\n")) as run:
            lib.run_agent_models()
        self.assertEqual(run.call_args.kwargs, {
            "capture_output": True, "text": True, "check": False, "timeout": 120})

    def test_nonzero_empty_and_timeout_yield_nothing(self):
        for side in (
            [self.proc(1, "a - A\n"), self.proc(2, "a - A\n")],
            [self.proc(0, "garbage\n"), self.proc(0, "")],
            [subprocess.TimeoutExpired("agent", 1), FileNotFoundError()],
        ):
            with mock.patch.object(lib.subprocess, "run", side_effect=side):
                self.assertEqual(lib.run_agent_models(), ([], ""))


class SlugTest(unittest.TestCase):
    def test_base_model_from_slug(self):
        cases = {
            "composer-2.5": "composer-2.5",
            "composer-2.5-fast": "composer-2.5",
            "cursor-grok-4.5-high": "grok-4.5",
            "grok-4.5-xhigh": "grok-4.5",
            "cursor-grok-4.6-low-fast": "grok-4.6",
            "grok-4.6-high": "grok-4.6",
            "claude-opus-5-thinking-high": "claude-opus-5",
            "claude-opus-5-thinking-max": "claude-opus-5",
            "gpt-5.5-extra-high": "gpt-5.5",
            "gpt-5.5-xhigh": "gpt-5.5",
            "gpt-5.5-none": "gpt-5.5",
            "gpt-5.5-fast-high": "gpt-5.5-fast",
            "gpt-5.5[context=1m]": "gpt-5.5",
            "plain-model": "plain-model",
        }
        for slug, base in cases.items():
            self.assertEqual(lib.base_model_from_slug(slug), base, slug)

    def test_effort_from_slug(self):
        e = lib.effort_from_slug
        self.assertIsNone(e("composer-2.5", "composer-2.5"))
        self.assertIsNone(e("composer-1", "composer-1"))
        self.assertEqual(e("cursor-grok-4.5-low", "grok-4.5"), "low")
        self.assertEqual(e("cursor-grok-4.5-high-fast", "grok-4.5"), "high")
        self.assertEqual(e("grok-4.5-medium", "grok-4.5"), "medium")
        self.assertEqual(e("grok-4.5-fast-xhigh", "grok-4.5"), "xhigh")
        self.assertEqual(e("grok-4.5-fast-medium", "grok-4.5"), "medium")
        self.assertIsNone(e("grok-4.5-bogus", "grok-4.5"))
        self.assertEqual(e("cursor-grok-4.6-xhigh", "grok-4.6"), "xhigh")
        self.assertEqual(e("cursor-grok-4.6-medium-fast", "grok-4.6"), "medium")
        self.assertIsNone(e("grok-4.6-xhigh", "grok-4.6"))
        self.assertEqual(e("gpt-5.5-high", "gpt-5.5"), "high")
        self.assertEqual(e("gpt-5.5-fast-low", "gpt-5.5"), "low")
        self.assertEqual(e("gpt-5.5-extra-high", "gpt-5.5"), "xhigh")
        self.assertEqual(e("gpt-5.5-none", "gpt-5.5"), "medium")
        self.assertEqual(e("opus-thinking-max", "opus"), "max")
        self.assertEqual(e("opus-thinking-medium", "opus"), "medium")
        self.assertIsNone(e("gpt-5.5", "gpt-5.5"))
        self.assertIsNone(e("gpt-5.5-weird", "gpt-5.5"))


class CatalogTest(unittest.TestCase):
    def build(self, docs, entries):
        fake_dt = mock.Mock()
        fake_dt.now.return_value.isoformat.return_value = "2030-01-01T00:00:00+00:00"
        with mock.patch.object(lib, "datetime", fake_dt):
            return lib.build_catalog(docs, entries)

    def test_build_catalog_merges_docs_and_agent_entries(self):
        docs = lib.parse_pricing_table(TABLE)
        docs["only-docs"] = {
            "id": "only-docs", "display_name": "Only Docs", "provider": "X", "pool": "api",
            "pricing": {"input": 1.0}, "notes": "requires max mode"}
        entries = [
            {"id": "composer-2.5", "display_name": "C"},
            {"id": "composer-2.5-fast", "display_name": "CF"},
            {"id": "cursor-grok-4.5-high", "display_name": "G"},
            {"id": "cursor-grok-4.6-low", "display_name": "G6"},
            {"id": "gpt-9-high", "display_name": "G9"},
            {"id": "gpt-9-low", "display_name": "G9"},
            {"id": "gpt-9-high-dup", "display_name": "x"},
            {"id": "gpt-9-xhigh", "display_name": "G9"},
            {"id": "gpt-9-max", "display_name": "G9"},
            {"id": "gpt-9-high", "display_name": "dup"},
            {"id": "odd[context=1m]", "display_name": "O"},
        ]
        cat = self.build(docs, entries)
        self.assertEqual(cat["fetched_at"], "2030-01-01T00:00:00+00:00")
        self.assertEqual(cat["source"], "agent-models+docs")
        self.assertEqual(cat["agent_cli"], "agent")
        by = {m["id"]: m for m in cat["models"]}
        self.assertEqual([m["id"] for m in cat["models"]], sorted(by))
        self.assertEqual(by["composer-2.5"]["effort_values"], ["medium", "high", "xhigh"])
        self.assertEqual(by["composer-2.5"]["agent_ids"], ["composer-2.5", "composer-2.5-fast"])
        self.assertTrue(by["composer-2.5"]["fast_available"])
        self.assertEqual(by["composer-2.5"]["provider"], "Cursor")
        self.assertEqual(by["grok-4.5"]["effort_values"], ["medium", "high", "xhigh"])
        self.assertTrue(by["grok-4.5"]["max_detected"])  # notes: Requires Max Mode
        self.assertEqual(by["grok-4.6"]["provider"], "Unknown")
        self.assertEqual(by["grok-4.6"]["pricing"]["unit"], "per_1M")
        self.assertEqual(by["gpt-9"]["effort_values"], ["high", "xhigh", "max"])
        self.assertTrue(by["gpt-9"]["max_detected"])
        self.assertEqual(by["gpt-9"]["pool"], "api")
        self.assertTrue(by["odd"]["max_detected"])
        self.assertEqual(by["only-docs"]["agent_ids"], [])
        self.assertTrue(by["only-docs"]["max_detected"])
        self.assertFalse(by["claude-opus-5"]["max_detected"])
        self.assertEqual(by["claude-opus-5"]["effort_values"], [])

    def test_docs_only_catalog(self):
        cat = self.build({}, [])
        self.assertEqual(cat["source"], "docs-only")
        self.assertIsNone(cat["agent_cli"])
        self.assertEqual(cat["models"], [])

    def test_filter_selectable_models(self):
        catalog = {"source": "agent-models+docs", "models": [
            model("auto"),
            model("plain"),
            model("maxed", max_detected=True),
            model("x-max"),
            model("noagents", agent_ids=[]),
            model("noted", notes="Requires Max Mode"),
            model("gpt-fast", fast_available=True),
        ]}
        ids = lambda **kw: [m["id"] for m in lib.filter_selectable_models(catalog, **kw)]
        self.assertEqual(ids(), ["plain"])
        self.assertEqual(ids(include_max=True), ["plain", "maxed", "x-max", "noted"])
        self.assertEqual(ids(include_fast=True, include_max=True),
                         ["plain", "maxed", "x-max", "noted", "gpt-fast"])
        # "gpt-fast" has base id that is a fast id: skipped unless include_fast
        self.assertNotIn("gpt-fast", ids())
        docs_only = {"source": "docs-only", "models": [model("noagents", agent_ids=[])]}
        self.assertEqual([m["id"] for m in lib.filter_selectable_models(docs_only)], ["noagents"])
        self.assertEqual(lib.filter_selectable_models({}), [])


class ResolveTest(unittest.TestCase):
    def test_builtin_and_config_maps(self):
        r = lib.resolve_model_param
        self.assertEqual(r("opus-5", "high"), "claude-opus-5-thinking-high")
        self.assertEqual(r("glm-5.2", "xhigh"), "glm-5.2-max")
        cfg = {"rfl_effort_maps": {"opus-5": {"high": "custom"}, "new": {"low": "n-low"}}}
        self.assertEqual(r("opus-5", "high", config=cfg), "custom")
        self.assertEqual(r("new", "low", config=cfg), "n-low")
        self.assertEqual(r("opus-5", "medium", config=cfg), "opus-5")  # override replaces map
        self.assertEqual(r("opus-5", "high", config={"rfl_effort_maps": None}),
                         "claude-opus-5-thinking-high")
        self.assertEqual(r("opus-5", "high", config={}), "claude-opus-5-thinking-high")
        # builtin map missing the effort falls through to the generic path
        self.assertEqual(r("opus-5", "low"), "opus-5")
        # builtin table is not mutated by config merges
        self.assertIn("medium", lib.BUILTIN_EFFORT_MAPS["opus-5"])
        self.assertNotIn("new", lib.BUILTIN_EFFORT_MAPS)

    def test_composer(self):
        r = lib.resolve_model_param
        self.assertEqual(r("composer-2.5-fast", "high", include_fast=True), "composer-2.5-fast")
        self.assertEqual(r("composer-2.5-fast", "high"), "composer-2.5")
        self.assertEqual(r("composer-2.7", "high", include_fast=True), "composer-2.5")
        self.assertEqual(r("composer-1", "high"), "composer-1")

    def test_grok(self):
        r = lib.resolve_model_param
        self.assertEqual(r("grok-4.5", "high"), "cursor-grok-4.5-high")
        self.assertEqual(r("grok-4.5", "max"), "grok-4.5-max")
        self.assertEqual(r("grok-4.5", "xhigh", include_fast=True), "grok-4.5-fast-xhigh")
        self.assertEqual(r("grok-4.5", "max", include_fast=True), "grok-4.5-fast-max")
        self.assertEqual(r("grok-4.6", "xhigh"), "cursor-grok-4.6-xhigh")
        self.assertEqual(r("grok-4.6", "max"), "cursor-grok-4.6-max")
        self.assertEqual(r("grok-4.6", "low", include_fast=True), "cursor-grok-4.6-low-fast")
        self.assertEqual(r("grok-4.6", "max", include_fast=True), "cursor-grok-4.6-max-fast")

    def test_generic_catalog_lookups(self):
        r = lib.resolve_model_param
        cat = {"models": [
            model("gpt-5.5", agent_ids=["gpt-5.5-high", "gpt-5.5-fast-high", "gpt-5.5"]),
            model("br", agent_ids=["br[effort=high]"]),
            model("first", agent_ids=["first-default"]),
            model("empty", agent_ids=[]),
        ]}
        self.assertEqual(r("gpt-5.5", "high", cat, include_fast=True), "gpt-5.5-fast-high")
        self.assertEqual(r("gpt-5.5", "high", cat), "gpt-5.5-high")
        self.assertEqual(r("gpt-5.5", "medium", cat, include_fast=True), "gpt-5.5-high")  # first agent id
        self.assertEqual(r("br", "high", cat), "br[effort=high]")
        self.assertEqual(r("first", "high", cat), "first-default")
        self.assertEqual(r("empty", "high", cat), "empty")
        self.assertEqual(r("missing", "high", cat), "missing")
        self.assertEqual(r("missing", "high", None, include_fast=True), "missing")
        self.assertEqual(r("missing", "high", {}), "missing")

    def test_id_in_catalog(self):
        cat = {"models": [{"id": "a", "agent_ids": ["a-high"]}, {"id": "b"}]}
        self.assertTrue(lib.id_in_catalog("a-high", cat))
        self.assertTrue(lib.id_in_catalog("b", cat))
        self.assertFalse(lib.id_in_catalog("c", cat))
        self.assertFalse(lib.id_in_catalog("c", {}))


class ConfigDerivedTest(unittest.TestCase):
    def test_efforts_for_model(self):
        f = lib.efforts_for_model
        self.assertEqual(f({"rfl_effort_maps": {"m": {"a": "x", "b": "y"}}}, "m"), ["a", "b"])
        self.assertEqual(f({"rfl_effort_maps": {"m": {}}}, "m"), lib.DEFAULT_EFFORT_LEVELS)
        self.assertEqual(f({}, "m"), ["medium", "high", "xhigh"])
        self.assertEqual(f({"effort_levels": ["low"]}, "m"), ["low"])
        self.assertEqual(f({"include_max": True}, "opus-5"), ["medium", "high", "xhigh", "max"])
        self.assertEqual(f({"include_max": True, "effort_levels": ["max"]}, "opus-5"), ["max"])
        self.assertEqual(f({"include_max": True}, "composer-2.5"), ["medium", "high", "xhigh"])
        self.assertEqual(f({"include_max": False}, "opus-5"), ["medium", "high", "xhigh"])
        cfg = {"effort_levels": ["high"]}
        f(cfg, "m")
        self.assertEqual(cfg["effort_levels"], ["high"])

    def test_expected_names_and_params(self):
        cfg = {"selected_models": ["grok-4.5", "opus-5"], "effort_levels": ["high"],
               "agent_name_prefix": "px"}
        self.assertEqual(lib.expected_agent_names(cfg), ["px-grok-4-5-high", "px-opus-5-high"])
        self.assertEqual(lib.expected_model_params(cfg, {}), {
            "px-grok-4-5-high": "cursor-grok-4.5-high",
            "px-opus-5-high": "claude-opus-5-thinking-high"})
        self.assertEqual(lib.expected_agent_names({}), [])
        cfg2 = {"selected_models": ["grok-4.5"], "effort_levels": ["high"], "include_fast": True}
        self.assertEqual(lib.expected_model_params(cfg2, {}),
                         {"sb-grok-4-5-high": "cursor-grok-4.5-high-fast"})


class FormatTest(unittest.TestCase):
    def test_pricing_label(self):
        f = lib.format_pricing_label
        self.assertEqual(
            f({"pricing": {"input": 1, "cache_read": 0.1, "output": 5.5}, "pool": "api"}),
            "$1.00 in / $0.10 cache / $5.50 out (api) (per 1M)")
        self.assertEqual(f({"pricing": {"output": 2}}), "$2.00 out (api) (per 1M)")
        self.assertEqual(f({"pricing": {}, "pool": "first-party"}), "first-party")
        self.assertEqual(f({}), "")

    def test_render_agent_markdown(self):
        tpl = "name: {{AGENT_NAME}}\nd: {{DESCRIPTION}}\nm: {{MODEL_PARAM}}\n{{BODY}}\n"
        out = lib.render_agent_markdown("sb-x", "gpt-5.5", "high", "gpt-5.5-high", tpl)
        self.assertIn("name: sb-x", out)
        self.assertIn("SB reusable ladder agent — gpt-5.5 effort=high (Cursor slug gpt-5.5-high).", out)
        self.assertIn("review/verify agent at gpt-5.5 / high.", out)
        self.assertIn("Do not triage or fix.", out)
        self.assertNotIn("{{", out)
        self.assertTrue(out.endswith(lib.MANAGED_MARKER + "\n"))
        same = lib.render_agent_markdown("n", "m", "high", "m", tpl)
        self.assertIn("effort=high.", same)
        opus = lib.render_agent_markdown("n", "opus-5", "high", "claude-opus-5-thinking-high", tpl)
        self.assertIn("opus-5 thinking effort=high (Cursor slug", opus)
        self.assertIn("unless the brief says incorporate/fix", opus)
        mapped = lib.render_agent_markdown("n", "glm-5.2", "xhigh", "glm-5.2-max", tpl)
        self.assertIn("effort=xhigh (mapped to max)", mapped)
        self.assertIn("unless the brief says incorporate/fix", mapped)
        notmapped = lib.render_agent_markdown("n", "glm-5.2", "high", "glm-5.2-max", tpl)
        self.assertNotIn("mapped to max", notmapped)
        marked = lib.render_agent_markdown("n", "m", "high", "m", tpl + lib.MANAGED_MARKER)
        self.assertEqual(marked.count(lib.MANAGED_MARKER), 1)
        self.assertTrue(marked.endswith(lib.MANAGED_MARKER))


class IoTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.tmp = Path(self._tmp.name)

    def test_load_and_write_json(self):
        self.assertEqual(lib.load_json(self.tmp / "none.json"), {})
        self.assertEqual(lib.load_json(str(self.tmp)), {})  # directory is not a file
        target = self.tmp / "a" / "b" / "c.json"
        lib.write_json(str(target), {"k": [1]})
        self.assertEqual(target.read_text(), '{\n  "k": [\n    1\n  ]\n}\n')
        self.assertEqual(lib.load_json(str(target)), {"k": [1]})
        self.assertEqual(lib.load_json(target), {"k": [1]})
        lib.write_json(target, {})
        self.assertEqual(target.read_text(), "{}\n")

    def test_load_json_malformed_raises(self):
        bad = self.tmp / "bad.json"
        bad.write_text("{x")
        with self.assertRaises(ValueError):
            lib.load_json(bad)

    def test_frontmatter_name_and_marker(self):
        f = self.tmp / "agent.md"
        self.assertIsNone(lib.frontmatter_name(f))
        self.assertFalse(lib.has_managed_marker(f))
        f.write_text("no frontmatter")
        self.assertIsNone(lib.frontmatter_name(f))
        f.write_text("---\nname: abc\n")
        self.assertIsNone(lib.frontmatter_name(f))
        f.write_text("---\ndescription: x\n---\nbody name: no\n")
        self.assertIsNone(lib.frontmatter_name(f))
        f.write_text("---\ndescription: x\nname:  sb-agent \n---\nbody\n")
        self.assertEqual(lib.frontmatter_name(f), "sb-agent")
        self.assertFalse(lib.has_managed_marker(f))
        f.write_text("x\n" + lib.MANAGED_MARKER)
        self.assertTrue(lib.has_managed_marker(f))


class FetchAndCacheTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.tmp = Path(self._tmp.name)
        self.g = self.tmp / "global.json"
        self.p = self.tmp / "proj" / "cache.json"

    def run_fetch(self, *, markdown=TABLE, fetch_exc=None, entries=(), cli="", project=True):
        err = io.StringIO()
        fetch = mock.Mock(side_effect=fetch_exc) if fetch_exc else mock.Mock(return_value=markdown)
        with mock.patch.object(lib, "fetch_docs_markdown", fetch), \
             mock.patch.object(lib, "run_agent_models", return_value=(list(entries), cli)), \
             contextlib.redirect_stderr(err):
            cat = lib.fetch_and_cache_catalog(self.g, self.p if project else None)
        return cat, err.getvalue()

    def test_success_writes_both_caches(self):
        cat, err = self.run_fetch(entries=[{"id": "gpt-9-high", "display_name": "G"}], cli="agent")
        self.assertEqual(err, "")
        self.assertEqual(cat["agent_cli"], "agent")
        self.assertEqual(json.loads(self.g.read_text()), cat)
        self.assertEqual(json.loads(self.p.read_text()), cat)

    def test_global_only_when_no_project_cache(self):
        self.run_fetch(project=False)
        self.assertTrue(self.g.is_file())
        self.assertFalse(self.p.exists())

    def test_cursor_agent_cli_reported(self):
        cat, _ = self.run_fetch(entries=[{"id": "gpt-9-high", "display_name": "G"}],
                                cli="cursor-agent")
        self.assertEqual(cat["agent_cli"], "cursor-agent")

    def test_fetch_failure_warns_and_continues_with_agent_models(self):
        for exc in (urllib.error.URLError("down"), TimeoutError("slow")):
            cat, err = self.run_fetch(
                fetch_exc=exc, entries=[{"id": "gpt-9-high", "display_name": "G"}], cli="agent")
            self.assertIn("WARN: docs fetch failed:", err)
            self.assertEqual([m["id"] for m in cat["models"]], ["gpt-9"])

    def test_empty_refresh_keeps_cached_global_catalog(self):
        cached = {"models": [{"id": "old"}], "source": "cached"}
        lib.write_json(self.g, cached)
        cat, err = self.run_fetch(fetch_exc=urllib.error.URLError("down"))
        self.assertEqual(cat, cached)
        self.assertIn(f"keeping cached catalog {self.g}", err)
        self.assertEqual(json.loads(self.g.read_text()), cached)  # not overwritten
        self.assertFalse(self.p.exists())

    def test_empty_refresh_falls_back_to_project_cache(self):
        lib.write_json(self.g, {"models": []})
        cached = {"models": [{"id": "proj"}]}
        lib.write_json(self.p, cached)
        cat, err = self.run_fetch(fetch_exc=urllib.error.URLError("down"))
        self.assertEqual(cat, cached)
        self.assertIn(str(self.p), err)

    def test_corrupt_or_non_object_cache_is_skipped(self):
        self.g.write_text("{corrupt")
        cached = {"models": [{"id": "proj"}]}
        lib.write_json(self.p, cached)
        cat, _ = self.run_fetch(fetch_exc=urllib.error.URLError("down"))
        self.assertEqual(cat, cached)
        self.g.write_text("[]")
        cat, _ = self.run_fetch(fetch_exc=urllib.error.URLError("down"))
        self.assertEqual(cat, cached)

    def test_oserror_reading_cache_is_skipped(self):
        cached = {"models": [{"id": "proj"}]}
        lib.write_json(self.p, cached)
        real = lib.load_json

        def flaky(path):
            if Path(path) == self.g:
                raise OSError("io")
            return real(path)

        with mock.patch.object(lib, "load_json", flaky):
            cat, _ = self.run_fetch(fetch_exc=urllib.error.URLError("down"))
        self.assertEqual(cat, cached)

    def test_empty_refresh_without_cache_writes_empty_catalog(self):
        cat, err = self.run_fetch(fetch_exc=urllib.error.URLError("down"), project=False)
        self.assertEqual(cat["models"], [])
        self.assertEqual(cat["source"], "docs-only")
        self.assertNotIn("keeping cached", err)
        self.assertEqual(json.loads(self.g.read_text())["models"], [])

    def test_empty_refresh_ignores_cache_with_no_models(self):
        lib.write_json(self.g, {"models": []})
        cat, _ = self.run_fetch(fetch_exc=urllib.error.URLError("down"))
        self.assertEqual(cat["models"], [])
        self.assertEqual(json.loads(self.p.read_text())["models"], [])


if __name__ == "__main__":
    unittest.main()
