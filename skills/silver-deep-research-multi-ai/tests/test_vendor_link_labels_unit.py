"""Offline unit tests for vendor_link_labels: rewrites, scrubbing, health probes, linkify."""

from __future__ import annotations

import os
import socket
import sys
import unittest
import urllib.error
from pathlib import Path
from unittest import mock

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS))

import vendor_link_labels as vll  # noqa: E402


class _Resp:
    """Context-manager stand-in for the object urllib.request.urlopen returns."""

    def __init__(self, status=200, url="https://final.example/"):
        self.status = status
        self._url = url

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        return False

    def geturl(self):
        return self._url


class _NoStatusResp(_Resp):
    def __init__(self, url):
        super().__init__(0, url)
        del self.status  # getattr(resp, "status", 200) default path


def _http_error(code):
    return urllib.error.HTTPError("https://x.example/", code, "msg", {}, None)


class _NoNetwork(unittest.TestCase):
    """Fail the test if any socket connection is attempted."""

    def setUp(self):
        self._saved = {k: os.environ.get(k) for k in (
            "SB_SKIP_VENDOR_URL_HEALTH", "SB_VENDOR_URL_HEALTH_STRICT",
            "HTTPS_PROXY", "HTTP_PROXY")}
        os.environ.pop("SB_SKIP_VENDOR_URL_HEALTH", None)
        os.environ.pop("SB_VENDOR_URL_HEALTH_STRICT", None)
        os.environ["HTTPS_PROXY"] = os.environ["HTTP_PROXY"] = "http://127.0.0.1:9"
        spy = mock.patch.object(
            socket.socket, "connect", side_effect=AssertionError("network used"))
        spy.start()
        self.addCleanup(spy.stop)
        self.addCleanup(self._restore)

    def _restore(self):
        for k, v in self._saved.items():
            if v is None:
                os.environ.pop(k, None)
            else:
                os.environ[k] = v


class RewriteTests(unittest.TestCase):
    def test_normalize_key(self):
        self.assertEqual(vll.normalize_vendor_url_key(" https://a.b/ "), "https://a.b")
        self.assertEqual(vll.normalize_vendor_url_key(None), "")

    def test_rewrite_branches(self):
        r = vll.rewrite_vendor_url
        self.assertIsNone(r(""))
        self.assertIsNone(r(None))
        self.assertEqual(r("https://agentsys.ai"), "https://github.com/agent-sh/agentsys")
        self.assertIsNone(r("https://deepwork.ai/"))
        # normalized key match (trailing slash form not literally present)
        self.assertEqual(
            r("https://github.com/ai-dlc/ai-dlc/"), "https://github.com/awslabs/aidlc-workflows")
        # substring rules
        self.assertEqual(
            r("https://WWW.AgentSys.ai/docs"), "https://github.com/agent-sh/agentsys")
        self.assertEqual(
            r("https://aws.amazon.com/ai-dlc/getting-started"),
            "https://github.com/awslabs/aidlc-workflows")
        self.assertEqual(
            r("https://developer.ibm.com/x/ai-driven-development-other"),
            "https://github.com/awslabs/aidlc-workflows")
        self.assertIsNone(r("https://www.DeepWork.ai"))
        self.assertEqual(
            r("https://github.com/Zuvo-AI/zuvo/"), "https://github.com/greglas75/zuvo")
        self.assertEqual(r("https://github.com/agent-sh/agentsys.ai"),
                         "https://github.com/agent-sh/agentsys.ai")
        self.assertEqual(r(" https://example.com/ok "), "https://example.com/ok")
        # developer.ibm.com without the article keyword is left alone
        self.assertEqual(r("https://developer.ibm.com/other"), "https://developer.ibm.com/other")


