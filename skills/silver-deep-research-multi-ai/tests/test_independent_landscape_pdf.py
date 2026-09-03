"""Independent landscape PDF is not an SPA print of landscape-report.html."""

from __future__ import annotations

import json
import os
import re
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS))

from landscape_independent_pdf import (  # noqa: E402
    GOOGLE_FONTS_HREF,
    INDEPENDENT_PDF_MARKER,
    PRINT_ROOT_ID,
    SPA_CHROME_NEEDLES,
    SPA_FONT_FAMILY,
    assert_print_html_independent,
    assert_section_bodies_in_text,
    build_independent_print_html,
    comparison_matrix_html,
    markdown_to_html,
    notable_divergence_bullets,
    quadrant_divergences,
    sync_canonical_payload_files,
    write_independent_landscape_pdf,
)


def _minimal_chart() -> dict:
    return {
        "primary_market_id": "apo",
        "markets": {
            "apo": {
                "titles": {
                    "mq": "APO positioning",
                    "mq_x": "Process orchestration",
                    "mq_y": "Autonomous execution",
                    "gmq": "APO Magic Quadrant",
                    "gmq_x": "Completeness of Vision",
                    "gmq_y": "Ability to Execute",
                    "wave": "APO Wave",
                },
                "mq_data": [
                    {"slug": "alpha", "label": "Alpha", "x": 7.2, "y": 8.1, "q": "Leaders"},
                    {"slug": "beta", "label": "Beta", "x": 3.1, "y": 7.4, "q": "Challengers"},
                ],
                "gmq_data": [
                    {"slug": "alpha", "label": "Alpha", "x": 3.0, "y": 8.0, "q": "Challengers"},
                    {"slug": "beta", "label": "Beta", "x": 7.5, "y": 3.2, "q": "Visionaries"},
                ],
                "wave_data": [
                    {"slug": "alpha", "label": "Alpha", "offering": 4.0, "strategy": 3.5, "presence": 3},
                    {"slug": "beta", "label": "Beta", "offering": 2.0, "strategy": 4.0, "presence": 2},
                ],
                "mq_colors": {
                    "Leaders": "#1f3864",
                    "Challengers": "#475569",
                    "Visionaries": "#2f5597",
                    "Niche Players": "#94a3b8",
                },
                "gmq_colors": {
                    "Leaders": "#1f3864",
                    "Challengers": "#475569",
                    "Visionaries": "#2f5597",
                    "Niche Players": "#94a3b8",
                },
            }
        },
    }


def _write_fixture(tmp: Path) -> Path:
    (tmp / "landscape").mkdir()
    (tmp / "comparison").mkdir()
    (tmp / "landscape" / "chart-data.json").write_text(json.dumps(_minimal_chart()), encoding="utf-8")
    (tmp / "landscape" / "landscape-report.md").write_text(
        "# Fixture Landscape\n\n"
        "## 1. Market Definition & Scope\n\n"
        "Process layer above coding agents. Inclusion requires three of seven gates.\n\n"
        "- Generic **coding agents** and IDE copilots\n"
        "- **Host runtimes** that execute code without a process catalog\n\n"
        "## 2. Market Overview\n\n"
        "Primary APO, secondary SDLC plugins, tertiary agentic SaaS.\n\n"
        "**Notable divergences** (disagreements among contributing models / waves / SCRs):\n\n"
        "- **AI-DLC:** `ocg-deepseek-v4-flash` (deepseek) — weakest APO core seed. "
        "`ocg-mimo-v2.5` (mimo) — enterprise-grade AWS-backed APO.\n\n"
        "## 3. Competitive Positioning — Analyst Frameworks\n\n"
        "Charts are generated separately.\n\n"
        "## 5. Vendors\n\n"
        "### Alpha (Commercial)\n\n"
        "* **Overview**: [Alpha](https://example.com/alpha) orchestrates gated SDLC workflows.\n"
        "* **Major Pros**:\n"
        "  * **Workflow composition**: Supported in startup-weighted comparison matrix.\n"
        "  * Nested _emphasis_ item\n",
        encoding="utf-8",
    )
    (tmp / "comparison" / "comparison.json").write_text(
        json.dumps(
            {
                "winner": "alpha",
                "runner_up": "beta",
                "rankings": [
                    {"solution": "alpha", "score": 40, "rank": 1},
                    {"solution": "beta", "score": 22, "rank": 2},
                ],
                "rows": [
                    {
                        "type": "feature",
                        "name": "Workflow composition",
                        "priority": "Critical",
                        "solutions": {"alpha": "✔", "beta": ""},
                    },
                    {
                        "type": "feature",
                        "name": "Audit log",
                        "priority": "Important",
                        "solutions": {"alpha": "✔", "beta": "✔"},
                    },
                    {
                        "type": "feature",
                        "name": "Per-seat transparency",
                        "priority": "Nice to have",
                        "solutions": {"alpha": "", "beta": "✔"},
                    },
                    {
                        "type": "feature",
                        "name": "Automated review loops",
                        "priority": "Important",
                        "solutions": {"alpha": "✔", "beta": ""},
                    },
                    {
                        "type": "feature",
                        "name": "Visual/E2E verification",
                        "priority": "Important",
                        "solutions": {"alpha": "", "beta": ""},
                    },
                ],
                "caveats": ["Unknowns are preferred over inferred ticks."],
            }
        ),
        encoding="utf-8",
    )
    html_path = tmp / "landscape-report.html"
    html_path.write_text(
        "<html><body id='content'><div id='exportBar'><button id='pdfExportBtn'>PDF</button></div></body></html>",
        encoding="utf-8",
    )
    return html_path


