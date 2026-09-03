"""Contracts for SPA vendor links, shared-URL collisions, and MQ-authoritative buckets."""

from __future__ import annotations

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "scripts"
TEMPLATE = ROOT / "assets" / "landscape-preview.template.html"


class VendorLinkCollisionTests(unittest.TestCase):
    def test_shared_marketplace_url_keeps_best_token_match_only(self) -> None:
        import sys

        sys.path.insert(0, str(SCRIPTS))
        from vendor_link_labels import filter_vendor_link_pairs

        pairs = filter_vendor_link_pairs(
            [
                ["SDLC Plugin", "https://claude.com/plugins"],
                ["Claude Plugins Pack", "https://claude.com/plugins"],
                ["Zuvo", "https://zuvo.dev/"],
            ]
        )
        by_label = {label: url for label, url in pairs}
        self.assertIn("Claude Plugins Pack", by_label)
        self.assertEqual(by_label["Claude Plugins Pack"], "https://claude.com/plugins")
        self.assertNotIn("SDLC Plugin", by_label)
        self.assertEqual(by_label.get("Zuvo"), "https://zuvo.dev/")

    def test_check_url_health_rejects_404(self) -> None:
        import os
        import sys
        import urllib.error
        from unittest.mock import patch

        sys.path.insert(0, str(SCRIPTS))
        from vendor_link_labels import check_url_health, filter_healthy_vendor_urls

        dead_url = "https://example.test/missing-vendor"
        live_url = "https://example.test/alive-vendor"

        def fake_urlopen(req, timeout=None, context=None):
            target = getattr(req, "full_url", None) or str(req)
            if "missing-vendor" in target:
                raise urllib.error.HTTPError(target, 404, "Not Found", hdrs=None, fp=None)

            class _Resp:
                status = 200

                def geturl(self):
                    return live_url

                def __enter__(self):
                    return self

                def __exit__(self, *args):
                    return False

            return _Resp()

        with patch.dict(os.environ, {"SB_SKIP_VENDOR_URL_HEALTH": "0"}, clear=False):
            with patch("vendor_link_labels.urllib.request.urlopen", side_effect=fake_urlopen):
                dead = check_url_health(dead_url)
                self.assertFalse(dead.get("ok"))
                self.assertEqual(dead.get("status"), 404)
                kept, dropped = filter_healthy_vendor_urls(
                    {"AI-DLC-dead": dead_url, "AgentSys": live_url}
                )
        self.assertNotIn("AI-DLC-dead", kept)
        self.assertIn("AgentSys", kept)
        self.assertTrue(any(d.get("label") == "AI-DLC-dead" for d in dropped))

    def test_filter_healthy_keeps_http_429(self) -> None:
        import sys
        from unittest.mock import patch

        sys.path.insert(0, str(SCRIPTS))
        from vendor_link_labels import filter_healthy_vendor_urls

        def fake_check(url: str, *, timeout: float = 12.0):
            return {
                "ok": False,
                "status": 429,
                "final_url": url,
                "error": "http-429",
                "transport_error": False,
            }

        with patch("vendor_link_labels.check_url_health", side_effect=fake_check):
            kept, dropped = filter_healthy_vendor_urls({"Devin": "https://devin.ai/"})
        self.assertIn("Devin", kept)
        self.assertEqual(dropped, [])

    def test_shared_url_with_no_token_match_drops_all(self) -> None:
        import sys

        sys.path.insert(0, str(SCRIPTS))
        from vendor_link_labels import filter_vendor_link_pairs

        pairs = filter_vendor_link_pairs(
            [
                ["Alpha Tool", "https://example.com/marketplace"],
                ["Beta Suite", "https://example.com/marketplace"],
            ]
        )
        self.assertEqual(pairs, [])

    def test_parenthetical_alias_keeps_bare_and_qualified_labels(self) -> None:
        import sys

        sys.path.insert(0, str(SCRIPTS))
        from vendor_link_labels import filter_vendor_link_pairs

        pairs = filter_vendor_link_pairs(
            [
                ["Devin (Cognition)", "https://devin.ai/"],
                ["Devin", "https://devin.ai/"],
                ["Zuvo", "https://zuvo.dev/"],
            ]
        )
        by_label = {label: url for label, url in pairs}
        self.assertEqual(by_label.get("Devin"), "https://devin.ai/")
        self.assertEqual(by_label.get("Devin (Cognition)"), "https://devin.ai/")
        self.assertEqual(by_label.get("Zuvo"), "https://zuvo.dev/")