class ScrubEmbeddedTests(unittest.TestCase):
    def test_strings(self):
        s = vll.scrub_embedded_vendor_urls
        self.assertEqual(s("https://deepwork.ai"), "")
        self.assertEqual(s("http://agentsys.ai"), "https://github.com/agent-sh/agentsys")
        self.assertEqual(s("plain text"), "plain text")
        out = s("AI-DLC — AI-Driven Development Lifecycle (developer.ibm.com / community)")
        self.assertIn("AWS Labs", out)
        out = s("see https://developer.ibm.com/articles/ai-driven-development-life-cycle/ and "
                "AI-DLC (IBM) plus IBM's AI-DLC")
        self.assertIn("https://github.com/awslabs/aidlc-workflows", out)
        self.assertIn("AI-DLC (AWS / awslabs)", out)
        self.assertIn("AWS AI-DLC", out)

    def test_scalars_pass_through(self):
        self.assertEqual(vll.scrub_embedded_vendor_urls(5), 5)
        self.assertIsNone(vll.scrub_embedded_vendor_urls(None))

    def test_list_filters_none_items(self):
        got = vll.scrub_embedded_vendor_urls(
            [{"title": "Claude Code Expert"}, {"name": "ok"}, 3])
        self.assertEqual(got, [{"name": "ok"}, 3])

    def test_dict_rules(self):
        s = vll.scrub_embedded_vendor_urls
        self.assertIsNone(s({"title": "The Claude  Code Expert"}))
        out = s({
            "url": "https://claude-code-expert.dev/x",
            "homepage": "https://agentsys.ai",
            "href": "https://deepwork.ai",
            "source_ref": "not-http AI-DLC (IBM)",
            "claim": "Claude Code Expert is a primary-market APO candidate for X. tail",
            "text": "IBM's AI-DLC",
            "relevance": "fine",
            "nested": {"url": "https://aws.amazon.com/ai-dlc"},
            "dropme": None,
            "num": 1,
            "url2": "x",
        })
        self.assertIsNone(out["url"])
        self.assertEqual(out["homepage"], "https://github.com/agent-sh/agentsys")
        self.assertIsNone(out["href"])
        self.assertEqual(out["source_ref"], "not-http AI-DLC (AWS / awslabs)")
        self.assertIn("is excluded (invented/sunset seed", out["claim"])
        self.assertIn("tail", out["claim"])
        self.assertEqual(out["text"], "AWS AI-DLC")
        self.assertEqual(out["nested"]["url"], "https://github.com/awslabs/aidlc-workflows")
        self.assertNotIn("dropme", out)
        self.assertEqual(out["num"], 1)

    def test_url_key_with_non_string_value_is_recursed(self):
        out = vll.scrub_embedded_vendor_urls({"url": None, "title": "t"})
        self.assertEqual(out, {"title": "t"})  # None scrubbed value is dropped


class LabelTests(unittest.TestCase):
    def test_generic_labels(self):
        g = vll.is_generic_link_label
        self.assertTrue(g(""))
        self.assertTrue(g(None))
        self.assertTrue(g("SDLC"))
        self.assertTrue(g("ABCD"))
        self.assertFalse(g("BMAD"))
        self.assertFalse(g("ABCDE"))
        self.assertFalse(g("Cursor"))

    def test_resolve(self):
        r = vll.resolve_vendor_link_label
        self.assertEqual(r("sdlc-plugin", "x"), "SDLC Plugin")
        self.assertEqual(r("my-tool", "API"), "My Tool")
        self.assertEqual(r("ai", "API"), "API")  # derived "Ai" ... generic? stays resolved
        self.assertEqual(r("", "API"), "API")
        self.assertEqual(r("x", " Real Name "), "Real Name")
        self.assertEqual(r(None, "CLI"), "CLI")

    def test_resolve_derived_generic(self):
        # derived label "Ci" lower-cases into the blocked set -> keep the original
        self.assertEqual(vll.resolve_vendor_link_label("ci", "API"), "API")


