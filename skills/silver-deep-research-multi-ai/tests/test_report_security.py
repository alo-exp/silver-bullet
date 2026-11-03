"""Security contracts for the landscape report and its print HTML (R12-01, R10b-01, R12-13, R12-24, R12-28).

Model- and web-derived text must reach the reader as text, never as markup: hostile entries
(`<img onerror>`, `javascript:` hrefs, quote breakouts) are rendered inert in the static HTML,
the embedded JSON is strict and minimal, and a Content-Security-Policy pins every script.
The dynamic (JavaScript) sinks are exercised by tests/js/landscape-report-xss.test.mjs.
"""

from __future__ import annotations

import base64
import hashlib
import json
import math
import os
import re
import sys
import tempfile
import unittest
from html.parser import HTMLParser
from pathlib import Path
from unittest import mock

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
if str(SCRIPTS) not in sys.path:
    sys.path.insert(0, str(SCRIPTS))

import landscape_independent_pdf as lip  # noqa: E402
import landscape_preview_render as lpr  # noqa: E402

HOSTILE = {
    "img": "<img src=x onerror=alert(1)>",
    "script": "<script>alert(2)</script>",
    "svg": '"><svg onload=alert(3)>',
    "iframe": "<iframe src=javascript:alert(4)></iframe>",
}
ALLOWED_CONTENT_TAGS = {
    "a", "blockquote", "br", "code", "div", "em", "h1", "h2", "h3", "h4", "h5", "h6", "hr",
    "li", "ol", "p", "pre", "strong", "table", "tbody", "td", "th", "thead", "tr", "ul",
}
EXECUTABLE_TAGS = {"img", "iframe", "object", "embed", "svg", "math", "frame", "frameset", "base",
                   "form", "input", "meta", "link", "style", "video", "audio", "source"}


def _hostile_markdown() -> str:
    return "\n".join(
        [
            "# Hostile landscape",
            "",
            "## 1. Problem",
            "",
            f"Raw HTML {HOSTILE['img']} and {HOSTILE['script']} must stay text.",
            f"[click me](javascript:alert(5)) [file](file:///etc/passwd) [data](data:text/html,x)",
            "[ok link](https://example.com/docs) and [relative](comparison/matrix.xlsx).",
            "",
            f"### Acme {HOSTILE['svg']} (Commercial)",
            "",
            f"* **Overview**: Acme ships `{HOSTILE['img']}` as an example payload.",
            "* **Major Pros**:",
            f"  * **SSO**: {HOSTILE['iframe']}",
            "",
            f"> **Key insight**: {HOSTILE['img']}",
            "",
            "| Vendor | Quadrant |",
            "|---|---|",
            f"| {HOSTILE['svg']} | Leaders |",
            "",
            "```",
            HOSTILE["script"],
            "```",
            "",
            "---",
        ]
    )


def _write(root: Path, rel: str, payload) -> None:
    path = root / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    text = payload if isinstance(payload, str) else json.dumps(payload)
    path.write_text(text, encoding="utf-8")


def build_hostile_run(root: Path) -> None:
    _write(root, "landscape/landscape-report.md", _hostile_markdown())
    _write(
        root,
        "comparison/comparison.json",
        {
            "rows": [
                {"type": "category", "name": "Core"},
                {
                    "type": "feature",
                    "name": HOSTILE["img"],
                    "priority": "Critical",
                    "solutions": {"acme": "✔", 'beta"><svg onload=alert(6)>': "<b>x</b>"},
                },
            ],
            "rankings": [
                {"solution": "acme", "score": 5},
                {"solution": 'beta"><svg onload=alert(6)>', "score": math.nan},
            ],
        },
    )
    _write(
        root,
        "landscape/chart-data.json",
        {
            "titles": {"mq": HOSTILE["img"], "gmq": HOSTILE["svg"]},
            "mq_data": [{"slug": "acme", "label": HOSTILE["img"], "x": math.inf, "y": 6.0, "q": "Leaders"}],
            "link_pairs": [["Acme", "javascript:alert(7)"], ["Beta", 'https://beta.example/"onmouseover="alert(8)']],
            "vendor_urls": {"Acme": "javascript:alert(7)"},
        },
    )
    _write(root, "need_profile.json", {"category": f"Streams {HOSTILE['img']}"})
    _write(
        root,
        "run_manifest.json",
        {"research_type": "solution-landscape", "query": f"Event streaming {HOSTILE['svg']}", "run_id": "run-x"},
    )
    _write(
        root,
        "contributions/all-envelopes.json",
        [{"phase_id": "DR-RETRIEVE", "logical_model_id": "m1", "payload": {"raw_text": "secret worker output"}}],
    )