class VendorBucketMqAuthorityTests(unittest.TestCase):
    def test_mq_overwrites_gmq_for_leaders_filter(self) -> None:
        import sys

        sys.path.insert(0, str(SCRIPTS))
        from synthesize_landscape import build_vendor_buckets

        mq = [
            {"label": "Cavekit v3.1", "q": "Visionaries"},
            {"label": "Silver Bullet", "q": "Leaders"},
        ]
        gmq = [
            {"label": "Cavekit v3.1", "q": "Leaders"},
            {"label": "Silver Bullet", "q": "Leaders"},
        ]
        buckets = build_vendor_buckets(mq, gmq_data=gmq, commercial=[], oss=[])
        self.assertIn("Silver Bullet", buckets["leaders"])
        self.assertNotIn("Cavekit v3.1", buckets["leaders"])

    def test_empty_commercial_does_not_fallback_to_global_saas(self) -> None:
        """All-OSS markets (sdlc-plugins) must not inherit Factory.ai/Devin catalogs."""
        import sys

        sys.path.insert(0, str(SCRIPTS))
        from synthesize_landscape import build_vendor_buckets

        mq = [{"label": "Oh My Pi (OMP)", "q": "Leaders"}]
        oss = [{"slug": "oh-my-pi", "name": "Oh My Pi (OMP)", "license": "OSS"}]
        buckets = build_vendor_buckets(mq, commercial=[], oss=oss)
        self.assertEqual(buckets["commercial"], [])
        self.assertEqual(buckets["oss"], ["Oh My Pi (OMP)"])
        self.assertNotIn("Factory.ai", buckets["commercial"])
        self.assertNotIn("Devin (Cognition)", buckets["commercial"])

    def test_empty_oss_does_not_fallback_to_global_plugins(self) -> None:
        """All-commercial markets (agentic-sdlc-saas) must not inherit GSD/BMAD/SB."""
        import sys

        sys.path.insert(0, str(SCRIPTS))
        from synthesize_landscape import build_vendor_buckets

        mq = [{"label": "Devin", "q": "Leaders"}]
        commercial = [{"slug": "devin", "name": "Devin"}]
        buckets = build_vendor_buckets(mq, commercial=commercial, oss=[])
        self.assertEqual(buckets["oss"], [])
        self.assertEqual(buckets["commercial"], ["Devin"])
        self.assertNotIn("GSD (Get Shit Done)", buckets["oss"])
        self.assertNotIn("BMAD-METHOD", buckets["oss"])
        self.assertNotIn("Silver Bullet", buckets["oss"])


class SpaTemplateContracts(unittest.TestCase):
    def test_marked_cdn_pinned_to_11_1_1(self) -> None:
        text = TEMPLATE.read_text(encoding="utf-8")
        self.assertIn("marked@11.1.1/marked.min.js", text)
        self.assertNotRegex(text, r"marked(?!@11\.1\.1)@")

    def test_fontsource_500_css_not_used(self) -> None:
        text = TEMPLATE.read_text(encoding="utf-8")
        self.assertNotIn("@fontsource/roboto-condensed@5.0.8/500.css", text)
        self.assertNotIn("roboto-condensed-latin-500-normal.woff2", text)
        self.assertIn("fonts.googleapis.com/css2?family=Roboto+Condensed", text)

    def test_hyperlinks_have_no_underline(self) -> None:
        text = TEMPLATE.read_text(encoding="utf-8")
        self.assertIn("#content a:not(.snav-btn)", text)
        self.assertIn("text-decoration: none;", text)
        # Screen/content link rules must not reintroduce underlines.
        self.assertNotRegex(
            text,
            r"#content a:not\(\.snav-btn\)[\s\S]{0,200}text-decoration:\s*underline",
        )
        self.assertNotIn("text-decoration:underline;", text)
        self.assertNotIn("border-bottom: 1px solid var(--sb-link-underline)", text)
        self.assertIn("function linkifyBareHttpUrls", text)
        self.assertIn("linkifyBareHttpUrls(document.getElementById('content'))", text)
        self.assertIn('target="_blank"', text)
        self.assertIn("noopener noreferrer", text)
        # Filter refresh must prefer primary buckets (avoids last-market bleed).
        self.assertIn("primaryBuckets", text)
        render_js = (ROOT / "scripts" / "landscape_preview_render.py").read_text(encoding="utf-8")
        self.assertIn("PRIMARY_CHART_DATA", render_js)
        self.assertIn("linkifyBareHttpUrls", render_js)

    def test_scrub_removes_stale_sdlc_plugin_marketplace_link(self) -> None:
        import sys

        sys.path.insert(0, str(SCRIPTS))
        from vendor_link_labels import scrub_vendor_markdown_links

        md = "See [SDLC Plugin](https://claude.com/plugins) and [Zuvo](https://zuvo.dev/)."
        out = scrub_vendor_markdown_links(
            md,
            vendor_urls={"Zuvo": "https://zuvo.dev/", "Claude Code Expert": "https://claude.com/plugins"},
            known_labels={"SDLC Plugin", "Zuvo", "Claude Code Expert"},
        )
        self.assertIn("See SDLC Plugin and", out)
        self.assertNotIn("[SDLC Plugin](https://claude.com/plugins)", out)
        self.assertIn("[Zuvo](https://zuvo.dev/)", out)

    def test_critical_fill_gap_annotator_present(self) -> None:
        text = TEMPLATE.read_text(encoding="utf-8")
        self.assertIn("function annotateCriticalFillGaps()", text)
        self.assertIn("annotateCriticalFillGaps();", text)