class HealthTests(_NoNetwork):
    def probe(self, url="https://x.example/", **kw):
        return vll.check_url_health(url, **kw)

    def test_not_http(self):
        r = self.probe("ftp://x")
        self.assertEqual((r["ok"], r["error"], r["transport_error"]), (False, "not-http", False))
        self.assertEqual(self.probe(None)["final_url"], "")

    def test_skip_env(self):
        for val in ("1", "true", "yes"):
            with mock.patch.dict(os.environ, {"SB_SKIP_VENDOR_URL_HEALTH": val}):
                with mock.patch("urllib.request.urlopen") as uo:
                    r = self.probe()
                uo.assert_not_called()
                self.assertEqual((r["ok"], r["status"], r["error"]), (True, 0, "skipped"))
        with mock.patch.dict(os.environ, {"SB_SKIP_VENDOR_URL_HEALTH": "0"}):
            with mock.patch("urllib.request.urlopen", return_value=_Resp(200)) as uo:
                self.assertTrue(self.probe()["ok"])
            uo.assert_called_once()

    def test_head_ok_and_request_shape(self):
        with mock.patch("urllib.request.Request", wraps=vll.urllib.request.Request) as rq, \
                mock.patch("urllib.request.urlopen", return_value=_Resp(200, "https://f/")) as uo:
            r = self.probe(timeout=3)
        self.assertEqual(r, {"ok": True, "status": 200, "final_url": "https://f/",
                             "error": None, "transport_error": False})
        self.assertEqual(rq.call_args.kwargs["method"], "HEAD")
        self.assertEqual(uo.call_args.kwargs["timeout"], 3)

    def test_non_ok_status_without_exception(self):
        with mock.patch("urllib.request.urlopen", return_value=_Resp(206)):
            r = self.probe()
        self.assertEqual((r["ok"], r["status"], r["error"]), (False, 206, "http-206"))

    def test_missing_status_and_blank_geturl(self):
        with mock.patch("urllib.request.urlopen", return_value=_NoStatusResp("")):
            r = self.probe("https://t.example/")
        self.assertEqual((r["ok"], r["status"], r["final_url"]), (True, 200, "https://t.example/"))

    def test_head_http_error_non_retry(self):
        with mock.patch("urllib.request.urlopen", side_effect=_http_error(404)) as uo:
            r = self.probe()
        self.assertEqual((r["ok"], r["status"], r["error"], r["transport_error"]),
                         (False, 404, "http-404", False))
        self.assertEqual(uo.call_count, 1)

    def test_retry_get_after_405_succeeds(self):
        calls = []

        def fake(req, **kw):
            calls.append(req.get_method())
            if len(calls) == 1:
                raise _http_error(405)
            return _Resp(200)

        with mock.patch("urllib.request.urlopen", side_effect=fake):
            r = self.probe()
        self.assertEqual(calls, ["HEAD", "GET"])
        self.assertTrue(r["ok"])

    def test_retry_get_http_error(self):
        for first in (401, 403, 405):
            seq = [_http_error(first), _http_error(404)]
            with mock.patch("urllib.request.urlopen", side_effect=seq):
                r = self.probe()
            self.assertEqual((r["ok"], r["status"], r["error"], r["transport_error"]),
                             (False, 404, "http-404", False))

    def test_retry_get_transport_error(self):
        seq = [_http_error(403), urllib.error.URLError("boom")]
        with mock.patch("urllib.request.urlopen", side_effect=seq):
            r = self.probe()
        self.assertIsNone(r["status"])
        self.assertTrue(r["transport_error"])
        self.assertTrue(r["error"].startswith("URLError"))

    def test_head_transport_errors(self):
        for exc in (urllib.error.URLError("dns"), TimeoutError("slow"), OSError("ssl")):
            with mock.patch("urllib.request.urlopen", side_effect=exc):
                r = self.probe()
            self.assertEqual((r["ok"], r["status"], r["transport_error"]), (False, None, True))
            self.assertIn(type(exc).__name__, r["error"])


class FilterTests(_NoNetwork):
    def health(self, mapping):
        def fake(url, *, timeout):
            return mapping[url]
        return mock.patch.object(vll, "check_url_health", side_effect=fake)

    def test_filter_urls_decisions(self):
        mapping = {
            "https://ok": {"ok": True},
            "https://dead": {"ok": False, "status": 404, "error": "http-404", "final_url": "https://dead"},
            "https://net": {"ok": False, "status": None, "transport_error": True, "error": "e"},
            "https://busy": {"ok": False, "status": 503, "error": "http-503"},
        }
        urls = {" OK ": "https://ok", "Dead": " https://dead ", "Net": "https://net",
                "Busy": "https://busy", "": "https://ok", "NoHttp": "ftp://x", "None": None}
        with self.health(mapping):
            kept, dropped = vll.filter_healthy_vendor_urls(urls, timeout=1)
        self.assertEqual(kept, {"OK": "https://ok", "Net": "https://net", "Busy": "https://busy"})
        self.assertEqual(len(dropped), 1)
        self.assertEqual(dropped[0]["label"], "Dead")
        self.assertEqual(dropped[0]["status"], 404)
        self.assertFalse(dropped[0]["transport_error"])

    def test_filter_urls_none_input(self):
        self.assertEqual(vll.filter_healthy_vendor_urls(None), ({}, []))

    def test_strict_drops_transport_and_transient(self):
        mapping = {
            "https://net": {"ok": False, "status": None, "transport_error": True, "error": "e"},
            "https://busy": {"ok": False, "status": 429, "error": "http-429"},
        }
        for val in ("1", "true", "yes"):
            with mock.patch.dict(os.environ, {"SB_VENDOR_URL_HEALTH_STRICT": val}), self.health(mapping):
                kept, dropped = vll.filter_healthy_vendor_urls(
                    {"Net": "https://net", "Busy": "https://busy"})
            self.assertEqual(kept, {})
            self.assertEqual({d["label"]: d["transport_error"] for d in dropped},
                             {"Net": True, "Busy": False})

    def test_filter_urls_end_to_end_through_urlopen(self):
        def fake(req, **kw):
            if "dead" in req.full_url:
                raise _http_error(404)
            if "net" in req.full_url:
                raise urllib.error.URLError("x")
            return _Resp(200)

        with mock.patch("urllib.request.urlopen", side_effect=fake):
            kept, dropped = vll.filter_healthy_vendor_urls(
                {"A": "https://a.example", "D": "https://dead.example", "N": "https://net.example"})
        self.assertEqual(set(kept), {"A", "N"})
        self.assertEqual([d["label"] for d in dropped], ["D"])

    def test_filter_pairs(self):
        mapping = {"https://ok": {"ok": True},
                   "https://dead": {"ok": False, "status": 404, "error": "x"}}
        pairs = [["A", "https://ok"], ["B", "https://dead"], ["short"], "junk", ("C", "https://ok", "x")]
        with self.health(mapping):
            kept, dropped = vll.filter_healthy_link_pairs(pairs)
        self.assertEqual(kept, [["A", "https://ok"], ["C", "https://ok"]])
        self.assertEqual([d["label"] for d in dropped], ["B"])