class _TagScan(HTMLParser):
    """Collect every element outside <script> with its attributes."""

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.elements: list[tuple[str, dict[str, str]]] = []
        self.content_tags: set[str] = set()
        self._content_depth = 0
        self.scripts: list[tuple[dict[str, str], str]] = []
        self._script_attrs: dict[str, str] | None = None
        self._script_text: list[str] = []
        self.text: list[str] = []
        self.meta_order: list[str] = []

    def handle_starttag(self, tag, attrs):
        amap = {k: (v or "") for k, v in attrs}
        self.elements.append((tag, amap))
        if tag == "script":
            self._script_attrs = amap
            self._script_text = []
            self.meta_order.append("script")
            return
        if tag == "meta" and amap.get("http-equiv", "").lower() == "content-security-policy":
            self.meta_order.append("csp")
        if self._content_depth:
            self.content_tags.add(tag)
            if tag not in {"br", "hr"}:
                self._content_depth += 1
        elif tag == "div" and amap.get("id") == "content":
            self._content_depth = 1

    def handle_endtag(self, tag):
        if tag == "script" and self._script_attrs is not None:
            self.scripts.append((self._script_attrs, "".join(self._script_text)))
            self._script_attrs = None
            return
        if self._content_depth and tag not in {"br", "hr"}:
            self._content_depth -= 1

    def handle_data(self, data):
        if self._script_attrs is not None:
            self._script_text.append(data)
        elif self._content_depth:
            self.text.append(data)


def _scan(html_text: str) -> _TagScan:
    scan = _TagScan()
    scan.feed(html_text)
    scan.close()
    return scan


def _strict_json(text: str):
    def _no_constants(name):
        raise ValueError(f"non-standard JSON constant {name}")

    return json.loads(text, parse_constant=_no_constants)


class _Case(unittest.TestCase):
    def setUp(self) -> None:
        env = mock.patch.dict(
            os.environ,
            {"SB_SKIP_VENDOR_URL_HEALTH": "1", "SB_SKIP_LANDSCAPE_PDF": "1", "SB_ALLOW_SKIP_LANDSCAPE_PDF": "1"},
        )
        env.start()
        self.addCleanup(env.stop)
        net = mock.patch("urllib.request.urlopen", side_effect=AssertionError("network access in a unit test"))
        net.start()
        self.addCleanup(net.stop)
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.root = Path(tmp.name)
        build_hostile_run(self.root)

    def render(self) -> str:
        lpr.render_landscape_outputs(self.root)
        return (self.root / "landscape-report.html").read_text(encoding="utf-8")