class BareHttpUrlLinkifyTests(unittest.TestCase):
    def test_linkify_bare_http_urls_wraps_prose_and_code_spans(self) -> None:
        import sys

        sys.path.insert(0, str(SCRIPTS))
        from vendor_link_labels import linkify_bare_http_urls

        md = (
            "Identity: homepage `https://zuvo.dev/` → GitHub "
            "https://github.com/greglas75/zuvo."
        )
        out = linkify_bare_http_urls(md)
        self.assertIn("[`https://zuvo.dev/`](https://zuvo.dev/)", out)
        self.assertIn(
            "[https://github.com/greglas75/zuvo](https://github.com/greglas75/zuvo)",
            out,
        )
        named = "[Zuvo](https://zuvo.dev/) plus https://zuvo.dev/"
        out2 = linkify_bare_http_urls(named)
        self.assertIn("[Zuvo](https://zuvo.dev/)", out2)
        self.assertIn("[https://zuvo.dev/](https://zuvo.dev/)", out2)
        self.assertNotIn("https://invented.example/", out2)

    def test_linkify_does_not_invent_urls(self) -> None:
        import sys

        sys.path.insert(0, str(SCRIPTS))
        from vendor_link_labels import linkify_bare_http_urls

        self.assertEqual(linkify_bare_http_urls("No links here."), "No links here.")
        self.assertEqual(linkify_bare_http_urls("`github.com/zuvo-ai/zuvo`"), "`github.com/zuvo-ai/zuvo`")

    def test_vendor_linkify_also_wraps_bare_urls(self) -> None:
        import sys

        sys.path.insert(0, str(SCRIPTS))
        from synthesize_landscape import _linkify_markdown_vendors

        pairs = [["Zuvo", "https://zuvo.dev/"]]
        out = _linkify_markdown_vendors("See Zuvo at https://zuvo.dev/ for the product.", pairs)
        self.assertIn("[Zuvo](https://zuvo.dev/)", out)
        self.assertIn("[https://zuvo.dev/](https://zuvo.dev/)", out)
        empty = _linkify_markdown_vendors("See https://zuvo.dev/.", [])
        self.assertIn("[https://zuvo.dev/](https://zuvo.dev/)", empty)


class MembershipFramingAndOssBucketTests(unittest.TestCase):
    def test_scrub_conductor_mid_tier_apo_cluster(self) -> None:
        import sys

        sys.path.insert(0, str(SCRIPTS))
        from category_pack import load_category_pack
        from synthesize_landscape import scrub_membership_framing

        pack = load_category_pack("agentic-sdlc-process-orchestrator")
        before = (
            "cc10x and Conductor form a mid-tier APO cluster sharing complementary strengths: "
            "Conductor has stronger workflow orchestration UI."
        )
        after = scrub_membership_framing(before, pack)
        self.assertIn("SaaS-adjacent", after)
        self.assertTrue(re.search(r"not an? APO", after, flags=re.I), after)
        self.assertNotIn("mid-tier APO cluster", after)

    def test_scrub_preserves_multiline_markdown(self) -> None:
        import sys

        sys.path.insert(0, str(SCRIPTS))
        from category_pack import load_category_pack
        from synthesize_landscape import scrub_membership_framing

        pack = load_category_pack("agentic-sdlc-process-orchestrator")
        md = (
            "# Title\n\n"
            "Keep this line.\n"
            "- cc10x and Conductor form a mid-tier APO cluster sharing complementary strengths.\n"
            "Also keep this.\n"
        )
        out = scrub_membership_framing(md, pack)
        self.assertIn("# Title", out)
        self.assertIn("Keep this line.", out)
        self.assertIn("Also keep this.", out)
        self.assertNotIn("mid-tier APO cluster", out)

    def test_enrich_keeps_metagpt_in_apo_oss_without_mq_point(self) -> None:
        """SPA enrich must use audit core, not MQ-only slugs, for market OSS buckets."""
        import json
        import sys
        import tempfile
        from pathlib import Path as P

        sys.path.insert(0, str(SCRIPTS))
        from landscape_preview_render import _enrich_chart_data

        chart = {
            "mq_data": [{"slug": "silver-bullet", "label": "Silver Bullet", "q": "Leaders"}],
            "markets": {
                "apo": {
                    "mq_data": [
                        {"slug": "silver-bullet", "label": "Silver Bullet", "q": "Leaders"}
                    ],
                    "gmq_data": [
                        {"slug": "silver-bullet", "label": "Silver Bullet", "q": "Leaders"}
                    ],
                    "vendor_buckets": {"commercial": [], "oss": ["Silver Bullet"], "leaders": [], "challengers": []},
                }
            },
            "vendor_buckets": {"commercial": [], "oss": ["MetaGPT", "Silver Bullet"], "leaders": [], "challengers": []},
        }
        with tempfile.TemporaryDirectory() as tmp:
            root = P(tmp)
            (root / "landscape").mkdir()
            (root / "landscape" / "catalog_audit.json").write_text(
                json.dumps(
                    {
                        "markets": {
                            "apo": {"core": ["silver-bullet", "metagpt"]},
                            "sdlc-plugins": {"core": []},
                            "agentic-sdlc-saas": {"core": []},
                        },
                        "matrix_slugs": ["silver-bullet", "metagpt"],
                        "adjacent": [],
                    }
                ),
                encoding="utf-8",
            )
            enriched = _enrich_chart_data(
                chart,
                root,
                {"rankings": [{"solution": "silver-bullet", "score": 10}]},
                need={"category_pack_id": "agentic-sdlc-process-orchestrator"},
            )
        apo_oss = enriched["markets"]["apo"]["vendor_buckets"]["oss"]
        self.assertIn("MetaGPT", apo_oss)
        self.assertIn("Silver Bullet", apo_oss)