class PairTests(unittest.TestCase):
    def test_token_score(self):
        self.assertEqual(vll._url_label_token_score("Claude Plugins Pack", "https://claude.com/plugins"), 2)
        self.assertEqual(vll._url_label_token_score(None, None), 0)

    def test_drop_ambiguous(self):
        d = vll.drop_ambiguous_shared_homepage_urls
        # invalid shapes never take part in collision detection and are not echoed back
        self.assertEqual(d([["A"], "junk"]), [])
        # empty label / non-http rows are skipped by the collision pass but pass through
        self.assertEqual(d([["", "https://a"], ["B", "ftp://b"]]),
                         [["", "https://a"], ["B", "ftp://b"]])
        # aliases sharing one homepage are kept
        alias = [["Devin", "https://devin.ai"], ["Devin (Cognition)", "https://devin.ai"],
                 ["Devin Pro", "https://devin.ai"]]
        self.assertEqual(d(alias), alias)
        # same label repeated -> single unique, kept
        rep = [["Foo", "https://foo.io"], ["Foo", "https://foo.io"]]
        self.assertEqual(d(rep), rep)
        # no token match -> drop all colliders, keep unrelated
        got = d([["Alpha", "https://m.example/x"], ["Beta", "https://m.example/x"], ["Gamma", "https://g"]])
        self.assertEqual(got, [["Gamma", "https://g"]])
        # tie on best score -> longest label kept
        got = d([["Plug", "https://plug.example/plug"], ["Plug Pro Max", "https://plug.example/plug"],
                 ["Other Plug", "https://plug.example/plug"]])
        self.assertEqual(got, [["Plug Pro Max", "https://plug.example/plug"]])
        # unique best score keeps only the leader
        got = d([["Zeta Tool", "https://zeta.example"], ["Other", "https://zeta.example"]])
        self.assertEqual(got, [["Zeta Tool", "https://zeta.example"]])
        # paren alias form
        par = [["Dev", "https://d.io"], ["Dev(X)", "https://d.io"]]
        self.assertEqual(d(par), par)

    def test_drop_ambiguous_equal_length_tie_is_deterministic(self):
        # Two colliding labels with the same score and the same length: the survivor must
        # not depend on set iteration order (PYTHONHASHSEED).
        import subprocess

        code = (
            "import sys; sys.path.insert(0, %r); import vendor_link_labels as v;"
            "print(v.drop_ambiguous_shared_homepage_urls("
            "[['Plugx Plug','https://plug.example/plug'],['Other Plug','https://plug.example/plug']]))"
        ) % str(SCRIPTS)
        outs = set()
        for seed in range(8):
            env = dict(os.environ, PYTHONHASHSEED=str(seed))
            res = subprocess.run([sys.executable, "-c", code], env=env,
                                 capture_output=True, text=True, check=True)
            outs.add(res.stdout.strip())
        self.assertEqual(outs, {"[['Plugx Plug', 'https://plug.example/plug']]"})

    def test_filter_vendor_link_pairs(self):
        f = vll.filter_vendor_link_pairs
        got = f([
            ["SDLC", "https://a.example"],
            ["Good Tool", "https://good.example"],
            ["Good Tool", "https://good2.example"],
            ["Dropped", "https://deepwork.ai"],
            ["Empty", ""],
            ["NoScheme", "ftp://x"],
            ["", "https://e.example"],
            ["Claude Harness", "https://github.com/anthropics/claude-code"],
            ["Claude  Harness2", "https://harness.example"],
            ["short"],
            "junk",
        ])
        self.assertEqual(got, [["Claude  Harness2", "https://harness.example"],
                               ["Good Tool", "https://good.example"]])
        self.assertEqual(f([["Claude Harness", "https://harness.dev"]]),
                         [["Claude Harness", "https://harness.dev"]])