class StaticContentTests(_Case):
    def test_report_body_is_prerendered_text_not_live_markup(self) -> None:
        html_text = self.render()
        scan = _scan(html_text)
        # The report body ships as static HTML: readable offline and with JavaScript off.
        self.assertIn("Hostile landscape", "".join(scan.text))
        self.assertLessEqual(scan.content_tags, ALLOWED_CONTENT_TAGS, scan.content_tags - ALLOWED_CONTENT_TAGS)
        visible = "".join(scan.text)
        for payload in HOSTILE.values():
            self.assertIn(payload, visible, "hostile text must survive as visible text")

    def test_no_element_carries_an_event_handler_or_executable_tag(self) -> None:
        scan = _scan(self.render())
        for tag, attrs in scan.elements:
            self.assertNotIn(tag, EXECUTABLE_TAGS - {"meta", "link", "style"}, (tag, attrs))
            for name in attrs:
                self.assertFalse(name.lower().startswith("on"), (tag, attrs))

    def test_every_href_is_http_relative_or_fragment(self) -> None:
        scan = _scan(self.render())
        hrefs = [attrs["href"] for tag, attrs in scan.elements if tag == "a" and "href" in attrs]
        self.assertIn("https://example.com/docs", hrefs)
        self.assertIn("comparison/matrix.xlsx", hrefs)
        for href in hrefs:
            scheme = re.match(r"^\s*([a-zA-Z][a-zA-Z0-9+.-]*):", href)
            if scheme:
                self.assertIn(scheme.group(1).lower(), {"http", "https"}, href)

    def test_page_does_not_load_or_call_marked(self) -> None:
        html_text = self.render()
        self.assertNotIn("marked.min.js", html_text)
        self.assertNotIn("marked.parse(", html_text)
        self.assertNotIn("new marked.Renderer", html_text)


class EmbeddedPayloadTests(_Case):
    def _payload(self, html_text: str):
        match = re.search(r'<script type="application/json" id="report-data">(.*?)</script>', html_text, re.S)
        self.assertIsNotNone(match)
        return _strict_json(match.group(1))

    def test_payload_is_strict_json_with_non_finite_numbers_nulled(self) -> None:
        payload = self._payload(self.render())
        ranking = [r for r in payload["comparison"]["rankings"] if r["solution"] != "acme"][0]
        self.assertIsNone(ranking["score"])
        self.assertIsNone(payload["chart_data"]["mq_data"][0]["x"])

    def test_payload_has_no_raw_envelopes_or_absolute_paths(self) -> None:
        html_text = self.render()
        payload = self._payload(html_text)
        self.assertNotIn("envelopes", payload)
        self.assertNotIn("secret worker output", html_text)
        self.assertNotIn("raw_text", html_text)
        self.assertNotIn(str(self.root), html_text)
        self.assertNotIn(str(self.root.resolve()), html_text)
        self.assertEqual(payload["canonical_paths"]["markdown"], "landscape/landscape-report.md")


class ContentSecurityPolicyTests(_Case):
    def test_csp_meta_precedes_scripts_and_pins_every_script(self) -> None:
        html_text = self.render()
        scan = _scan(html_text)
        self.assertTrue(scan.meta_order and scan.meta_order[0] == "csp", scan.meta_order)
        csp = next(
            attrs["content"]
            for tag, attrs in scan.elements
            if tag == "meta" and attrs.get("http-equiv", "").lower() == "content-security-policy"
        )
        directives = {part.split()[0]: part.split()[1:] for part in csp.split(";") if part.strip()}
        script_src = directives["script-src"]
        self.assertNotIn("'unsafe-inline'", script_src)
        self.assertNotIn("'unsafe-eval'", script_src)
        self.assertEqual(directives.get("object-src"), ["'none'"])
        self.assertEqual(directives.get("base-uri"), ["'none'"])
        for attrs, body in scan.scripts:
            if attrs.get("type") == "application/json":
                continue
            if "src" in attrs:
                self.assertIn(attrs["src"], script_src)
                self.assertTrue(attrs["src"].startswith("https://"), attrs["src"])
                continue
            digest = base64.b64encode(hashlib.sha256(body.encode("utf-8")).digest()).decode("ascii")
            self.assertIn(f"'sha256-{digest}'", script_src)