class CategoryPackHomepageTests(unittest.TestCase):
    def test_sdlc_plugin_has_no_marketplace_homepage(self) -> None:
        import json

        pack_path = (
            ROOT.parent
            / "silver-deep-research"
            / "reference"
            / "landscape"
            / "category-packs"
            / "agentic-sdlc-process-orchestrator.json"
        )
        pack = json.loads(pack_path.read_text(encoding="utf-8"))
        homepage = (pack.get("homepage_by_slug") or {}).get("sdlc-plugin")
        self.assertTrue(
            homepage is None or homepage == "",
            msg=f"sdlc-plugin must not invent marketplace homepage, got {homepage!r}",
        )
        self.assertEqual((pack.get("homepage_by_slug") or {}).get("zuvo"), "https://zuvo.dev/")
        self.assertEqual(
            (pack.get("github_by_slug") or {}).get("zuvo"),
            "https://github.com/greglas75/zuvo",
        )

    def test_false_zuvo_github_urls_rewrite_to_greglas75(self) -> None:
        import sys

        sys.path.insert(0, str(ROOT / "scripts"))
        from vendor_link_labels import rewrite_vendor_url

        self.assertEqual(
            rewrite_vendor_url("https://github.com/zuvo-ai/zuvo"),
            "https://github.com/greglas75/zuvo",
        )
        self.assertEqual(
            rewrite_vendor_url("https://github.com/zuvo-labs/zuvo"),
            "https://github.com/greglas75/zuvo",
        )
        self.assertEqual(
            rewrite_vendor_url("https://github.com/greglas75/zuvo"),
            "https://github.com/greglas75/zuvo",
        )

    def test_parked_marketing_domains_rewrite_to_github(self) -> None:
        import json
        import sys

        sys.path.insert(0, str(ROOT / "scripts"))
        from vendor_link_labels import rewrite_vendor_url

        self.assertEqual(
            rewrite_vendor_url("https://cc10x.dev/"),
            "https://github.com/romiluz13/cc10x",
        )
        self.assertEqual(
            rewrite_vendor_url("https://cavekit.ai/"),
            "https://github.com/JuliusBrussee/cavekit",
        )
        self.assertEqual(
            rewrite_vendor_url("https://barkain.com/"),
            "https://github.com/barkain/claude-code-workflow-orchestration",
        )
        pack_path = (
            ROOT.parent
            / "silver-deep-research"
            / "reference"
            / "landscape"
            / "category-packs"
            / "agentic-sdlc-process-orchestrator.json"
        )
        pack = json.loads(pack_path.read_text(encoding="utf-8"))
        homepage = pack.get("homepage_by_slug") or {}
        self.assertEqual(homepage.get("cc10x"), "https://github.com/romiluz13/cc10x")
        self.assertEqual(homepage.get("cavekit-v31"), "https://github.com/JuliusBrussee/cavekit")
        self.assertEqual(
            homepage.get("barkain-workflow-orchestrator"),
            "https://github.com/barkain/claude-code-workflow-orchestration",
        )


if __name__ == "__main__":
    unittest.main()