class MarkdownScrubTests(unittest.TestCase):
    def test_scrub_links(self):
        md = "[A](https://old/a) [B](https://old/b) [C](https://keep/c) text"
        out = vll.scrub_vendor_markdown_links(
            md, vendor_urls={" A ": " https://new/a "}, known_labels={"B"})
        self.assertEqual(out, "[A](https://new/a) B [C](https://keep/c) text")

    def test_scrub_defaults(self):
        self.assertEqual(vll.scrub_vendor_markdown_links(None, vendor_urls=None), "")
        self.assertEqual(vll.scrub_vendor_markdown_links("[A](https://a)", vendor_urls={}), "[A](https://a)")
        self.assertEqual(vll.scrub_vendor_markdown_links("[A](https://a)", vendor_urls={"A": ""}), "A")


class LinkifyTests(unittest.TestCase):
    def test_split_trailing(self):
        sp = vll.split_url_trailing_punct
        self.assertEqual(sp(None), ("", ""))
        self.assertEqual(sp("https://a.b/x.,"), ("https://a.b/x", ".,"))
        self.assertEqual(sp("https://a.b/(x)"), ("https://a.b/(x)", ""))
        self.assertEqual(sp("https://a.b/x)"), ("https://a.b/x", ")"))
        self.assertEqual(sp("https://a.b/x]"), ("https://a.b/x", "]"))
        self.assertEqual(sp("https://a.b/x>"), ("https://a.b/x", ">"))
        self.assertEqual(sp("https://a.b/[x]"), ("https://a.b/[x]", ""))
        self.assertEqual(sp("https://a.b/<x>"), ("https://a.b/<x>", ""))
        self.assertEqual(sp("..."), ("", "..."))

    def test_prose_urls_non_http_branch(self):
        # BARE_HTTP_URL_RE only matches http(s); force the guard with a stub regex match
        fake = mock.Mock()
        fake.sub.side_effect = lambda repl, text: repl(
            mock.Mock(group=lambda n=0: "ftp://x."))
        with mock.patch.object(vll, "BARE_HTTP_URL_RE", fake):
            self.assertEqual(vll._linkify_prose_urls("t"), "ftp://x.")

    def test_code_span(self):
        c = vll._linkify_code_span_url
        self.assertEqual(c("`"), "`")
        self.assertEqual(c("xx`"), "xx`")
        self.assertEqual(c("`https://a.b`"), "[`https://a.b`](https://a.b)")
        self.assertEqual(c("`  https://a.b. `"), "[`https://a.b`](https://a.b).")
        self.assertEqual(c("`ls -la`"), "`ls -la`")
        self.assertEqual(c("`https://a.b and more`"), "`https://a.b and more`")
        self.assertEqual(c("`HTTP://A.B`"), "[`HTTP://A.B`](HTTP://A.B)")

    def test_linkify(self):
        lk = vll.linkify_bare_http_urls
        self.assertEqual(lk(""), "")
        self.assertIsNone(lk(None))
        md = ("see https://a.b/x, and [t](https://c.d) and <https://e.f> "
              "and `https://g.h` and `code` done.")
        out = lk(md)
        self.assertIn("[https://a.b/x](https://a.b/x),", out)
        self.assertIn("[t](https://c.d)", out)
        self.assertIn("<https://e.f>", out)
        self.assertIn("[`https://g.h`](https://g.h)", out)
        self.assertIn("`code`", out)
        self.assertEqual(lk("no urls here"), "no urls here")


if __name__ == "__main__":
    unittest.main()