class PrintHtmlTests(_Case):
    def test_print_html_keeps_only_http_links_and_escapes_text(self) -> None:
        print_html = lip.build_independent_print_html(self.root)
        scan = _scan(print_html)
        hrefs = [attrs.get("href", "") for tag, attrs in scan.elements if tag == "a"]
        self.assertIn("https://example.com/docs", hrefs)
        for href in hrefs:
            self.assertNotRegex(href.lower(), r"^\s*(javascript|file|data|vbscript):")
        for tag, attrs in scan.elements:
            for name in attrs:
                self.assertFalse(name.lower().startswith("on"), (tag, attrs))
        self.assertNotIn("<img src=x", print_html)
        self.assertIn("&lt;img src=x onerror=alert(1)&gt;", print_html)

    def test_print_html_loads_no_remote_resources_and_blocks_script(self) -> None:
        print_html = lip.build_independent_print_html(self.root)
        self.assertNotIn("fonts.googleapis.com", print_html)
        self.assertNotIn("<script", print_html)
        csp = re.search(r'http-equiv="Content-Security-Policy" content="([^"]+)"', print_html)
        self.assertIsNotNone(csp)
        self.assertIn("default-src 'none'", csp.group(1))
        self.assertNotIn("script-src", csp.group(1))


class RendererUnitTests(unittest.TestCase):
    def test_safe_href_accepts_http_relative_and_fragments_only(self) -> None:
        for good in ("https://a.example/x", "HTTP://a.example", "comparison/x.xlsx", "#section", "x.html?y=1"):
            self.assertEqual(lip.safe_href(good), good, good)
        for bad in (
            "", None, "javascript:alert(1)", "JaVaScRiPt:alert(1)", "java\tscript:alert(1)",
            " \x01javascript:alert(1)", "data:text/html,x", "file:///etc/passwd", "vbscript:x",
            "//evil.example/x", "\\\\evil\\share", "/\\evil", "\\/evil", "mailto:a@b.c",
        ):
            self.assertIsNone(lip.safe_href(bad), repr(bad))

    def test_anchor_variants(self) -> None:
        self.assertEqual(lip._html_ext_anchor("javascript:x", "<em>t</em>"), "<em>t</em>")
        self.assertEqual(lip._html_ext_anchor("a/b.html", "t"), '<a href="a/b.html">t</a>')
        self.assertEqual(
            lip._html_ext_anchor('https://x.example/"q', "t"),
            '<a href="https://x.example/&quot;q" target="_blank" rel="noopener noreferrer">t</a>',
        )

    def test_fenced_code_blockquote_and_rule(self) -> None:
        out = lip.markdown_to_html("```\n<b>x</b>\n  y\n```\n> **Risk**: <i>q</i>\n> > nested\n\n---\ntail")
        self.assertIn("<pre><code>&lt;b&gt;x&lt;/b&gt;\n  y</code></pre>", out)
        self.assertIn("<blockquote><p><strong>Risk</strong>: &lt;i&gt;q&lt;/i&gt;</p>", out)
        self.assertIn("<blockquote><p>nested</p></blockquote>", out)
        self.assertIn("<hr>", out)
        self.assertIn("<p>tail</p>", out)
        self.assertEqual(lip.markdown_to_html("```\nunterminated <x>"), "<pre><code>unterminated &lt;x&gt;</code></pre>")

    def test_deep_blockquote_nesting_is_bounded(self) -> None:
        out = lip.markdown_to_html(">" * 5000 + " deep <x>")
        self.assertEqual(out.count("<blockquote>"), lip._MAX_QUOTE_DEPTH + 1)
        self.assertIn("&lt;x&gt;", out)



class TemplateScriptIntegrityTests(unittest.TestCase):
    def test_every_external_script_is_version_pinned_and_has_sri(self):
        import re

        html = (Path(__file__).resolve().parents[1] / "assets" / "landscape-preview.template.html").read_text(encoding="utf-8")
        tags = re.findall(r"<script\b[^>]*\bsrc=\"(https?://[^\"]+)\"[^>]*>", html)
        self.assertGreaterEqual(len(tags), 3)
        for tag in re.findall(r"<script\b[^>]*\bsrc=\"https?://[^>]*>", html):
            url = re.search(r'src="([^"]+)"', tag).group(1)
            self.assertRegex(url, r"@\d+\.\d+\.\d+/", url)  # exact version, never a range or latest
            self.assertRegex(tag, r'integrity="sha384-[A-Za-z0-9+/]{64}"', url)
            self.assertIn('crossorigin="anonymous"', tag)


if __name__ == "__main__":
    unittest.main()