class IndependentPrintHtmlTests(unittest.TestCase):
    def test_print_html_has_vector_charts_and_no_spa_chrome(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            _write_fixture(root)
            print_html = build_independent_print_html(root)
            assert_print_html_independent(print_html)
            self.assertIn(INDEPENDENT_PDF_MARKER, print_html)
            self.assertIn(f'id="{PRINT_ROOT_ID}"', print_html)
            self.assertIn('data-chart="mq:apo"', print_html)
            self.assertIn('data-chart="gmq:apo"', print_html)
            self.assertIn('data-chart="wave:apo"', print_html)
            self.assertIn('data-slug="alpha"', print_html)
            self.assertIn("<svg", print_html)
            self.assertIn("class=\"fig-pt\"", print_html)
            self.assertIn("Market Definition", print_html)
            self.assertIn("Competitive Positioning", print_html)
            self.assertIn("Comparison matrix", print_html)
            self.assertNotIn("Comparison matrix highlights", print_html)
            self.assertIn("Audit log", print_html)
            self.assertIn("Per-seat transparency", print_html)
            self.assertIn("Automated review loops", print_html)
            self.assertIn("Visual/E2E verification", print_html)
            self.assertIn("Process layer above coding agents", print_html)
            self.assertIn("Notable divergences", print_html)
            self.assertIn("ocg-deepseek-v4-flash", print_html)
            self.assertRegex(print_html, r"(?:ocg-|claude-|gemini-|gpt-)[A-Za-z0-9._-]+")
            self.assertIn("contributing models", print_html)
            self.assertNotIn("No MQ vs GMQ quadrant disagreements", print_html)
            self.assertNotIn("Renderer:", print_html)
            visible = re.sub(r"<!--.*?-->", "", print_html, flags=re.S)
            self.assertNotIn(INDEPENDENT_PDF_MARKER, visible)
            self.assertNotIn("Positioning matrix", print_html)
            self.assertIn("Magic Quadrant", print_html)
            for needle in SPA_CHROME_NEEDLES:
                self.assertNotIn(needle, print_html)
            self.assertNotIn("id='content'", print_html)
            self.assertNotIn('id="content"', print_html)

    def test_print_html_uses_spa_roboto_condensed(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            _write_fixture(root)
            print_html = build_independent_print_html(root)
            self.assertIn(SPA_FONT_FAMILY, print_html)
            self.assertIn(GOOGLE_FONTS_HREF, print_html)
            self.assertIn("font-weight: 300", print_html)
            self.assertNotIn("Palatino", print_html)
            self.assertNotIn("Georgia, serif", print_html)

    def test_print_html_strips_markdown_list_markers(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            _write_fixture(root)
            print_html = build_independent_print_html(root)
            self.assertNotRegex(print_html, r"<li>\s*[-*•]")
            self.assertNotRegex(print_html, r"<li>\s*\*\*")
            self.assertNotIn("**Overview**", print_html)
            self.assertNotIn("[Alpha](https://example.com/alpha)", print_html)
            self.assertIn("<strong>coding agents</strong>", print_html)
            self.assertIn("<strong>Overview</strong>", print_html)
            self.assertIn("<em>emphasis</em>", print_html)
            self.assertIn('href="https://example.com/alpha"', print_html)
            self.assertIn("<ul>", print_html)
            self.assertGreater(print_html.count("<ul>"), 1)

    def test_chart_vendor_coords_match_chart_data(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            _write_fixture(root)
            print_html = build_independent_print_html(root)
            chart = _minimal_chart()["markets"]["apo"]
            point_re = re.compile(
                r'data-chart="([^"]+)" data-slug="([^"]+)" data-x="([^"]+)" data-y="([^"]+)"'
            )
            found: dict[tuple[str, str], tuple[float, float]] = {}
            for match in point_re.finditer(print_html):
                found[(match.group(1), match.group(2))] = (
                    float(match.group(3)),
                    float(match.group(4)),
                )
            for pt in chart["mq_data"]:
                got = found[("mq:apo", pt["slug"])]
                self.assertAlmostEqual(got[0], pt["x"], places=4)
                self.assertAlmostEqual(got[1], pt["y"], places=4)
            for pt in chart["gmq_data"]:
                got = found[("gmq:apo", pt["slug"])]
                self.assertAlmostEqual(got[0], pt["x"], places=4)
                self.assertAlmostEqual(got[1], pt["y"], places=4)
            for pt in chart["wave_data"]:
                got = found[("wave:apo", pt["slug"])]
                self.assertAlmostEqual(got[0], pt["strategy"], places=4)
                self.assertAlmostEqual(got[1], pt["offering"], places=4)
            self.assertIn("x=strategy, y=offering", print_html)

    def test_markdown_to_html_nested_lists_have_no_raw_prefixes(self) -> None:
        html = markdown_to_html(
            "- Generic **coding agents**\n"
            "* **Overview**: hello\n"
            "  * **Workflow composition**: nested\n"
            "1. First numbered\n"
        )
        self.assertNotRegex(html, r"<li>\s*[-*•]")
        self.assertNotIn("**", html)
        self.assertIn("<strong>coding agents</strong>", html)
        self.assertIn("<strong>Workflow composition</strong>", html)
        self.assertIn("<ol>", html)
        self.assertIn("<ul>", html)

    def test_markdown_bold_link_is_not_raw(self) -> None:
        html = markdown_to_html(
            "- **[AxonFlow](https://www.axonflow.ai/)** (`axonflow`) — pack adjacent_seed\n"
        )
        self.assertNotIn("**", html)
        self.assertIn("<strong>", html)
        self.assertIn('href="https://www.axonflow.ai/"', html)
        self.assertNotRegex(html, r"<li>\s*[-*•]")
        self.assertIn('target="_blank"', html)
        self.assertIn("noopener noreferrer", html)

    def test_markdown_to_html_autolinks_bare_and_code_urls(self) -> None:
        html = markdown_to_html(
            "See https://zuvo.dev/ and `https://github.com/greglas75/zuvo` for identity.\n"
        )
        self.assertIn('href="https://zuvo.dev/"', html)
        self.assertIn('href="https://github.com/greglas75/zuvo"', html)
        self.assertIn('target="_blank"', html)
        self.assertIn("noopener noreferrer", html)
        self.assertIn("<code>", html)
        self.assertRegex(
            html,
            r'<a href="https://zuvo\.dev/" target="_blank" rel="noopener noreferrer">https://zuvo\.dev/</a>',
        )
        self.assertRegex(
            html,
            r'<code><a href="https://github.com/greglas75/zuvo" target="_blank" rel="noopener noreferrer">https://github.com/greglas75/zuvo</a></code>',
        )

    def test_mq_gmq_quadrant_disagreement_is_listed(self) -> None:
        diffs = quadrant_divergences(_minimal_chart())
        pairs = {(d["slug"], d["mq"], d["gmq"]) for d in diffs}
        self.assertIn(("alpha", "Leaders", "Challengers"), pairs)
        self.assertIn(("beta", "Challengers", "Visionaries"), pairs)

    def test_section_body_assert_rejects_headings_only(self) -> None:
        markdown = (
            "## 1. Market Definition & Scope\n\n"
            "Unique inclusion sentence about seven process gates for this fixture.\n\n"
            "## 5. Vendors\n\n"
            "Alpha orchestrates gated SDLC workflows for the fixture body check.\n"
        )
        with self.assertRaises(AssertionError):
            assert_section_bodies_in_text(
                markdown,
                "1. Market Definition & Scope\n5. Vendors\n",
            )
        assert_section_bodies_in_text(
            markdown,
            "Unique inclusion sentence about seven process gates for this fixture. "
            "Alpha orchestrates gated SDLC workflows for the fixture body check.",
        )

    def test_print_html_includes_full_comparison_matrix(self) -> None:
        html = comparison_matrix_html(
            {
                "winner": "alpha",
                "runner_up": "beta",
                "rankings": [
                    {"solution": "alpha", "score": 40, "rank": 1},
                    {"solution": "beta", "score": 22, "rank": 2},
                ],
                "rows": [
                    {
                        "type": "feature",
                        "name": "Audit log",
                        "priority": "Important",
                        "solutions": {"alpha": "✔", "beta": "✔"},
                    },
                    {
                        "type": "feature",
                        "name": "Per-seat transparency",
                        "priority": "Nice to have",
                        "solutions": {"alpha": "", "beta": "✔"},
                    },
                ],
            }
        )
        self.assertIn("Comparison matrix", html)
        self.assertNotIn("Comparison matrix highlights", html)
        self.assertIn("Audit log", html)
        self.assertIn("Per-seat transparency", html)
        self.assertIn("Weighted score", html)
        self.assertIn("40", html)
        self.assertIn("22", html)

    def test_sync_canonical_payload_matches_report_data(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            payload = {
                "markdown": "# SPA canonical\n\n## 1. Market Definition & Scope\n\nLockstep body.\n",
                "chart_data": {"primary_market_id": "apo", "markets": {}},
                "comparison": {
                    "winner": "alpha",
                    "rows": [{"type": "feature", "name": "Audit log"}],
                },
            }
            (root / "landscape-report.html").write_text(
                '<html><script type="application/json" id="report-data">'
                + json.dumps(payload)
                + "</script></html>",
                encoding="utf-8",
            )
            written = sync_canonical_payload_files(root)
            self.assertTrue(written["markdown"].endswith("landscape-report.md"))
            self.assertEqual(
                (root / "landscape" / "landscape-report.md").read_text(encoding="utf-8"),
                payload["markdown"] if payload["markdown"].endswith("\n") else payload["markdown"] + "\n",
            )
            disk_cmp = json.loads((root / "comparison" / "comparison.json").read_text(encoding="utf-8"))
            self.assertEqual(disk_cmp["winner"], "alpha")
            self.assertEqual(disk_cmp["rows"][0]["name"], "Audit log")

    def test_print_html_prefers_canonical_markdown_files(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            _write_fixture(root)
            (root / "landscape" / "landscape-report.md").write_text(
                "# File markdown without disagreements\n\n## 1. Market Definition & Scope\n\nScope only.\n",
                encoding="utf-8",
            )
            payload = {
                "markdown": (
                    "# SPA markdown\n\n"
                    "**Notable divergences** (disagreements among contributing models):\n"
                    "- **Conductor:** `claude-opus-4.8-medium` vs `ocg-qwen3.7-plus` — complementary vs thin wrapper.\n"
                ),
                "chart_data": _minimal_chart(),
                "comparison": {"winner": "alpha", "runner_up": "beta", "rankings": []},
            }
            (root / "landscape-report.html").write_text(
                '<html><script type="application/json" id="report-data">'
                + json.dumps(payload)
                + "</script></html>",
                encoding="utf-8",
            )
            print_html = build_independent_print_html(root)
            self.assertIn("File markdown without disagreements", print_html)
            self.assertIn("Scope only", print_html)
            self.assertNotIn("SPA markdown", print_html)
            self.assertNotIn("claude-opus-4.8-medium", print_html)

    def test_notable_bullets_fallback_to_consolidation(self) -> None:
        bullets = notable_divergence_bullets(
            "# No divergences heading\n",
            {
                "divergence": [
                    {
                        "text": "Conductor is complementary not substitutive.",
                        "supporting_agents": ["claude-opus-4.8-medium", "ocg-mimo-v2.5"],
                    }
                ]
            },
        )
        joined = " ".join(bullets)
        self.assertTrue(any("claude-opus-4.8-medium" in b for b in bullets), joined)
        self.assertTrue(any("ocg-mimo-v2.5" in b for b in bullets), joined)


class IndependentPdfWriteTests(unittest.TestCase):
    def test_write_does_not_pass_spa_html_to_playwright(self) -> None:
        from landscape_preview_render import write_sibling_landscape_pdf

        with tempfile.TemporaryDirectory() as tmp:
            html_path = _write_fixture(Path(tmp))
            pdf_path = html_path.with_name("landscape-report.pdf")
            captured: dict = {}

            def _fake_run(cmd, check):
                captured["cmd"] = list(cmd)
                pdf_path.write_bytes(b"%PDF-1.4 independent")
                class _R:
                    returncode = 0
                return _R()

            with patch("landscape_independent_pdf.subprocess.run", side_effect=_fake_run) as mocked:
                info = write_sibling_landscape_pdf(html_path)
            self.assertTrue(mocked.called)
            argv = captured["cmd"]
            self.assertIn("pdf", argv)
            self.assertEqual(Path(argv[-1]).resolve(), pdf_path.resolve())
            source = str(argv[-2])
            self.assertTrue(source.startswith("file:"))
            self.assertNotIn("landscape-report.html", source)
            self.assertIn(".print.html", source)
            self.assertIn(f"#{PRINT_ROOT_ID}", argv)
            self.assertNotIn("#content", argv)
            self.assertEqual(info["engine"], INDEPENDENT_PDF_MARKER)
            self.assertEqual(info["status"], "ok")

    def test_write_independent_rejects_spa_chrome_in_pdf_bytes(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            _write_fixture(root)
            pdf_path = root / "landscape-report.pdf"

            def _fake_run(cmd, check):
                pdf_path.write_bytes(b"%PDF-1.4 exportBar pdfExportBtn")
                class _R:
                    returncode = 0
                return _R()

            with patch("landscape_independent_pdf.subprocess.run", side_effect=_fake_run):
                with self.assertRaisesRegex(RuntimeError, "SPA chrome"):
                    write_independent_landscape_pdf(root, pdf_path)

    def test_svg_uniquifies_shared_axis_lines(self) -> None:
        from landscape_independent_pdf import _svg_scatter

        svg = _svg_scatter(
            points=[
                {"slug": "a", "label": "Alpha", "x": 9.5, "y": 5.0, "q": "Visionaries"},
                {"slug": "b", "label": "Beta", "x": 9.5, "y": 5.1, "q": "Visionaries"},
                {"slug": "c", "label": "Gamma", "x": 9.5, "y": 5.2, "q": "Visionaries"},
            ],
            title="t",
            x_label="x",
            y_label="y",
            colors={},
            chart_kind="mq:test",
        )
        xs = [float(v) for v in re.findall(r'data-x="([^"]+)"', svg)]
        ys = [float(v) for v in re.findall(r'data-y="([^"]+)"', svg)]
        self.assertEqual(len(xs), 3)
        self.assertEqual(len(set(xs)), 3, msg=f"shared vertical {xs}")
        self.assertEqual(len(set(ys)), 3, msg=f"shared horizontal {ys}")

    def test_point_labels_stay_inside_plot(self) -> None:
        from landscape_independent_pdf import _place_point_labels

        pad_l, pad_t, plot_w, plot_h = 96.0, 36.0, 608.0, 450.0
        x_min, x_max = pad_l + 3, pad_l + plot_w - 3
        y_min, y_max = pad_t + 11, pad_t + plot_h - 3
        names = [
            "Silver Bullet",
            "BMAD-METHOD",
            "GSD (Get Shit Done)",
            "Oh My Pi (OMP)",
            "Ruflo / Claude Flow",
            "GitHub Spec Kit",
            "SuperClaude",
            "Superpowers",
            "Zuvo",
            "Claude Harness",
        ]
        items = [(x_max - 6.0, y_min + 24.0 + i * 16.0, name, 6.5) for i, name in enumerate(names)]
        placed = _place_point_labels(items, x_min=x_min, x_max=x_max, y_min=y_min, y_max=y_max)
        self.assertEqual(len(placed), len(items))
        boxes = []
        for tx, ty, lab in placed:
            width = max(24.0, min(x_max - x_min - 4.0, len(lab) * 5.0 + 4.0))
            height = 12.0
            box = (tx - width / 2.0, ty - height + 3.0, width, height)
            boxes.append(box)
            self.assertGreaterEqual(box[0], x_min - 0.51, msg=lab)
            self.assertLessEqual(box[0] + box[2], x_max + 0.51, msg=lab)
            self.assertGreaterEqual(box[1], y_min - 0.51, msg=lab)
            self.assertLessEqual(box[1] + box[3], y_max + 0.51, msg=lab)
        for i, a in enumerate(boxes):
            for j, b in enumerate(boxes):
                if i >= j:
                    continue
                ax, ay, aw, ah = a
                bx, by, bw, bh = b
                overlap = not (ax + aw < bx or bx + bw < ax or ay + ah < by or by + bh < ay)
                self.assertFalse(overlap, msg=f"label overlap {i}/{j}")

    def test_html_regen_writes_sibling_pdf_by_default(self) -> None:
        from landscape_preview_render import render_landscape_preview_file

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            html_path = _write_fixture(root)
            with patch.dict(
                os.environ,
                {
                    "SB_SKIP_LANDSCAPE_PDF": "",
                    "SB_ALLOW_SKIP_LANDSCAPE_PDF": "",
                    "PYTEST_CURRENT_TEST": "",
                },
            ):
                with patch(
                    "landscape_preview_render.collect_landscape_payload",
                    return_value={"markdown": "# x"},
                ):
                    with patch(
                        "landscape_preview_render.render_landscape_preview",
                        return_value="<html></html>",
                    ):
                        with patch(
                            "landscape_preview_render.write_sibling_landscape_pdf",
                            return_value={
                                "pdf": str(root / "landscape-report.pdf"),
                                "bytes": 12,
                            },
                        ) as writer:
                            result = render_landscape_preview_file(root, out=html_path)
            writer.assert_called_once()
            self.assertNotEqual(result.get("pdf"), "skipped")

    def test_html_regen_skip_requires_allow_flag(self) -> None:
        from landscape_preview_render import render_landscape_preview_file

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            html_path = _write_fixture(root)
            with patch.dict(
                os.environ,
                {"SB_SKIP_LANDSCAPE_PDF": "1", "SB_ALLOW_SKIP_LANDSCAPE_PDF": "1"},
            ):
                with patch(
                    "landscape_preview_render.collect_landscape_payload",
                    return_value={"markdown": "# x"},
                ):
                    with patch(
                        "landscape_preview_render.render_landscape_preview",
                        return_value="<html></html>",
                    ):
                        with patch(
                            "landscape_preview_render.write_sibling_landscape_pdf",
                            return_value={"pdf": "x", "bytes": 1},
                        ) as writer:
                            result = render_landscape_preview_file(root, out=html_path)
            writer.assert_not_called()
            self.assertEqual(result.get("pdf"), "skipped")

    def test_html_regen_ignores_bare_skip_outside_tests(self) -> None:
        from landscape_preview_render import render_landscape_preview_file

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            html_path = _write_fixture(root)
            with patch.dict(
                os.environ,
                {
                    "SB_SKIP_LANDSCAPE_PDF": "1",
                    "SB_ALLOW_SKIP_LANDSCAPE_PDF": "",
                    "PYTEST_CURRENT_TEST": "",
                },
            ):
                with patch(
                    "landscape_preview_render.collect_landscape_payload",
                    return_value={"markdown": "# x"},
                ):
                    with patch(
                        "landscape_preview_render.render_landscape_preview",
                        return_value="<html></html>",
                    ):
                        with patch(
                            "landscape_preview_render.write_sibling_landscape_pdf",
                            return_value={
                                "pdf": str(root / "landscape-report.pdf"),
                                "bytes": 12,
                            },
                        ) as writer:
                            result = render_landscape_preview_file(root, out=html_path)
            writer.assert_called_once()
            self.assertNotEqual(result.get("pdf"), "skipped")


if __name__ == "__main__":
    unittest.main()
